# Installs fnm, Node LTS, pnpm, and Bun for the target user.
# Touches user-level fnm, pnpm, and bun files under the target home.
# Idempotent: installers reuse existing files and LTS/defaults are reasserted.

module_id() { echo "lang-node"; }
module_label() { echo "Install Node via fnm"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  [[ -n ${NEW_USER:-} ]] || die "NEW_USER is required."
  apt_install curl ca-certificates unzip

  bun_asset() {
    case $(dpkg --print-architecture) in
      amd64) echo "bun-linux-x64.zip" ;;
      arm64) echo "bun-linux-aarch64.zip" ;;
      *) die "Unsupported Bun architecture: $(dpkg --print-architecture)" ;;
    esac
  }

  as_user "$NEW_USER" "curl -fsSL https://fnm.vercel.app/install | PROFILE=/dev/null bash -s -- --skip-shell"
  as_user "$NEW_USER" "export PATH=\"\$HOME/.local/share/fnm:\$PATH\"; eval \"\$(fnm env --shell bash)\"; fnm install --lts; fnm default lts-latest"
  as_user "$NEW_USER" "curl -fsSL https://get.pnpm.io/install.sh | ENV=/dev/null SHELL=\$(command -v sh) sh -"
  as_user "$NEW_USER" "tmp_dir=\$(mktemp -d); mkdir -p \"\$HOME/.bun/bin\"; curl -fsSL \"https://github.com/oven-sh/bun/releases/latest/download/$(bun_asset)\" -o \"\$tmp_dir/bun.zip\"; unzip -q -o \"\$tmp_dir/bun.zip\" -d \"\$tmp_dir\"; install -m 0755 \"\$tmp_dir\"/bun-*/bun \"\$HOME/.bun/bin/bun\"; rm -rf \"\$tmp_dir\""
}
