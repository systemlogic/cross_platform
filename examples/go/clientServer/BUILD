load("@rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "server_lib",
    srcs = ["server_lib.go"],
    importpath = "cross_platform/examples/go/clientServer",
    visibility = ["//examples/go:__subpackages__"],
)

go_test(
    name = "server_test",
    srcs = ["server_lib_test.go"],
    pure = "on",
    deps = [":server_lib"],
)
