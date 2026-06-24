#!/usr/bin/env bash
# test_cross_platform.sh
#
# Runs x86_64, arm64 (Linux in Docker) and macOS ARM64 builds in parallel.
#
# Container behaviour:
#   • Image is pulled only when not already present locally.
#   • Containers are long-lived (sleep infinity); they are stopped but NOT
#     removed on exit, so they are reused on the next run.
#   • Bazel output cache is persisted in named Docker volumes that survive
#     container restarts and script re-runs.
#
# Performance note:
#   • arm64 runs natively on Apple Silicon — fast.
#   • x86_64 runs under QEMU emulation on Apple Silicon; Bazel JVM startup
#     alone can take several minutes.  A heartbeat line is printed every 30 s
#     so the pane stays visibly alive while waiting.
#
# Terminal layout (tmux):
#
#   ┌──────────────┬──────────────┐
#   │   x86_64     │   arm64      │  ← upper half
#   ├──────────────┼──────────────┤
#   │  macos_arm64 │   command    │  ← lower half
#   └──────────────┴──────────────┘
#
# Requirements: tmux, docker (Docker Desktop with multi-arch / binfmt_misc)

# ── Resolve script path (works with symlinks and relative invocation) ─────────
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Persistent names (no timestamp → same container / volume reused every run) ─
DOCKER_IMAGE="ubuntu:latest"
X86_CONTAINER="cross_build_x86_64"
ARM64_CONTAINER="cross_build_arm64"
X86_CACHE_VOL="cross_build_x86_64_bazel_cache"
ARM64_CACHE_VOL="cross_build_arm64_bazel_cache"

# ── Helper: bring a container to the running state, creating it on first use ──
# Usage: ensure_container <name> <platform> <cache_vol>
ensure_container() {
    local name="$1" platform="$2" cache_vol="$3"
    local state
    state=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "absent")
    case "$state" in
        running)
            echo "[${name}] Container already running — reusing."
            ;;
        exited|created|paused)
            echo "[${name}] Container stopped (${state}) — restarting."
            docker start "$name"
            ;;
        *)
            echo "[${name}] Container not found — creating (first run)."
            docker volume create "$cache_vol" > /dev/null
            docker create \
                --name     "$name" \
                --platform "$platform" \
                -v "${SCRIPT_DIR}:/workspace" \
                -v "${HOME}/.ssh:/root/.ssh:ro" \
                -v "${cache_vol}:/root/.cache/bazel" \
                -e GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" \
                -w /workspace \
                "$DOCKER_IMAGE" \
                sleep infinity > /dev/null
            docker start "$name"
            ;;
    esac
    # Join the buildbuddy-net network so the container can reach the
    # BuildBuddy remote cache (grpc://buildbuddy-app:9090).
    docker network connect buildbuddy-net "$name" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
# INNER MODE  –  invoked by each tmux pane
# Usage: <script> --run-arch x86_64|arm64|macos <log-file> <status-file>
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--run-arch" ]]; then
    ARCH="$2"
    LOG_FILE="$3"
    STATUS_FILE="$4"
    # Derive timing file from status file (replace "done" with "time")
    TIMING_FILE="${STATUS_FILE/done/time}"
    ARCH_START=$(date +%s)

    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  [${ARCH}]  Started: $(date)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        case "$ARCH" in
            x86_64)
                echo "  NOTE: x86_64 runs under QEMU emulation on Apple Silicon."
                echo "        Bazel JVM startup can take several minutes — heartbeat"
                echo "        lines are printed every 30 s to confirm it is alive."
                echo ""
                ensure_container "$X86_CONTAINER" "linux/amd64" "$X86_CACHE_VOL"
                docker exec "$X86_CONTAINER" bash -c "
set -e
cd /workspace
BUILD_START=\$(date +%s)

# Background heartbeat — prints elapsed time every 30 s during the slow
# QEMU-emulated Bazel JVM startup so the pane does not look frozen.
(
    while true; do
        sleep 30
        ELAPSED=\$(( \$(date +%s) - BUILD_START ))
        printf '  ♥  [x86_64] still running … %dm %ds\n' \"\$(( ELAPSED / 60 ))\" \"\$(( ELAPSED % 60 ))\"
    done
) &
HEARTBEAT_PID=\$!
trap 'kill \"\$HEARTBEAT_PID\" 2>/dev/null; true' EXIT INT TERM

