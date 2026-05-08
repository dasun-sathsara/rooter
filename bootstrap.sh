#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
NEW_USER=${NEW_USER:-dasun}
SSH_PORT=${SSH_PORT:-22}
GITHUB_USER=${GITHUB_USER:-}
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY:-}
GO_VERSION=${GO_VERSION:-1.22.5}
PROFILE=
NON_INTERACTIVE=0
DRY_RUN=0
LIST=0

source "$ROOT_DIR/lib/ui.sh"
source "$ROOT_DIR/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: bootstrap.sh [flags]
  --user <name>          User to create/configure, default dasun
  --ssh-port <port>      SSH port, default 22
  --github-user <name>   GitHub username for authorized_keys
  --ssh-public-key <key>  SSH public key to add to authorized_keys
  --profile <name>       Profile from profiles/<name>.txt
  --non-interactive      Do not prompt; requires --profile
  --dry-run              Show selected modules without running them
  --list                 List discovered modules
USAGE
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --user) NEW_USER=$2; shift 2 ;;
    --ssh-port) SSH_PORT=$2; shift 2 ;;
    --github-user) GITHUB_USER=$2; shift 2 ;;
    --ssh-public-key) SSH_PUBLIC_KEY=$2; shift 2 ;;
    --profile) PROFILE=$2; shift 2 ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --list) LIST=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) die "Unknown flag: $1" ;;
  esac
done

require_root
source "$ROOT_DIR/lib/preflight.sh"
preflight_run

mapfile -t MODULE_FILES < <(find "$ROOT_DIR/modules" -maxdepth 1 -type f -name '*.sh' | sort)
[[ ${#MODULE_FILES[@]} -gt 0 ]] || die "No modules found."

module_meta() {
  local file=$1 field=$2
  (
    set -Eeuo pipefail
    source "$file"
    "$field"
  )
}

declare -A MODULE_LABELS=()
declare -A MODULE_FILES_BY_ID=()
declare -A MODULE_DEFAULTS=()
declare -A MODULE_IDS_BY_LABEL=()
MODULE_IDS=()

for file in "${MODULE_FILES[@]}"; do
  id=$(module_meta "$file" module_id)
  label=$(module_meta "$file" module_label)
  default=$(module_meta "$file" module_default)
  MODULE_IDS+=("$id")
  MODULE_LABELS[$id]=$label
  MODULE_FILES_BY_ID[$id]=$file
  MODULE_DEFAULTS[$id]=$default
  MODULE_IDS_BY_LABEL[$label]=$id
done

if [[ $LIST -eq 1 ]]; then
  for id in "${MODULE_IDS[@]}"; do
    printf '%s\t%s\t%s\n' "$id" "${MODULE_DEFAULTS[$id]}" "${MODULE_LABELS[$id]}"
  done
  exit 0
fi

SELECTED_IDS=()
if [[ -n $PROFILE ]]; then
  profile_file="$ROOT_DIR/profiles/$PROFILE.txt"
  [[ -f $profile_file ]] || die "Profile not found: $PROFILE"
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    line=${line//[[:space:]]/}
    [[ -z $line ]] && continue
    [[ -n ${MODULE_FILES_BY_ID[$line]:-} ]] || die "Unknown module in profile $PROFILE: $line"
    SELECTED_IDS+=("$line")
  done <"$profile_file"
elif [[ $NON_INTERACTIVE -eq 1 ]]; then
  die "--non-interactive requires --profile."
else
  choices=()
  for id in "${MODULE_IDS[@]}"; do
    choices+=("${MODULE_LABELS[$id]}")
  done
  mapfile -t picked_labels < <(choose_many "${choices[@]}")
  for label in "${picked_labels[@]}"; do
    SELECTED_IDS+=("${MODULE_IDS_BY_LABEL[$label]}")
  done
fi

[[ ${#SELECTED_IDS[@]} -gt 0 ]] || die "No modules selected."

if [[ -z $GITHUB_USER && -z $SSH_PUBLIC_KEY ]]; then
  [[ $NON_INTERACTIVE -eq 0 ]] || die "--github-user, GITHUB_USER, --ssh-public-key, or SSH_PUBLIC_KEY is required."
  key_source=$(choose_one "Fetch from GitHub" "Paste SSH public key")
  if [[ $key_source == "Fetch from GitHub" ]]; then
    GITHUB_USER=$(prompt_input "GitHub username for SSH keys" "$NEW_USER")
  else
    SSH_PUBLIC_KEY=$(prompt_input "SSH public key")
  fi
fi

export NEW_USER SSH_PORT GITHUB_USER SSH_PUBLIC_KEY GO_VERSION DRY_RUN ROOT_DIR

log "Selected modules: ${SELECTED_IDS[*]}"
if [[ $DRY_RUN -eq 1 ]]; then
  ok "Dry run complete."
  exit 0
fi

for id in "${MODULE_IDS[@]}"; do
  selected=0
  for wanted in "${SELECTED_IDS[@]}"; do
    [[ $id == "$wanted" ]] && selected=1
  done
  [[ $selected -eq 1 ]] || continue
  file=${MODULE_FILES_BY_ID[$id]}
  log "Running ${MODULE_LABELS[$id]}"
  source "$file"
  if ! module_run; then
    warn "Module failed: $id"
  fi
  ok "Finished ${MODULE_LABELS[$id]}"
done

cat <<EOF

Summary
- User: $NEW_USER
- SSH port: $SSH_PORT
- Modules: ${SELECTED_IDS[*]}

Reminders
- Log out and back in for shell and group changes to take effect.
- Verify a second SSH session works before disconnecting the current one.
EOF
