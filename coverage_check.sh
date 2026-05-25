#!/usr/bin/env bash
# coverage_check.sh
#
# Measures code coverage for lines changed in the last commit (HEAD~1..HEAD),
# per language. Validates that patch coverage >= THRESHOLD (default 75%)
# for every affected language; exits 0 (PASS) or 1 (FAIL).
#
# The diff is derived automatically from the last commit:
#   git diff HEAD~1..HEAD
# No patch file needs to be supplied.
#
# Supported languages: C/C++, Java, Go, Python
# Coverage tool: Bazel's built-in `bazel coverage` (lcov output)
#
# Usage:
#   ./coverage_check.sh [OPTIONS]
#
# Options:
#   --config <cfg>      Bazel platform config  (default: auto-detected)
#                       One of: x86_64 | arm64 | macos_arm64 | macos_x86_64
#   --threshold <pct>   Minimum coverage % required (default: 75)
#   --keep-report       Do not delete the temporary coverage report
#   -h | --help         Show this help
#
# Examples:
#   ./coverage_check.sh --config macos_arm64
#   ./coverage_check.sh --threshold 80

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAZEL="${SCRIPT_DIR}/bazel"

# ── Defaults ──────────────────────────────────────────────────────────────────
BAZEL_CONFIG=""
THRESHOLD=75
KEEP_REPORT=0
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="${SCRIPT_DIR}/coverage_reports/${TIMESTAMP}"
LCOV_MERGED="${REPORT_DIR}/merged_coverage.dat"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { echo -e "${CYAN}[coverage]${RESET} $*"; }
warn() { echo -e "${YELLOW}[warning]${RESET}  $*"; }
die()  { echo -e "${RED}[error]${RESET}    $*" >&2; exit 1; }

usage() {
    sed -n '/^# Usage:/,/^[^#]/{ /^#/{ s/^# \{0,2\}//; p }; /^[^#]/q }' "$0"
    exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)      BAZEL_CONFIG="$2"; shift 2 ;;
        --threshold)   THRESHOLD="$2";   shift 2 ;;
        --keep-report) KEEP_REPORT=1;    shift ;;
        -h|--help)     usage ;;
        *) die "Unknown option: $1  (run with --help for usage)" ;;
    esac
done

# ── Auto-detect Bazel platform config ─────────────────────────────────────────
detect_config() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "${os}" in
        Darwin)
            [[ "${arch}" == "arm64" ]] && echo "macos_arm64" || echo "macos_x86_64" ;;
        Linux)
            [[ "${arch}" == "aarch64" || "${arch}" == "arm64" ]] && echo "arm64" || echo "x86_64" ;;
        *) die "Unsupported OS: ${os}" ;;
    esac
}

if [[ -z "${BAZEL_CONFIG}" ]]; then
    BAZEL_CONFIG="$(detect_config)"
    log "Auto-detected Bazel config: --config=${BAZEL_CONFIG}"
fi

# ── Derive diff from last commit (HEAD~1..HEAD) ───────────────────────────────
CURRENT_BRANCH="$(git -C "${SCRIPT_DIR}" rev-parse --abbrev-ref HEAD)"
HEAD_SHA="$(git -C "${SCRIPT_DIR}" rev-parse --short HEAD)"
PREV_SHA="$(git -C "${SCRIPT_DIR}" rev-parse --short HEAD~1 2>/dev/null)" \
    || die "Could not resolve HEAD~1. Repository must have at least 2 commits."

log "Branch : ${CURRENT_BRANCH}"
log "Diff   : ${PREV_SHA}..${HEAD_SHA}  (HEAD~1..HEAD — last commit)"

PATCH_CONTENT="$(git -C "${SCRIPT_DIR}" diff HEAD~1..HEAD)"

[[ -n "${PATCH_CONTENT}" ]] || die "Diff is empty — last commit introduced no changes."

# ── Parse patch → {file: sorted list of added/changed line numbers} ───────────
# Outputs lines of the form:  <file>:<lineno>
parse_patch_lines() {
    local patch="$1"
    local current_file="" new_start new_count lineno

    while IFS= read -r line; do
        # New file in the patch
        if [[ "${line}" =~ ^\+\+\+\ b/(.+)$ ]]; then
            current_file="${BASH_REMATCH[1]}"
            continue
        fi

        # Hunk header: @@ -old_start,old_count +new_start,new_count @@
        if [[ "${line}" =~ ^@@\ -[0-9]+(,[0-9]+)?\ \+([0-9]+)(,([0-9]+))?\ @@ ]]; then
            new_start="${BASH_REMATCH[2]}"
            new_count="${BASH_REMATCH[4]:-1}"
            lineno="${new_start}"
            continue
        fi

        [[ -z "${current_file}" || -z "${lineno}" ]] && continue

        if [[ "${line}" =~ ^\+ && ! "${line}" =~ ^\+\+\+ ]]; then
            # Added/changed line — record it
            echo "${current_file}:${lineno}"
            (( lineno++ )) || true
        elif [[ ! "${line}" =~ ^- ]]; then
            # Context line — advance new-file pointer
            (( lineno++ )) || true
        fi
        # Removed lines (^-) don't advance the new-file pointer
    done <<< "${patch}"
}

