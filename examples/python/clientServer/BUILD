load("@rules_python//python:defs.bzl", "py_binary", "py_library", "py_test")

py_library(
    name = "server_lib",
    srcs = ["server_lib.py"],
    imports = ["."],
)

py_binary(
    name = "server",
    srcs = ["server.py"],
    main = "server.py",
    deps = [":server_lib"],
)

py_binary(
    name = "client",
    srcs = ["client.py"],
    main = "client.py",
    deps = ["@pip//requests"],
)

py_test(
    name = "server_test",
    srcs = ["server_test.py"],
    main = "server_test.py",
    deps = [
        ":server_lib",
        "@pip//requests",
    ],
)
