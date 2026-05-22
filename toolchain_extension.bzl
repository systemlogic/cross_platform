"""Module extension wiring all cross-compilation toolchain repositories into Bzlmod."""

load(
    "//:toolchain_repositories.bzl",
    "gcc_9_arm64_repository",
    "gcc_9_x86_64_repository",
    "gcc_14_arm64_aarch64_hosted_repository",
    "gcc_x86_64_on_aarch64_repository",
    "grpc_java_maven_repositories",
    "jdk_temurin_21_linux_aarch64_repository",
    "jdk_temurin_21_linux_x86_64_repository",
    "jdk_temurin_21_macos_arm64_repository",
    "jdk_temurin_21_macos_x86_64_repository",
    "llvm_linux_aarch64_repository",
    "llvm_linux_x86_64_repository",
    "llvm_macos_arm64_repository",
    "llvm_macos_x86_64_repository",
    "macos_sdk_repository",
    "protoc_linux_aarch64_repository",
    "protoc_linux_x86_64_repository",
    "protoc_macos_arm64_repository",
    "protoc_macos_x86_64_repository",
    "protoc_gen_go_linux_aarch64_repository",
    "protoc_gen_go_linux_x86_64_repository",
    "protoc_gen_go_macos_arm64_repository",
    "protoc_gen_go_macos_x86_64_repository",
    "protoc_gen_go_grpc_linux_aarch64_repository",
    "protoc_gen_go_grpc_linux_x86_64_repository",
    "protoc_gen_go_grpc_macos_arm64_repository",
    "protoc_gen_go_grpc_macos_x86_64_repository",
    "protoc_gen_grpc_java_linux_aarch64_repository",
    "protoc_gen_grpc_java_linux_x86_64_repository",
    "protoc_gen_grpc_java_macos_arm64_repository",
    "protoc_gen_grpc_java_macos_x86_64_repository",
)

def _toolchain_ext_impl(module_ctx):
    # Linux GCC cross-compilers (exec: linux/x86_64)
    gcc_9_x86_64_repository(name = "gcc_9_x86_64")
    gcc_9_arm64_repository(name = "gcc_9_arm64")

    # ARM GNU Toolchain 14.2.rel1 — aarch64-hosted, targeting aarch64-none-linux-gnu.
    # Used on aarch64 exec machines to compile Linux arm64 targets natively.
    gcc_14_arm64_aarch64_hosted_repository(name = "gcc_14_arm64_aarch64_hosted")

    # GCC 12 cross-compiler for x86_64 Linux target — runs on aarch64 exec machines.
    # Assembled from Ubuntu 22.04 arm64 .deb packages (hermetic, no apt-get).
    gcc_x86_64_on_aarch64_repository(name = "gcc_x86_64_on_aarch64")

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

    # Temurin JDK 21.0.11+10 — one repo per exec platform.
    # strip_prefix already accounts for the macOS Contents/Home bundle layout,
    # so bin/java is at the repository root for all four repos.
    jdk_temurin_21_macos_arm64_repository(name = "jdk_macos_arm64")
    jdk_temurin_21_macos_x86_64_repository(name = "jdk_macos_x86_64")
    jdk_temurin_21_linux_x86_64_repository(name = "jdk_linux_x86_64")
    jdk_temurin_21_linux_aarch64_repository(name = "jdk_linux_aarch64")

    # protoc 29.3 — one per exec platform.
    protoc_macos_arm64_repository(name = "protoc_macos_arm64")
    protoc_macos_x86_64_repository(name = "protoc_macos_x86_64")
    protoc_linux_x86_64_repository(name = "protoc_linux_x86_64")
    protoc_linux_aarch64_repository(name = "protoc_linux_aarch64")

    # protoc-gen-go v1.35.2 — Go protobuf message generator.
    protoc_gen_go_macos_arm64_repository(name = "protoc_gen_go_macos_arm64")
    protoc_gen_go_macos_x86_64_repository(name = "protoc_gen_go_macos_x86_64")
    protoc_gen_go_linux_x86_64_repository(name = "protoc_gen_go_linux_x86_64")
    protoc_gen_go_linux_aarch64_repository(name = "protoc_gen_go_linux_aarch64")

    # protoc-gen-go-grpc v1.5.1 — Go gRPC service stub generator.
    protoc_gen_go_grpc_macos_arm64_repository(name = "protoc_gen_go_grpc_macos_arm64")
    protoc_gen_go_grpc_macos_x86_64_repository(name = "protoc_gen_go_grpc_macos_x86_64")
    protoc_gen_go_grpc_linux_x86_64_repository(name = "protoc_gen_go_grpc_linux_x86_64")
    protoc_gen_go_grpc_linux_aarch64_repository(name = "protoc_gen_go_grpc_linux_aarch64")

    # protoc-gen-grpc-java 1.68.0 — Java gRPC service stub generator.
    protoc_gen_grpc_java_macos_arm64_repository(name = "protoc_gen_grpc_java_macos_arm64")
    protoc_gen_grpc_java_macos_x86_64_repository(name = "protoc_gen_grpc_java_macos_x86_64")
    protoc_gen_grpc_java_linux_x86_64_repository(name = "protoc_gen_grpc_java_linux_x86_64")
    protoc_gen_grpc_java_linux_aarch64_repository(name = "protoc_gen_grpc_java_linux_aarch64")

    # gRPC Java 1.68.0 Maven JARs — downloaded via Bazel's http downloader (no host JVM).
    grpc_java_maven_repositories()

toolchain_ext = module_extension(
    implementation = _toolchain_ext_impl,
)
