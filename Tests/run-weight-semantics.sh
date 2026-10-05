#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
test_dir=$(mktemp -d /tmp/count-weight-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -parse-as-library \
    "$repo_dir/Count.kcal/Abstract/WeightHistory.swift" \
    "$repo_dir/Count.kcal/Abstract/System/Extensions.swift" \
    "$repo_dir/Tests/WeightHistorySemantics.swift" \
    -o "$test_dir/weight-semantics"
TZ=Europe/Zurich "$test_dir/weight-semantics"
