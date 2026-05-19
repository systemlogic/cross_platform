"""Repository rule that downloads a CPython standalone build.

Uses python-build-standalone (https://github.com/astral-sh/python-build-standalone)
which ships hermetic, relocatable CPython builds for all major platforms.

The downloaded archive extracts to:
  python/
    bin/python3        ← interpreter
    bin/pip3
    lib/python3.X/
      site-packages/   ← where pip wheels are installed
    include/
    ...

After download a BUILD.bazel is injected that exposes:
  :all_files  — filegroup of every file in the install
  :py_runtime — py_runtime_toolchain target
  :toolchain  — toolchain() target registered with //python:toolchain_type
"""

# Mapping from (os, arch) detected at rule evaluation time to the
# python-build-standalone artifact name suffix and sha256.
# Update URLs/hashes when upgrading Python.
_PYTHON_VERSION = "3.12.7"
_RELEASE_DATE = "20241016"

_PLATFORMS = {
    # (repository_ctx.os.name prefix, repository_ctx.os.arch) → (artifact_suffix, sha256)
    ("linux", "x86_64"): (
        "x86_64-unknown-linux-gnu-install_only.tar.gz",
        # sha256: fill in from https://github.com/astral-sh/python-build-standalone/releases
        "",
    ),
    ("linux", "aarch64"): (
        "aarch64-unknown-linux-gnu-install_only.tar.gz",
        "",
    ),
    ("mac os x", "arm64"): (
        "aarch64-apple-darwin-install_only.tar.gz",
        "",
    ),
    ("mac os x", "x86_64"): (
        "x86_64-apple-darwin-install_only.tar.gz",
        "",
    ),
}

_BUILD_TEMPLATE = """\
load("@cross_platform//python:toolchain.bzl", "py_runtime_toolchain")

filegroup(
    name = "all_files",
    srcs = glob(["python/**"], allow_empty = False),
    visibility = ["//visibility:public"],
)

py_runtime_toolchain(
    name = "py_runtime",
    interpreter = "python/bin/python3",
    runtime_files = [":all_files"],
    visibility = ["//visibility:public"],
)

toolchain(
    name = "toolchain",
    toolchain = ":py_runtime",
    toolchain_type = "@cross_platform//python:toolchain_type",
    exec_compatible_with = {exec_constraints},
    target_compatible_with = [],
    visibility = ["//visibility:public"],
)
"""

def _exec_constraints(os_name, arch):
    if "linux" in os_name and arch == "x86_64":
        return '["@platforms//os:linux", "@platforms//cpu:x86_64"]'
    if "linux" in os_name and arch == "aarch64":
        return '["@platforms//os:linux", "@platforms//cpu:aarch64"]'
    if "mac" in os_name and arch == "arm64":
        return '["@platforms//os:macos", "@platforms//cpu:arm64"]'
    if "mac" in os_name and arch == "x86_64":
        return '["@platforms//os:macos", "@platforms//cpu:x86_64"]'
    return "[]"

def _python_repository_impl(repository_ctx):
    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()

    # Normalize arch aliases
    if arch in ("amd64", "x86-64"):
        arch = "x86_64"
    if arch in ("arm64", "aarch64"):
        arch = "aarch64" if "linux" in os_name else "arm64"

    platform_key = None
    for key in _PLATFORMS:
        if os_name.startswith(key[0]) and arch == key[1]:
            platform_key = key
            break

    if platform_key == None:
        fail("Unsupported exec platform: os={}, arch={}".format(os_name, arch))

    artifact_suffix, sha256 = _PLATFORMS[platform_key]
    artifact = "cpython-{}+{}-{}".format(_PYTHON_VERSION, _RELEASE_DATE, artifact_suffix)
    url = "https://github.com/astral-sh/python-build-standalone/releases/download/{}/{}".format(
        _RELEASE_DATE,
        artifact,
    )

    download_kwargs = dict(url = url, stripPrefix = "")
    if sha256:
        download_kwargs["sha256"] = sha256

    repository_ctx.download_and_extract(**download_kwargs)

    exec_constraints = _exec_constraints(os_name, arch)
    repository_ctx.file("BUILD.bazel", _BUILD_TEMPLATE.format(
        exec_constraints = exec_constraints,
    ))

python_repository = repository_rule(
    implementation = _python_repository_impl,
    doc = "Downloads a hermetic CPython standalone build for the exec platform.",
    attrs = {},
)
