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
        sha256 = repository_ctx.attr.sha256,
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
        "sha256": attr.string(default = ""),
    },
)

# =============================================================================
# Temurin JDK 21.0.11+10 — four platform archives
#
# macOS: strip_prefix includes Contents/Home so the JDK root lands at repo root.
# Linux: top-level directory stripped, JDK root lands at repo root.
# After extraction, bin/java is always at ./bin/java for all four repos.
# =============================================================================

def jdk_temurin_21_macos_arm64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.11%2B10/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.11_10.tar.gz"],
        sha256 = "6ebcf221c9b41507b14c098e93c6ead6440b8d9bd154f8ec666c4c73abbdb201",
        strip_prefix = "jdk-21.0.11+10/Contents/Home",
        build_file = "//external_tool:BUILD.jdk.bazel",
    )

def jdk_temurin_21_macos_x86_64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.11%2B10/OpenJDK21U-jdk_x64_mac_hotspot_21.0.11_10.tar.gz"],
        sha256 = "34180eb03e6d207c388cce3da668f6cc7cd7508c185c24782fadac2c9c0e66f9",
        strip_prefix = "jdk-21.0.11+10/Contents/Home",
        build_file = "//external_tool:BUILD.jdk.bazel",
    )

def jdk_temurin_21_linux_x86_64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.11%2B10/OpenJDK21U-jdk_x64_linux_hotspot_21.0.11_10.tar.gz"],
        sha256 = "4b2220e232a97997b436ca6ab15cbf70171ecff52958a46159dfa5a8c44ca4de",
        strip_prefix = "jdk-21.0.11+10",
        build_file = "//external_tool:BUILD.jdk.bazel",
    )

def jdk_temurin_21_linux_aarch64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.11%2B10/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.11_10.tar.gz"],
        sha256 = "8d498ec88e1c1989fab95c6784240ab92d011e29c54d20a3f9c324b13476f9ad",
        strip_prefix = "jdk-21.0.11+10",
        build_file = "//external_tool:BUILD.jdk.bazel",
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
#
# ld.lld in this package is dynamically linked against libxml2.so.2.  Its ELF
# RPATH ($ORIGIN/../lib) causes the OS loader to look in lib/ relative to the
# binary, so we bundle libxml2 there during repository setup.  If libxml2 is not
# installed on the host we download the Ubuntu 22.04 arm64 .deb as a hermetic
# fallback (Bazel caches the download in the output base).

def _llvm_linux_aarch64_impl(repository_ctx):
    repository_ctx.download_and_extract(
        url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/clang+llvm-18.1.8-aarch64-linux-gnu.tar.xz",
        stripPrefix = "clang+llvm-18.1.8-aarch64-linux-gnu",
    )

    # Search the host's library cache, then common paths.
    find_result = repository_ctx.execute([
        "bash",
        "-c",
        "{ ldconfig -p 2>/dev/null | grep 'libxml2\\.so\\.2 ' | awk '{print $NF}' | head -1; " +
        "find /usr/lib /lib /usr/local/lib -maxdepth 5 -name 'libxml2.so.*' -not -name '*.a' " +
        "  2>/dev/null | sort -V | tail -1; } | grep -v '^$' | head -1",
    ])
    libxml = find_result.stdout.strip()

    if libxml:
        cp = repository_ctx.execute(["cp", libxml, "lib/libxml2.so.2"])
        if cp.return_code != 0:
            fail("Failed to copy libxml2 from host: " + cp.stderr)
    else:
        # libxml2 not found on host — download from Ubuntu 22.04 arm64 package mirror.
        repository_ctx.download(
            url = "http://ports.ubuntu.com/ubuntu-ports/pool/main/libx/libxml2/libxml2_2.9.13+dfsg-1ubuntu0.6_arm64.deb",
            output = "_libxml2.deb",
        )
        extract = repository_ctx.execute([
            "bash",
            "-c",
            "set -e; " +
            "mkdir -p _libxml2_tmp && cd _libxml2_tmp; " +
            "ar x ../_libxml2.deb; " +
            "if [ -f data.tar.xz ]; then tar xJf data.tar.xz; " +
            "elif [ -f data.tar.zst ]; then " +
            "  if command -v zstd >/dev/null 2>&1; then " +
            "    zstd -d data.tar.zst -o data.tar && tar xf data.tar && rm -f data.tar; " +
            "  else tar --zstd -xf data.tar.zst; fi; " +
            "elif [ -f data.tar.gz ]; then tar xzf data.tar.gz; fi; " +
            "SO=$(find . -name 'libxml2.so.*' -not -name '*.a' 2>/dev/null | sort -V | tail -1); " +
            "cp \"$SO\" ../lib/libxml2.so.2; " +
            "cd ..; rm -rf _libxml2.deb _libxml2_tmp",
        ])
        if extract.return_code != 0:
            fail(
                "Could not bundle libxml2.so.2 for ld.lld.\n" +
                "Quick fix: sudo apt-get install -y libxml2\n" +
                extract.stderr,
            )

    repository_ctx.symlink(
        repository_ctx.path(repository_ctx.attr.build_file),
        "BUILD.bazel",
    )

