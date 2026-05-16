load("@rules_go//go:def.bzl", "go_binary")

go_binary(
    name = "server",
    srcs = ["main.go"],
    pure = "on",
    deps = ["//examples/go/clientServer:server_lib"],
)
