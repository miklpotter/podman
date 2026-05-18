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

# ── Compose file selection ────────────────────────────────────────────────────

select_compose_file() {
  local arg="${1:-}"

  if [[ -n "${arg}" ]]; then
    # Argument provided — resolve relative to script dir if not absolute
    if [[ "${arg}" != /* ]]; then
      arg="${SCRIPT_DIR}/${arg}"
    fi
    if [[ ! -f "${arg}" ]]; then
      echo "Error: compose file not found: ${arg}"
      exit 1
    fi
    echo "${arg}"
    return
  fi

  # No argument — discover *.yaml files in script dir
  local -a yaml_files=()
  while IFS= read -r -d '' f; do
    yaml_files+=("$f")
  done < <(find "${SCRIPT_DIR}" -maxdepth 1 -name '*.yaml' -print0 | sort -z)

  if [[ ${#yaml_files[@]} -eq 0 ]]; then
    echo "Error: no *.yaml files found in ${SCRIPT_DIR}"
    exit 1
  fi

  if [[ ${#yaml_files[@]} -eq 1 ]]; then
    echo "${yaml_files[0]}"
    return
  fi

  echo ""
  echo "Available compose files:"
  local i=1
  for f in "${yaml_files[@]}"; do
    echo "  ${i}) $(basename "${f}")"
    ((i++))
  done
  echo ""

  local choice
  while true; do
    read -r -p "Select compose file [1-${#yaml_files[@]}]: " choice
    if [[ "${choice}" =~ ^[0-9]+$ ]] && \
       (( choice >= 1 && choice <= ${#yaml_files[@]} )); then
      echo "${yaml_files[$((choice - 1))]}"
      return
    fi
    echo "  Please enter a number between 1 and ${#yaml_files[@]}."
  done
}

COMPOSE_FILE="$(select_compose_file "${1:-}")"
echo "Compose file : $(basename "${COMPOSE_FILE}")"
