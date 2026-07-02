#!/usr/bin/env bash
# affected_server_targets.sh
#
# Lists Bazel targets tagged 'server' in //examples/... that are transitively
# affected by source-file changes in the last commit (HEAD~1..HEAD).
#
# How it works:
#   1. Collects changed source files via:
#        git diff HEAD~1..HEAD --name-only -- "*.go" "*.py" "*.java" "*.cpp" "*.c" "*.h"
#   2. Passes them to bazel query to find server-tagged targets that depend on
#      those files:
#        ./bazel query "attr(tags, 'server', rdeps(//examples/..., set(<files>)))"
#
# Usage:
#   ./ansible/affected_server_targets.sh [-h | --help]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BAZEL="${WORKSPACE_DIR}/bazel"

# ── Colours ───────────────────────────────────────────────────────────────────
# Diagnostic/progress output goes to stderr so that stdout carries only the
# final bazel target labels (one per line) — safe to consume programmatically.
CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
log()  { echo -e "${CYAN}[affected]${RESET} $*" >&2; }
warn() { echo -e "${YELLOW}[warning]${RESET}  $*" >&2; }
die()  { echo -e "${RED}[error]${RESET}    $*" >&2; exit 1; }

[[ "${1-}" == "-h" || "${1-}" == "--help" ]] && {
    sed -n '/^# Usage:/,/^[^#]/{ /^#/{ s/^# \{0,2\}//; p }; /^[^#]/q }' "$0"
    exit 0
}

# ── Resolve commits ───────────────────────────────────────────────────────────
HEAD_SHA="$(git -C "${WORKSPACE_DIR}" rev-parse --short HEAD)"
PREV_SHA="$(git -C "${WORKSPACE_DIR}" rev-parse --short HEAD~1 2>/dev/null)" \
    || die "Could not resolve HEAD~1 — repository must have at least 2 commits."

log "Diff: ${PREV_SHA}..${HEAD_SHA}  (HEAD~1..HEAD)"

# ── Collect changed source files ──────────────────────────────────────────────
mapfile -t CHANGED_FILES < <(
    git -C "${WORKSPACE_DIR}" diff HEAD~1..HEAD --name-only \
        -- "*.go" "*.py" "*.java" "*.cpp" "*.c" "*.h" 2>/dev/null || true
)

if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
    warn "No supported source files changed in the last commit (*.go *.py *.java *.cpp *.c *.h)."
    exit 0
fi

log "Changed source files (${#CHANGED_FILES[@]}):"
for f in "${CHANGED_FILES[@]}"; do
    echo "    ${f}" >&2
done

# ── Query affected server targets ─────────────────────────────────────────────
# set() accepts workspace-relative paths as Bazel source-file nodes.
FILE_SET="${CHANGED_FILES[*]}"
QUERY="attr(tags, 'server', rdeps(//examples/..., set(${FILE_SET})))"

log "Running bazel query..."
log "  Query: ${QUERY}"

mapfile -t SERVER_TARGETS < <(
    "${BAZEL}" query "${QUERY}" --output=label 2>/dev/null \
        | grep -v '^$' || true
)

if [[ ${#SERVER_TARGETS[@]} -eq 0 ]]; then
    warn "No server-tagged targets are affected by the last commit."
    exit 0
fi

log "Affected server targets (${#SERVER_TARGETS[@]}):"
printf '%s\n' "${SERVER_TARGETS[@]}"