echo \">>> [x86_64] \$(date '+%H:%M:%S')  Running setup.sh ...\"
chmod +x ./setup.sh ./bazel 2>/dev/null || true
./setup.sh
echo \">>> [x86_64] \$(date '+%H:%M:%S')  Stopping existing Bazel instances...\"
killall java 2>/dev/null || pkill java 2>/dev/null || true
sleep 1
# Disk cache lives inside the named Docker volume (/root/.cache/bazel) so it
# survives container restarts and output-base hash changes (e.g. Bazel upgrades).
mkdir -p /root/.cache/bazel/disk_cache
echo \">>> [x86_64] \$(date '+%H:%M:%S')  Running: ./bazel test --config=x86_64 //examples/...\"
./bazel test  --config=x86_64 --disk_cache=/root/.cache/bazel/disk_cache //examples/...
echo \">>> [x86_64] \$(date '+%H:%M:%S')  Running: ./bazel build --config=x86_64 //examples/...\"
./bazel build --config=x86_64 --disk_cache=/root/.cache/bazel/disk_cache //examples/...
ELAPSED=\$(( \$(date +%s) - BUILD_START ))
echo \">>> [x86_64] \$(date '+%H:%M:%S')  Done!  Total time: \$(( ELAPSED / 60 ))m \$(( ELAPSED % 60 ))s\"
"
                ;;

            arm64)
                ensure_container "$ARM64_CONTAINER" "linux/arm64" "$ARM64_CACHE_VOL"
                docker exec "$ARM64_CONTAINER" bash -c "
set -e
cd /workspace
BUILD_START=\$(date +%s)
echo \">>> [arm64] \$(date '+%H:%M:%S')  Running setup.sh ...\"
chmod +x ./setup.sh ./bazel 2>/dev/null || true
./setup.sh
echo \">>> [arm64] \$(date '+%H:%M:%S')  Stopping existing Bazel instances...\"
killall java 2>/dev/null || pkill java 2>/dev/null || true
sleep 1
echo \">>> [arm64] \$(date '+%H:%M:%S')  Running: ./bazel test --config=arm64 //examples/...\"
./bazel test --config=arm64 //examples/...
echo \">>> [arm64] \$(date '+%H:%M:%S')  Running: ./bazel build --config=arm64 //examples/...\"
./bazel build --config=arm64 //examples/...
ELAPSED=\$(( \$(date +%s) - BUILD_START ))
echo \">>> [arm64] \$(date '+%H:%M:%S')  Done!  Total time: \$(( ELAPSED / 60 ))m \$(( ELAPSED % 60 ))s\"
"
                ;;

            macos)
                # Native execution on the macOS host — no Docker needed.
                # Bazel cache lives in the host ~/.cache/bazel and is
                # naturally persistent across runs.
                (
                    set -e
                    cd "$SCRIPT_DIR"
                    BUILD_START=$(date +%s)
                    echo ">>> [macos_arm64] $(date '+%H:%M:%S')  Running setup.sh ..."
                    chmod +x ./setup.sh ./bazel 2>/dev/null || true
                    ./setup.sh
                    echo ">>> [macos_arm64] $(date '+%H:%M:%S')  Stopping existing Bazel instances..."
                    killall java 2>/dev/null || true
                    sleep 1
                    echo ">>> [macos_arm64] $(date '+%H:%M:%S')  Running: ./bazel test --config=macos_arm64 //examples/..."
                    ./bazel test --config=macos_arm64 //examples/...
                    echo ">>> [macos_arm64] $(date '+%H:%M:%S')  Running: ./bazel build --config=macos_arm64 //examples/..."
                    ./bazel build --config=macos_arm64 //examples/...
                    ELAPSED=$(( $(date +%s) - BUILD_START ))
                    echo ">>> [macos_arm64] $(date '+%H:%M:%S')  Done!  Total time: $(( ELAPSED / 60 ))m $(( ELAPSED % 60 ))s"
                )
                ;;

            *)
                echo "Unknown arch: $ARCH" >&2
                echo "1" > "$STATUS_FILE"
                exit 1
                ;;
        esac
    } 2>&1 | tee "$LOG_FILE"

    RUN_EXIT=${PIPESTATUS[0]}
    ARCH_ELAPSED=$(( $(date +%s) - ARCH_START ))
    echo "$RUN_EXIT" > "$STATUS_FILE"
    echo "$ARCH_ELAPSED" > "$TIMING_FILE"

    echo ""
    if [[ "$RUN_EXIT" -eq 0 ]]; then
        echo "✓ [${ARCH}] BUILD SUCCEEDED  ($(( ARCH_ELAPSED / 60 ))m $(( ARCH_ELAPSED % 60 ))s)"
    else
        echo "✗ [${ARCH}] BUILD FAILED  (exit code: ${RUN_EXIT}, elapsed: $(( ARCH_ELAPSED / 60 ))m $(( ARCH_ELAPSED % 60 ))s)"
    fi

    echo ""
    echo "Waiting for monitor to close this pane..."
    # Keep pane alive until the monitor kills it
    while true; do sleep 30; done
