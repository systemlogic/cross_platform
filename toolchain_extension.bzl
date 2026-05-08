"""Module extension wiring all cross-compilation toolchain repositories into Bzlmod."""

load(
    "//:toolchain_repositories.bzl",
    "gcc_9_arm64_repository",
    "gcc_9_x86_64_repository",
    "gcc_aarch64_native_repository",
    "llvm_linux_aarch64_repository",
    "llvm_linux_x86_64_repository",
    "llvm_macos_arm64_repository",
    "llvm_macos_x86_64_repository",
    "macos_sdk_repository",
)

def _toolchain_ext_impl(module_ctx):
    # Linux GCC cross-compilers (exec: linux/x86_64)
    gcc_9_x86_64_repository(name = "gcc_9_x86_64")
    gcc_9_arm64_repository(name = "gcc_9_arm64")

    # Bootlin aarch64 sysroot (headers/libs for aarch64 Linux target).
    # The compiler binaries in this tarball are x86_64-hosted; the actual
    # compiler on aarch64 exec machines comes from llvm_linux_aarch64.
    gcc_aarch64_native_repository(name = "gcc_aarch64_native")

    # macOS LLVM 18 (exec: macos/arm64) — no host compiler used.
    # LLVM no longer ships x86_64-macOS binaries; ARM64 exec cross-compiles to x86_64 via -target.
    llvm_macos_arm64_repository(name = "llvm_macos_arm64")

    # macOS LLVM 17 (exec: macos/x86_64) — last LLVM release with macOS x86_64 binaries.
    # Cross-compiles to both x86_64-apple-macos10.15 and arm64-apple-macos12 via -target.
    llvm_macos_x86_64_repository(name = "llvm_macos_x86_64")

    # LLVM 18 Linux binaries — used when exec machine is Linux.
    # x86_64 build: cross-compiles to macOS, or natively to Linux x86_64 (with sysroot).
    # aarch64 build: cross-compiles to macOS or Linux x86_64 (with Bootlin x86_64 sysroot).
    llvm_linux_x86_64_repository(name = "llvm_linux_x86_64")
    llvm_linux_aarch64_repository(name = "llvm_linux_aarch64")

    # macOS SDK path detected via xcrun (macOS) or MACOS_SDK_PATH env var (Linux).
    # Degrades gracefully when neither is set.
    macos_sdk_repository(name = "macos_sdk")

toolchain_ext = module_extension(
    implementation = _toolchain_ext_impl,
)