_llvm_linux_aarch64_rule = repository_rule(
    implementation = _llvm_linux_aarch64_impl,
    attrs = {
        "build_file": attr.label(mandatory = True, allow_single_file = True),
    },
)

def llvm_linux_aarch64_repository(name):
    _llvm_linux_aarch64_rule(
        name = name,
        build_file = "//external_tool:BUILD.llvm_linux.bazel",
    )

# ARM GNU Toolchain 14.2.rel1 — aarch64 Linux hosted, targeting aarch64-none-linux-gnu.
# The compiler runs on an aarch64 exec machine and produces aarch64 Linux output.
# Self-contained: includes its own glibc sysroot at aarch64-none-linux-gnu/libc/,
# matching the layout that cc_toolchain_config.bzl expects.
# Replaces llvm_linux_aarch64 for the Linux arm64 target on aarch64 exec machines.
def gcc_14_arm64_aarch64_hosted_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-aarch64-aarch64-none-linux-gnu.tar.xz"],
        sha256 = "299c56db1644c135670afabbf801b97a42e5ef6069d73157ab869458cbda2096",
        strip_prefix = "arm-gnu-toolchain-14.2.rel1-aarch64-aarch64-none-linux-gnu",
        build_file = "//external_tool:BUILD.gcc_9_arm64.bazel",
        patch_cmds = [
            "SYSROOT=aarch64-none-linux-gnu/libc; " +
            "for SO in \"$SYSROOT/usr/lib/libc.so\" \"$SYSROOT/usr/lib64/libc.so\" \"$SYSROOT/usr/lib/libm.so\" \"$SYSROOT/usr/lib64/libm.so\"; do " +
            "if [ -f \"$SO\" ] && head -1 \"$SO\" | grep -q 'GNU ld script'; then " +
            "sed -i 's# /lib/# =/lib/#g' \"$SO\"; " +
            "sed -i 's# /usr/lib/# =/usr/lib/#g' \"$SO\"; " +
            "sed -i 's# /lib64/# =/lib64/#g' \"$SO\"; " +
            "sed -i 's# /usr/lib64/# =/usr/lib64/#g' \"$SO\"; " +
            "fi; " +
            "done",
        ],
    )

