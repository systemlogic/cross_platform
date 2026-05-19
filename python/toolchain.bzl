"""Python runtime toolchain definition for py_self_executable."""

PyRuntimeInfo = provider(
    doc = "Information about a bundled CPython runtime.",
    fields = {
        "interpreter": "The python3 executable File.",
        "runtime_files": "Depset of all files that make up the Python installation.",
        "runtime_root": "Exec-root-relative path to the Python install root (contains bin/, lib/).",
    },
)

def _py_runtime_toolchain_impl(ctx):
    interpreter = ctx.file.interpreter
    runtime_files = depset(ctx.files.runtime_files)

    # The runtime root is two levels up from bin/python3
    # e.g. external/cpython_linux_x86_64/bin/python3 → external/cpython_linux_x86_64
    runtime_root = "/".join(interpreter.path.split("/")[:-2])

    return [platform_common.ToolchainInfo(
        py_runtime = PyRuntimeInfo(
            interpreter = interpreter,
            runtime_files = runtime_files,
            runtime_root = runtime_root,
        ),
    )]

py_runtime_toolchain = rule(
    implementation = _py_runtime_toolchain_impl,
    attrs = {
        "interpreter": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Label for the python3 binary inside the downloaded runtime.",
        ),
        "runtime_files": attr.label_list(
            allow_files = True,
            mandatory = True,
            doc = "All files in the Python installation (filegroup :all_files).",
        ),
    },
)
