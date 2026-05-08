# Installs Neovim from official pre-built GitHub release tarballs.
# Overwrites existing installations cleanly in /usr/local.

module_id() { echo "neovim"; }
module_label() { echo "Install Neovim"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  local arch url tmp_dir
  case $(dpkg --print-architecture) in
    amd64) arch=x86_64 ;;
    arm64) arch=arm64 ;;
    *) die "Unsupported neovim architecture: $(dpkg --print-architecture)" ;;
  esac
  
  url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${arch}.tar.gz"
  tmp_dir=$(mktemp -d)
  
  curl -fsSL "$url" | tar -xz -C "$tmp_dir"
  cp -r "$tmp_dir"/nvim-linux-*/bin "$tmp_dir"/nvim-linux-*/lib "$tmp_dir"/nvim-linux-*/share /usr/local/
  rm -rf "$tmp_dir"
}
