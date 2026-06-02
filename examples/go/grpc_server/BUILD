load("@rules_go//go:def.bzl", "go_binary")
load("//license:report.bzl", "license_report")

go_binary(
    name = "server",
    srcs = ["main.go"],
    pure = "on",
    deps = [
        "//examples/go/grpc_service",
        "//examples/proto:greeter_go_lib",
        "@org_golang_google_grpc//:grpc",
    ],
    tags = [
        "server",
    ],
)

# License report for the Go gRPC server and all its transitive dependencies.
# Build:  ./bazel build //examples/go/grpc_server:server_licenses
# Read:   cat bazel-bin/examples/go/grpc_server/server_licenses_license_report.txt
license_report(
    name = "server_licenses",
    target = ":server",
    artifact_name = "Go gRPC Server (//examples/go/grpc_server:server)",
    deps_licenses = [
        "//license:go_grpc_deps",
        "//license:project_license",
    ],
)
