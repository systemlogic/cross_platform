load("@rules_python//python:defs.bzl", "py_library")
load("@rules_go//go:def.bzl", "go_library")
load("//proto:defs.bzl", "cc_proto_library", "go_proto_library", "java_grpc_library", "java_proto_library", "proto_library", "py_grpc_library", "py_proto_library")

# ── Source definition ────────────────────────────────────────────────────────

proto_library(
    name = "greeter_proto",
    srcs = ["greeter.proto"],
    visibility = ["//visibility:public"],
)

# ── C++ message types ────────────────────────────────────────────────────────
# Outputs: greeter.pb.cc, greeter.pb.h
# Add protobuf C++ runtime to deps when building:
#   cc_library(srcs = [":greeter_cc_proto"], deps = ["@com_google_protobuf//:protobuf"])

cc_proto_library(
    name = "greeter_cc_proto",
    deps = [":greeter_proto"],
    visibility = ["//visibility:public"],
)

# ── Java message types ───────────────────────────────────────────────────────
# Output: directory containing HelloRequest.java, HelloReply.java, etc.
# Wire into java_library(srcs = [":greeter_java_proto"], deps = ["@maven//:com_google_protobuf_protobuf_java"])

java_proto_library(
    name = "greeter_java_proto",
    deps = [":greeter_proto"],
    visibility = ["//visibility:public"],
)

# ── Java gRPC service stubs ──────────────────────────────────────────────────
# Output: directory containing GreeterGrpc.java
# Needs grpc_java_plugin in the proto toolchain (protoc-gen-grpc-java).

java_grpc_library(
    name = "greeter_java_grpc",
    deps = [":greeter_proto"],
    visibility = ["//visibility:public"],
)

# ── Python message types ─────────────────────────────────────────────────────
# Output: greeter_pb2.py

py_proto_library(
    name = "greeter_py_proto",
    deps = [":greeter_proto"],
    visibility = ["//visibility:public"],
)

# ── Python gRPC service stubs ────────────────────────────────────────────────
# Output: greeter_pb2_grpc.py
# Needs grpc_python_plugin in the proto toolchain.

py_grpc_library(
    name = "greeter_py_grpc",
    deps = [":greeter_proto"],
    visibility = ["//visibility:public"],
)

# ── Python importable libraries ──────────────────────────────────────────────
# Wrap generated files so downstream py_binary targets can import them.

py_library(
    name = "greeter_py_proto_lib",
    srcs = [":greeter_py_proto"],
    imports = ["."],
    deps = ["@pip//protobuf"],
    visibility = ["//visibility:public"],
)

py_library(
    name = "greeter_py_grpc_lib",
    srcs = [":greeter_py_grpc"],
    imports = ["."],
    deps = [
        ":greeter_py_proto_lib",
        "@pip//grpcio",
    ],
    visibility = ["//visibility:public"],
)

# ── Go messages + gRPC stubs ─────────────────────────────────────────────────
# Outputs: greeter.pb.go, greeter_grpc.pb.go
# Needs grpc_go_plugin + grpc_go_grpc_plugin in the proto toolchain.
# Wire into go_library(srcs = [":greeter_go_proto"], importpath = "...", deps = [
#   "@org_golang_google_protobuf//proto",
#   "@org_golang_google_grpc//:grpc",
# ])

go_proto_library(
    name = "greeter_go_proto",
    deps = [":greeter_proto"],
    visibility = ["//visibility:public"],
)

# ── Go importable library ────────────────────────────────────────────────────
# Wraps generated greeter.pb.go + greeter_grpc.pb.go into a go_library so
# downstream go_binary / go_test targets can import it as a normal package.

go_library(
    name = "greeter_go_lib",
    srcs = [":greeter_go_proto"],
    importpath = "cross_platform/examples/proto/greeter",
    deps = [
        "@org_golang_google_grpc//:grpc",
        "@org_golang_google_grpc//codes",
        "@org_golang_google_grpc//status",
        "@org_golang_google_protobuf//reflect/protoreflect",
        "@org_golang_google_protobuf//runtime/protoimpl",
    ],
    visibility = ["//visibility:public"],
)
