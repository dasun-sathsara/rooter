# Personal Ubuntu Server Setup

This repo bootstraps a fresh Ubuntu 24.04 server for a small personal fleet. It interactively creates a passwordless sudo user, hardens SSH, installs a CLI/dev stack, and applies public dotfiles with GNU stow.

## Quick Start

```bash
git clone <this-repo> server-setup
cd server-setup
sudo bash bootstrap.sh --github-user dasun
# or:
sudo bash bootstrap.sh --ssh-public-key 'ssh-ed25519 AAAA... dasun@server-bootstrap'
```

## New Cloud Server SSH Setup

Create or choose an SSH key on your workstation first:

```bash
ssh-keygen -t ed25519 -C "dasun@server-bootstrap"
cat ~/.ssh/id_ed25519.pub
```

Either add the public key to GitHub under **Settings -> SSH and GPG keys** and run with `--github-user`, or paste the public key directly with `--ssh-public-key`. The bootstrap user module writes the selected keys to `/home/<user>/.ssh/authorized_keys`, and the SSH hardening module refuses to run if that file is empty.

When creating a new Ubuntu 24.04 cloud VM, add the same public key in the provider's SSH key field. Boot the server, connect as the provider's initial user, then copy or clone this repo:

```bash
ssh root@SERVER_IP
# or: ssh ubuntu@SERVER_IP
sudo apt-get update
sudo apt-get install -y git
git clone <this-repo> server-setup
cd server-setup
sudo bash bootstrap.sh --profile minimal --github-user dasun
# or paste a public key directly:
sudo bash bootstrap.sh --profile minimal --ssh-public-key 'ssh-ed25519 AAAA... dasun@server-bootstrap'
```

Before disconnecting, open a second terminal and verify the new user can log in:

```bash
ssh dasun@SERVER_IP
sudo -n true
```

Only close the original session after the second SSH session works. SSH hardening keeps port `22`, disables password auth and root login, and writes `AllowUsers dasun` by default.

## Flags And Environment

| Flag | Environment | Default | Description |
| --- | --- | --- | --- |
| `--user <name>` | `NEW_USER` | `dasun` | User to create and configure. |
| `--ssh-port <port>` | `SSH_PORT` | `22` | SSH port written to the hardening drop-in. |
| `--github-user <name>` | `GITHUB_USER` | prompt | Fetches keys from `https://github.com/<name>.keys`. |
| `--ssh-public-key <key>` | `SSH_PUBLIC_KEY` | prompt | Adds a pasted SSH public key directly to `authorized_keys`. |
| `--profile <name>` | none | none | Reads module IDs from `profiles/<name>.txt`. |
| `--non-interactive` | none | off | Disables prompts; requires `--profile` and all required config. |
| `--dry-run` | `DRY_RUN` | `0` | Shows selected modules without running them. |
| `--list` | none | off | Lists discovered modules. |
| none | `GO_VERSION` | `1.22.5` | Go version installed by `modules/71-lang-go.sh`. |
| none | `BOOTSTRAP_TEST_PUBLIC_KEY` | none | Test-only key injected into `authorized_keys`. |
| none | `BOOTSTRAP_SMOKE_TEST` | `0` | Test-only mode that skips latest CLI binary installs in Docker smoke tests. |

CLI flags win over environment variables. If neither a GitHub user nor a public key is provided, interactive runs ask which SSH key mode to use; `--non-interactive` requires one of those inputs up front.

## Profiles

Profiles are newline-delimited module IDs in `profiles/*.txt`. Blank lines and `#` comments are ignored.

`minimal.txt` includes `user`, `ssh-harden`, `cli-tools`, `modern-cli`, `zsh`, and `dotfiles`.

`dev.txt` includes everything in `minimal.txt` plus Neovim, tmux, Python uv, Go, Rust, Node via fnm, pnpm, and Bun. Docker is intentionally excluded.

To add a profile, create a new `profiles/<name>.txt` containing module IDs in the order you want them selected. Execution still follows module filename order.

## Modules

