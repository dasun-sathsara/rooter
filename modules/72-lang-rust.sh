# Installs Rust for the target user through rustup-init.
# Touches only user-level rustup/cargo directories under the target home.
# Idempotent: existing rustup is updated to stable.

module_id() { echo "lang-rust"; }
module_label() { echo "Install Rust"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  [[ -n ${NEW_USER:-} ]] || die "NEW_USER is required."
  apt_install curl ca-certificates build-essential
  if as_user "$NEW_USER" "command -v rustup >/dev/null 2>&1"; then
    as_user "$NEW_USER" "rustup update stable"
  else
    as_user "$NEW_USER" "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile default --default-toolchain stable"
  fi
}
