# Installs the base CLI package stack used by the remaining modules.
# Touches only apt-managed packages and no user configuration.
# Idempotent: apt handles already-installed packages.

module_id() { echo "cli-tools"; }
module_label() { echo "Install CLI tools"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  apt_install git stow curl ca-certificates gnupg unzip tar jq ripgrep fd-find fzf htop direnv build-essential bzip2 make
}
