load("@rules_java//java:defs.bzl", "java_binary")

# Run: ./bazel run //examples/java/grpc_client:client -- world
# Run: ./bazel run //examples/java/grpc_client:client -- world localhost 50051

java_binary(
    name = "client",
    srcs = ["Client.java"],
    main_class = "com.example.greeter.Client",
    deps = [
        "//examples/java/grpc_service:grpc_service",
        "@maven_grpc_api//:jar",
        "@maven_grpc_core//:jar",
        "@maven_grpc_netty_shaded//:jar",
        "@maven_grpc_stub//:jar",
    ],
)
