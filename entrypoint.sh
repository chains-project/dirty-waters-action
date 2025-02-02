#!/bin/bash
set -e

# Check if GITHUB_TOKEN is set
if [ -z "$INPUT_GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN is not set"
    exit 1
fi

# Extract inputs from environment variables (GitHub Actions sets these automatically)
GITHUB_TOKEN="${INPUT_GITHUB_TOKEN}"
export GITHUB_API_TOKEN=$GITHUB_TOKEN
DIRTY_WATERS_VERSION="${INPUT_DIRTY_WATERS_VERSION}"
PROJECT_REPO="${INPUT_PROJECT_REPO}"
VERSION_OLD="${INPUT_VERSION_OLD}"
VERSION_NEW="${INPUT_VERSION_NEW}"
DIFFERENTIAL_ANALYSIS="${INPUT_DIFFERENTIAL_ANALYSIS}"
PACKAGE_MANAGER="${INPUT_PACKAGE_MANAGER}"
# TODO: pnpm-scope
NAME_MATCH="${INPUT_NAME_MATCH}"
SPECIFIED_SMELLS="${INPUT_SPECIFIED_SMELLS}"
DEBUG="${INPUT_DEBUG}"

cd /app/dirty-waters/
# Checkout to the desired version of Dirty Waters if provided
if [ -n "$DIRTY_WATERS_VERSION" ]; then
    git checkout "$DIRTY_WATERS_VERSION"
fi
# Change to the tool directory
cd tool/

# Build the command
CMD="python main.py -p ${PROJECT_REPO} -v ${VERSION_OLD} -s -pm ${PACKAGE_MANAGER}"

# Add differential analysis if version_new is provided
if [ -n "$DIFFERENTIAL_ANALYSIS" ]; then
    CMD="$CMD -vn ${VERSION_NEW} -d"
fi

# TODO: Add pnpm-scope if provided

# Add name matching if provided
if [ -n "$NAME_MATCH" ]; then
    CMD="$CMD -n"
fi

# Add specified smells if provided
if [ -n "$SPECIFIED_SMELLS" ]; then
    CMD="$CMD ${SPECIFIED_SMELLS}"
fi

# Add debug flag if provided
if [ "$DEBUG" = true ]; then
    CMD="$CMD --debug"
fi

echo "Running command: $CMD"
eval $CMD

# Check if any reports were generated
if [ ! -d "results" ]; then
    echo "An error occurred: no reports were generated"
    exit 1
fi

# Get the latest reports
latest_static_report=$(ls -t results/*_static_summary.md | head -n1)
latest_diff_report=$(ls -t results/*_diff_summary.md | head -n1 || false)

# Prepare the comment content
COMMENT="## Dirty Waters Analysis Results\n\n"
if [ -n "$latest_diff_report" ]; then
    COMMENT+="### Differential Analysis\n"
    COMMENT+=$(cat "$latest_diff_report")
else
    COMMENT+="### Static Analysis\n"
    COMMENT+=$(cat "$latest_static_report")
fi

# Get PR number if we're in a PR
PR_NUMBER=$(jq -r ".pull_request.number" "$GITHUB_EVENT_PATH")

if [ "$PR_NUMBER" != "null" ]; then
    # Post comment to PR
    curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"body\":\"$COMMENT\"}" \
        "https://api.github.com/repos/$PROJECT_REPO/issues/$PR_NUMBER/comments"
elif [ "$INPUT_COMMENT_ON_COMMIT" == "true" ]; then
    # Check if there are high severity issues
    if [[ $(cat "$latest_static_report" | grep -o "(⚠️⚠️⚠️): [0-9]*" | grep -o "[0-9]*" | sort -nr | head -n1) -gt 0 ]]; then
        # Get the commit SHA
        COMMIT_SHA=$(git rev-parse HEAD)
        # Post comment on commit
        curl -s -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"body\":\"$COMMENT\"}" \
            "https://api.github.com/repos/$PROJECT_REPO/commits/$COMMIT_SHA/comments"
    fi
fi

# Move reports to GitHub workspace
mv results/* $GITHUB_WORKSPACE/

# Check for high severity issues if enabled
if [ "$INPUT_FAIL_ON_HIGH_SEVERITY" == "true" ]; then
    # Check for pattern "(⚠️⚠️⚠️): <number>", which may occur more than once. If any of the occurrences is greater than 0, fail the build
    if [[ $(cat "$latest_static_report" | grep -o "(⚠️⚠️⚠️): [0-9]*" | grep -o "[0-9]*" | sort -nr | head -n1) -gt 0 ]]; then
        echo "High severity issues found. Failing the build"
        exit 1
    fi
fi

# For the remaining issues, we fail the build if INPUT_X_TO_FAIL is surpassed
# First, we get the total number of packages, via searching for "Total packages in the supply chain: <number>"
total_packages=$(cat "$latest_static_report" | grep -o "Total packages in the supply chain: [0-9]*" | grep -o "[0-9]*")
# Then, for each severity level, we check if the number of issues surpasses the percentage threshold (INPUT_X_TO_FAIL)
# If it does, we fail the build

# Get the number of issues for each severity level
for severity in "⚠️⚠️" "⚠️"; do
    # For all occurrences of the pattern, we check if the number of issues surpasses the threshold\
    # If it does, we fail the build
    for count in $(cat "$latest_static_report" | grep -o "($severity): [0-9]*" | grep -o "[0-9]*"); do
        if [[ $(echo "scale=2; $count / $total_packages * 100" | bc) -gt $INPUT_X_TO_FAIL ]]; then
            echo "Number of $severity issues surpasses the threshold. Failing the build"
            exit 1
        fi
    done
done

echo "Analysis completed successfully"
exit 0
