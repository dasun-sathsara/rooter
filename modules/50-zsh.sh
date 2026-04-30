# Installs zsh, installs oh-my-zsh for the target user, and changes their shell.
# Touches /home/<user>/.oh-my-zsh and the user's login shell.
# Idempotent: existing oh-my-zsh directories are updated instead of replaced.

module_id() { echo "zsh"; }
module_label() { echo "Install zsh"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  [[ -n ${NEW_USER:-} ]] || die "NEW_USER is required."

  apt_install zsh git curl
  user_home=$(getent passwd "$NEW_USER" | cut -d: -f6)
  if [[ -d $user_home/.oh-my-zsh/.git ]]; then
    as_user "$NEW_USER" "git -C '$user_home/.oh-my-zsh' pull --ff-only"
  else
    as_user "$NEW_USER" "RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
  fi
  chsh -s "$(command -v zsh)" "$NEW_USER"
}
