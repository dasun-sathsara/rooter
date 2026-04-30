#!/usr/bin/env bash
set -Eeuo pipefail

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root."
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

file_exists() {
  [[ -e $1 ]]
}

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

as_user() {
  local user=$1
  shift
  sudo -H -u "$user" bash -lc "$*"
}

ensure_line_in_file() {
  local file=$1 line=$2 marker=${3:-$2}
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fq "$marker" "$file"; then
    printf '%s\n' "$line" >>"$file"
  fi
}

is_container() {
  [[ -f /.dockerenv ]] && return 0
  grep -qaE '(docker|containerd|kubepods|lxc)' /proc/1/cgroup 2>/dev/null
}
