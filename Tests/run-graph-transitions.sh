#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
test_dir=$(mktemp -d /tmp/count-graph-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -parse-as-library \
    "$repo_dir/Count.kcal/Abstract/EnergyBalance.swift" \
    "$repo_dir/Count.kcal/Views/CalorieGraph/EnergyGraphValues.swift" \
    "$repo_dir/Tests/EnergyGraphTransitions.swift" \
    -o "$test_dir/graph-transitions"
"$test_dir/graph-transitions"
