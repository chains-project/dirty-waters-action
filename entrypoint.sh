#!/bin/bash
set -e

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN is not set"
    exit 1
fi

export GITHUB_API_TOKEN=$GITHUB_TOKEN

# Change to the tool directory
cd /app/dirty-waters/tool

# Extract inputs from environment variables (GitHub Actions sets these automatically)
PROJECT_REPO="${INPUT_PROJECT_REPO}"
VERSION_OLD="${INPUT_VERSION_OLD}"
VERSION_NEW="${INPUT_VERSION_NEW}"
PACKAGE_MANAGER="${INPUT_PACKAGE_MANAGER}"

# Build the command
CMD="python main.py -p ${PROJECT_REPO} -v ${VERSION_OLD} -s -pm ${PACKAGE_MANAGER}"

# Add differential analysis if version_new is provided
if [ -n "$VERSION_NEW" ]; then
    CMD="$CMD -vn ${VERSION_NEW} -d"
fi

echo "Running command: $CMD"
eval $CMD

# Check if any reports were generated
if [ ! -d "results" ]; then
    echo "No reports were generated"
    exit 1
fi

# Get the latest reports
latest_static_report=$(ls -t results/*_static_summary.md | head -n1)
latest_diff_report=$(ls -t results/*_diff_summary.md | head -n1 || true)

# Prepare the comment content
COMMENT="## Dirty Waters Analysis Results\n\n"
COMMENT+="### Static Analysis\n"
COMMENT+=$(cat "$latest_static_report")

if [ -n "$latest_diff_report" ]; then
    COMMENT+="\n\n### Differential Analysis\n"
    COMMENT+=$(cat "$latest_diff_report")
fi

# Post comment if we're in a PR
if [ "$GITHUB_EVENT_NAME" == "pull_request" ]; then
    PR_NUMBER=$(jq -r .pull_request.number "$GITHUB_EVENT_PATH")
    REPO_FULL_NAME=$(jq -r .repository.full_name "$GITHUB_EVENT_PATH")

    # Post comment to PR
    curl -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO_FULL_NAME/issues/$PR_NUMBER/comments" \
        -d "{\"body\":$(echo "$COMMENT" | jq -R -s .)}"
fi

# Move reports to GitHub workspace
mv results/* $GITHUB_WORKSPACE/

# Check for high severity issues if enabled
if [ "$INPUT_FAIL_ON_HIGH_SEVERITY" == "true" ]; then
    high_severity_count=0
    no_source_code=$(grep -c "Packages with no Source Code URL(⚠️⚠️⚠️):" "$latest_static_report" || true)
    github_404=$(grep -c "Packages with Github URLs that are 404(⚠️⚠️⚠️):" "$latest_static_report" || true)
    inaccessible_tags=$(grep -c "Packages with inaccessible GitHub tags(⚠️⚠️⚠️):" "$latest_static_report" || true)

    high_severity_count=$((no_source_code + github_404 + inaccessible_tags))

    if [ $high_severity_count -gt 0 ]; then
        echo "::error::Found $high_severity_count high severity supply chain issues!"
        exit 1
    fi
fi

echo "Analysis completed successfully"