fi

# ─────────────────────────────────────────────────────────────────────────────
# OUTER MODE  –  entry point: sets up tmux and launches all panes
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

LOG_DIR="${SCRIPT_DIR}/build_logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SESSION="cross_build_${TIMESTAMP}"

X86_LOG="${LOG_DIR}/x86_64_${TIMESTAMP}.log"
ARM64_LOG="${LOG_DIR}/arm64_${TIMESTAMP}.log"
MACOS_LOG="${LOG_DIR}/macos_${TIMESTAMP}.log"
SUMMARY_LOG="${LOG_DIR}/summary_${TIMESTAMP}.log"

# Status files: each pane writes its exit code here when done
X86_STATUS="/tmp/x86_done_${TIMESTAMP}"
ARM64_STATUS="/tmp/arm64_done_${TIMESTAMP}"
MACOS_STATUS="/tmp/macos_done_${TIMESTAMP}"

# Timing files: each pane writes elapsed seconds here when done
X86_TIMING="/tmp/x86_time_${TIMESTAMP}"
ARM64_TIMING="/tmp/arm64_time_${TIMESTAMP}"
MACOS_TIMING="/tmp/macos_time_${TIMESTAMP}"

mkdir -p "$LOG_DIR"

# ── Dependency checks ─────────────────────────────────────────────────────────
for cmd in tmux docker; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '${cmd}' is required but not found." >&2
        exit 1
    fi
done

if ! docker info &>/dev/null 2>&1; then
    echo "Error: Docker daemon is not running." >&2
    echo "       Start Docker Desktop and try again." >&2
    exit 1
fi

# ── Pull image for each required platform only if not already present locally ──
for platform in linux/amd64 linux/arm64; do
    if docker run --rm --pull never --platform "$platform" "$DOCKER_IMAGE" true >/dev/null 2>&1; then
        echo "Image ${DOCKER_IMAGE} for ${platform} already present — skipping pull."
    else
        echo "Pulling ${DOCKER_IMAGE} for ${platform}..."
        docker pull --platform "$platform" "$DOCKER_IMAGE"
    fi
done

echo ""
echo "Session : $SESSION"
echo "Logs    : $LOG_DIR"
echo ""

# ── Write monitor script (avoids quoting complexity in send-keys) ─────────────
MONITOR_SH="/tmp/monitor_${TIMESTAMP}.sh"

# Variables expanded NOW (baked into the file):
#   *_STATUS, *_TIMING, SESSION, *_LOG, TIMESTAMP, MONITOR_SH
# Variables escaped with \$ are evaluated at RUNTIME inside the monitor.
cat > "$MONITOR_SH" << MONITOR_EOF
#!/usr/bin/env bash
X86_STATUS="${X86_STATUS}"
ARM64_STATUS="${ARM64_STATUS}"
MACOS_STATUS="${MACOS_STATUS}"
X86_TIMING="${X86_TIMING}"
ARM64_TIMING="${ARM64_TIMING}"
MACOS_TIMING="${MACOS_TIMING}"
SESSION="${SESSION}"
SUMMARY_LOG="${SUMMARY_LOG}"
X86_LOG="${X86_LOG}"
ARM64_LOG="${ARM64_LOG}"
MACOS_LOG="${MACOS_LOG}"
TIMESTAMP="${TIMESTAMP}"
MONITOR_SH="${MONITOR_SH}"

_fmt_time() {
    local s=\${1:-0}
    [[ "\$s" == "?" ]] && { echo "?"; return; }
    printf '%dm %ds' "\$(( s / 60 ))" "\$(( s % 60 ))"
}

