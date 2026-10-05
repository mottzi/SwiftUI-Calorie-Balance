#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
test_dir=$(mktemp -d /tmp/count-energy-contour-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -parse-as-library \
    "$repo_dir/Count.kcal.complications/GoalProgress.swift" \
    "$repo_dir/Count.kcal.complications/EnergyContour.swift" \
    "$repo_dir/Tests/EnergyContourSemantics.swift" \
    -o "$test_dir/energy-contour"
"$test_dir/energy-contour"
