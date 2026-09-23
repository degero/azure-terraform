#!/usr/bin/env bash
set -euo pipefail

VERSION="${TERRAFORM_DOCS_VERSION:?TERRAFORM_DOCS_VERSION not set}"

curl -sSLo /tmp/terraform-docs.tar.gz \
  "https://github.com/terraform-docs/terraform-docs/releases/download/v${VERSION}/terraform-docs-v${VERSION}-linux-amd64.tar.gz"
tar -xzf /tmp/terraform-docs.tar.gz -C /tmp terraform-docs
chmod +x /tmp/terraform-docs
sudo mv /tmp/terraform-docs /usr/local/bin/terraform-docs
terraform-docs --version
