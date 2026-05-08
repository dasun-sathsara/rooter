# Installs modern replacements for common Unix CLI tools from upstream sources.
# Touches /etc/apt sources for eza and release binaries under /usr/local/bin.
# Idempotent: release binaries overwrite cleanly and apt-managed tools update.

module_id() { echo "modern-cli"; }
module_label() { echo "Install modern CLI tools"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  apt_install curl ca-certificates gnupg jq tar bzip2 make

  if [[ ${BOOTSTRAP_SMOKE_TEST:-0} -eq 1 ]]; then
    warn "BOOTSTRAP_SMOKE_TEST=1; skipping latest CLI binary installs."
    return 0
  fi

  github_release_json() {
    local repo=$1
    curl -fsSL "https://api.github.com/repos/$repo/releases/latest"
  }

  github_asset_url() {
    local repo=$1 pattern=$2
    github_release_json "$repo" |
      jq -r --arg pattern "$pattern" 'first(.assets[] | select(.name | test($pattern)) | .browser_download_url) // empty'
  }

  github_latest_tag() {
    local repo=$1
    github_release_json "$repo" | jq -r '.tag_name'
  }

  deb_arch() {
    case $(dpkg --print-architecture) in
      amd64) echo "amd64" ;;
      arm64) echo "arm64" ;;
      *) die "Unsupported deb architecture: $(dpkg --print-architecture)" ;;
    esac
  }

  rust_target_arch() {
    case $(dpkg --print-architecture) in
      amd64) echo "x86_64-unknown-linux-musl" ;;
      arm64) echo "aarch64-unknown-linux-musl" ;;
      *) die "Unsupported Rust binary architecture: $(dpkg --print-architecture)" ;;
    esac
  }

  install_latest_deb() {
    local repo=$1 pattern=$2 name=$3 url tmp_deb
    url=$(github_asset_url "$repo" "$pattern")
    [[ -n $url ]] || { warn "Could not find latest $name release asset."; return 1; }
    tmp_deb=$(mktemp)
    curl -fsSL "$url" -o "$tmp_deb"
    apt_install "$tmp_deb"
    rm -f "$tmp_deb"
  }

  install_eza() {
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc |
      gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg
    printf 'deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main\n' \
      >/etc/apt/sources.list.d/gierens.list
    chmod 0644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    apt-get update
    apt_install eza
  }

  install_zoxide() {
    local target url tmp_dir zoxide_bin
    target=$(rust_target_arch)
    url=$(github_asset_url "ajeetdsouza/zoxide" "^zoxide-[0-9.]+-$target\\.tar\\.gz$")
    [[ -n $url ]] || { warn "Could not find latest zoxide release asset."; return 1; }
    tmp_dir=$(mktemp -d)
    curl -fsSL "$url" | tar -xz -C "$tmp_dir"
    zoxide_bin=$(find "$tmp_dir" -type f -name zoxide -perm -111 -print -quit)
    [[ -n $zoxide_bin ]] || die "zoxide binary missing from release archive."
    install -m 0755 "$zoxide_bin" /usr/local/bin/zoxide
    rm -rf "$tmp_dir"
  }

  install_dua() {
    local target tag
    target=$(rust_target_arch)
    tag=$(github_latest_tag "Byron/dua-cli")
    curl -LSfs https://raw.githubusercontent.com/Byron/dua-cli/master/ci/install.sh |
      sh -s -- --git Byron/dua-cli --target "$target" --crate dua --tag "$tag" --to /usr/local/bin --force
  }

  install_btop() {
    local arch url tmp_dir
    case $(dpkg --print-architecture) in
      amd64) arch=x86_64 ;;
      arm64) arch=aarch64 ;;
      *) die "Unsupported btop architecture: $(dpkg --print-architecture)" ;;
    esac
    url=$(github_asset_url "aristocratos/btop" "^btop-$arch-unknown-linux-musl\\.tbz$")
    [[ -n $url ]] || { warn "Could not find latest btop release asset."; return 1; }
    tmp_dir=$(mktemp -d)
    curl -fsSL "$url" | tar -xj -C "$tmp_dir"
    make -C "$tmp_dir/btop" install PREFIX=/usr/local
    rm -rf "$tmp_dir"
  }

  install_bat() {
    local arch
    arch=$(deb_arch)
    install_latest_deb "sharkdp/bat" "^bat_[0-9.]+_${arch}\\.deb$" "bat"
  }

  install_duf() {
    local arch
    case $(dpkg --print-architecture) in
      amd64) arch=amd64 ;;
      arm64) arch=arm64 ;;
      *) die "Unsupported duf architecture: $(dpkg --print-architecture)" ;;
    esac
    install_latest_deb "muesli/duf" "^duf_[0-9.]+_linux_${arch}\\.deb$" "duf"
  }

  install_bat || warn "Failed to install bat"
  install_eza || warn "Failed to install eza"
  install_zoxide || warn "Failed to install zoxide"
  install_dua || warn "Failed to install dua"
  install_btop || warn "Failed to install btop"
  install_duf || warn "Failed to install duf"
}
