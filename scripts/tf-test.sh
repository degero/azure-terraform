#!/usr/bin/env bash
# scripts/tf-test.sh
# Usage: tf-test.sh [true|false]   (default: false)
set -uo pipefail

generate_report="${1:-false}"

rc=0
while IFS= read -r dir; do
  echo "::group::$dir"

  test_args=()
  if [[ "$generate_report" == "true" ]]; then
    test_args+=(-junit-xml=results.xml)
  fi

  terraform -chdir="$dir" init -backend=false -input=false || rc=1
  terraform -chdir="$dir" test "${test_args[@]}" || rc=1
  echo "::endgroup::"
done < <(find modules modulegroups tests -name '*.tftest.hcl' -not -path '*/.terraform/*' -exec dirname {} \; | sort -u)

exit $rc
