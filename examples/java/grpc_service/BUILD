load("@rules_java//java:defs.bzl", "java_library", "java_test")

# Build: ./bazel build //examples/java/grpc_service:grpc_service
# Test:  ./bazel test  //examples/java/grpc_service:service_test

java_library(
    name = "grpc_service",
    srcs = [
        "GreeterServiceImpl.java",
        "//examples/proto:greeter_java_proto",
        "//examples/proto:greeter_java_grpc",
    ],
    deps = [
        "@maven_error_prone_annotations//:jar",
        "@maven_failureaccess//:jar",
        "@maven_grpc_api//:jar",
        "@maven_grpc_context//:jar",
        "@maven_grpc_core//:jar",
        "@maven_grpc_protobuf//:jar",
        "@maven_grpc_protobuf_lite//:jar",
        "@maven_grpc_stub//:jar",
        "@maven_guava//:jar",
        "@maven_javax_annotation//:jar",
        "@maven_perfmark_api//:jar",
        "@maven_protobuf_java//:jar",
    ],
    visibility = ["//examples/java:__subpackages__"],
)

java_test(
    name = "service_test",
    srcs = ["GreeterServiceTest.java"],
    main_class = "com.example.greeter.GreeterServiceTest",
    use_testrunner = False,
    deps = [
        ":grpc_service",
        "@maven_grpc_api//:jar",
        "@maven_grpc_core//:jar",
        "@maven_grpc_netty_shaded//:jar",
        "@maven_grpc_stub//:jar",
    ],
)
