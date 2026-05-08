# Installs Neovim, preferring the stable PPA with a fallback to the
# official pre-built tarball from GitHub releases.
# Idempotent: PPA install is safe on re-run; tarball overwrites cleanly.

module_id() { echo "neovim"; }
module_label() { echo "Install Neovim"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail

  install_ppa() {
    apt_install software-properties-common
    add-apt-repository -y ppa:neovim-ppa/stable
    apt-get update
    if apt-cache policy neovim 2>/dev/null | grep -q 'neovim-ppa'; then
      apt_install neovim
      return 0
    fi
    return 1
  }

  install_github_tarball() {
    local arch url tmp_dir
    case $(dpkg --print-architecture) in
      amd64) arch=x86_64 ;;
      arm64) arch=arm64 ;;
      *) die "Unsupported neovim architecture: $(dpkg --print-architecture)" ;;
    esac
    url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${arch}.tar.gz"
    tmp_dir=$(mktemp -d)
    curl -fsSL "$url" | tar -xz -C "$tmp_dir" || { warn "Failed to download neovim tarball."; rm -rf "$tmp_dir"; return 1; }
    cp -r "$tmp_dir"/nvim-linux-*/bin "$tmp_dir"/nvim-linux-*/lib "$tmp_dir"/nvim-linux-*/share /usr/local/
    rm -rf "$tmp_dir"
  }

  if install_ppa; then
    return 0
  fi
  warn "Neovim PPA unavailable; falling back to GitHub release tarball"
  install_github_tarball || warn "Failed to install neovim from GitHub release"
}
