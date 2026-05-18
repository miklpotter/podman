#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/podman-compose.env"

# Source optional config (provides PODMAN_BASE override if set)
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

# Verify podman is available
if ! command -v podman &>/dev/null; then
  echo "Error: 'podman' not found on PATH."
  echo "Install Podman Desktop from https://podman-desktop.io/"
  exit 1
fi
