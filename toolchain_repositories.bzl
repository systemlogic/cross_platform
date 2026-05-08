def _macos_sdk_impl(repository_ctx):
    result = repository_ctx.execute(["xcrun", "--show-sdk-path"])
    sdk_path = result.stdout.strip() if result.return_code == 0 else ""
    # On Linux (or any non-macOS host) fall back to an env-var supplied SDK path,
    # e.g.  export MACOS_SDK_PATH=/opt/MacOSX13.sdk
    if not sdk_path:
        sdk_path = repository_ctx.os.environ.get("MACOS_SDK_PATH", "")
    repository_ctx.file("sdk_path.bzl", 'MACOS_SDK_PATH = "%s"\n' % sdk_path)
    repository_ctx.file("BUILD.bazel", "")

macos_sdk_repository = repository_rule(
    implementation = _macos_sdk_impl,
    configure = True,  # re-run when the Xcode SDK changes
)

def _toolchain_archive_impl(repository_ctx):
    print(repository_ctx.attr.urls)
    repository_ctx.download_and_extract(
        url = repository_ctx.attr.urls[0],
        stripPrefix = repository_ctx.attr.strip_prefix,
    )

    for cmd in repository_ctx.attr.patch_cmds:
        result = repository_ctx.execute(["bash", "-c", cmd], quiet = False)
        if result.return_code != 0:
            fail("Patch command failed: %s\n%s" % (cmd, result.stderr))

    repository_ctx.symlink(repository_ctx.path(repository_ctx.attr.build_file), "BUILD.bazel")

toolchain_archive_repository = repository_rule(
    implementation = _toolchain_archive_impl,
    attrs = {
        "urls": attr.string_list(mandatory = True),
        "strip_prefix": attr.string(mandatory = True),
        "build_file": attr.label(mandatory = True, allow_single_file = True),
        "patch_cmds": attr.string_list(default = []),
    },
)

def gcc_9_x86_64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://toolchains.bootlin.com/downloads/releases/toolchains/x86-64/tarballs/x86-64--glibc--stable-2024.02-1.tar.bz2"],
        strip_prefix = "x86-64--glibc--stable-2024.02-1",
        build_file = "//external_tool:BUILD.gcc_9_x86_64.bazel",
        patch_cmds = [
            "SYSROOT=x86_64-buildroot-linux-gnu/sysroot; " +
            "for SO in \"$SYSROOT/usr/lib64/libc.so\" \"$SYSROOT/usr/lib/libc.so\" \"$SYSROOT/usr/lib/libm.so\" \"$SYSROOT/usr/lib64/libm.so\"; do " +
            "if [ -f \"$SO\" ] && head -1 \"$SO\" | grep -q 'GNU ld script'; then " +
            "sed -i 's# /lib64/# =/lib64/#g' \"$SO\"; " +
            "sed -i 's# /usr/lib64/# =/usr/lib64/#g' \"$SO\"; " +
            "sed -i 's# /lib/# =/lib/#g' \"$SO\"; " +
            "sed -i 's# /usr/lib/# =/usr/lib/#g' \"$SO\"; " +
            "fi; " +
            "done",
        ],
    )

def gcc_9_arm64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz"],
        strip_prefix = "gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu",
        build_file = "//external_tool:BUILD.gcc_9_arm64.bazel",
        patch_cmds = [
            "SYSROOT=aarch64-none-linux-gnu/libc; " +
            "for LIBC_SO in \"$SYSROOT/usr/lib/libc.so\" \"$SYSROOT/usr/lib64/libc.so\"; do " +
            "if [ -f \"$LIBC_SO\" ]; then " +
            "sed -i 's# /lib/# =/lib/#g' \"$LIBC_SO\"; " +
            "sed -i 's# /usr/lib/# =/usr/lib/#g' \"$LIBC_SO\"; " +
            "sed -i 's# /lib64/# =/lib64/#g' \"$LIBC_SO\"; " +
            "sed -i 's# /usr/lib64/# =/usr/lib64/#g' \"$LIBC_SO\"; " +
            "fi; " +
            "done",
        ],
    )

