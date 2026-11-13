#!/usr/bin/env bash
set -euo pipefail

VERSION="${TERRAFORM_DOCS_VERSION:-0.18.0}"
TARGET_DIR="${TARGET_DIR:-${HOME}/.local/bin}"
mkdir -p "$TARGET_DIR"

os_name="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch_name="$(uname -m)"
case "$os_name" in
  linux) asset_os="linux" ;;
  darwin) asset_os="darwin" ;;
  mingw*|msys*|cygwin*) asset_os="windows" ;;
  *)
    echo "Unsupported OS: $os_name" >&2
    exit 1
    ;;
esac

case "$arch_name" in
  x86_64|amd64) asset_arch="amd64" ;;
  arm64|aarch64) asset_arch="arm64" ;;
  *)
    echo "Unsupported architecture: $arch_name" >&2
    exit 1
    ;;
esac

asset_name="terraform-docs-v${VERSION}-${asset_os}-${asset_arch}"

if [ "$asset_os" = "windows" ]; then
  rm -rf /tmp/terraform-docs
  archive_path="/tmp/terraform-docs-${VERSION}-${asset_os}-${asset_arch}.zip"
  curl -sSLo "$archive_path" "https://github.com/terraform-docs/terraform-docs/releases/download/v${VERSION}/${asset_name}.zip"
  unzip -oq "$archive_path" -d /tmp/terraform-docs
  chmod +x /tmp/terraform-docs/terraform-docs.exe
  install -m 0755 /tmp/terraform-docs/terraform-docs.exe "$TARGET_DIR/terraform-docs.exe"
  cat > "$TARGET_DIR/terraform-docs" <<'SH'
#!/usr/bin/env bash
exec "$(dirname "$0")/terraform-docs.exe" "$@"
SH
  chmod +x "$TARGET_DIR/terraform-docs"
else
  archive_path="/tmp/terraform-docs-${VERSION}-${asset_os}-${asset_arch}.tar.gz"
  curl -sSLo "$archive_path" "https://github.com/terraform-docs/terraform-docs/releases/download/v${VERSION}/${asset_name}.tar.gz"
  tar -xzf "$archive_path" -C /tmp terraform-docs
  chmod +x /tmp/terraform-docs
  install -m 0755 /tmp/terraform-docs "$TARGET_DIR/terraform-docs"
fi

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$TARGET_DIR" >> "$GITHUB_PATH"
fi

PATH="$TARGET_DIR:$PATH"
if [ "$asset_os" = "windows" ]; then
  terraform-docs.exe --version
else
  terraform-docs --version
fi
