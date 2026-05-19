"""py_self_executable — build rule producing a fully self-contained Python binary.

The output is a shell script whose tail is a tar.gz payload. When executed on
any machine with /bin/sh, it:
  1. Extracts the payload to ~/.cache/py_exe/<hash>/ (once, keyed by content hash).
  2. Runs the bundled CPython interpreter with the bundled app entry-point.

Everything needed at runtime is embedded in a single file:
  • CPython runtime from the registered //python:toolchain_type toolchain.
  • Python source files listed in `srcs`.
  • Pip wheel contents from `deps` (pre-extracted :pkg filegroups).

Example
-------
    load("//python:defs.bzl", "py_self_executable")

    py_self_executable(
        name = "my_app",
        main = "main.py",
        srcs = glob(["*.py"]),
        deps = ["@pip_requests//:pkg"],
    )
"""

load(":toolchain.bzl", "PyRuntimeInfo")

def _py_self_executable_impl(ctx):
    toolchain = ctx.toolchains["//python:toolchain_type"]
    py_runtime = toolchain.py_runtime  # PyRuntimeInfo

    output = ctx.actions.declare_file(ctx.label.name)

    src_files = ctx.files.srcs + ctx.files.data

    # Each dep is a :pkg filegroup from pip_wheel_repository.
    pip_files = []
    for dep in ctx.attr.deps:
        pip_files.extend(dep.files.to_list())

    # Determine unique pip repo roots (external/<repo>) from pip file paths.
    pip_dirs = {}
    for f in pip_files:
        parts = f.path.split("/")
        if len(parts) >= 2 and parts[0] == "external":
            pip_dirs["external/" + parts[1]] = True

    # Strip the package path so srcs land flat inside app/.
    strip_prefixes = []
    if ctx.label.package:
        strip_prefixes.append(ctx.label.package)
    strip_prefixes.extend(ctx.attr.strip_src_prefixes)

    all_inputs = depset(
        direct = [ctx.file._builder, ctx.file._bootstrap] + src_files + pip_files,
        transitive = [py_runtime.runtime_files],
    )

    args = ctx.actions.args()
    args.add(ctx.file._builder)            # argv[0] for python3: the builder script
    args.add("--bootstrap", ctx.file._bootstrap)
    args.add("--output", output)
    args.add("--python-runtime-root", py_runtime.runtime_root)
    args.add("--main", ctx.attr.main)
    if src_files:
        args.add_all("--srcs", src_files)
    if strip_prefixes:
        args.add_all("--src-strip-prefixes", strip_prefixes)
    if pip_dirs:
        args.add_all("--pip-dirs", pip_dirs.keys())

    ctx.actions.run(
        executable = py_runtime.interpreter,
        arguments = [args],
        inputs = all_inputs,
        outputs = [output],
        mnemonic = "PySelfExecutable",
        progress_message = "Bundling self-executable Python binary %{output}",
        use_default_shell_env = False,
    )

    return [DefaultInfo(
        files = depset([output]),
        executable = output,
    )]

py_self_executable = rule(
    implementation = _py_self_executable_impl,
    executable = True,
    toolchains = ["//python:toolchain_type"],
    attrs = {
        "main": attr.string(
            mandatory = True,
            doc = "Entry-point filename relative to the package, e.g. 'main.py'.",
        ),
        "srcs": attr.label_list(
            allow_files = [".py"],
            doc = "Python source files bundled under app/ inside the executable.",
        ),
        "deps": attr.label_list(
            allow_files = False,
            doc = "Pip wheel filegroup targets to merge into Python's site-packages.",
        ),
        "strip_src_prefixes": attr.string_list(
            default = [],
            doc = "Extra path prefixes to strip from srcs (the package path is always stripped).",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Extra data files bundled alongside the sources.",
        ),
        "_builder": attr.label(
            default = "//python:bundle_builder.py",
            allow_single_file = True,
        ),
        "_bootstrap": attr.label(
            default = "//python:bootstrap.sh.tpl",
            allow_single_file = True,
        ),
    },
    doc = "Produces a hermetic, self-contained Python executable with bundled CPython runtime and pip dependencies.",
)