# Bootlin aarch64 sysroot — the tarball's compiler binaries are x86_64-hosted
# (Bootlin naming refers to the target, not the exec host).  Only the sysroot
# at aarch64-buildroot-linux-gnu/sysroot is used; the aarch64-hosted LLVM
# (llvm_linux_aarch64) provides the actual compiler on aarch64 exec machines.
def gcc_aarch64_native_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://toolchains.bootlin.com/downloads/releases/toolchains/aarch64/tarballs/aarch64--glibc--stable-2024.02-1.tar.bz2"],
        strip_prefix = "aarch64--glibc--stable-2024.02-1",
        build_file = "//external_tool:BUILD.gcc_aarch64_native.bazel",
        patch_cmds = [
            "SYSROOT=aarch64-buildroot-linux-gnu/sysroot; " +
            "for LIBC_SO in \"$SYSROOT/usr/lib/libc.so\" \"$SYSROOT/usr/lib64/libc.so\"; do " +
            "if [ -f \"$LIBC_SO\" ]; then " +
            "sed -i 's# /lib/# =/lib/#g' \"$LIBC_SO\"; " +
            "sed -i 's# /usr/lib/# =/usr/lib/#g' \"$LIBC_SO\"; " +
            "sed -i 's# /lib64/# =/lib64/#g' \"$LIBC_SO\"; " +
            "sed -i 's# /usr/lib64/# =/usr/lib64/#g' \"$LIBC_SO\"; " +
            "fi; " +
            "done",
        ],
    )

# LLVM 18.1.8 for macOS — runs on an Apple Silicon (ARM64) exec machine.
# Can cross-compile to both arm64-apple-macos12 and x86_64-apple-macos10.15 via -target.
# Note: LLVM no longer ships x86_64-macOS pre-built binaries; ARM64 exec covers both
# target arches via Clang's cross-compilation support.
def llvm_macos_arm64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/clang+llvm-18.1.8-arm64-apple-macos11.tar.xz"],
        strip_prefix = "clang+llvm-18.1.8-arm64-apple-macos11",
        build_file = "//external_tool:BUILD.llvm_macos.bazel",
    )

# LLVM 18.1.8 for Linux x86_64 — runs on a Linux x86_64 exec machine.
# Used to cross-compile macOS targets (arm64-apple-macos12, x86_64-apple-macos10.15)
# via -target; requires MACOS_SDK_PATH to be set for system headers.
def llvm_linux_x86_64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/clang+llvm-18.1.8-x86_64-linux-gnu-ubuntu-18.04.tar.xz"],
        strip_prefix = "clang+llvm-18.1.8-x86_64-linux-gnu-ubuntu-18.04",
        build_file = "//external_tool:BUILD.llvm_linux.bazel",
    )

# LLVM 18.1.8 for Linux aarch64 — runs on a Linux ARM64 exec machine.
# Used to cross-compile macOS targets (arm64-apple-macos12, x86_64-apple-macos10.15)
# via -target; requires MACOS_SDK_PATH to be set for system headers.
# Also used to cross-compile to Linux x86_64 via -target x86_64-linux-gnu with
# the Bootlin x86_64 sysroot (gcc_9_x86_64 repo).
def llvm_linux_aarch64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/clang+llvm-18.1.8-aarch64-linux-gnu.tar.xz"],
        strip_prefix = "clang+llvm-18.1.8-aarch64-linux-gnu",
        build_file = "//external_tool:BUILD.llvm_linux.bazel",
        patch_cmds = [
            # ld.lld links against libxml2.so.2, but Ubuntu 24.04+ ships libxml2.so.16.
            # Copy whatever libxml2 the host has into lib/ so ld.lld finds it via
            # its $ORIGIN/../lib RUNPATH without needing any system-path changes.
            "LIBXML=$(find /usr/lib -maxdepth 4 -name 'libxml2.so.*' -not -name '*.a' 2>/dev/null | sort -V | tail -1); " +
            "[ -n \"$LIBXML\" ] && cp \"$LIBXML\" lib/libxml2.so.2 || true",
        ],
    )

# LLVM 17.0.6 for macOS x86_64 — runs on an Intel Mac exec machine.
# LLVM 18+ no longer ships macOS x86_64 pre-built binaries; 17.0.6 is the
# latest release that does.  Can cross-compile to both x86_64-apple-macos10.15
# and arm64-apple-macos12 via -target.
def llvm_macos_x86_64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/clang+llvm-17.0.6-x86_64-apple-darwin22.0.tar.xz"],
        strip_prefix = "clang+llvm-17.0.6-x86_64-apple-darwin22.0",
        build_file = "//external_tool:BUILD.llvm_macos.bazel",
    )
