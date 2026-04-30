#!/usr/bin/env bash
set -Eeuo pipefail

install_gum() {
  if cmd_exists gum; then
    return 0
  fi

  mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key |
    gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  printf 'deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *\n' \
    >/etc/apt/sources.list.d/charm.list
  apt-get update
  apt_install gum
}

preflight_run() {
  apt-get update
  apt_install ca-certificates curl gnupg lsb-release sudo
  install_gum
}
