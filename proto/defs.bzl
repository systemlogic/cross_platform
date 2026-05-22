"""User-facing proto code-generation rules.

Rules:
  proto_library       — collect .proto sources into a provider
  cc_proto_library    — generate C++ message types  (protoc --cpp_out)
  java_proto_library  — generate Java message types (protoc --java_out)
  py_proto_library    — generate Python message types (protoc --python_out)
  py_grpc_library     — generate Python gRPC stubs   (protoc --grpc_python_out, needs grpc_python_plugin)
  go_proto_library    — generate Go messages + gRPC stubs (needs plugins in toolchain)
  java_grpc_library   — generate Java gRPC service stubs (needs grpc_java_plugin)

All code-generation rules return the generated source files via DefaultInfo.
Wire them into cc_library / java_library / py_library / go_library as srcs.

Output naming convention (proto file "foo.proto"):
  C++:    foo.pb.cc  foo.pb.h
  Python: foo_pb2.py
  Go:     foo.pb.go  [foo_grpc.pb.go when grpc_go_grpc_plugin present]
  Java:   declared directory (package layout from java_package option)
"""

load("//proto:proto_toolchain.bzl", "ProtoToolchainInfo")

# ---------------------------------------------------------------------------
# ProtoInfo provider
# ---------------------------------------------------------------------------

ProtoInfo = provider(
    doc = "Carries .proto source files for downstream code-generation rules.",
    fields = {
        "direct_sources": "depset of direct .proto File objects",
        "transitive_sources": "depset of all transitive .proto Files (including deps)",
    },
)

# ---------------------------------------------------------------------------
# proto_library
# ---------------------------------------------------------------------------

def _proto_library_impl(ctx):
    direct = depset(direct = ctx.files.srcs)
    transitive_deps = [dep[ProtoInfo].transitive_sources for dep in ctx.attr.deps]
    transitive = depset(direct = ctx.files.srcs, transitive = transitive_deps)
    return [
        ProtoInfo(direct_sources = direct, transitive_sources = transitive),
        DefaultInfo(files = direct),
    ]

proto_library = rule(
    implementation = _proto_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".proto"],
            doc = "The .proto source files owned by this target.",
        ),
        "deps": attr.label_list(
            providers = [ProtoInfo],
            doc = "Other proto_library targets whose types are imported.",
        ),
    },
)

# ---------------------------------------------------------------------------
# Internal helper: build the common protoc action
# ---------------------------------------------------------------------------

def _run_protoc(ctx, toolchain, direct_sources, all_sources, lang_flag, outputs, extra_args = [], plugins = []):
    """Run protoc once, producing `outputs`.

    Args:
      toolchain:      ProtoToolchainInfo
      direct_sources: list of direct .proto Files to compile
      all_sources:    depset of all transitive .proto Files (for inputs)
      lang_flag:      string like "--cpp_out=<path>" or "--go_out=paths=source_relative:<path>"
      outputs:        list of declared output Files (or one declare_directory)
      extra_args:     additional string args appended after lang_flag
      plugins:        list of plugin File objects (added as inputs + --plugin= flags)
    """
    args = ctx.actions.args()
    args.add("--proto_path", ".")
    args.add("--proto_path", toolchain.protoc_include_path)
    args.add(lang_flag)
    for a in extra_args:
        args.add(a)
    for src in direct_sources:
        args.add(src.path)

    plugin_args = []
    for plugin in plugins:
        # Derive the protoc plugin key from the binary name.
        # Binary: "protoc-gen-go"  →  key: "go"  →  flag: --plugin=protoc-gen-go=<path>
        bin_name = plugin.basename
        if bin_name.endswith(".exe"):
            bin_name = bin_name[:-4]
        if bin_name.startswith("protoc-gen-"):
            plugin_key = bin_name[len("protoc-gen-"):]
        else:
            plugin_key = bin_name
        args.add("--plugin=protoc-gen-%s=%s" % (plugin_key, plugin.path))

    inputs = depset(
        direct = toolchain.protoc_includes + plugins,
        transitive = [all_sources],
    )

    ctx.actions.run(
        executable = toolchain.protoc,
        arguments = [args],
        inputs = inputs,
        outputs = outputs,
        mnemonic = "ProtoCompile",
        progress_message = "Compiling proto sources for %s" % ctx.label,
    )

# ---------------------------------------------------------------------------
# cc_proto_library  →  foo.pb.cc + foo.pb.h
# ---------------------------------------------------------------------------

