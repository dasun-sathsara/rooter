#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
IMAGE=rooter-test:ubuntu-24.04
CONTAINER=
TEST_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO2uYnBootstrapSmokeTestOnly000000000000000000000 test@example"

cleanup() {
  if [[ -n ${CONTAINER:-} ]]; then
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

pass() { printf '[pass] %s\n' "$*"; }
fail() {
  printf '[fail] %s\n' "$*" >&2
  exit 1
}

build_image() {
  tmp_dir=$(mktemp -d)
  cp -a "$ROOT_DIR" "$tmp_dir/rooter"
  cat >"$tmp_dir/Dockerfile" <<'DOCKERFILE'
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get install -y sudo openssh-server ca-certificates curl gnupg git \
  && echo 'root:root' | chpasswd \
  && mkdir -p /run/sshd
COPY rooter /opt/rooter
DOCKERFILE
  docker build -t "$IMAGE" "$tmp_dir"
  rm -rf "$tmp_dir"
}

assert_in_container() {
  local label=$1
  shift
  if docker exec "$CONTAINER" "$@"; then
    pass "$label"
  else
    fail "$label"
  fi
}

run_smoke() {
  CONTAINER=$(docker run -d --privileged "$IMAGE" sleep infinity)
  docker exec "$CONTAINER" bash -lc "printf '%s\n' user ssh-harden cli-tools modern-cli dotfiles >/opt/rooter/profiles/docker-smoke.txt"
  docker exec \
    -e BOOTSTRAP_SMOKE_TEST=1 \
    "$CONTAINER" \
    bash /opt/rooter/bootstrap.sh \
    --profile docker-smoke \
    --non-interactive \
    --user testuser \
    --ssh-public-key "$TEST_KEY"

  assert_in_container "user exists" id testuser
  assert_in_container "sudo group includes user" bash -lc "id -nG testuser | tr ' ' '\n' | grep -Fx sudo"
  assert_in_container "passwordless sudo file exists" test -f /etc/sudoers.d/90-testuser
  assert_in_container "authorized_keys populated" test -s /home/testuser/.ssh/authorized_keys
  assert_in_container "ssh hardening drop-in exists" test -f /etc/ssh/sshd_config.d/99-hardening.conf
  assert_in_container "sshd config validates" /usr/sbin/sshd -t
  assert_in_container "cli tool installed" bash -lc "command -v git && command -v stow && command -v jq"
  assert_in_container "zsh dotfile symlinked" test -L /home/testuser/.zshrc
  assert_in_container "gitconfig dotfile symlinked" test -L /home/testuser/.gitconfig
}

command -v docker >/dev/null 2>&1 || fail "docker is required"
build_image
run_smoke
pass "docker smoke profile passed"
