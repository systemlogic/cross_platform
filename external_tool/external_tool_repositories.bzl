load(
    "//:toolchain_repositories.bzl",
    "gcc_9_arm64_repository",
    "gcc_9_x86_64_repository",
    "llvm_macos_arm64_repository",
    "macos_sdk_repository",
)

def external_tool_workspace():
    # Linux GCC cross-compilers (downloaded tarballs, exec: linux/x86_64)
    gcc_9_x86_64_repository(name = "gcc_9_x86_64")
    gcc_9_arm64_repository(name = "gcc_9_arm64")

    # macOS LLVM 18 (downloaded tarball, exec: macos/arm64)
    # LLVM no longer ships x86_64-macOS pre-built binaries; the ARM64 build
    # cross-compiles to x86_64 via -target x86_64-apple-macos10.15.
    llvm_macos_arm64_repository(name = "llvm_macos_arm64")

    # Detects the macOS SDK path via xcrun; degrades gracefully on non-macOS hosts.
    macos_sdk_repository(name = "macos_sdk")

