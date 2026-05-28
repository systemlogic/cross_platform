"""py_runnable — fast dev runner that uses Bazel runfiles directly.

Unlike py_self_executable, this rule does NOT create a compressed archive.
Build time is a single text-file write. Run time is instant — no extraction.

The trade-off: the output binary requires Bazel's output base to be intact
(runfiles are symlinks into it). Use py_self_executable for portable deployment
and py_runnable for fast local iteration.

Example
-------
    load("//python:defs.bzl", "py_runnable")

    py_runnable(
        name = "my_app",
        main = "main.py",
        srcs = ["main.py"],
        deps = ["@pip_torch//:pkg"],
    )

    # bazel run //my_pkg:my_app
"""

load(":toolchain.bzl", "PyRuntimeInfo")

def _runfiles_path(short_path):
    """Convert a file's short_path to its path inside the runfiles tree.

    Bazel short_path conventions:
      - Main repo:     "pkg/file.py"         → "_main/pkg/file.py"
      - External repo: "../<repo>/path/file"  → "<repo>/path/file"
    """
    if short_path.startswith("../"):
        return short_path[3:]
    return "_main/" + short_path

def _repo_root_from_short_path(short_path):
    """Return the top-level runfiles directory for an external-repo file.

    e.g. "../+python_ext+pip_torch/torch/__init__.py" → "+python_ext+pip_torch"
    Returns None for main-repo files.
    """
    if short_path.startswith("../"):
        return short_path[3:].split("/")[0]
    return None

def _py_runnable_impl(ctx):
    toolchain = ctx.toolchains["//python:toolchain_type"]
    py_runtime = toolchain.py_runtime

    output = ctx.actions.declare_file(ctx.label.name)

    src_files = ctx.files.srcs + ctx.files.data

    pip_files = []
    for dep in ctx.attr.deps:
        pip_files.extend(dep.files.to_list())

    # Interpreter path inside the runfiles tree
    interp_path = _runfiles_path(py_runtime.interpreter.short_path)

    # Collect unique pip repo roots for PYTHONPATH
    pip_roots = {}
    for f in pip_files:
        root = _repo_root_from_short_path(f.short_path)
        if root:
            pip_roots[root] = True

    # Main script path inside the runfiles tree
    main_runfiles_path = "_main/{}/{}".format(ctx.label.package, ctx.attr.main)

    # Build PYTHONPATH: one entry per pip repo root, plus the src directory
    # so relative imports within the package work.
    src_dir = "_main/{}".format(ctx.label.package)
    pythonpath_parts = (
        ["${RUNFILES}/" + r for r in pip_roots.keys()] +
        ["${RUNFILES}/" + src_dir]
    )
    pythonpath = ":".join(pythonpath_parts)

    script = """\
#!/bin/sh
set -e
# Resolve the runfiles tree.
# bazel run sets RUNFILES_DIR; direct execution uses the adjacent .runfiles dir.
_SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
if [ -n "${{RUNFILES_DIR}}" ]; then
    RUNFILES="${{RUNFILES_DIR}}"
else
    RUNFILES="${{_SELF}}.runfiles"
fi
# Follow one level of symlink (bazel run may symlink the launcher).
if [ ! -d "${{RUNFILES}}" ]; then
    _REAL="$(readlink "${{_SELF}}" 2>/dev/null || true)"
    if [ -n "${{_REAL}}" ]; then
        _REAL_DIR="$(cd "$(dirname "${{_REAL}}")" && pwd)"
        RUNFILES="${{_REAL_DIR}}/$(basename "${{_REAL}}").runfiles"
    fi
fi
export PYTHONPATH="{pythonpath}"
exec "${{RUNFILES}}/{interp}" "${{RUNFILES}}/{main}" "$@"
""".format(
        pythonpath = pythonpath,
        interp = interp_path,
        main = main_runfiles_path,
    )

    ctx.actions.write(
        output = output,
        content = script,
        is_executable = True,
    )

    all_runfiles = ctx.runfiles(
        files = src_files + pip_files,
        transitive_files = py_runtime.runtime_files,
    )

    return [DefaultInfo(
        files = depset([output]),
        executable = output,
        runfiles = all_runfiles,
    )]

py_runnable = rule(
    implementation = _py_runnable_impl,
    executable = True,
    toolchains = ["//python:toolchain_type"],
    attrs = {
        "main": attr.string(
            mandatory = True,
            doc = "Entry-point filename relative to the package, e.g. 'main.py'.",
        ),
        "srcs": attr.label_list(
            allow_files = [".py"],
            doc = "Python source files.",
        ),
        "deps": attr.label_list(
            allow_files = False,
            doc = "Pip wheel filegroup targets (:pkg) to add to PYTHONPATH.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Extra data files made available at runtime.",
        ),
    },
    doc = "Fast dev runner: no bundling, no extraction — runs directly from Bazel runfiles.",
)
