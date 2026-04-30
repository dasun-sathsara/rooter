# Installs a pinned Go toolchain tarball into /usr/local/go.
# Touches /usr/local/go and /etc/profile.d/go-path.sh.
# Idempotent: matching installed versions are skipped; changed versions replace Go.

module_id() { echo "lang-go"; }
module_label() { echo "Install Go"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  [[ -n ${GO_VERSION:-} ]] || die "GO_VERSION is required."

  arch=$(uname -m)
  case $arch in
    x86_64) go_arch=amd64 ;;
    aarch64 | arm64) go_arch=arm64 ;;
    *) die "Unsupported Go architecture: $arch" ;;
  esac

  if [[ -x /usr/local/go/bin/go ]] && [[ $(/usr/local/go/bin/go version) == *"go$GO_VERSION "* ]]; then
    return 0
  fi

  apt_install curl ca-certificates tar
  tmp_tar=$(mktemp)
  curl -fsSL "https://go.dev/dl/go$GO_VERSION.linux-$go_arch.tar.gz" -o "$tmp_tar"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "$tmp_tar"
  rm -f "$tmp_tar"
  printf 'export PATH="/usr/local/go/bin:$PATH"\n' >/etc/profile.d/go-path.sh
}
