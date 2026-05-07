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
            "LIBC_SO=$SYSROOT/usr/lib64/libc.so; " +
            "if [ -f \"$LIBC_SO\" ]; then " +
            "sed -i 's# /lib64/# =/lib64/#g' \"$LIBC_SO\"; " +
            "sed -i 's# /usr/lib64/# =/usr/lib64/#g' \"$LIBC_SO\"; " +
            "fi",
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
