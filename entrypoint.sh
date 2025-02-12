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
PNPM_SCOPE="${INPUT_PNPM_SCOPE}"
NAME_MATCH="${INPUT_NAME_MATCH}"
SPECIFIED_SMELLS="${INPUT_SPECIFIED_SMELLS}"
DEBUG="${INPUT_DEBUG}"
# NO_GRADUAL_REPORT="${INPUT_NO_GRADUAL_REPORT}"
ALLOW_PR_COMMENT="${INPUT_ALLOW_PR_COMMENT}"
COMMENT_ON_COMMIT="${INPUT_COMMENT_ON_COMMIT}"
LATEST_COMMIT_SHA="${INPUT_LATEST_COMMIT_SHA}"

cd /app/dirty-waters/
# Checkout to the desired version of Dirty Waters if provided
if [ -n "$DIRTY_WATERS_VERSION" ]; then
    git checkout "$DIRTY_WATERS_VERSION"
fi
# Change to the tool directory
cd tool/
cp -r $GITHUB_WORKSPACE/tool/cache/ .
# DEBUG: Checking if cache was correctly copied
echo "Printing cache inside GITHUB_WORKSPACE/"
ls -la $GITHUB_WORKSPACE/tool/cache/
echo "Printing cache inside tool/"
ls -la cache/

# Build the command
CMD="python main.py -p ${PROJECT_REPO} -v ${VERSION_OLD} -s -pm ${PACKAGE_MANAGER}"

# Add differential analysis if enabled
if [ "$DIFFERENTIAL_ANALYSIS" == "true" ]; then
    CMD="$CMD -vn ${VERSION_NEW} -d"
fi

# Add name matching if provided
if [ -n "$NAME_MATCH" ]; then
    CMD="$CMD -n"
fi

# Add pnpm_scope if provided
if [ -n "$PNPM_SCOPE" ]; then
    CMD="$CMD --pnpm-scope $PNPM_SCOPE"
fi

# Add specified smells if provided
if [ -n "$SPECIFIED_SMELLS" ]; then
    CMD="$CMD ${SPECIFIED_SMELLS}"
fi

# Add debug flag if provided
if [ "$DEBUG" == "true" ]; then
    CMD="$CMD --debug"
fi

# Add no gradual report flag if provided
if [ "$NO_GRADUAL_REPORT" == "true" ]; then
    CMD="$CMD --no-gradual-report"
fi

echo "Running command: $CMD"
eval $CMD

cp -r cache/ "$GITHUB_WORKSPACE/tool"

# Check if any reports were generated
if [ ! -d "results" ]; then
    echo "An error occurred: no reports were generated"
    exit 1
fi

if [ "$DIFFERENTIAL_ANALYSIS" == "true" ]; then
    latest_diff_report=$(ls -t $PWD/results/*/*_diff_summary.md | head -n1 || false)
    latest_report=$latest_diff_report
else
    latest_static_report=$(ls -t $PWD/results/*/*_static_summary.md | head -n1)
    latest_report=$latest_static_report
fi
#DEBUG PRINT BELOW
echo "Found report at $latest_report"
COMMENT=$(cat "$latest_report")

# We cat the report to the console regardless
cat "$latest_report"

# Get PR number if we're in a PR
PR_NUMBER=$(jq -r ".pull_request.number" "$GITHUB_EVENT_PATH")

if [ "$PR_NUMBER" != "null" && "$ALLOW_PR_COMMENT" == "true" ]; then
    # Post comment to PR
    echo "Commenting on https://api.github.com/repos/$PROJECT_REPO/issues/$PR_NUMBER/comments"
    curl -s -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization : token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$PROJECT_REPO/issues/$PR_NUMBER/comments" \
        -d "{\"body\":\"$COMMENT\"}"
elif [ "$COMMENT_ON_COMMIT" == "true" ]; then
    # Check if there are high severity issues
    echo "Checking if there are high severity issues to comment in commit"
    if [[ $(cat "$latest_report" | grep -o "(⚠️⚠️⚠️) [0-9]*" | grep -o "[0-9]*" | sort -nr | head -n1) -gt 0 ]]; then
        echo "Commenting on $LATEST_COMMIT_SHA"
        # Post comment on commit
        curl -s -X POST \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/$PROJECT_REPO/commits/$LATEST_COMMIT_SHA/comments" \
            -d "{\"body\":\"$COMMENT\"}"
    fi
fi

# Move reports to GitHub workspace
cp -r results/* $GITHUB_WORKSPACE/

# Check for high severity issues if enabled
if [ "$INPUT_FAIL_ON_HIGH_SEVERITY" == "true" ]; then
    # Check for pattern "(⚠️⚠️⚠️): <number>", which may occur more than once. If any of the occurrences is greater than 0, fail the build
    if [[ $(cat "$latest_report" | grep -o "(⚠️⚠️⚠️) [0-9]*" | grep -o "[0-9]*" | sort -nr | head -n1) -gt 0 ]]; then
        echo "High severity issues found. Failing the build"
        exit 1
    fi
fi

# For the remaining issues, we fail the build if INPUT_X_TO_FAIL is surpassed
# First, we get the total number of packages, via searching for "Total packages in the supply chain: <number>"
total_packages=$(cat "$latest_report" | grep -o "Total packages in the supply chain: [0-9]*" | grep -o "[0-9]*")
# Then, for each severity level, we check if the number of issues surpasses the percentage threshold (INPUT_X_TO_FAIL)
# If it does, we fail the build

# Get the number of issues for each severity level
for severity in "⚠️⚠️" "⚠️"; do
    # For all occurrences of the pattern, we check if the number of issues surpasses the threshold\
    # If it does, we fail the build
    for count in $(cat "$latest_report" | grep -o "($severity) [0-9]*" | grep -o "[0-9]*"); do
        if [[ $(echo "scale=2; $count / $total_packages * 100" | bc) -gt $INPUT_X_TO_FAIL ]]; then
            echo "Number of $severity issues surpasses the threshold. Failing the build"
            exit 1
        fi
    done
done

echo "Analysis completed successfully"
exit 0
