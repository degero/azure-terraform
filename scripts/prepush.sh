#!/usr/bin/env bash
# scripts/prepush.sh
# Run the same static checks CI runs, locally, before pushing.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"


echo "==> Terraform fmt check"
terraform fmt -recursive -check

echo "==> Terraform validate"
failed=0
for env_path in environments/*/; do
  env_name=$(basename "$env_path")
  if ! terraform -chdir="$env_path" init -backend=false -input=false > /dev/null; then
    echo "✗ Init failed in $env_name"
    failed=1
    continue
  fi

  if ! terraform -chdir="$env_path" validate; then
    echo "✗ Validation failed in $env_name"
    failed=1
  fi
done

if [[ "$failed" -eq 1 ]]; then
  exit 1
fi

echo "==> Terraform lint (tflint)"
if ! command -v tflint >/dev/null 2>&1; then
  echo "==> tflint (modules)"
  tflint -f compact --recursive --chdir=modules      --config="$REPO_ROOT/.tflint.modules.hcl"
  tflint -f compact --recursive --chdir=modulegroups  --config="$REPO_ROOT/.tflint.modules.hcl"

  echo "==> tflint (environments)"
  tflint -f compact --recursive --chdir=environments
else
  echo "Terraform lint (tflint) not found locally — skipping (will still run in CI)"
fi

echo "==> Checkov"
if command -v checkov >/dev/null 2>&1; then
  checkov -d . --config-file "$REPO_ROOT/.checkov.yaml"
else
  echo "Checkov not found locally — skipping (will still run in CI)"
fi

echo "==> Powershell script lint (Invoke-ScriptAnalyzer)"
if command -v pwsh >/dev/null 2>&1 && pwsh -NoProfile -Command "Get-Module -ListAvailable -Name PSScriptAnalyzer" | grep -q PSScriptAnalyzer; then
  pwsh -c "Invoke-ScriptAnalyzer -Path scripts -Severity Warning -Recurse -EnableExit"
else
  echo "Powershell script lint (Invoke-ScriptAnalyzer) not found locally — skipping (will still run in CI)"
fi

echo "==> Shell script lint (shellcheck)"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning "$(find . -type f -name "*.sh" -not -path "*/.terraform/*")"
else
  echo "Shell script lint (shellcheck) not found locally — skipping (will still run in CI)"
fi

echo "==> Github Actions lint (actionlint)"
if command -v shellcheck >/dev/null 2>&1; then
  actionlint
else
  echo "Github Actions lint (actionlint) not found locally — skipping (will still run in CI)"
fi

echo "==> Prettier check (json, jsonc, yaml, yml, md), cSpell check"
if ! command -v npx >/dev/null 2>&1; then
  npx --no-install cspell lint --no-progress --show-context .
  npx --no-install prettier --write "**/*.{json,jsonc,yaml,yml,md}"
else
  echo "Node not found locally — skipping cSpell and Prettier (will still run in CI)"
fi

echo "==> All checks passed"
