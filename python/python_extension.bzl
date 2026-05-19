"""Bzlmod module extension for Python runtime and pip wheel repositories.

Declare in MODULE.bazel:

    python_ext = use_extension("//python:python_extension.bzl", "python_ext")

    # Optionally override the default CPython repository name:
    # python_ext.runtime(name = "cpython")

    python_ext.pip(
        name   = "pip_requests",
        url    = "https://files.pythonhosted.org/packages/.../requests-2.32.3-py3-none-any.whl",
        sha256 = "70761cfe03c773ceb22aa2f671b4757976145175cdfca038c02654d061d6dcc6",
    )

    use_repo(python_ext, "cpython", "pip_requests")

Then register the toolchain in MODULE.bazel:

    register_toolchains("@cpython//:toolchain")
"""

load(":python_repository.bzl", "python_repository")
load(":pip_repository.bzl", "pip_wheel_repository")

_DEFAULT_RUNTIME_NAME = "cpython"

def _python_extension_impl(module_ctx):
    runtime_name = _DEFAULT_RUNTIME_NAME

    for mod in module_ctx.modules:
        # Handle runtime tag (optional, lets users rename the repo)
        for tag in mod.tags.runtime:
            runtime_name = tag.name

        # One CPython repo for the exec platform
        python_repository(name = runtime_name)

        # One pip wheel repo per pip() tag
        for tag in mod.tags.pip:
            pip_wheel_repository(
                name = tag.name,
                url = tag.url,
                sha256 = tag.sha256,
            )

_runtime_tag = tag_class(
    attrs = {
        "name": attr.string(
            default = _DEFAULT_RUNTIME_NAME,
            doc = "Name of the CPython repository (default: 'cpython').",
        ),
    },
)

_pip_tag = tag_class(
    attrs = {
        "name": attr.string(
            mandatory = True,
            doc = "Repository name, e.g. 'pip_requests'.",
        ),
        "url": attr.string(
            mandatory = True,
            doc = "Direct URL to the .whl file on PyPI.",
        ),
        "sha256": attr.string(
            default = "",
            doc = "Expected SHA-256 of the wheel (recommended for reproducibility).",
        ),
    },
)

python_ext = module_extension(
    implementation = _python_extension_impl,
    tag_classes = {
        "runtime": _runtime_tag,
        "pip": _pip_tag,
    },
)
