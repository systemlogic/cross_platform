load("@rules_go//go:def.bzl", "go_binary")

go_binary(
    name = "server",
    srcs = ["main.go"],
    pure = "on",
    deps = [
        "//examples/go/grpc_service",
        "//examples/proto:greeter_go_lib",
        "@org_golang_google_grpc//:grpc",
    ],
)
