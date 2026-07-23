"""
Configuration transition to build a target for Linux arm64
from any exec platform (typically Linux x86_64).

Mirrors the .bazelrc `build:arm64` config programmatically so that a single
BUILD rule can produce an arm64 binary without requiring --config=arm64 on
the command line.

Usage:
    load("//:transitions.bzl", "linux_arm64_binary")

    cc_binary(name = "server", ...)

    linux_arm64_binary(
        name = "server_arm64",
        binary = ":server",
    )

Then build with:
    bazel build //<pkg>:server_arm64
"""

# ---------------------------------------------------------------------------
# Transition: flip the target platform to Linux arm64.
#
# outputs must list every command-line option the transition writes.
# inputs lists options whose current value the implementation reads (none here
# because the target platform is hardcoded, not derived from the caller).
# ---------------------------------------------------------------------------

def _linux_arm64_transition_impl(settings, attr):
    _ = settings  # unused — transition is unconditional
    _ = attr
    return {
        "//command_line_option:platforms": "//platforms:arm64_platform",
        "//command_line_option:cpu": "arm64",
        # Register both toolchains so Bazel resolves the right one whether
        # the exec machine is x86_64 (gcc_arm64_toolchain) or aarch64
        # (gcc_arm64_native_toolchain).
        "//command_line_option:extra_toolchains": [
            "//:gcc_arm64_toolchain",
            "//:gcc_arm64_native_toolchain",
        ],
    }

_linux_arm64_transition = transition(
    implementation = _linux_arm64_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:platforms",
        "//command_line_option:cpu",
        "//command_line_option:extra_toolchains",
    ],
)

# ---------------------------------------------------------------------------
# Rule: linux_arm64_binary
#
# A thin wrapper that applies the transition to its `binary` dep and
# re-exports the resulting executable so it can be built or run directly.
# ---------------------------------------------------------------------------

def _linux_arm64_binary_impl(ctx):
    # When a transition is applied on an attr.label, Bazel wraps the result
    # in a single-element list.
    dep = ctx.attr.binary[0]
    default_info = dep[DefaultInfo]

    src_executable = default_info.files_to_run.executable
    runfiles = default_info.default_runfiles

    # Bazel requires the executable in DefaultInfo to be created by this rule,
    # not forwarded from a dep. Create a symlink so the file is "owned" here.
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = out, target_file = src_executable, is_executable = True)

    return [
        DefaultInfo(
            files = depset([out]),
            runfiles = runfiles,
            executable = out,
        ),
    ]

linux_arm64_binary = rule(
    implementation = _linux_arm64_binary_impl,
    executable = True,
    attrs = {
        "binary": attr.label(
            mandatory = True,
            # The transition is applied on the outgoing edge to this dep,
            # so `binary` (and all its transitive deps) are built for arm64
            # while the wrapper rule itself stays in the exec platform config.
            cfg = _linux_arm64_transition,
            executable = True,
        ),
        # Required by Bazel when any rule in the package uses a Starlark
        # configuration transition (function_transition_allowlist).
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
