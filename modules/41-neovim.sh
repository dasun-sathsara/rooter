# Installs Neovim from the stable Neovim PPA.
# Touches apt sources through add-apt-repository and apt-managed packages.
# Idempotent: add-apt-repository and apt installs are safe on re-run.

module_id() { echo "neovim"; }
module_label() { echo "Install Neovim"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  apt_install software-properties-common
  add-apt-repository -y ppa:neovim-ppa/stable
  apt-get update
  apt_install neovim
}
