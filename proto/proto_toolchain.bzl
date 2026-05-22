"""Proto toolchain — provides protoc binary and optional gRPC code-gen plugins."""

ProtoToolchainInfo = provider(
    doc = "Details about a proto compilation toolchain.",
    fields = {
        "protoc": "protoc executable File",
        "protoc_include_path": "execroot-relative path to the well-known proto includes dir",
        "protoc_includes": "list of well-known .proto Files (for Bazel input tracking)",
        "grpc_java_plugin": "protoc-gen-grpc-java executable File, or None",
        "grpc_go_plugin": "protoc-gen-go executable File, or None",
        "grpc_go_grpc_plugin": "protoc-gen-go-grpc executable File, or None",
    },
)

def _proto_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        proto = ProtoToolchainInfo(
            protoc = ctx.executable.protoc,
            protoc_include_path = ctx.attr.protoc_include_path,
            protoc_includes = ctx.files.protoc_includes,
            grpc_java_plugin = ctx.executable.grpc_java_plugin if ctx.attr.grpc_java_plugin else None,
            grpc_go_plugin = ctx.executable.grpc_go_plugin if ctx.attr.grpc_go_plugin else None,
            grpc_go_grpc_plugin = ctx.executable.grpc_go_grpc_plugin if ctx.attr.grpc_go_grpc_plugin else None,
        ),
    )]

proto_toolchain = rule(
    implementation = _proto_toolchain_impl,
    attrs = {
        "protoc": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            doc = "The protoc compiler binary.",
        ),
        "protoc_include_path": attr.string(
            mandatory = True,
            doc = "Execroot-relative path to well-known protos include dir (e.g. external/.../include).",
        ),
        "protoc_includes": attr.label_list(
            allow_files = True,
            cfg = "exec",
            doc = "Well-known .proto files — tracked so protoc reruns when they change.",
        ),
        "grpc_java_plugin": attr.label(
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            doc = "protoc-gen-grpc-java plugin binary (optional).",
        ),
        "grpc_go_plugin": attr.label(
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            doc = "protoc-gen-go plugin binary (optional).",
        ),
        "grpc_go_grpc_plugin": attr.label(
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            doc = "protoc-gen-go-grpc plugin binary (optional).",
        ),
    },
)
