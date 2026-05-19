load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library", "cc_test")

cc_library(
    name = "hello-greet",
    srcs = ["hello-greet.cc"],
    hdrs = ["hello-greet.h"],
)

cc_binary(
    name = "hello-world",
    srcs = ["hello-world.cc"],
    deps = [
        ":hello-greet",
        "//examples/cc/lib:hello-time",
    ],
)

cc_test(
    name = "hello_greet_test",
    srcs = ["hello_greet_test.cc"],
    deps = [":hello-greet"],
)