# GCC 12 cross-compiler for x86_64 Linux target — runs on aarch64 exec machines.
# Downloads Ubuntu 22.04 LTS (Jammy) arm64 packages directly from the Ubuntu archive;
# no apt-get or host package manager involvement (hermetic http downloads).
#
# Three packages are combined into a single repository:
#   gcc-12-x86-64-linux-gnu   — GCC 12 compiler binary and helper programs
#   binutils-x86-64-linux-gnu — cross-binutils (ld, ar, objcopy, …)
#   libgcc-12-dev-amd64-cross — GCC runtime: crtbegin.o, libgcc.a, internal headers
#
# A wrapper script at bin/x86_64-linux-gnu-gcc passes -B at runtime so GCC 12 finds
# its internal files (crt*.o, libgcc.a, compiler headers) relative to the repository.
# The x86_64 glibc sysroot (headers/libs) is taken from the gcc_9_x86_64 Bootlin repo.
def _gcc_x86_64_on_aarch64_impl(repository_ctx):
    pkgs = [
        (
            "gcc-12-x86-64-linux-gnu",
            "http://ports.ubuntu.com/ubuntu-ports/pool/universe/g/gcc-12-cross/" +
            "gcc-12-x86-64-linux-gnu_12.3.0-1ubuntu1~22.04.3cross1_arm64.deb",
            "eac763296aecba5a3b2313032a923233ffb241ae561af4615e1aef4a86f3cc73",
        ),
        (
            "binutils-x86-64-linux-gnu",
            "http://ports.ubuntu.com/ubuntu-ports/pool/main/b/binutils/" +
            "binutils-x86-64-linux-gnu_2.38-4ubuntu2.12_arm64.deb",
            "c239870543213279089e49b4b7aee015559ed17d0937442b1ce3740d7c88a8e5",
        ),
        (
            "libgcc-12-dev-amd64-cross",
            "http://ports.ubuntu.com/ubuntu-ports/pool/universe/g/gcc-12-cross/" +
            "libgcc-12-dev-amd64-cross_12.3.0-1ubuntu1~22.04.3cross1_all.deb",
            "c7cee2018704a3964cda9c9d575103922f2e73fffe03749ce19b344d1ef071ee",
        ),
        (
            "cpp-12-x86-64-linux-gnu",
            "http://ports.ubuntu.com/ubuntu-ports/pool/universe/g/gcc-12-cross/" +
            "cpp-12-x86-64-linux-gnu_12.3.0-1ubuntu1~22.04.3cross1_arm64.deb",
            "169faa995975e8974136655e7b287559f887c58761e046ce7d287260f3f15709",
        ),
        (
            "g++-12-x86-64-linux-gnu",
            "http://ports.ubuntu.com/ubuntu-ports/pool/universe/g/gcc-12-cross/" +
            "g++-12-x86-64-linux-gnu_12.3.0-1ubuntu1~22.04.3cross1_arm64.deb",
            "887b1906979bc79b1951a54a65e77a7b066ff2df6a6b232254c251a98fd154a1",
        ),
        (
            "libstdc++-12-dev-amd64-cross",
            "http://ports.ubuntu.com/ubuntu-ports/pool/universe/g/gcc-12-cross/" +
            "libstdc++-12-dev-amd64-cross_12.3.0-1ubuntu1~22.04.3cross1_all.deb",
            "22c59d4414dda1dbc1c388ba5a3048461e02e53425b4faf3a82f876d4850c596",
        ),
        # cc1 (from cpp-12-x86-64-linux-gnu) links against these shared libraries at runtime.
        (
            "libisl23",
            "http://ports.ubuntu.com/ubuntu-ports/pool/main/i/isl/" +
            "libisl23_0.24-2build1_arm64.deb",
            "1e6e12c1ec8aa83839fe9451b533bfe5bf63b44b0e66a71c1e41706c481fb6e9",
        ),
        (
            "libmpc3",
            "http://ports.ubuntu.com/ubuntu-ports/pool/main/m/mpclib3/" +
            "libmpc3_1.2.1-2build1_arm64.deb",
            "7f6fc0fdb744474a5f49077c37bc848af64392eb970fddf447092f190a3fe635",
        ),
        (
            "libmpfr6",
            "http://ports.ubuntu.com/ubuntu-ports/pool/main/m/mpfr4/" +
            "libmpfr6_4.1.0-3build3_arm64.deb",
            "cef55f2fe8a149d8d460140a10b8e8539ada9f7fbfa3a44f77ac2a049b3baaa2",
        ),
    ]

    for (pkg_name, url, sha256) in pkgs:
        deb = "_{}.deb".format(pkg_name)
        repository_ctx.download(url = url, output = deb, sha256 = sha256)
        # Use dpkg-deb by full path to avoid sandbox PATH restrictions.
        result = repository_ctx.execute(["/usr/bin/dpkg-deb", "--extract", deb, "."])
        if result.return_code != 0:
            fail("Failed to extract {}: {}".format(pkg_name, result.stderr))
        repository_ctx.execute(["rm", "-f", deb])

    setup = repository_ctx.execute([
        "bash", "-c",
        r"""set -e
mkdir -p bin
cat > bin/x86_64-linux-gnu-gcc << 'WRAPPER_EOF'
#!/bin/bash
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LD_LIBRARY_PATH="$REPO/usr/lib/aarch64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$REPO/usr/bin/x86_64-linux-gnu-gcc-12" \
    -B "$REPO/usr/lib/gcc-cross/x86_64-linux-gnu/12/" \
    "$@"
WRAPPER_EOF
chmod +x bin/x86_64-linux-gnu-gcc
ln -sf x86_64-linux-gnu-gcc bin/x86_64-linux-gnu-cpp
ln -sf x86_64-linux-gnu-gcc bin/x86_64-linux-gnu-g++
for t in ar as ld nm objcopy objdump ranlib readelf strip; do
    cat > "bin/x86_64-linux-gnu-$t" << TOOL_EOF
#!/bin/bash
REPO="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
export LD_LIBRARY_PATH="\$REPO/usr/lib/aarch64-linux-gnu\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "\$REPO/usr/bin/x86_64-linux-gnu-$t" "\$@"
TOOL_EOF
    chmod +x "bin/x86_64-linux-gnu-$t"
done
""",
    ])
    if setup.return_code != 0:
        fail("Failed to create bin/ wrappers: " + setup.stderr)

    repository_ctx.symlink(
        repository_ctx.path(repository_ctx.attr.build_file),
        "BUILD.bazel",
    )

