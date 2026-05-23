load("@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl", "feature", "flag_group", "flag_set", "tool_path", "with_feature_set")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")


def _impl(ctx):
    tool_paths = [
        tool_path(name = "gcc", path = ctx.attr.gcc_path),
        tool_path(name = "ld", path = ctx.attr.ld_path),
        tool_path(name = "ar", path = ctx.attr.ar_path),
        tool_path(name = "cpp", path = ctx.attr.cpp_path),
        tool_path(name = "gcov", path = "/bin/false"),
        tool_path(name = "nm", path = "/bin/false"),
        tool_path(name = "objdump", path = "/bin/false"),
        tool_path(name = "strip", path = "/bin/false"),
    ]

    base_path = ctx.attr.sysroot_path
    sysroot_subdir = ctx.attr.sysroot_subdir
    if not sysroot_subdir:
        arm = ctx.attr.cpu in ["aarch64", "arm64"]
        sysroot_subdir = "aarch64-none-linux-gnu/libc" if arm else "x86_64-buildroot-linux-gnu/sysroot"
    sysroot_path = base_path + "/" + sysroot_subdir
    sysroot_flags = ["--sysroot=" + sysroot_path]

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
                        ACTION_NAMES.clif_match,
                        ACTION_NAMES.lto_backend,
                        ACTION_NAMES.preprocess_assemble,
                        ACTION_NAMES.linkstamp_compile,
                    ],
                    flag_groups = [flag_group(flags = sysroot_flags)],
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
                    flag_groups = [flag_group(flags = sysroot_flags + ["-lstdc++", "-lm"])],
                ),
            ],
        ),
        feature(
            name = "strip_flags",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = [
                        ACTION_NAMES.cpp_link_executable,
                        ACTION_NAMES.cpp_link_dynamic_library,
                    ],
                    flag_groups = [flag_group(flags = ["-Wl,--strip-all"])],
                    with_features = [with_feature_set(features = ["opt"])],
                ),
            ],
        ),
    ]

    builtin_includes = ["/", base_path + "/lib/gcc"]
    if ctx.attr.gcc_builtin_include_dir:
        builtin_includes = builtin_includes + [ctx.attr.gcc_builtin_include_dir]

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = features,
        toolchain_identifier = ctx.attr.cpu,
        host_system_name = "local",
        target_system_name = "local",
        target_cpu = ctx.attr.cpu,
        target_libc = "unknown",
        compiler = "gcc",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        tool_paths = tool_paths,
        builtin_sysroot = sysroot_path,
        cxx_builtin_include_directories = builtin_includes,
    )

cc_toolchain_config = rule(
    implementation = _impl,
    attrs = {
        "cpu": attr.string(),
        "gcc_path": attr.string(),
        "ld_path": attr.string(),
        "ar_path": attr.string(),
        "cpp_path": attr.string(),
        "sysroot_path": attr.string(),
        # Optional override for the sysroot subdirectory under sysroot_path.
        # Defaults to arch-derived path when empty.
        "sysroot_subdir": attr.string(default = ""),
        # Extra GCC internal include directory for toolchains whose compiler is
        # relocated from its original installation prefix (e.g. Ubuntu cross-compiler
        # packages extracted to a Bazel repository). Added to cxx_builtin_include_dirs
        # so Bazel tracks headers from the versioned GCC include path correctly.
        "gcc_builtin_include_dir": attr.string(default = ""),
    },
)
