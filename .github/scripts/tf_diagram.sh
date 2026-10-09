#!/usr/bin/env bash
# Render a Terraform architecture diagram with TerraVision, adding icons/names
# for azapi_resource (Azure Verified Modules), which TerraVision can't map itself.
#
# CI (plan + graph already produced by earlier workflow steps, no extra planning):
#   tf_diagram.sh --tf-dir environments/test --plan environments/test/plan.json \
#                 --graph environments/test/graph.dot --title "Terraform: test" \
#                 --out docs/test-terraform-diagram.svg
#
# Local (plans for you using dummy Azure credentials unless ARM_* are already set;
# your backend must already be local, e.g. via a gitignored backend_override.tf):
#   tf_diagram.sh --tf-dir environments/test --out docs/test.svg
#
# Requires on PATH: terravision, dot (+ neato layout engine), python3, git.
# Also terraform when --plan/--graph are not given.
set -euo pipefail

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
  echo
  echo "Options:"
  echo "  --tf-dir DIR         Terraform root module (required)"
  echo "  --out FILE           output SVG path (required)"
  echo "  --plan FILE          pre-generated 'terraform show -json' output"
  echo "  --graph FILE         pre-generated 'terraform graph' output (needs --plan)"
  echo "  --title TEXT         diagram title (default: Architecture)"
  echo "  --keep-annotations   also save the generated annotation file next to --out"
  exit "${1:-1}"
}

TF_DIR="" OUT="" PLAN="" GRAPH="" TITLE="Architecture" KEEP_ANN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --tf-dir) TF_DIR="${2:?}"; shift 2 ;;
    --out) OUT="${2:?}"; shift 2 ;;
    --plan) PLAN="${2:?}"; shift 2 ;;
    --graph) GRAPH="${2:?}"; shift 2 ;;
    --title) TITLE="${2:?}"; shift 2 ;;
    --keep-annotations) KEEP_ANN=1; shift ;;
    -h | --help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done
[ -n "$TF_DIR" ] && [ -n "$OUT" ] || usage 1
if { [ -n "$PLAN" ] && [ -z "$GRAPH" ]; } || { [ -z "$PLAN" ] && [ -n "$GRAPH" ]; }; then
  echo "ERROR: --plan and --graph must be given together" >&2
  exit 1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
abspath() { (cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd)" "$(basename "$1")"); }

need() { command -v "$1" > /dev/null 2>&1 || { echo "ERROR: '$1' not found on PATH" >&2; exit 1; }; }
need terravision; need dot; need python3; need git
echo 'digraph{a->b}' | neato -Tsvg > /dev/null 2>&1 || {
  echo "ERROR: Graphviz 'neato' layout engine is unavailable." >&2
  echo "       On newer Ubuntu/Debian: sudo apt install libgvplugin-neato-layout8 && sudo dot -c" >&2
  exit 1
}

TF_DIR_ABS="$(cd "$TF_DIR" && pwd)"
mkdir -p "$(dirname "$OUT")"
OUT_ABS="$(abspath "$OUT")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- let TerraVision clone modules that are pinned to a commit SHA ---------------
mkdir -p "$WORK/bin"
REAL_GIT="$(command -v git)"
export REAL_GIT
cp "$HERE/git-sha-shim.sh" "$WORK/bin/git"
chmod +x "$WORK/bin/git"
export PATH="$WORK/bin:$PATH"
export GIT_PYTHON_GIT_EXECUTABLE="$WORK/bin/git"

# --- plan + graph (only when not supplied, i.e. local runs) ----------------------
if [ -z "$PLAN" ]; then
  need terraform
  echo "==> planning $TF_DIR (local run)"
  export ARM_USE_CLI="${ARM_USE_CLI:-false}"
  export ARM_SKIP_PROVIDER_REGISTRATION="${ARM_SKIP_PROVIDER_REGISTRATION:-true}"
  export ARM_SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:-00000000-0000-0000-0000-000000000000}"
  export ARM_TENANT_ID="${ARM_TENANT_ID:-00000000-0000-0000-0000-000000000000}"
  export ARM_CLIENT_ID="${ARM_CLIENT_ID:-00000000-0000-0000-0000-000000000000}"
  export ARM_CLIENT_SECRET="${ARM_CLIENT_SECRET:-dummy}"
  (
    cd "$TF_DIR_ABS"
    terraform init -reconfigure -input=false > /dev/null
    terraform plan -input=false -lock=false -out="$WORK/tfplan" > /dev/null
    terraform show -json "$WORK/tfplan" > "$WORK/plan.json"
    terraform graph > "$WORK/graph.dot"
  )
  PLAN="$WORK/plan.json"
  GRAPH="$WORK/graph.dot"
fi
PLAN="$(abspath "$PLAN")"
GRAPH="$(abspath "$GRAPH")"

# Run a TerraVision subcommand from the pre-generated plan/graph; if that mode isn't
# supported for the subcommand, retry letting TerraVision run terraform itself.
tv() {
  local sub="$1"
  shift
  if terravision "$sub" --source "$TF_DIR_ABS" --planfile "$PLAN" --graphfile "$GRAPH" "$@"; then
    return 0
  fi
  echo "WARNING: 'terravision $sub' failed with --planfile/--graphfile; retrying with live terraform" >&2
  terravision "$sub" --source "$TF_DIR_ABS" "$@"
}

echo "==> reading the node graph TerraVision builds"
tv graphdata --outfile "$WORK/graph.json" > /dev/null

echo "==> inferring icons/labels for azapi resources"
python3 "$HERE/azapi_annotate.py" "$PLAN" "$WORK/graph.json" --title "$TITLE" > "$WORK/annotations.yml"
if [ "$KEEP_ANN" = "1" ]; then
  cp "$WORK/annotations.yml" "${OUT_ABS%.*}.annotations.yml"
  echo "    saved ${OUT_ABS%.*}.annotations.yml"
fi

echo "==> rendering"
RENDER="$WORK/render"
mkdir -p "$RENDER"
# Run from an empty dir: TerraVision's output file naming varies (e.g. *.dot.svg), so
# we find whatever SVG it produced instead of assuming a name.
(cd "$RENDER" && tv draw --annotate "$WORK/annotations.yml" --format svg --outfile diagram)

mapfile -t SVGS < <(find "$RENDER" -type f -name '*.svg' | sort)
if [ "${#SVGS[@]}" -eq 0 ]; then
  echo "ERROR: TerraVision produced no SVG. Files in render dir:" >&2
  ls -la "$RENDER" >&2
  exit 1
fi
if [ "${#SVGS[@]}" -gt 1 ]; then
  echo "WARNING: multiple SVGs produced; using ${SVGS[0]}" >&2
fi
cp "${SVGS[0]}" "$OUT_ABS"
[ -s "$OUT_ABS" ] || { echo "ERROR: $OUT_ABS is empty" >&2; exit 1; }
echo "==> wrote $OUT ($(wc -c < "$OUT_ABS") bytes)"
