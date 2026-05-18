load("@rules_java//java:defs.bzl", "java_binary", "java_library", "java_test")

java_library(
    name = "server_lib",
    srcs = ["ServerLib.java"],
)

java_binary(
    name = "server",
    srcs = ["Server.java"],
    main_class = "Server",
    deps = [":server_lib"],
)

java_binary(
    name = "client",
    srcs = ["Client.java"],
    main_class = "Client",
)

java_test(
    name = "server_test",
    srcs = ["ServerTest.java"],
    main_class = "ServerTest",
    use_testrunner = False,
    deps = [":server_lib"],
)
