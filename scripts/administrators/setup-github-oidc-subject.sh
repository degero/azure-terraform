#!/usr/bin/env bash
set -euo pipefail

# setup-github-oidc-subject
# used to give a fine grained control over OIDC auth
# extending from the default with environment and job_workflow_ref

usage() {
  echo "Usage: $0 [owner/repo]"
  echo
  echo "  [owner/repo]  Optional. A single repo to target."
  echo "                Default (no args): every repo in GITHUB_REPOS (.env)."
  echo
  echo "  Sets the OIDC subject claim customization template, including"
  echo "  repository_owner_id, repository_id, environment, and"
  echo "  job_workflow_ref — required for the environment-scoped and"
  echo "  workflow-pinned federated credentials used elsewhere in this setup."
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

if [[ $# -gt 1 ]]; then
  echo "Error: expected at most one argument (owner/repo)." >&2
  usage
fi

if ! command -v gh &>/dev/null; then
  echo "gh CLI not found. Install from https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "gh CLI is not authenticated (run 'gh auth login')." >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  repos=("$1")
else
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  env_file="$script_dir/.env"

  if [[ ! -f "$env_file" ]]; then
    echo "Missing .env file at $env_file" >&2
    exit 1
  fi

  set -a
  # shellcheck source=.env
  source "$env_file"
  set +a

  : "${GITHUB_REPOS:?GITHUB_REPOS is not set in .env}"
  read -ra repos <<< "$GITHUB_REPOS"
fi

for repo in "${repos[@]}"; do
  if [[ ! "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
    echo "Error: '$repo' is not in owner/repo format — skipping" >&2
    continue
  fi

  echo "=== Setting OIDC subject claim template on $repo ==="

  gh api --method PUT "repos/$repo/actions/oidc/customization/sub" \
    --input - <<'EOF'
{
  "use_default": false,
  "include_claim_keys": ["repository_owner_id", "repository_id", "environment", "job_workflow_ref"]
}
EOF

  echo "  -> confirming:"
  gh api "repos/$repo/actions/oidc/customization/sub"
  echo
done

echo "Done."
