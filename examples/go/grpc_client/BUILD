load("@rules_go//go:def.bzl", "go_binary")

go_binary(
    name = "client",
    srcs = ["main.go"],
    pure = "on",
    deps = [
        "//examples/proto:greeter_go_lib",
        "@org_golang_google_grpc//:grpc",
        "@org_golang_google_grpc//credentials/insecure",
    ],
)
