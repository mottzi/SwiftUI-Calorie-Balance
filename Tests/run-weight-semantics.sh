#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
test_dir=$(mktemp -d /tmp/count-weight-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -parse-as-library -DWEIGHT_CHART_TESTS \
    "$repo_dir/Count.kcal/Abstract/WeightHistory.swift" \
    "$repo_dir/Count.kcal/Abstract/System/Extensions.swift" \
    "$repo_dir/Count.kcal/Development/WeightChartScenario.swift" \
    "$repo_dir/Tests/WeightHistorySemantics.swift" \
    -o "$test_dir/weight-semantics"
for chart_test_timezone in Europe/Zurich America/New_York Asia/Kathmandu Pacific/Auckland UTC; do
    print -r -- "Timezone: $chart_test_timezone"
    TZ="$chart_test_timezone" "$test_dir/weight-semantics"
done