_gcc_x86_64_on_aarch64_rule = repository_rule(
    implementation = _gcc_x86_64_on_aarch64_impl,
    attrs = {
        "build_file": attr.label(mandatory = True, allow_single_file = True),
    },
)

def gcc_x86_64_on_aarch64_repository(name):
    _gcc_x86_64_on_aarch64_rule(
        name = name,
        build_file = "//external_tool:BUILD.gcc_9_x86_64.bazel",
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

# =============================================================================
# protoc 29.3 — one per exec platform
#
# Archive layout (no top-level directory, strip_prefix = ""):
#   bin/protoc
#   include/google/protobuf/*.proto
#
# sha256 values: run `shasum -a 256 <file>` after first download and fill in.
# =============================================================================

def protoc_linux_x86_64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/protocolbuffers/protobuf/releases/download/v29.3/protoc-29.3-linux-x86_64.zip"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.protoc.bazel",
    )

def protoc_linux_aarch64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/protocolbuffers/protobuf/releases/download/v29.3/protoc-29.3-linux-aarch_64.zip"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.protoc.bazel",
    )

def protoc_macos_arm64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/protocolbuffers/protobuf/releases/download/v29.3/protoc-29.3-osx-aarch_64.zip"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.protoc.bazel",
    )

def protoc_macos_x86_64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/protocolbuffers/protobuf/releases/download/v29.3/protoc-29.3-osx-x86_64.zip"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.protoc.bazel",
    )

# =============================================================================
# protoc-gen-go v1.35.2 — protobuf Go code generator
# Archive contains a single binary: protoc-gen-go
# =============================================================================

def protoc_gen_go_linux_x86_64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/protocolbuffers/protobuf-go/releases/download/v1.35.2/protoc-gen-go.v1.35.2.linux.amd64.tar.gz"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def protoc_gen_go_linux_aarch64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/protocolbuffers/protobuf-go/releases/download/v1.35.2/protoc-gen-go.v1.35.2.linux.arm64.tar.gz"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def protoc_gen_go_macos_arm64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/protocolbuffers/protobuf-go/releases/download/v1.35.2/protoc-gen-go.v1.35.2.darwin.arm64.tar.gz"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def protoc_gen_go_macos_x86_64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/protocolbuffers/protobuf-go/releases/download/v1.35.2/protoc-gen-go.v1.35.2.darwin.amd64.tar.gz"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

# =============================================================================
# protoc-gen-go-grpc v1.5.1 — gRPC Go service stub generator
# Archive contains a single binary: protoc-gen-go-grpc
# =============================================================================

