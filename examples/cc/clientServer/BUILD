load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library", "cc_test")

cc_library(
    name = "server_lib",
    srcs = ["server_lib.cc"],
    hdrs = ["server_lib.h"],
)

cc_binary(
    name = "client",
    srcs = ["client.cc"],
)

cc_binary(
    name = "server",
    srcs = ["server.cc"],
    deps = [":server_lib"],
)

cc_test(
    name = "server_test",
    srcs = ["server_test.cc"],
    deps = [":server_lib"],
)
