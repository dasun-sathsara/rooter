# Creates the target sudo user, installs passwordless sudo, and installs SSH keys.
# Touches /home/<user>, /etc/sudoers.d/90-<user>, and authorized_keys.
# Idempotent: existing users, sudoers files, and repeated keys are reused.

module_id() { echo "user"; }
module_label() { echo "Create sudo user"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  [[ -n ${NEW_USER:-} ]] || die "NEW_USER is required."
  [[ -n ${GITHUB_USER:-} || -n ${SSH_PUBLIC_KEY:-} || -n ${BOOTSTRAP_TEST_PUBLIC_KEY:-} ]] ||
    die "GITHUB_USER or SSH_PUBLIC_KEY is required."

  if ! id -u "$NEW_USER" >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" "$NEW_USER"
  fi
  usermod -aG sudo "$NEW_USER"

  sudoers_file="/etc/sudoers.d/90-$NEW_USER"
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$NEW_USER" >"$sudoers_file"
  chmod 0440 "$sudoers_file"
  visudo -cf "$sudoers_file" >/dev/null

  user_home=$(getent passwd "$NEW_USER" | cut -d: -f6)
  install -d -m 0700 -o "$NEW_USER" -g "$NEW_USER" "$user_home/.ssh"
  auth_keys="$user_home/.ssh/authorized_keys"
  touch "$auth_keys"
  chmod 0600 "$auth_keys"
  chown "$NEW_USER:$NEW_USER" "$auth_keys"

  tmp_keys=$(mktemp)
  if [[ -n ${BOOTSTRAP_TEST_PUBLIC_KEY:-} ]]; then
    printf '%s\n' "$BOOTSTRAP_TEST_PUBLIC_KEY" >"$tmp_keys"
  elif [[ -n ${SSH_PUBLIC_KEY:-} ]]; then
    printf '%s\n' "$SSH_PUBLIC_KEY" >"$tmp_keys"
  else
    curl -fsSL "https://github.com/$GITHUB_USER.keys" -o "$tmp_keys"
  fi
  if [[ -s $tmp_keys ]]; then
    while IFS= read -r key; do
      [[ -z $key ]] && continue
      grep -Fxq "$key" "$auth_keys" || printf '%s\n' "$key" >>"$auth_keys"
    done <"$tmp_keys"
  fi
  rm -f "$tmp_keys"
  chown "$NEW_USER:$NEW_USER" "$auth_keys"
}