def protoc_gen_go_grpc_linux_x86_64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/grpc/grpc-go/releases/download/cmd%2Fprotoc-gen-go-grpc%2Fv1.5.1/protoc-gen-go-grpc.v1.5.1.linux.amd64.tar.gz"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def protoc_gen_go_grpc_linux_aarch64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/grpc/grpc-go/releases/download/cmd%2Fprotoc-gen-go-grpc%2Fv1.5.1/protoc-gen-go-grpc.v1.5.1.linux.arm64.tar.gz"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def protoc_gen_go_grpc_macos_arm64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/grpc/grpc-go/releases/download/cmd%2Fprotoc-gen-go-grpc%2Fv1.5.1/protoc-gen-go-grpc.v1.5.1.darwin.arm64.tar.gz"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def protoc_gen_go_grpc_macos_x86_64_repository(name):
    toolchain_archive_repository(
        name = name,
        urls = ["https://github.com/grpc/grpc-go/releases/download/cmd%2Fprotoc-gen-go-grpc%2Fv1.5.1/protoc-gen-go-grpc.v1.5.1.darwin.amd64.tar.gz"],
        sha256 = "",
        strip_prefix = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

# =============================================================================
# protoc-gen-grpc-java 1.68.0 — gRPC Java service stub generator
#
# Distributed as a standalone executable (not an archive) from Maven Central.
# The .exe extension is misleading — these are native ELF/Mach-O binaries.
# =============================================================================

def _grpc_java_plugin_impl(repository_ctx):
    repository_ctx.download(
        url = repository_ctx.attr.url,
        output = "protoc-gen-grpc-java",
        sha256 = repository_ctx.attr.sha256,
        executable = True,
    )
    repository_ctx.symlink(
        repository_ctx.path(repository_ctx.attr.build_file),
        "BUILD.bazel",
    )

_grpc_java_plugin_repository = repository_rule(
    implementation = _grpc_java_plugin_impl,
    attrs = {
        "url": attr.string(mandatory = True),
        "sha256": attr.string(default = ""),
        "build_file": attr.label(mandatory = True, allow_single_file = True),
    },
)

def protoc_gen_grpc_java_linux_x86_64_repository(name):
    _grpc_java_plugin_repository(
        name = name,
        url = "https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/1.68.0/protoc-gen-grpc-java-1.68.0-linux-x86_64.exe",
        sha256 = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def protoc_gen_grpc_java_linux_aarch64_repository(name):
    _grpc_java_plugin_repository(
        name = name,
        url = "https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/1.68.0/protoc-gen-grpc-java-1.68.0-linux-aarch_64.exe",
        sha256 = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def protoc_gen_grpc_java_macos_arm64_repository(name):
    _grpc_java_plugin_repository(
        name = name,
        url = "https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/1.68.0/protoc-gen-grpc-java-1.68.0-osx-aarch_64.exe",
        sha256 = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def protoc_gen_grpc_java_macos_x86_64_repository(name):
    _grpc_java_plugin_repository(
        name = name,
        url = "https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/1.68.0/protoc-gen-grpc-java-1.68.0-osx-x86_64.exe",
        sha256 = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

# =============================================================================
# grpc_python_plugin 1.68.0 — gRPC Python service stub generator
#
# Distributed as a standalone executable from GitHub releases.
# Binary is renamed to protoc-gen-grpc_python so protoc uses --grpc_python_out.
# =============================================================================

def _grpc_python_plugin_impl(repository_ctx):
    repository_ctx.download(
        url = repository_ctx.attr.url,
        output = "protoc-gen-grpc_python",
        sha256 = repository_ctx.attr.sha256,
        executable = True,
    )
    repository_ctx.symlink(
        repository_ctx.path(repository_ctx.attr.build_file),
        "BUILD.bazel",
    )

_grpc_python_plugin_repository = repository_rule(
    implementation = _grpc_python_plugin_impl,
    attrs = {
        "url": attr.string(mandatory = True),
        "sha256": attr.string(default = ""),
        "build_file": attr.label(mandatory = True, allow_single_file = True),
    },
)

def grpc_python_plugin_linux_x86_64_repository(name):
    _grpc_python_plugin_repository(
        name = name,
        url = "https://github.com/grpc/grpc/releases/download/v1.68.0/grpc_python_plugin-linux-x86_64.exe",
        sha256 = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def grpc_python_plugin_linux_aarch64_repository(name):
    _grpc_python_plugin_repository(
        name = name,
        url = "https://github.com/grpc/grpc/releases/download/v1.68.0/grpc_python_plugin-linux-aarch_64.exe",
        sha256 = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def grpc_python_plugin_macos_arm64_repository(name):
    _grpc_python_plugin_repository(
        name = name,
        url = "https://github.com/grpc/grpc/releases/download/v1.68.0/grpc_python_plugin-osx-aarch_64.exe",
        sha256 = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

def grpc_python_plugin_macos_x86_64_repository(name):
    _grpc_python_plugin_repository(
        name = name,
        url = "https://github.com/grpc/grpc/releases/download/v1.68.0/grpc_python_plugin-osx-x86_64.exe",
        sha256 = "",
        build_file = "//external_tool:BUILD.proto_plugin.bazel",
    )

# =============================================================================
# maven_jar_repository — downloads a single Maven JAR from a URL.
#
# Exposes the JAR as a java_import :jar target (BUILD.maven_jar.bazel).
# Uses Bazel's built-in http downloader — no host JVM or Maven tooling needed.
# Used for the gRPC Java runtime: grpc-java 1.68.0, protobuf-java 3.25.5, guava.
# =============================================================================

def _maven_jar_impl(repository_ctx):
    repository_ctx.download(
        url = repository_ctx.attr.url,
        output = "lib.jar",
        sha256 = repository_ctx.attr.sha256,
    )
    repository_ctx.symlink(
        repository_ctx.path(repository_ctx.attr.build_file),
        "BUILD.bazel",
    )

_maven_jar_repository = repository_rule(
    implementation = _maven_jar_impl,
    attrs = {
        "url": attr.string(mandatory = True),
        "sha256": attr.string(default = ""),
        "build_file": attr.label(mandatory = True, allow_single_file = True),
    },
)

def grpc_java_maven_repositories():
    """Downloads all Maven JARs required by the Java gRPC example."""

    # Core gRPC interfaces: Channel, Server, Metadata, CallOptions, Status …
    _maven_jar_repository(
        name = "maven_grpc_api",
        url = "https://repo1.maven.org/maven2/io/grpc/grpc-api/1.68.0/grpc-api-1.68.0.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # io.grpc.Context — separated from grpc-api in 1.x; referenced by grpc-api public API
    _maven_jar_repository(
        name = "maven_grpc_context",
        url = "https://repo1.maven.org/maven2/io/grpc/grpc-context/1.68.0/grpc-context-1.68.0.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # AbstractStub, ClientCalls, ServerCalls, StreamObserver — needed by generated stubs
    _maven_jar_repository(
        name = "maven_grpc_stub",
        url = "https://repo1.maven.org/maven2/io/grpc/grpc-stub/1.68.0/grpc-stub-1.68.0.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # ProtoUtils.marshaller() — wires protobuf messages into gRPC method descriptors
    _maven_jar_repository(
        name = "maven_grpc_protobuf",
        url = "https://repo1.maven.org/maven2/io/grpc/grpc-protobuf/1.68.0/grpc-protobuf-1.68.0.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # ProtoLiteUtils — runtime dep of grpc-protobuf (ProtoUtils.marshaller delegates to it)
    _maven_jar_repository(
        name = "maven_grpc_protobuf_lite",
        url = "https://repo1.maven.org/maven2/io/grpc/grpc-protobuf-lite/1.68.0/grpc-protobuf-lite-1.68.0.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # grpc-core: io.grpc.internal.* classes used at runtime by grpc-netty-shaded.
    # Not bundled inside grpc-netty-shaded.jar; must be on the classpath separately.
    _maven_jar_repository(
        name = "maven_grpc_core",
        url = "https://repo1.maven.org/maven2/io/grpc/grpc-core/1.68.0/grpc-core-1.68.0.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # Netty transport (shaded): NettyServerBuilder, NettyChannelBuilder.
    # Bundles shaded Netty; requires grpc-core and grpc-api on the classpath.
    _maven_jar_repository(
        name = "maven_grpc_netty_shaded",
        url = "https://repo1.maven.org/maven2/io/grpc/grpc-netty-shaded/1.68.0/grpc-netty-shaded-1.68.0.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # Protobuf runtime — must match the protoc version (29.3 → Java 4.29.3).
    # protoc 26+ generates code that calls RuntimeVersion.validateProtobufGencodeVersion()
    # and uses API changes that only exist in protobuf-java 4.x.
    _maven_jar_repository(
        name = "maven_protobuf_java",
        url = "https://repo1.maven.org/maven2/com/google/protobuf/protobuf-java/4.29.3/protobuf-java-4.29.3.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # Guava — ListenableFuture used in AbstractFutureStub public API
    _maven_jar_repository(
        name = "maven_guava",
        url = "https://repo1.maven.org/maven2/com/google/guava/guava/33.3.1-jre/guava-33.3.1-jre.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # FailureAccess — split out of guava; needed when guava is on the compile path
    _maven_jar_repository(
        name = "maven_failureaccess",
        url = "https://repo1.maven.org/maven2/com/google/guava/failureaccess/1.0.2/failureaccess-1.0.2.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # javax.annotation-api — @Generated annotation on protoc-gen-grpc-java output
    _maven_jar_repository(
        name = "maven_javax_annotation",
        url = "https://repo1.maven.org/maven2/javax/annotation/javax.annotation-api/1.3.2/javax.annotation-api-1.3.2.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # perfmark-api — used by grpc-core ClientCallImpl for tracing; required at runtime
    _maven_jar_repository(
        name = "maven_perfmark_api",
        url = "https://repo1.maven.org/maven2/io/perfmark/perfmark-api/0.27.0/perfmark-api-0.27.0.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )

    # error_prone_annotations — annotation-only jar; guards against missing annotation class
    _maven_jar_repository(
        name = "maven_error_prone_annotations",
        url = "https://repo1.maven.org/maven2/com/google/errorprone/error_prone_annotations/2.28.0/error_prone_annotations-2.28.0.jar",
        build_file = "//external_tool:BUILD.maven_jar.bazel",
    )