declare -A PATCH_LINES  # key="file:lineno" → 1
declare -A PATCHED_FILES  # key=file → 1

log "Parsing patch..."
while IFS= read -r entry; do
    PATCH_LINES["${entry}"]=1
    PATCHED_FILES["${entry%%:*}"]=1
done < <(parse_patch_lines "${PATCH_CONTENT}")

[[ ${#PATCHED_FILES[@]} -eq 0 ]] && die "No changed source files found in patch."

log "Changed files in patch (${#PATCHED_FILES[@]}):"
for f in "${!PATCHED_FILES[@]}"; do
    echo "    ${f}"
done

# ── Classify changed files by language ────────────────────────────────────────
declare -A LANG_HAS_CHANGES  # lang → 1

for f in "${!PATCHED_FILES[@]}"; do
    case "${f}" in
        *.cc|*.cpp|*.cxx|*.c|*.h|*.hh|*.hpp) LANG_HAS_CHANGES["cc"]=1 ;;
        *.java)                                LANG_HAS_CHANGES["java"]=1 ;;
        *.go)                                  LANG_HAS_CHANGES["go"]=1 ;;
        *.py)                                  LANG_HAS_CHANGES["python"]=1 ;;
    esac
done

if [[ ${#LANG_HAS_CHANGES[@]} -eq 0 ]]; then
    warn "No supported source files changed (C/C++, Java, Go, Python). Nothing to check."
    exit 0
fi

log "Languages with changes: ${!LANG_HAS_CHANGES[*]}"

# ── Map languages to Bazel test targets ───────────────────────────────────────
declare -A LANG_TARGETS=(
    [cc]="//examples/cc/..."
    [java]="//examples/java/..."
    [go]="//examples/go/..."
    [python]="//examples/python/..."
)

# Build target list for only the affected languages
COVERAGE_TARGETS=()
for lang in "${!LANG_HAS_CHANGES[@]}"; do
    COVERAGE_TARGETS+=("${LANG_TARGETS[${lang}]}")
done

# ── Run bazel coverage ────────────────────────────────────────────────────────
mkdir -p "${REPORT_DIR}"

log "Running: ./bazel coverage --config=${BAZEL_CONFIG} --combined_report=lcov ${COVERAGE_TARGETS[*]}"
echo ""

# Bazel writes the merged lcov report to bazel-out/_coverage/_coverage_report.dat
# We capture it after the run.
"${BAZEL}" coverage \
    --config="${BAZEL_CONFIG}" \
    --combined_report=lcov \
    --instrument_test_targets \
    -- "${COVERAGE_TARGETS[@]}" \
    2>&1 | tee "${REPORT_DIR}/bazel_coverage.log" || {
        echo ""
        die "bazel coverage failed — see ${REPORT_DIR}/bazel_coverage.log"
    }

echo ""

# Locate the merged lcov report Bazel produced
BAZEL_COVERAGE_DAT="${SCRIPT_DIR}/bazel-out/_coverage/_coverage_report.dat"
if [[ ! -f "${BAZEL_COVERAGE_DAT}" ]]; then
    # Fall back: aggregate per-test coverage.dat files
    log "Merged report not found at expected path; aggregating per-test reports..."
    > "${LCOV_MERGED}"
    find "${SCRIPT_DIR}/bazel-testlogs" -name "coverage.dat" 2>/dev/null | while read -r dat; do
        cat "${dat}" >> "${LCOV_MERGED}"
    done
    [[ -s "${LCOV_MERGED}" ]] || die "No coverage data found under bazel-testlogs/."
    BAZEL_COVERAGE_DAT="${LCOV_MERGED}"
fi

cp "${BAZEL_COVERAGE_DAT}" "${LCOV_MERGED}"
log "Coverage data: ${LCOV_MERGED}"

# ── Parse lcov report filtered to patch lines ─────────────────────────────────
# lcov format:
#   SF:<source file>
#   DA:<line>,<hit-count>
#   LF:<total instrumented lines>
#   LH:<lines hit>
#   end_of_record

compute_patch_coverage() {
    local lcov_file="$1"
    # Outputs: lang covered total
    local current_sf="" lang
    declare -A lang_covered lang_total

    for l in cc java go python; do
        lang_covered[$l]=0
        lang_total[$l]=0
    done

    while IFS= read -r line; do
        if [[ "${line}" =~ ^SF:(.+)$ ]]; then
            current_sf="${BASH_REMATCH[1]}"
            # Normalise: strip leading workspace path or external/ prefix
            current_sf="${current_sf#*/_main/}"    # strip Bazel's sandbox prefix
            current_sf="${current_sf#*/execroot/}" # strip execroot prefix
            # Keep only the part after the module root (heuristic: trim up to /examples/)
            current_sf="${current_sf##*/cross_platform/}"
            continue
        fi

        if [[ "${line}" == "end_of_record" ]]; then
            current_sf=""
            continue
        fi

        [[ -z "${current_sf}" ]] && continue

        if [[ "${line}" =~ ^DA:([0-9]+),([0-9]+) ]]; then
            local lineno="${BASH_REMATCH[1]}"
            local hits="${BASH_REMATCH[2]}"
            local key="${current_sf}:${lineno}"

            # Only count lines that appear in the patch
            [[ "${PATCH_LINES[${key}]+set}" ]] || continue

            # Determine language from file extension
            case "${current_sf}" in
                *.cc|*.cpp|*.cxx|*.c|*.h|*.hh|*.hpp) lang="cc" ;;
                *.java) lang="java" ;;
                *.go)   lang="go" ;;
                *.py)   lang="python" ;;
                *) continue ;;
            esac

            (( lang_total[$lang]++ )) || true
            [[ "${hits}" -gt 0 ]] && (( lang_covered[$lang]++ )) || true
        fi
    done < "${lcov_file}"

    for l in cc java go python; do
        echo "${l} ${lang_covered[$l]} ${lang_total[$l]}"
    done
}

