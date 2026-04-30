# Applies SSH hardening through an sshd_config.d drop-in and installs fail2ban.
# Touches /etc/ssh/sshd_config.d/99-hardening.conf and fail2ban packages.
# Idempotent: the drop-in is rewritten safely after validating authorized_keys.

module_id() { echo "ssh-harden"; }
module_label() { echo "Harden SSH"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  [[ -n ${NEW_USER:-} ]] || die "NEW_USER is required."
  [[ -n ${SSH_PORT:-} ]] || die "SSH_PORT is required."
  [[ $SSH_PORT =~ ^[0-9]+$ ]] || die "SSH_PORT must be numeric."
  ((SSH_PORT >= 1 && SSH_PORT <= 65535)) || die "SSH_PORT must be between 1 and 65535."

  id -u "$NEW_USER" >/dev/null 2>&1 || die "Target user does not exist: $NEW_USER"

  user_home=$(getent passwd "$NEW_USER" | cut -d: -f6)
  [[ -n $user_home && -d $user_home ]] || die "Home directory missing for $NEW_USER."
  auth_keys="$user_home/.ssh/authorized_keys"
  [[ -s $auth_keys ]] || die "Refusing SSH hardening: $auth_keys is empty."
  key_count=$(grep -Ec '^[[:space:]]*(ssh-|ecdsa-|sk-)' "$auth_keys" || true)
  ((key_count > 0)) || die "Refusing SSH hardening: no public keys found in $auth_keys."

  apt_install openssh-server fail2ban
  sshd_bin=$(command -v sshd || echo /usr/sbin/sshd)
  [[ -x $sshd_bin ]] || die "sshd binary not found."
  if [[ ! -d /run/sshd ]]; then
    install -d -m 0755 /run/sshd
  fi
  "$sshd_bin" -t
  "$sshd_bin" -T >/dev/null 2>&1 || warn "Could not inspect current effective sshd config before hardening."

  install -d -m 0755 /etc/ssh/sshd_config.d
  cat >/etc/ssh/sshd_config.d/99-hardening.conf <<EOF
Port $SSH_PORT
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers $NEW_USER
MaxAuthTries 3
EOF

  "$sshd_bin" -t
  effective_config=$("$sshd_bin" -T)
  grep -Eq '^pubkeyauthentication yes$' <<<"$effective_config" || die "Effective sshd config did not enable PubkeyAuthentication."
  grep -Eq '^passwordauthentication no$' <<<"$effective_config" || die "Effective sshd config did not disable PasswordAuthentication."
  grep -Eq '^kbdinteractiveauthentication no$' <<<"$effective_config" || die "Effective sshd config did not disable KbdInteractiveAuthentication."
  grep -Eq '^permitrootlogin no$' <<<"$effective_config" || die "Effective sshd config did not disable root login."
  awk -v user="$NEW_USER" '$1 == "allowusers" { for (i = 2; i <= NF; i++) if ($i == user) found = 1 } END { exit found ? 0 : 1 }' \
    <<<"$effective_config" || die "Effective sshd config did not include AllowUsers $NEW_USER."
  grep -Eq '^maxauthtries 3$' <<<"$effective_config" || die "Effective sshd config did not set MaxAuthTries 3."

  if cmd_exists systemctl && ! is_container; then
    systemctl reload ssh || systemctl reload sshd
  elif cmd_exists service; then
    service ssh reload || "$sshd_bin" -t
  else
    "$sshd_bin" -t
  fi

  if cmd_exists systemctl && ! is_container; then
    systemctl enable --now fail2ban || true
  elif cmd_exists service; then
    service fail2ban start || true
  fi
}