| ID | File | Description |
| --- | --- | --- |
| `user` | `modules/10-user.sh` | Creates the sudo user, passwordless sudoers file, and `authorized_keys`. |
| `ssh-harden` | `modules/20-ssh-harden.sh` | Writes SSH hardening drop-in and installs fail2ban. |
| `cli-tools` | `modules/40-cli-tools.sh` | Installs base apt CLI packages. |
| `modern-cli` | `modules/42-modern-cli.sh` | Installs `bat`, `eza`, `zoxide`, `dua`, `btop`, and `duf` from upstream/latest sources. |
| `neovim` | `modules/41-neovim.sh` | Installs Neovim from `ppa:neovim-ppa/stable`. |
| `zsh` | `modules/50-zsh.sh` | Installs zsh and oh-my-zsh without replacing your `.zshrc`. |
| `tmux` | `modules/60-tmux.sh` | Installs tmux and TPM. |
| `lang-python` | `modules/70-lang-python.sh` | Installs uv with the official installer. |
| `lang-go` | `modules/71-lang-go.sh` | Installs pinned Go into `/usr/local/go`. |
| `lang-rust` | `modules/72-lang-rust.sh` | Installs stable Rust with rustup. |
| `lang-node` | `modules/73-lang-node.sh` | Installs fnm, Node LTS, pnpm, and Bun. |
| `docker` | `modules/80-docker.sh` | Installs Docker from the official apt repo and adds the user to `docker`. |
| `dotfiles` | `modules/90-dotfiles.sh` | Applies packages from `dotfiles/` with GNU stow. |

## Adding A New Module

Modules are discovered by globbing `modules/*.sh`, sorted by filename, with no central registry. Adding a new module is exactly one new file that defines only these four functions:

```bash
# Installs or configures one focused feature.
# Touches the paths or services listed here.
# Idempotency notes go here.

module_id() { echo "example"; }
module_label() { echo "Example module"; }
module_default() { echo "off"; }
module_run() {
  set -Eeuo pipefail
  log "Doing work"
  apt_install example-package
  ensure_line_in_file "/etc/profile.d/example.sh" "export EXAMPLE=1"
}
```

Use `module_id` in profiles and `module_label` for the interactive menu. Module files may define local helper logic inside `module_run`; do not add top-level side effects.

## Adding A Language Toolchain

Use `modules/7x-lang-*.sh` as the pattern. Keep the toolchain user-local when possible, pin system-wide tarball versions with an env var, and make re-runs update or skip existing installs cleanly.

The Node module uses fnm for Node LTS, pnpm's standalone installer, and Bun's official GitHub release zip. Startup paths for fnm, pnpm, Bun, uv, and cargo live in the managed zsh dotfiles so installers do not need to own shell rc files.

Reference installer docs: [Bun installation](https://bun.com/docs/installation), [pnpm installation](https://pnpm.io/installation), [uv installation](https://docs.astral.sh/uv/getting-started/installation/), [rustup](https://rustup.rs/), and [fnm](https://github.com/Schniz/fnm).

## Dotfiles Layout

Each top-level directory in `dotfiles/` is one stow package. From the repo root, `stow -t "$HOME" -d dotfiles zsh` maps `dotfiles/zsh/.zshrc` to `$HOME/.zshrc`, while `dotfiles/nvim/.config/nvim/init.lua` maps to `$HOME/.config/nvim/init.lua`.

Seeded from this machine: zsh, tmux, git, nvim, yazi, zellij, and fish configs where present. Empty starter packages have `.gitkeep` placeholders and are skipped by the dotfiles module.

Starter dotfiles to add when needed: any package you want to manage with stow under `dotfiles/<pkg>/`.

Ambiguous `.config` directories were not copied automatically: `gh`, `htop`, `superfile`, `zed`, desktop settings, app caches, and machine-specific system config.

## Docker Tests

Run:

```bash
bash test/docker-test.sh
```

The Docker test intentionally uses a small smoke profile: `user`, `ssh-harden`, `cli-tools`, `modern-cli`, and `dotfiles`. It sets `BOOTSTRAP_SMOKE_TEST=1`, so it does not install every language runtime or latest-release CLI binary in containers.

## Known Caveats

Log out and back in for shell and group membership changes to take effect.

SSH hardening refuses to run if the target user has an empty `authorized_keys`; still verify a second SSH session before disconnecting the current one.

Containers do not behave exactly like real systemd hosts. The SSH module validates with `sshd -t` and falls back from `systemctl` to `service` or validation-only behavior in containers.
