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

  echo "" >&2
  echo "Available compose files:" >&2
  local i=1
  for f in "${yaml_files[@]}"; do
    echo "  ${i}) $(basename "${f}")" >&2
    ((i++))
  done
  echo "" >&2

  local choice
  while true; do
    read -r -p "Select compose file [1-${#yaml_files[@]}]: " choice
    if [[ "${choice}" =~ ^[0-9]+$ ]] && \
       (( choice >= 1 && choice <= ${#yaml_files[@]} )); then
      echo "${yaml_files[$((choice - 1))]}"
      return
    fi
    echo "  Please enter a number between 1 and ${#yaml_files[@]}." >&2
  done
}

COMPOSE_FILE="$(select_compose_file "${1:-}")"
echo "Compose file : $(basename "${COMPOSE_FILE}")"

# ── PODMAN_BASE resolution ────────────────────────────────────────────────────

compose_basename="$(basename "${COMPOSE_FILE}")"

# Resolve PODMAN_BASE: use built-in defaults if not already set
if [[ -z "${PODMAN_BASE:-}" ]]; then
  case "${compose_basename}" in
    compose-orcl.yaml)
      PODMAN_BASE="${HOME}/opt/oracle"
      ;;
    compose-orcl-apex26.yaml)
      PODMAN_BASE="${HOME}/opt/oracle/apex26"
      ;;
    *)
      # Generic fallback: derive from yaml stem (e.g. compose-orcl-apex27 → apex27)
      stem="${compose_basename%.yaml}"
      stem="${stem#compose-orcl-}"
      stem="${stem#compose-}"
      PODMAN_BASE="${HOME}/opt/oracle/${stem}"
      ;;
  esac
fi

echo ""
read -r -p "PODMAN_BASE [${PODMAN_BASE}]: " user_base
if [[ -n "${user_base}" ]]; then
  PODMAN_BASE="${user_base}"
fi
export PODMAN_BASE
echo "PODMAN_BASE  : ${PODMAN_BASE}"

# ── Password prompting ────────────────────────────────────────────────────────

prompt_password() {
  local var_name="$1"
  local prompt_label="$2"
  local value=""

  echo ""
  while true; do
    read -r -s -p "Enter ${prompt_label} (or 'q' to quit): " value
    echo ""
    if [[ "${value}" == "q" || "${value}" == "Q" ]]; then
      echo "Exiting."
      exit 0
    fi
    if [[ -n "${value}" ]]; then
      break
    fi
    echo "  Password cannot be empty."
  done

  export "${var_name}=${value}"
}

if [[ -z "${ORACLE_PWD:-}" ]]; then
  prompt_password "ORACLE_PWD" "ORACLE_PWD"
fi

if [[ -z "${ORDS_PUBLIC_USER_PWD:-}" ]]; then
  prompt_password "ORDS_PUBLIC_USER_PWD" "ORDS_PUBLIC_USER_PWD"
fi

echo "Passwords    : set"

# ── Optional cleanup ──────────────────────────────────────────────────────────

echo ""
read -r -p "Remove existing containers for this stack? [y/N]: " remove_containers
if [[ "${remove_containers}" =~ ^[Yy]$ ]]; then
  echo "  Stopping and removing containers..."
  podman compose -f "${COMPOSE_FILE}" stop  2>/dev/null || true
  podman compose -f "${COMPOSE_FILE}" rm -f 2>/dev/null || true
  echo "  Containers removed."

  read -r -p "Also remove the network? [y/N]: " remove_network
  if [[ "${remove_network}" =~ ^[Yy]$ ]]; then
    echo "  Bringing down network..."
    podman compose -f "${COMPOSE_FILE}" down 2>/dev/null || true
    echo "  Network removed."
  fi
fi

# ── Pre-launch summary ────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────"
echo "  Compose file : $(basename "${COMPOSE_FILE}")"
echo "  PODMAN_BASE  : ${PODMAN_BASE}"
echo "────────────────────────────────────────"
echo ""

# ── APEX download ─────────────────────────────────────────────────────────────

APEX_URL="https://download.oracle.com/otn_software/apex/apex-latest.zip"
APEX_DIR="${PODMAN_BASE}/apex"
APEX_ZIP="${PODMAN_BASE}/apex-latest.zip"

apex_has_content() {
  [[ -d "${APEX_DIR}" ]] && [[ -n "$(ls -A "${APEX_DIR}" 2>/dev/null)" ]]
}

download_apex() {
  mkdir -p "${PODMAN_BASE}"
  echo "  Downloading apex-latest.zip (this may take several minutes)..."
  curl -L -o "${APEX_ZIP}" "${APEX_URL}"
  echo "  Extracting..."
  unzip -o "${APEX_ZIP}" -d "${PODMAN_BASE}"
  rm -f "${APEX_ZIP}"
  echo "  APEX ready in: ${APEX_DIR}"
}

echo ""
if apex_has_content; then
  echo "APEX directory already exists: ${APEX_DIR}"
  read -r -p "Replace with a fresh apex-latest.zip download? [y/N]: " replace_apex
  if [[ "${replace_apex}" =~ ^[Yy]$ ]]; then
    echo "  Removing existing APEX directory..."
    rm -rf "${APEX_DIR}"
    download_apex
  else
    echo "  Keeping existing APEX directory."
  fi
else
  echo "APEX directory not found or empty: ${APEX_DIR}"
  echo "ORDS requires the apex directory to install APEX automatically during build."
  read -r -p "Download apex-latest.zip now? [Y/n]: " download_apex_yn
  if [[ ! "${download_apex_yn}" =~ ^[Nn]$ ]]; then
    download_apex
  else
    echo "  Warning: ORDS will not install APEX without the apex directory."
  fi
fi

# ── Create required directories ───────────────────────────────────────────────

mkdir -p \
  "${PODMAN_BASE}/oradata" \
  "${PODMAN_BASE}/ords/config" \
  "${PODMAN_BASE}/ords/secrets" \
  "${PODMAN_BASE}/apex"

# ── Launch ────────────────────────────────────────────────────────────────────

echo "Starting stack..."
podman compose -f "${COMPOSE_FILE}" up -d
echo ""
echo "Stack is up. ORDS health check may take 1-2 minutes."
echo "Check status: podman compose -f ${COMPOSE_FILE} ps"
