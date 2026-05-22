load("@rules_java//java:defs.bzl", "java_binary")

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
)
