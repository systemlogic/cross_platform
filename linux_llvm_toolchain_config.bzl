load("@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl", "feature", "flag_group", "flag_set", "tool_path")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

def _impl(ctx):
    tool_paths = [
        tool_path(name = "gcc",     path = ctx.attr.clang_path),
        tool_path(name = "ld",      path = ctx.attr.ld_path),
        tool_path(name = "ar",      path = ctx.attr.ar_path),
        tool_path(name = "cpp",     path = ctx.attr.clang_path),
        tool_path(name = "gcov",    path = "/bin/false"),
        tool_path(name = "nm",      path = ctx.attr.nm_path),
        tool_path(name = "objdump", path = "/bin/false"),
        tool_path(name = "strip",   path = ctx.attr.strip_path),
    ]

    target_triple = ctx.attr.target_triple
    sysroot_path  = ctx.attr.sysroot_path

    compile_flags = ["-target", target_triple]
    link_flags    = ["-target", target_triple, "-fuse-ld=lld", "-lstdc++", "-lm"]
    if sysroot_path:
        compile_flags = compile_flags + ["--sysroot=" + sysroot_path]
        link_flags    = link_flags    + ["--sysroot=" + sysroot_path]
    if ctx.attr.gcc_toolchain:
        compile_flags = compile_flags + ["--gcc-toolchain=" + ctx.attr.gcc_toolchain]
        link_flags    = link_flags    + ["--gcc-toolchain=" + ctx.attr.gcc_toolchain]

    features = [
        feature(
            name = "default_compile_flags",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = [
                        ACTION_NAMES.c_compile,
                        ACTION_NAMES.cpp_compile,
                        ACTION_NAMES.cpp_header_parsing,
                        ACTION_NAMES.cpp_module_compile,
                        ACTION_NAMES.cpp_module_codegen,
                        ACTION_NAMES.preprocess_assemble,
                        ACTION_NAMES.linkstamp_compile,
                    ],
                    flag_groups = [flag_group(flags = compile_flags)],
                ),
            ],
        ),
        feature(
            name = "default_linker_flags",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = [
                        ACTION_NAMES.cpp_link_executable,
                        ACTION_NAMES.cpp_link_dynamic_library,
                    ],
                    flag_groups = [flag_group(flags = link_flags)],
                ),
            ],
        ),
    ]

    builtin_includes = ["/"]
    if sysroot_path:
        builtin_includes = builtin_includes + [
            sysroot_path + "/usr/include",
            sysroot_path + "/usr/local/include",
        ]
    if ctx.attr.clang_include_dir:
        builtin_includes = builtin_includes + [ctx.attr.clang_include_dir]

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = features,
        toolchain_identifier = ctx.label.name,
        host_system_name = "local",
        target_system_name = "local",
        target_cpu = ctx.attr.cpu,
        target_libc = "glibc",
        compiler = "clang",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        tool_paths = tool_paths,
        builtin_sysroot = sysroot_path if sysroot_path else "",
        cxx_builtin_include_directories = builtin_includes,
    )

cc_linux_llvm_toolchain_config = rule(
    implementation = _impl,
    attrs = {
        "cpu":               attr.string(),
        "clang_path":        attr.string(),
        "ar_path":           attr.string(),
        "ld_path":           attr.string(),
        "nm_path":           attr.string(),
        "strip_path":        attr.string(),
        "target_triple":     attr.string(),
        # Path to the target sysroot (e.g. the Bootlin GCC sysroot directory).
        # When set, --sysroot= is passed to both compile and link actions.
        "sysroot_path":      attr.string(default = ""),
        # Path to LLVM's own compiler headers (e.g. lib/clang/18/include).
        "clang_include_dir": attr.string(default = ""),
        # Path to the GCC installation root (e.g. the Bootlin toolchain directory).
        # When set, --gcc-toolchain= is passed so clang can locate crtbegin/crtend
        # and libgcc from the matching GCC installation.
        "gcc_toolchain":     attr.string(default = ""),
    },
)
