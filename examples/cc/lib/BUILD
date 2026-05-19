load("@rules_cc//cc:defs.bzl", "cc_library", "cc_test")

cc_library(
    name = "hello-time",
    srcs = ["hello-time.cc"],
    hdrs = ["hello-time.h"],
    visibility = ["//examples/cc/main:__pkg__"],
)

cc_test(
    name = "hello_time_test",
    srcs = ["hello_time_test.cc"],
    deps = [":hello-time"],
)
