#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
test_dir=$(mktemp -d /tmp/count-complication-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -parse-as-library \
    "$repo_dir/Count.kcal.complications/GoalProgress.swift" \
    "$repo_dir/Tests/ComplicationGoalSemantics.swift" \
    -o "$test_dir/complication-goals"
"$test_dir/complication-goals"
