#!/usr/bin/env bash
# run_checks.sh — Cross-platform entry point for Ansible checks.
#
# 1. Detects OS and architecture.
# 2. Ensures ansible-playbook is installed (brew / apt / dnf / yum / pip3).
# 3. Invokes playbook.yml with the project root as extra var.
#
# Supported platforms: macOS x86_64 / arm64, Linux x86_64 / arm64 (aarch64).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

OS="$(uname -s)"
ARCH="$(uname -m)"

# ── Colour helpers ────────────────────────────────────────────────────────────
_info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
_ok()    { printf '\033[1;32m[ OK ]\033[0m  %s\n' "$*"; }
_warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
_error() { printf '\033[1;31m[ERR ]\033[0m  %s\n' "$*" >&2; }

# ── Extend PATH for user-level pip installs ───────────────────────────────────
extend_pip_paths() {
    # Linux: ~/.local/bin
    [[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"

    # macOS: ~/Library/Python/X.Y/bin (try common versions)
    for ver in 3.13 3.12 3.11 3.10 3.9; do
        local candidate="${HOME}/Library/Python/${ver}/bin"
        [[ -d "${candidate}" ]] && export PATH="${candidate}:${PATH}"
    done
}

# ── Check whether ansible-playbook is on PATH ─────────────────────────────────
ansible_available() {
    command -v ansible-playbook &>/dev/null
}

# ── Install Ansible ───────────────────────────────────────────────────────────
install_ansible() {
    _info "ansible-playbook not found on PATH — installing Ansible..."

    case "${OS}" in
        Darwin)
            if command -v brew &>/dev/null; then
                _info "macOS (${ARCH}): installing via Homebrew"
                brew install ansible
            elif command -v pip3 &>/dev/null; then
                _info "macOS (${ARCH}): Homebrew not found, installing via pip3 --user"
                pip3 install --user ansible
                extend_pip_paths
            else
                _error "Neither Homebrew nor pip3 found."
                _error "Install Homebrew (https://brew.sh) or Python 3, then re-run."
                exit 1
            fi
            ;;

        Linux)
            # Normalise arm64/aarch64 label for messages only
            local arch_label="${ARCH}"
            [[ "${ARCH}" == "aarch64" ]] && arch_label="arm64"

            if command -v apt-get &>/dev/null; then
                _info "Linux/${arch_label}: installing via apt-get"
                sudo apt-get update -qq
                sudo apt-get install -y ansible
            elif command -v dnf &>/dev/null; then
                _info "Linux/${arch_label}: installing via dnf"
                sudo dnf install -y ansible
            elif command -v yum &>/dev/null; then
                _info "Linux/${arch_label}: installing via yum"
                sudo yum install -y ansible
            elif command -v pip3 &>/dev/null; then
                _warn "No system package manager matched; falling back to pip3 --user"
                pip3 install --user ansible
                extend_pip_paths
            elif command -v pip &>/dev/null; then
                _warn "No system package manager matched; falling back to pip --user"
                pip install --user ansible
                extend_pip_paths
            else
                _error "No supported package manager or pip found."
                _error "Install Python 3 and pip, then re-run."
                exit 1
            fi
            ;;

        *)
            _error "Unsupported OS: ${OS}"
            exit 1
            ;;
    esac

    # After installation, the binary may live under ~/.local/bin (pip --user)
    extend_pip_paths

    if ! ansible_available; then
        _error "Ansible installation completed but 'ansible-playbook' is still not on PATH."
        _error "PATH searched: ${PATH}"
        exit 1
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
_info "Platform: ${OS} ${ARCH}"

extend_pip_paths   # extend PATH before the first check

if ansible_available; then
    _ok "Ansible already installed: $(ansible-playbook --version | head -1)"
else
    install_ansible
    _ok "Ansible installed: $(ansible-playbook --version | head -1)"
fi

_info "Project root : ${PROJECT_DIR}"
_info "Inventory    : ${SCRIPT_DIR}/inventory.ini"
_info "Playbook     : ${SCRIPT_DIR}/playbook.yml"
echo

# Pass any extra CLI args (e.g. --tags, --skip-tags, -v) through to ansible-playbook
ansible-playbook \
    -i "${SCRIPT_DIR}/inventory.ini" \
    "${SCRIPT_DIR}/playbook.yml" \
    --extra-vars "project_dir=${PROJECT_DIR}" \
    "$@"