def _cc_proto_library_impl(ctx):
    toolchain = ctx.toolchains["//proto:toolchain_type"].proto

    direct_sources = []
    for dep in ctx.attr.deps:
        direct_sources.extend(dep[ProtoInfo].direct_sources.to_list())

    all_sources = depset(transitive = [dep[ProtoInfo].transitive_sources for dep in ctx.attr.deps])

    cc_outs = []
    hdr_outs = []
    for src in direct_sources:
        stem = src.basename[:-len(".proto")]
        cc_outs.append(ctx.actions.declare_file(stem + ".pb.cc"))
        hdr_outs.append(ctx.actions.declare_file(stem + ".pb.h"))

    _run_protoc(
        ctx = ctx,
        toolchain = toolchain,
        direct_sources = direct_sources,
        all_sources = all_sources,
        lang_flag = "--cpp_out=" + ctx.bin_dir.path,
        outputs = cc_outs + hdr_outs,
    )

    return [DefaultInfo(files = depset(cc_outs + hdr_outs))]

cc_proto_library = rule(
    implementation = _cc_proto_library_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            providers = [ProtoInfo],
        ),
    },
    toolchains = ["//proto:toolchain_type"],
)

# ---------------------------------------------------------------------------
# java_proto_library  →  declared directory (package-based layout)
# ---------------------------------------------------------------------------

def _java_proto_library_impl(ctx):
    toolchain = ctx.toolchains["//proto:toolchain_type"].proto

    direct_sources = []
    for dep in ctx.attr.deps:
        direct_sources.extend(dep[ProtoInfo].direct_sources.to_list())

    all_sources = depset(transitive = [dep[ProtoInfo].transitive_sources for dep in ctx.attr.deps])

    # protoc writes a srcjar when the output path ends in .srcjar (supported since protobuf 3.x).
    # java_library.srcs handles .srcjar natively; declare_directory does not expand in srcs.
    out_srcjar = ctx.actions.declare_file(ctx.label.name + "_java_srcs.srcjar")

    _run_protoc(
        ctx = ctx,
        toolchain = toolchain,
        direct_sources = direct_sources,
        all_sources = all_sources,
        lang_flag = "--java_out=" + out_srcjar.path,
        outputs = [out_srcjar],
    )

    return [DefaultInfo(files = depset([out_srcjar]))]

java_proto_library = rule(
    implementation = _java_proto_library_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            providers = [ProtoInfo],
        ),
    },
    toolchains = ["//proto:toolchain_type"],
)

# ---------------------------------------------------------------------------
# java_grpc_library  →  declared directory (needs grpc_java_plugin in toolchain)
# ---------------------------------------------------------------------------

def _java_grpc_library_impl(ctx):
    toolchain = ctx.toolchains["//proto:toolchain_type"].proto
    if not toolchain.grpc_java_plugin:
        fail("java_grpc_library requires grpc_java_plugin in the proto toolchain.")

    direct_sources = []
    for dep in ctx.attr.deps:
        direct_sources.extend(dep[ProtoInfo].direct_sources.to_list())

    all_sources = depset(transitive = [dep[ProtoInfo].transitive_sources for dep in ctx.attr.deps])

    # Use .srcjar output so java_library.srcs handles it natively.
    out_srcjar = ctx.actions.declare_file(ctx.label.name + "_java_grpc_srcs.srcjar")

    _run_protoc(
        ctx = ctx,
        toolchain = toolchain,
        direct_sources = direct_sources,
        all_sources = all_sources,
        lang_flag = "--grpc-java_out=" + out_srcjar.path,
        outputs = [out_srcjar],
        plugins = [toolchain.grpc_java_plugin],
    )

    return [DefaultInfo(files = depset([out_srcjar]))]

java_grpc_library = rule(
    implementation = _java_grpc_library_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            providers = [ProtoInfo],
        ),
    },
    toolchains = ["//proto:toolchain_type"],
)

# ---------------------------------------------------------------------------
# py_proto_library  →  foo_pb2.py
# ---------------------------------------------------------------------------

def _py_proto_library_impl(ctx):
    toolchain = ctx.toolchains["//proto:toolchain_type"].proto

    direct_sources = []
    for dep in ctx.attr.deps:
        direct_sources.extend(dep[ProtoInfo].direct_sources.to_list())

    all_sources = depset(transitive = [dep[ProtoInfo].transitive_sources for dep in ctx.attr.deps])

    py_outs = []
    for src in direct_sources:
        stem = src.basename[:-len(".proto")]
        py_outs.append(ctx.actions.declare_file(stem + "_pb2.py"))

    _run_protoc(
        ctx = ctx,
        toolchain = toolchain,
        direct_sources = direct_sources,
        all_sources = all_sources,
        lang_flag = "--python_out=" + ctx.bin_dir.path,
        outputs = py_outs,
    )

    return [DefaultInfo(files = depset(py_outs))]

