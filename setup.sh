#!/usr/bin/env bash
# Ensures required host packages are installed before building.
# Called automatically by ./bazel on every invocation (cheap if already satisfied).
#
# To add a requirement, append to REQUIRED_PACKAGES:
#   "package_name:OS:arch"
#   OS   — Linux | Darwin | *
#   arch — arm64 | aarch64 | x86_64 | *

set -euo pipefail

OS="$(uname -s)"
ARCH="$(uname -m)"

# ── Package requirements ─────────────────────────────────────────────────────
REQUIRED_PACKAGES=(
  "libxml2-dev:Linux:arm64"
  "curl:Linux:*"
  "tmux:Darwin:*"
)

# ── Helpers ──────────────────────────────────────────────────────────────────
detect_pkg_manager() {
  if   command -v apt-get &>/dev/null; then echo "apt"
  elif command -v dnf     &>/dev/null; then echo "dnf"
  elif command -v yum     &>/dev/null; then echo "yum"
  elif command -v brew    &>/dev/null; then echo "brew"
  else echo "unknown"
  fi
}

is_installed() {
  local pkg="$1" mgr="$2"
  case "${mgr}" in
    apt)  dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null \
            | grep -q "install ok installed" ;;
    dnf|yum) rpm -q "${pkg}" &>/dev/null ;;
    brew) brew list --formula "${pkg}" &>/dev/null 2>&1 ;;
    *)    return 1 ;;
  esac
}

install_pkg() {
  local pkg="$1" mgr="$2"
  echo "[setup] Installing missing package: ${pkg}" >&2
  case "${mgr}" in
    apt)  apt update && apt install -y "${pkg}" ;;
    dnf)  dnf install -y "${pkg}" ;;
    yum)  yum install -y "${pkg}" ;;
    brew) brew install "${pkg}" ;;
    *)    echo "ERROR: No supported package manager found to install '${pkg}'" >&2; exit 1 ;;
  esac
}

arch_matches() {
  local req="$1"
  case "${req}" in
    "*")            return 0 ;;
    arm64|aarch64)  [[ "${ARCH}" == "arm64" || "${ARCH}" == "aarch64" ]] ;;
    *)              [[ "${ARCH}" == "${req}" ]] ;;
  esac
}

# ── Main ─────────────────────────────────────────────────────────────────────
PKG_MGR="$(detect_pkg_manager)"

for entry in "${REQUIRED_PACKAGES[@]}"; do
  IFS=':' read -r pkg req_os req_arch <<< "${entry}"

  [[ "${req_os}"   != "*" && "${OS}"   != "${req_os}"   ]] && continue
  arch_matches "${req_arch}"                               || continue

  if ! is_installed "${pkg}" "${PKG_MGR}"; then
    install_pkg "${pkg}" "${PKG_MGR}"
  fi
done

# ── macOS-only setup ──────────────────────────────────────────────────────────
if [[ "${OS}" == "Darwin" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  "${SCRIPT_DIR}/setup_buildbuddy.sh"
fi
