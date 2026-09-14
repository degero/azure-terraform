#!/usr/bin/env bash
# Wrapper for `terraform init` that picks up this environment's backend.hcl.
# Copy this file alongside backend.hcl into each environments/<name>/ folder.
set -euo pipefail

TARGET_DIR="$(pwd)"
BACKEND_FILE="${TARGET_DIR}/backend.hcl"

if [[ ! -f "${BACKEND_FILE}" ]]; then
  echo "error: backend.hcl not found in ${TARGET_DIR}" >&2
  exit 1
fi

exec terraform -chdir="${TARGET_DIR}" init -backend-config="${BACKEND_FILE}" "$@"
