#!/usr/bin/env bash
# Installed as `git` ahead of the real git on PATH (by tf_diagram.sh).
#
# TerraVision clones modules with `git clone --branch <ref>`, which only accepts
# branch/tag names, so modules pinned to a commit SHA fail. This rewrites
#   git clone ... --branch <40-hex-sha> ... <dest>
# into a normal clone followed by `git checkout <sha>`.
# Everything else is passed straight through to the real git.
set -euo pipefail

REAL_GIT="${REAL_GIT:-/usr/bin/git}"

if [ "${1:-}" = "clone" ]; then
  args=("$@")
  out=()
  sha=""
  i=0
  while [ "$i" -lt "${#args[@]}" ]; do
    a="${args[$i]}"
    if [ "$a" = "--branch" ] || [ "$a" = "-b" ]; then
      v="${args[$((i + 1))]:-}"
      if [[ "$v" =~ ^[0-9a-f]{40}$ ]] || [[ "$v" =~ ^[0-9a-f]{64}$ ]]; then
        sha="$v"
        i=$((i + 2))
        continue
      fi
    fi
    out+=("$a")
    i=$((i + 1))
  done

  if [ -n "$sha" ]; then
    "$REAL_GIT" "${out[@]}"
    dest="${out[${#out[@]} - 1]}" # clone destination is the last argument
    exec "$REAL_GIT" -C "$dest" checkout --quiet "$sha"
  fi
fi

exec "$REAL_GIT" "$@"
