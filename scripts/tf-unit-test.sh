#!/usr/bin/env bash
# scripts/run-tests.sh
set -uo pipefail

rc=0
while IFS= read -r dir; do
  echo "::group::$dir"
  terraform -chdir="$dir" init -backend=false -input=false || rc=1
  terraform -chdir="$dir" test || rc=1
  echo "::endgroup::"
done < <(find modules modulegroups -name '*.tftest.hcl' -not -path '*/.terraform/*' -exec dirname {} \; | sort -u)

exit $rc
