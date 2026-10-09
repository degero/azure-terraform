#!/usr/bin/env bash
# Draw an architecture diagram for a Terraform dir that uses azapi/AVM modules.
#
# Usage: tools/diagram.sh [source_dir] [output_base] [format]
#   tools/diagram.sh ./environments/test docs/architecture svg
#
# Runs fully offline-friendly: dummy Azure credentials, no cloud calls beyond
# the first `terraform init` (providers/modules). Requires: terraform, terravision,
# graphviz, python3. The azapi_annotate.py script must sit next to this one.
set -euo pipefail

SRC="${1:-./environments/test}"
OUT="${2:-docs/architecture}"
FORMAT="${3:-svg}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Dummy credentials so azapi/azurerm can plan without logging in.
export ARM_USE_CLI=false
export ARM_SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:-00000000-0000-0000-0000-000000000000}"
export ARM_TENANT_ID="${ARM_TENANT_ID:-00000000-0000-0000-0000-000000000000}"
export ARM_CLIENT_ID="${ARM_CLIENT_ID:-00000000-0000-0000-0000-000000000000}"
export ARM_CLIENT_SECRET="${ARM_CLIENT_SECRET:-dummy}"
export ARM_SKIP_PROVIDER_REGISTRATION=true

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> terraform plan ($SRC)"
(
  cd "$SRC"
  terraform init -reconfigure -input=false >/dev/null
  terraform plan -input=false -out="$WORK/tfplan" >/dev/null
  terraform show -json "$WORK/tfplan" > "$WORK/plan.json"
)

echo "==> terravision graphdata"
terravision graphdata --source "$SRC" --outfile "$WORK/graph.json" >/dev/null

echo "==> generating annotations from azapi resource types"
python3 "$HERE/azapi_annotate.py" "$WORK/plan.json" "$WORK/graph.json" \
  --title "${DIAGRAM_TITLE:-Architecture}" > "$WORK/terravision.generated.yml"

mkdir -p "$(dirname "$OUT")"
if [ "${KEEP_ANNOTATIONS:-0}" = "1" ]; then
  cp "$WORK/terravision.generated.yml" "$OUT.annotations.yml"
  echo "    saved $OUT.annotations.yml"
fi

echo "==> terravision draw"
terravision draw --source "$SRC" --annotate "$WORK/terravision.generated.yml" \
  --format "$FORMAT" --outfile "$OUT"