echo ""
echo "Monitoring builds  (x86_64 + arm64 + macos_arm64 in parallel)..."
echo "  Note: x86_64 runs under QEMU emulation — Bazel JVM startup takes"
echo "        several minutes.  Watch for heartbeat lines in its pane."
echo ""
echo "Logs:"
echo "  x86_64      → \$X86_LOG"
echo "  arm64       → \$ARM64_LOG"
echo "  macos_arm64 → \$MACOS_LOG"
echo ""

MONITOR_START=\$(date +%s)

# Live status loop — shows done vs pending arches every 3 s.
while [[ ! -f "\$X86_STATUS" || ! -f "\$ARM64_STATUS" || ! -f "\$MACOS_STATUS" ]]; do
    ELAPSED=\$(( \$(date +%s) - MONITOR_START ))
    DONE=""
    PENDING=""
    [[ -f "\$X86_STATUS" ]]   && DONE+="\${DONE:+  }x86_64"      || PENDING+="\${PENDING:+  }x86_64"
    [[ -f "\$ARM64_STATUS" ]] && DONE+="\${DONE:+  }arm64"        || PENDING+="\${PENDING:+  }arm64"
    [[ -f "\$MACOS_STATUS" ]] && DONE+="\${DONE:+  }macos_arm64"  || PENDING+="\${PENDING:+  }macos_arm64"
    printf '\r  [%02d:%02d]  done: %-28s  pending: %-20s' \
        "\$(( ELAPSED / 60 ))" "\$(( ELAPSED % 60 ))" \
        "\${DONE:----}" "\${PENDING:----}"
    sleep 3
done
printf '\n'
echo ""

X86_RC=\$(cat  "\$X86_STATUS"  2>/dev/null || echo 1)
ARM64_RC=\$(cat "\$ARM64_STATUS" 2>/dev/null || echo 1)
MACOS_RC=\$(cat "\$MACOS_STATUS" 2>/dev/null || echo 1)

X86_TIME=\$(_fmt_time "\$(cat "\$X86_TIMING"  2>/dev/null || echo '?')")
ARM64_TIME=\$(_fmt_time "\$(cat "\$ARM64_TIMING" 2>/dev/null || echo '?')")
MACOS_TIME=\$(_fmt_time "\$(cat "\$MACOS_TIMING" 2>/dev/null || echo '?')")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  BUILD RESULTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "\$X86_RC" == "0" ]]; then
    echo "  x86_64     : SUCCESS ✓  (\$X86_TIME)"
else
    echo "  x86_64     : FAILED  ✗  (exit: \$X86_RC, elapsed: \$X86_TIME)"
fi
if [[ "\$ARM64_RC" == "0" ]]; then
    echo "  arm64      : SUCCESS ✓  (\$ARM64_TIME)"
else
    echo "  arm64      : FAILED  ✗  (exit: \$ARM64_RC, elapsed: \$ARM64_TIME)"
fi
if [[ "\$MACOS_RC" == "0" ]]; then
    echo "  macos_arm64: SUCCESS ✓  (\$MACOS_TIME)"
else
    echo "  macos_arm64: FAILED  ✗  (exit: \$MACOS_RC, elapsed: \$MACOS_TIME)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Write summary log
{
    echo "=== Cross-Platform Build Summary ==="
    echo "Timestamp : \$TIMESTAMP"
    echo ""
    [[ "\$X86_RC"   == "0" ]] && echo "x86_64     : SUCCESS  (\$X86_TIME)"   || echo "x86_64     : FAILED (exit: \$X86_RC, elapsed: \$X86_TIME)"
    [[ "\$ARM64_RC" == "0" ]] && echo "arm64      : SUCCESS  (\$ARM64_TIME)"  || echo "arm64      : FAILED (exit: \$ARM64_RC, elapsed: \$ARM64_TIME)"
    [[ "\$MACOS_RC" == "0" ]] && echo "macos_arm64: SUCCESS  (\$MACOS_TIME)"  || echo "macos_arm64: FAILED (exit: \$MACOS_RC, elapsed: \$MACOS_TIME)"
    echo ""
    echo "Detailed logs:"
    echo "  x86_64      : \$X86_LOG"
    echo "  arm64       : \$ARM64_LOG"
    echo "  macos_arm64 : \$MACOS_LOG"
    echo "  Summary     : \$SUMMARY_LOG"
} | tee "\$SUMMARY_LOG"

