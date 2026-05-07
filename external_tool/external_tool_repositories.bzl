load("//:toolchain_repositories.bzl", "gcc_9_arm64_repository", "gcc_9_x86_64_repository")

def external_tool_workspace():
    # Register all external tool repositories used by this workspace.
    gcc_9_x86_64_repository(name = "gcc_9_x86_64")
    gcc_9_arm64_repository(name = "gcc_9_arm64")

