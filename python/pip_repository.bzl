"""Repository rule that downloads and extracts a single pip wheel.

A pip wheel is a zip file. This rule downloads the wheel and extracts it so
that Bazel targets can depend on its contents without needing pip at build time.

Usage in MODULE.bazel (via the python_ext module extension):

    python_ext.pip(
        name   = "pip_requests",
        url    = "https://files.pythonhosted.org/packages/.../requests-2.32.3-py3-none-any.whl",
        sha256 = "70761cfe03c773ceb22aa2f671b4757976145175cdfca038c02654d061d6dcc6",
    )
    use_repo(python_ext, "pip_requests")

    # In BUILD.bazel:
    py_self_executable(
        ...
        deps = ["@pip_requests//:pkg"],
    )

The exposed target :pkg is a filegroup of all files extracted from the wheel.
The extracted layout matches what pip normally puts in site-packages (e.g.
requests/, requests-2.32.3.dist-info/).
"""

_BUILD_CONTENT = """\
filegroup(
    name = "pkg",
    srcs = glob(["**"]),
    visibility = ["//visibility:public"],
)
"""

def _pip_wheel_repository_impl(repository_ctx):
    url = repository_ctx.attr.url
    sha256 = repository_ctx.attr.sha256

    # Wheels are zip files; download_and_extract understands them directly.
    download_kwargs = dict(url = url, type = "zip", stripPrefix = "")
    if sha256:
        download_kwargs["sha256"] = sha256

    repository_ctx.download_and_extract(**download_kwargs)
    repository_ctx.file("BUILD.bazel", _BUILD_CONTENT)

pip_wheel_repository = repository_rule(
    implementation = _pip_wheel_repository_impl,
    doc = "Downloads and extracts a single pip wheel for use as a py_self_executable dep.",
    attrs = {
        "url": attr.string(
            mandatory = True,
            doc = "Direct URL to the .whl file.",
        ),
        "sha256": attr.string(
            default = "",
            doc = "Expected SHA-256 of the wheel (leave empty to skip verification).",
        ),
    },
)