py_proto_library = rule(
    implementation = _py_proto_library_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            providers = [ProtoInfo],
        ),
    },
    toolchains = ["//proto:toolchain_type"],
)

# ---------------------------------------------------------------------------
# py_grpc_library  →  foo_pb2_grpc.py  (needs grpc_python_plugin in toolchain)
# ---------------------------------------------------------------------------

def _py_grpc_library_impl(ctx):
    direct_sources = []
    for dep in ctx.attr.deps:
        direct_sources.extend(dep[ProtoInfo].direct_sources.to_list())

    all_sources = depset(transitive = [dep[ProtoInfo].transitive_sources for dep in ctx.attr.deps])

    grpc_py_outs = []
    for src in direct_sources:
        stem = src.basename[:-len(".proto")]
        grpc_py_outs.append(ctx.actions.declare_file(stem + "_pb2_grpc.py"))

    # grpc_tools.protoc cannot handle "--proto_path ." in its virtual file system.
    # Use each proto file's own directory as the proto_path and pass the full path
    # as input. grpc_tools preserves the full path structure relative to the out
    # dir, so with --grpc_python_out=ctx.bin_dir.path the output lands at
    # bin/<package>/greeter_pb2_grpc.py, which matches declare_file().
    args = ctx.actions.args()
    for src in direct_sources:
        args.add("--proto_path=" + src.dirname)
    args.add("--grpc_python_out=" + ctx.bin_dir.path)
    for src in direct_sources:
        args.add(src.path)

    ctx.actions.run(
        executable = ctx.executable._grpcio_tools_protoc,
        arguments = [args],
        inputs = all_sources,
        outputs = grpc_py_outs,
        mnemonic = "GrpcPyCompile",
        progress_message = "Generating Python gRPC stubs for %s" % ctx.label,
    )

    return [DefaultInfo(files = depset(grpc_py_outs))]

py_grpc_library = rule(
    implementation = _py_grpc_library_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            providers = [ProtoInfo],
        ),
        "_grpcio_tools_protoc": attr.label(
            default = "//tools:grpcio_tools_protoc",
            executable = True,
            cfg = "exec",
        ),
    },
)

# ---------------------------------------------------------------------------
# go_proto_library  →  foo.pb.go  [+ foo_grpc.pb.go if plugin present]
# ---------------------------------------------------------------------------

def _go_proto_library_impl(ctx):
    toolchain = ctx.toolchains["//proto:toolchain_type"].proto
    if not toolchain.grpc_go_plugin:
        fail("go_proto_library requires grpc_go_plugin (protoc-gen-go) in the proto toolchain.")

    direct_sources = []
    for dep in ctx.attr.deps:
        direct_sources.extend(dep[ProtoInfo].direct_sources.to_list())

    all_sources = depset(transitive = [dep[ProtoInfo].transitive_sources for dep in ctx.attr.deps])

    go_outs = []
    grpc_go_outs = []
    for src in direct_sources:
        stem = src.basename[:-len(".proto")]
        go_outs.append(ctx.actions.declare_file(stem + ".pb.go"))
        if toolchain.grpc_go_grpc_plugin:
            grpc_go_outs.append(ctx.actions.declare_file(stem + "_grpc.pb.go"))

    all_outs = go_outs + grpc_go_outs

    # Message types
    _run_protoc(
        ctx = ctx,
        toolchain = toolchain,
        direct_sources = direct_sources,
        all_sources = all_sources,
        lang_flag = "--go_out=paths=source_relative:" + ctx.bin_dir.path,
        outputs = go_outs,
        plugins = [toolchain.grpc_go_plugin],
    )

    # gRPC service stubs (separate protoc invocation)
    if grpc_go_outs:
        _run_protoc(
            ctx = ctx,
            toolchain = toolchain,
            direct_sources = direct_sources,
            all_sources = all_sources,
            lang_flag = "--go-grpc_out=paths=source_relative:" + ctx.bin_dir.path,
            outputs = grpc_go_outs,
            plugins = [toolchain.grpc_go_grpc_plugin],
        )

    return [DefaultInfo(files = depset(all_outs))]

go_proto_library = rule(
    implementation = _go_proto_library_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            providers = [ProtoInfo],
        ),
    },
    toolchains = ["//proto:toolchain_type"],
)
