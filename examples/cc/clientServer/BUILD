load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library", "cc_shared_library", "cc_test")

cc_library(
    name = "server_lib_impl",
    srcs = ["server_lib.cc"],
    hdrs = ["server_lib.h"],
)

# Creating a shared library
cc_shared_library(
    name = "server_lib",
    deps = [":server_lib_impl"],
)

cc_binary(
    name = "client",
    srcs = ["client.cc"],
)

# Avoid linking library from random path.
# or otherwise copy it to required locatiion
# when binary is being exported to production
# system. Check the shared library path.
"""
ldd  bazel-bin/examples/cc/clientServer/server
	libserver_lib.so => /root/.cache/bazel/_bazel_root/6644f93ebb27d3f116a07816edfb09d7/execroot/_main/bazel-out/k8-opt/bin/examples/cc/clientServer/../../../_solib_x86_64/_Uexamples_Scc_SclientServer/libserver_lib.so (0x00007fffff7b3000)
	libstdc++.so.6 => /usr/lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007fffff511000)
	libm.so.6 => /usr/lib/x86_64-linux-gnu/libm.so.6 (0x00007fffff3eb000)
	libc.so.6 => /usr/lib/x86_64-linux-gnu/libc.so.6 (0x00007fffff1ca000)
	libgcc_s.so.1 => /usr/lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007fffff19c000)
	/lib64/ld-linux-x86-64.so.2 (0x00007ffffffc1000)
"""
cc_binary(
    name = "server",
    srcs = ["server.cc"],
    deps = [":server_lib_impl"],
    # dynamic_deps = [":server_lib"],
)

cc_test(
    name = "server_test",
    srcs = ["server_test.cc"],
    deps = [":server_lib_impl"],
    dynamic_deps = [":server_lib"],
)
