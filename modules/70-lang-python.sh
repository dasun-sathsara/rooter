# Installs uv for the target user via the official installer.
# Touches only user-level uv files under the target user's home directory.
# Idempotent: the official installer updates/reuses an existing installation.

module_id() { echo "lang-python"; }
module_label() { echo "Install Python uv"; }
module_default() { echo "on"; }
module_run() {
  set -Eeuo pipefail
  [[ -n ${NEW_USER:-} ]] || die "NEW_USER is required."
  apt_install curl ca-certificates
  as_user "$NEW_USER" "curl -LsSf https://astral.sh/uv/install.sh | INSTALLER_NO_MODIFY_PATH=1 sh"
}
