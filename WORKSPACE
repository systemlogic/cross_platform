load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# GCC 9.3.0 for x86_64 Linux (via Bootlin)
http_archive(
    name = "gcc_9_x86_64",
    urls = ["https://toolchains.bootlin.com/downloads/releases/toolchains/x86-64/tarballs/x86-64--glibc--stable-2024.02-1.tar.bz2"],
    strip_prefix = "x86-64--glibc--stable-2024.02-1",
    build_file_content = """filegroup(name = "all_files", srcs = glob(["**/*"]), visibility = ["//visibility:public"])""",
)

# GCC 9.2.1 for ARM64 Linux (Aarch64) (via ARM Developer portal)
http_archive(
    name = "gcc_9_arm64",
    urls = ["https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz"],
    strip_prefix = "gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu",
    build_file_content = """filegroup(name = "all_files", srcs = glob(["**/*"]), visibility = ["//visibility:public"])""",
)
