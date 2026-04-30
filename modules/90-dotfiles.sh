# Applies the repo's public dotfiles to the target user's home with GNU stow.
# Touches symlinks under /home/<user> and reads packages from dotfiles/.
# Idempotent: stow restows packages and adopts matching existing files.

module_id() { echo "dotfiles"; }
module_label() { echo "Apply dotfiles"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  [[ -n ${NEW_USER:-} ]] || die "NEW_USER is required."
  [[ -n ${ROOT_DIR:-} ]] || die "ROOT_DIR is required."

  apt_install stow
  user_home=$(getent passwd "$NEW_USER" | cut -d: -f6)
  [[ -d $ROOT_DIR/dotfiles ]] || die "Missing dotfiles directory."
  find "$ROOT_DIR/dotfiles" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort |
    while IFS= read -r pkg; do
      [[ -n $pkg ]] || continue
      if ! find "$ROOT_DIR/dotfiles/$pkg" -type f ! -name .gitkeep -print -quit | grep -q .; then
        warn "Skipping empty dotfiles package: $pkg"
        continue
      fi
      chown -R "$NEW_USER:$NEW_USER" "$ROOT_DIR/dotfiles/$pkg"
      as_user "$NEW_USER" "cd '$ROOT_DIR' && stow -R -t '$user_home' -d dotfiles '$pkg'"
    done
}
