load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library", "cc_test")
load("//:transitions.bzl", "linux_arm64_binary")

cc_library(
    name = "hello-greet",
    srcs = ["hello-greet.cc"],
    hdrs = ["hello-greet.h"],
)

cc_binary(
    name = "hello-world",
    srcs = ["hello-world.cc"],
    deps = [
        ":hello-greet",
        "//examples/cc/lib:hello-time",
    ],
)

cc_test(
    name = "hello_greet_test",
    srcs = ["hello_greet_test.cc"],
    deps = [":hello-greet"],
)

# Build hello-world for Linux arm64 from any exec platform.
# On x86_64 exec: uses gcc_arm64_toolchain (ARM cross-compiler GCC 9).
# On aarch64 exec: uses gcc_arm64_native_toolchain (ARM GCC 14.2).
#
#   bazel build //examples/cc/main:hello-world_arm64
linux_arm64_binary(
    name = "hello-world_arm64",
    binary = ":hello-world",
    target_compatible_with = ["@platforms//os:linux"],
)
