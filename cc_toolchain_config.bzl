load("@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl", "feature", "flag_group", "flag_set", "tool_path")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")


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


    arm = ctx.attr.cpu in ["aarch64", "arm64"]
    base_path = ctx.attr.sysroot_path
    sysroot_path = base_path + ("/aarch64-none-linux-gnu/libc"  if arm else "/x86_64-buildroot-linux-gnu/sysroot") 
    print(sysroot_path)
    sysroot_flags = ["--sysroot=" + sysroot_path]
    print(sysroot_flags)

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
                    flag_groups = [flag_group(flags = sysroot_flags)],
                ),
            ],
        ),
    ] 


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
	cxx_builtin_include_directories = [
		"/",
            	base_path + "/lib/gcc",
    	],
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
    },
    provides = [CcToolchainConfigInfo],
)