rm -f "\$X86_STATUS" "\$ARM64_STATUS" "\$MACOS_STATUS"
rm -f "\$X86_TIMING" "\$ARM64_TIMING" "\$MACOS_TIMING"

echo ""
echo "Closing build panes in 5 seconds  (Ctrl+C to keep them open)..."
sleep 5

# Kill the three build panes.  After each kill the survivors slide down to
# fill the gap, so killing index .0 three times removes all three.
tmux kill-pane -t "\${SESSION}:0.0" 2>/dev/null || true
tmux kill-pane -t "\${SESSION}:0.0" 2>/dev/null || true
tmux kill-pane -t "\${SESSION}:0.0" 2>/dev/null || true

echo ""
echo "Summary written to:"
echo "  \$SUMMARY_LOG"
echo ""
echo "Press Enter to exit."
read -r
rm -f "\$MONITOR_SH"
tmux kill-session -t "\$SESSION" 2>/dev/null || true
MONITOR_EOF

chmod +x "$MONITOR_SH"

# ── Create tmux session ───────────────────────────────────────────────────────
tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -n "builds"

# Layout construction for 2×2 grid:
#   Step 1: split-v -p 50  → pane 0 (top 50%), pane 1 (bottom 50%)
#   Step 2: select pane 0, split-h  → pane 0 (top-left), pane 1 (top-right), pane 2 (bottom)
#   Step 3: select pane 2 (bottom), split-h  → pane 0 (top-left), pane 1 (top-right),
#                                               pane 2 (bottom-left), pane 3 (bottom-right)
#
#   ┌──────────────┬──────────────┐
#   │   pane 0     │   pane 1     │   x86_64  |  arm64
#   ├──────────────┼──────────────┤
#   │   pane 2     │   pane 3     │   macos_arm64  |  command
#   └──────────────┴──────────────┘
tmux split-window -v -p 50 -t "${SESSION}:builds"
tmux select-pane  -t "${SESSION}:builds.0"
tmux split-window -h       -t "${SESSION}:builds.0"
tmux select-pane  -t "${SESSION}:builds.2"
tmux split-window -h       -t "${SESSION}:builds.2"

# Pane titles (requires tmux ≥ 2.6)
tmux set-option -t "$SESSION" pane-border-status top 2>/dev/null || true
tmux select-pane -t "${SESSION}:builds.0" -T " ◆ x86_64      "
tmux select-pane -t "${SESSION}:builds.1" -T " ◆ arm64       "
tmux select-pane -t "${SESSION}:builds.2" -T " ◆ macos_arm64 "
tmux select-pane -t "${SESSION}:builds.3" -T " ◆ Command     "

# ── Send commands to panes ────────────────────────────────────────────────────
tmux send-keys -t "${SESSION}:builds.0" \
    "\"${SCRIPT}\" --run-arch x86_64 \"${X86_LOG}\" \"${X86_STATUS}\"" Enter

tmux send-keys -t "${SESSION}:builds.1" \
    "\"${SCRIPT}\" --run-arch arm64 \"${ARM64_LOG}\" \"${ARM64_STATUS}\"" Enter

tmux send-keys -t "${SESSION}:builds.2" \
    "\"${SCRIPT}\" --run-arch macos \"${MACOS_LOG}\" \"${MACOS_STATUS}\"" Enter

tmux send-keys -t "${SESSION}:builds.3" \
    "\"${MONITOR_SH}\"" Enter

# ── Attach ────────────────────────────────────────────────────────────────────
# If already inside tmux, use switch-client (nesting is not allowed without
# unsetting $TMUX).  switch-client returns immediately, so we poll until the
# inner session is gone; attach-session blocks naturally.
if [[ -n "${TMUX:-}" ]]; then
    echo "Switching to tmux session '${SESSION}'  (Ctrl+B D to detach)"
    tmux switch-client -t "$SESSION"
    while tmux has-session -t "$SESSION" 2>/dev/null; do sleep 2; done
else
    echo "Attaching to tmux session '${SESSION}'  (Ctrl+B D to detach)"
    tmux attach-session -t "$SESSION"
fi

# Reached after the session is killed (user pressed Enter in monitor pane)
echo ""
if [[ -f "$SUMMARY_LOG" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$SUMMARY_LOG"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
