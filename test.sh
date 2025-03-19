#!/usr/bin/env bash

latest_report="/home/gaspa/kth/thesis/dirty-waters/results/results_2025-03-16-18-17-19/v11.10.0_static_summary.md"

COMMENT=$(cat "$latest_report")
cat "$latest_report" # Debug purposes: we always paste it in the logs

# Check for CI failure conditions
CI_WILL_FAIL=0

# Check for high severity issues
if [ "true" == "true" ]; then
    echo "[DEBUG] Fails on high severity, checking for any high severity issues"
    if [[ $(cat "$latest_report" | grep -o "(⚠️⚠️⚠️): [0-9]*" | grep -o "[0-9]*" | sort -nr | head -n1) -gt 0 ]]; then
        echo "High severity issues found. CI will fail."
        CI_WILL_FAIL=1
    fi
fi

# function from https://unix.stackexchange.com/questions/137110/comparison-of-decimal-numbers-in-bash
compare() (IFS=" "
  exec awk "BEGIN{if (!($*)) exit(1)}"
)

# Only check for threshold violations if we haven't already decided to fail
if [ $CI_WILL_FAIL -eq 0 ]; then
    echo "[DEBUG] Haven't decided to fail yet, checking for threshold being surpassed"
    total_packages=$(cat "$latest_report" | grep -o "Total packages in the supply chain: [0-9]*" | grep -o "[0-9]*")
    for severity in "⚠️⚠️⚠️" "⚠️⚠️"; do
        for count in $(cat "$latest_report" | grep -o "($severity): [0-9]*" | grep -o "[0-9]*"); do
            echo "[DEBUG] Count for $severity is $count"
            if compare "$(echo "scale=2; $count / $total_packages * 100" | bc) > 5"; then
                echo "Number of $severity issues surpasses the threshold. CI will fail."
                CI_WILL_FAIL=1
                break 2  # Break both loops once we know we'll fail
            fi
        done
    done
fi

# Handle comments only if CI will fail
if [ $CI_WILL_FAIL -eq 1 ]; then
    # Handle commit comments
    if [ "true" == "true" ]; then
        echo "[DEBUG] COmmenting on commit"
    fi
fi

# Copy results
# cp -r results/* "$GITHUB_WORKSPACE/"

# Exit with failure if CI_WILL_FAIL is set
if [ $CI_WILL_FAIL -eq 1 ]; then
  echo "CI will fail"
  exit 1
else 
  echo "CI will pass"
  exit 0
fi