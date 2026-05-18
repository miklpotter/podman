# Podman Compose Launcher — Design Spec

**Date:** 2026-05-18
**Status:** Approved

## Overview

A self-contained shell script (`run-compose.sh`) that simplifies running `podman compose` for any Oracle APEX / ORDS stack in this repository. It handles compose file selection, base directory configuration, password prompting, optional pre-run cleanup, and launch — without requiring the user to edit any YAML file or know about environment variables in advance.

## Goals

- Work with both existing compose files and any future ones added to the `compose/` directory
- Allow users to relocate volume data to any path without editing YAML
- Never store passwords in any file
- Be fully self-contained: script + config template live alongside the compose YAMLs

## Files Changed / Created

| File | Action |
| --- | --- |
| `compose/run-compose.sh` | Created — launcher script |
| `compose/podman-compose.env` | Created — optional config template (no passwords) |
| `compose/compose-orcl.yaml` | Updated — volume paths use `${PODMAN_BASE}` |
| `compose/compose-orcl-apex26.yaml` | Updated — volume paths use `${PODMAN_BASE}` |

## PODMAN_BASE Convention

Each compose YAML is updated to reference a single variable `${PODMAN_BASE}` as the root for all bind-mount volumes. The subdirectory structure is normalised across both files:

```text
${PODMAN_BASE}/oradata        — Oracle datafiles
${PODMAN_BASE}/ords/config    — ORDS configuration
${PODMAN_BASE}/ords/secrets   — ORDS credential files
${PODMAN_BASE}/apex           — APEX installation
```

**Built-in defaults per compose file:**

| Compose file | Default PODMAN_BASE |
| --- | --- |
| `compose-orcl.yaml` | `${HOME}/opt/oracle` |
| `compose-orcl-apex26.yaml` | `${HOME}/opt/oracle/apex26` |
| Future files (no mapping) | `${HOME}/opt/oracle/<yaml-stem>` |

The user always confirms or overrides `PODMAN_BASE` interactively before anything runs.

## Config File — `podman-compose.env`

Sourced by the script at startup if present. Ships as a commented-out template. Passwords are **never** stored here — only `PODMAN_BASE`.

```bash
# podman-compose.env
# Uncomment to override the default PODMAN_BASE for this session.
# PODMAN_BASE="${HOME}/opt/oracle"
```

## Script Flow

```text
run-compose.sh
│
├─ 1. Source ./podman-compose.env if present
│
├─ 2. Select compose file
│     ├─ Argument provided → validate it exists, use it
│     └─ No argument → discover *.yaml in script dir, show numbered menu
│
├─ 3. Confirm PODMAN_BASE
│     ├─ Resolve: .env / env export → override; else built-in default
│     └─ Prompt: "PODMAN_BASE [<default>]: " — Enter accepts, type to change
│
├─ 4. Check ORACLE_PWD
│     └─ Not set → prompt securely (hidden input); type 'q' to exit
│
├─ 5. Check ORDS_PUBLIC_USER_PWD
│     └─ Not set → prompt securely (hidden input); type 'q' to exit
│
├─ 6. Optional cleanup
│     ├─ "Remove existing containers? [y/N]"
│     │     yes → podman compose -f <file> stop (silent); podman compose -f <file> rm -f (silent)
│     └─ "Also remove the network? [y/N]"   (only asked if containers removed)
│           yes → podman compose -f <file> down (handles network dependency ordering)
│
├─ 7. Pre-launch summary
│     └─ Print: compose file, PODMAN_BASE, cleanup performed — confirm state before action
│
└─ 8. Create required directories (mkdir -p) then launch
      podman compose -f <file> up -d
```

## Error Handling

| Condition | Behaviour |
| --- | --- |
| Compose file argument not found | Exit immediately with message, before any prompts |
| `podman` not on PATH | Exit immediately with install hint |
| User types `q` at password prompt | Clean exit, no partial state |
| PODMAN_BASE does not exist | Warn, confirm creation, then `mkdir -p` subdirs |
| Containers not running at cleanup | Errors suppressed (`2>/dev/null`), continues silently |

## Security

- Passwords exported into current process only — never written to disk
- `set -euo pipefail` — unexpected errors halt execution
- Password input uses `read -s` (no echo)
- `.env` file intentionally excludes password fields

## Out of Scope

- First-time setup tasks (downloading APEX zip, `chown oradata`) — handled by `setup_dbfree_env.sh`
- Named volume cleanup — named volumes in these YAMLs are declared but unused; bind-mount data on disk is always preserved
- Windows support — script targets macOS/Linux (bash); paths use POSIX conventions