log "Analysing coverage for patch lines..."
declare -A COVERED TOTAL PCT
while read -r lang cov tot; do
    COVERED[$lang]="${cov}"
    TOTAL[$lang]="${tot}"
    if [[ "${tot}" -gt 0 ]]; then
        PCT[$lang]=$(( cov * 100 / tot ))
    else
        PCT[$lang]=-1
    fi
done < <(compute_patch_coverage "${LCOV_MERGED}")

# ── Results ───────────────────────────────────────────────────────────────────
declare -A LANG_LABELS=(
    [cc]="C/C++"
    [java]="Java"
    [go]="Go"
    [python]="Python"
)

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  PATCH COVERAGE RESULTS  (threshold: ${THRESHOLD}%)${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

OVERALL_STATUS=0

for lang in cc java go python; do
    # Only report languages that had changes in the patch
    [[ "${LANG_HAS_CHANGES[${lang}]+set}" ]] || continue

    label="${LANG_LABELS[$lang]}"
    cov="${COVERED[$lang]}"
    tot="${TOTAL[$lang]}"
    pct="${PCT[$lang]}"

    if [[ "${tot}" -eq 0 ]]; then
        # The language had changed files but none were instrumented
        # (e.g. only header changes, or coverage not available for this target)
        warn "  ${label}: no instrumented patch lines found in coverage data."
        warn "         Changed files may be headers, generated code, or excluded from coverage."
        continue
    fi

    if [[ "${pct}" -ge "${THRESHOLD}" ]]; then
        status_str="${GREEN}PASS ✓${RESET}"
    else
        status_str="${RED}FAIL ✗${RESET}"
        OVERALL_STATUS=1
    fi

    printf "  %-10s  %3d%% coverage  (%d / %d patch lines covered)  %b\n" \
        "${label}" "${pct}" "${cov}" "${tot}" "${status_str}"
done

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "${OVERALL_STATUS}" -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}PATCH STATUS: PASS${RESET}  — all languages meet the ${THRESHOLD}% threshold."
else
    echo -e "  ${RED}${BOLD}PATCH STATUS: FAIL${RESET}  — one or more languages are below ${THRESHOLD}% coverage."
fi

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "  Coverage report : ${LCOV_MERGED}"
echo "  Bazel log       : ${REPORT_DIR}/bazel_coverage.log"
echo ""

# ── Cleanup ───────────────────────────────────────────────────────────────────
if [[ "${KEEP_REPORT}" -eq 0 && "${OVERALL_STATUS}" -eq 0 ]]; then
    rm -rf "${REPORT_DIR}"
fi

exit "${OVERALL_STATUS}"
