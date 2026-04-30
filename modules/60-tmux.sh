# Installs tmux and bootstraps TPM under the target user's home directory.
# Touches apt-managed tmux and /home/<user>/.tmux/plugins/tpm.
# Idempotent: existing TPM clones are updated with git pull.

module_id() { echo "tmux"; }
module_label() { echo "Install tmux and TPM"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  [[ -n ${NEW_USER:-} ]] || die "NEW_USER is required."

  apt_install tmux git
  user_home=$(getent passwd "$NEW_USER" | cut -d: -f6)
  install -d -m 0755 -o "$NEW_USER" -g "$NEW_USER" "$user_home/.tmux/plugins"
  if [[ -d $user_home/.tmux/plugins/tpm/.git ]]; then
    as_user "$NEW_USER" "git -C '$user_home/.tmux/plugins/tpm' pull --ff-only"
  else
    as_user "$NEW_USER" "git clone https://github.com/tmux-plugins/tpm '$user_home/.tmux/plugins/tpm'"
  fi
}
