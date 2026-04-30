#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[..] %s\n' "$*"; }
ok() { printf '[ok] %s\n' "$*"; }
warn() { printf '[!!] %s\n' "$*" >&2; }
die() {
  printf '[xx] %s\n' "$*" >&2
  exit 1
}

prompt_input() {
  local prompt=$1 default=${2:-}
  gum input --prompt "$prompt: " --value "$default"
}

prompt_confirm() {
  local prompt=$1
  gum confirm "$prompt"
}

choose_many() {
  gum choose --no-limit "$@"
}

choose_one() {
  gum choose "$@"
}
