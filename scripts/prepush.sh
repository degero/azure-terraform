#!/usr/bin/env bash
# scripts/prepush.sh
# Run the same static checks CI runs, locally, before pushing.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "==> Terraform fmt check"
terraform fmt -recursive -check

echo "==> tflint (modules)"
tflint -f compact --recursive --chdir=modules      --config="$REPO_ROOT/.tflint.modules.hcl"
tflint -f compact --recursive --chdir=modulegroups  --config="$REPO_ROOT/.tflint.modules.hcl"

echo "==> tflint (environments)"
tflint -f compact --recursive --chdir=environments

echo "==> Checkov"
if command -v checkov >/dev/null 2>&1; then
  checkov -d . --config-file "$REPO_ROOT/.checkov.yaml"
else
  echo "checkov not found locally — skipping (will still run in CI)"
fi

echo "==> All checks passed"
