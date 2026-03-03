#!/usr/bin/env bash
set -euo pipefail

# Defaults
# these defaults are focused on my (mac) based environment
# change BASE_DIR to suit yours.
BASE_DIR="/Users/${USER}/opt/oracle"
ORADATA_DIR="$BASE_DIR/oradata"
ORDS_CONFIG_DIR="$BASE_DIR/ords_config"
ORDS_SECRETS_DIR="$BASE_DIR/ords_secrets"
APEX_URL="https://download.oracle.com/otn_software/apex/apex-latest.zip"

usage() {
  cat <<EOF
Usage: $0 [-o ORACLE_PWD] [-p ORDS_PUBLIC_USER_PWD] [-z]

Options:
  -o    Oracle password
  -p    ORDS public user password
  -z    Download and unzip apex-latest.zip
  -h    Show this help

If passwords are not provided as options, you will be prompted securely.
EOF
}

ORACLE_PWD=""
ORDS_PUBLIC_USER_PWD=""
DOWNLOAD_APEX=false

while getopts ":o:p:zh" opt; do
  case "$opt" in
    o) ORACLE_PWD="$OPTARG" ;;
    p) ORDS_PUBLIC_USER_PWD="$OPTARG" ;;
    z) DOWNLOAD_APEX=true ;;
    h) usage; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG"; usage; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument."; usage; exit 1 ;;
  esac
done

# Prompt securely if not supplied
if [[ -z "$ORACLE_PWD" ]]; then
  read -r -s -p "Enter ORACLE_PWD: " ORACLE_PWD
  echo
fi

if [[ -z "$ORDS_PUBLIC_USER_PWD" ]]; then
  read -r -s -p "Enter ORDS_PUBLIC_USER_PWD: " ORDS_PUBLIC_USER_PWD
  echo
fi

# Export for current shell process (and child processes)
export ORACLE_PWD
export ORDS_PUBLIC_USER_PWD

mkdir -p "$ORADATA_DIR" "$ORDS_CONFIG_DIR" "$ORDS_SECRETS_DIR"

if [[ "$DOWNLOAD_APEX" == true ]]; then
  curl -L --output-dir "$BASE_DIR" -O "$APEX_URL"
  unzip -o "$BASE_DIR/apex-latest.zip" -d "$BASE_DIR"
  echo "Downloaded and extracted: apex-latest.zip"
else
  echo "Skipping APEX download/unzip (use -z to enable)."
fi

echo "Done."
echo "Directories created under: $BASE_DIR"