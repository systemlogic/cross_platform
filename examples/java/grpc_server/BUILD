load("@rules_java//java:defs.bzl", "java_binary")
load("//license:report.bzl", "license_report")

# Run: ./bazel run //examples/java/grpc_server:server
# Run: ./bazel run //examples/java/grpc_server:server -- 50051

java_binary(
    name = "server",
    srcs = ["Server.java"],
    main_class = "com.example.greeter.Server",
    deps = [
        "//examples/java/grpc_service:grpc_service",
        "@maven_grpc_api//:jar",
        "@maven_grpc_core//:jar",
        "@maven_grpc_netty_shaded//:jar",
    ],
    tags = [
        "server"
    ],
)

# License report for the Java gRPC server and all its transitive dependencies.
# Build:  ./bazel build //examples/java/grpc_server:server_licenses
# Read:   cat bazel-bin/examples/java/grpc_server/server_licenses_license_report.txt
license_report(
    name = "server_licenses",
    target = ":server",
    artifact_name = "Java gRPC Server (//examples/java/grpc_server:server)",
    deps_licenses = [
        "//license:java_grpc_deps",
        "//license:project_license",
    ],
)
