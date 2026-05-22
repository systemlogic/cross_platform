load("@rules_go//go:def.bzl", "go_library", "go_test")

# Build and run:
#   ./bazel run //examples/go/grpc_server:server
#   ./bazel run //examples/go/grpc_client:client -- world
# Test:
#   ./bazel test //examples/go/grpc_service:server_test

go_library(
    name = "grpc_service",
    srcs = ["server_lib.go"],
    importpath = "cross_platform/examples/go/grpc_service",
    deps = [
        "//examples/proto:greeter_go_lib",
    ],
    visibility = ["//examples/go:__subpackages__"],
)

go_test(
    name = "server_test",
    srcs = ["server_lib_test.go"],
    pure = "on",
    deps = [
        ":grpc_service",
        "//examples/proto:greeter_go_lib",
        "@org_golang_google_grpc//:grpc",
        "@org_golang_google_grpc//credentials/insecure",
    ],
)
