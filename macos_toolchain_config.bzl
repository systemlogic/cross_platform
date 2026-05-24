load("@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl", "feature", "flag_group", "flag_set", "tool_path", "variable_with_value", "with_feature_set")
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

    sdk_path = ctx.attr.sdk_path
    target_triple = ctx.attr.target_triple

    # -isysroot is the canonical macOS flag; Clang passes it through to ld as -syslibroot.
    # -fuse-ld=lld makes Clang use ld64.lld from its own bin/ instead of the host ld.
    compile_flags = ["-target", target_triple]
    link_flags    = ["-target", target_triple, "-fuse-ld=lld", "-lc++"]
    if sdk_path:
        compile_flags = compile_flags + ["-isysroot", sdk_path]
        link_flags    = link_flags    + ["-isysroot", sdk_path]

    features = [
        feature(name = "supports_pic", enabled = True),
        feature(
            name = "pic",
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
                    flag_groups = [
                        flag_group(
                            flags = ["-fPIC"],
                            expand_if_available = "pic",
                        ),
                    ],
                ),
            ],
        ),
        # Override Bazel's built-in libraries_to_link legacy feature to replace
        # GNU ld -whole-archive/-no-whole-archive with macOS ld64 -force_load,
        # which is the equivalent flag understood by ld64.lld.
        feature(
            name = "libraries_to_link",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = [
                        ACTION_NAMES.cpp_link_executable,
                        ACTION_NAMES.cpp_link_dynamic_library,
                        ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                    ],
                    flag_groups = [
                        flag_group(
                            iterate_over = "libraries_to_link",
                            flag_groups = [
                                flag_group(
                                    flag_groups = [
                                        flag_group(
                                            flags = ["-Wl,-force_load,%{libraries_to_link.name}"],
                                            expand_if_true = "libraries_to_link.is_whole_archive",
                                        ),
                                        flag_group(
                                            flags = ["%{libraries_to_link.name}"],
                                            expand_if_false = "libraries_to_link.is_whole_archive",
                                        ),
                                    ],
                                    expand_if_equal = variable_with_value(
                                        name = "libraries_to_link.type",
                                        value = "static_library",
                                    ),
                                ),
                                flag_group(
                                    iterate_over = "libraries_to_link.object_files",
                                    flags = ["%{libraries_to_link.object_files}"],
                                    expand_if_equal = variable_with_value(
                                        name = "libraries_to_link.type",
                                        value = "object_file_group",
                                    ),
                                ),
                                flag_group(
                                    flags = ["%{libraries_to_link.name}"],
                                    expand_if_equal = variable_with_value(
                                        name = "libraries_to_link.type",
                                        value = "object_file",
                                    ),
                                ),
                                flag_group(
                                    flags = ["%{libraries_to_link.name}"],
                                    expand_if_equal = variable_with_value(
                                        name = "libraries_to_link.type",
                                        value = "interface_library",
                                    ),
                                ),
                                flag_group(
                                    flags = ["-l%{libraries_to_link.name}"],
                                    expand_if_equal = variable_with_value(
                                        name = "libraries_to_link.type",
                                        value = "dynamic_library",
                                    ),
                                ),
                                flag_group(
                                    flags = ["%{libraries_to_link.name}"],
                                    expand_if_equal = variable_with_value(
                                        name = "libraries_to_link.type",
                                        value = "versioned_dynamic_library",
                                    ),
                                ),
                            ],
                            expand_if_available = "libraries_to_link",
                        ),
                    ],
                ),
            ],
        ),
        feature(
            name = "runtime_library_search_directories",
            flag_sets = [
                flag_set(
                    actions = [
                        ACTION_NAMES.cpp_link_executable,
                        ACTION_NAMES.cpp_link_dynamic_library,
                        ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                    ],
                    flag_groups = [
                        flag_group(
                            iterate_over = "runtime_library_search_directories",
                            flag_groups = [
                                flag_group(
                                    flags = [
                                        "-Xlinker",
                                        "-rpath",
                                        "-Xlinker",
                                        "@loader_path/%{runtime_library_search_directories}",
                                    ],
                                ),
                            ],
                            expand_if_available = "runtime_library_search_directories",
                        ),
                    ],
                ),
            ],
        ),
        feature(
            name = "set_install_name",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = [
                        ACTION_NAMES.cpp_link_dynamic_library,
                        ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                    ],
                    flag_groups = [
                        flag_group(
                            flags = ["-Wl,-install_name,@rpath/%{runtime_solib_name}"],
                            expand_if_available = "runtime_solib_name",
                        ),
                    ],
                ),
            ],
        ),
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
        feature(
            name = "strip_flags",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = [
                        ACTION_NAMES.cpp_link_executable,
                        ACTION_NAMES.cpp_link_dynamic_library,
                    ],
                    flag_groups = [flag_group(flags = ["-Wl,-S"])],
                    with_features = [with_feature_set(features = ["opt"])],
                ),
            ],
        ),
    ]

    builtin_includes = ["/"]
    if sdk_path:
        builtin_includes = builtin_includes + [sdk_path + "/usr/include"]
    if ctx.attr.clang_include_dir:
        builtin_includes = builtin_includes + [ctx.attr.clang_include_dir]

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = features,
        toolchain_identifier = ctx.label.name,
        host_system_name = "local",
        target_system_name = "local",
        target_cpu = ctx.attr.cpu,
        target_libc = "macos",
        compiler = "clang",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        tool_paths = tool_paths,
        builtin_sysroot = sdk_path,
        cxx_builtin_include_directories = builtin_includes,
    )

cc_macos_toolchain_config = rule(
    implementation = _impl,
    attrs = {
        "cpu":              attr.string(),
        "clang_path":       attr.string(),
        "ar_path":          attr.string(),
        "ld_path":          attr.string(),
        "nm_path":          attr.string(),
        "strip_path":       attr.string(),
        "sdk_path":         attr.string(),
        "target_triple":    attr.string(),
        # Path to LLVM's own compiler headers (e.g. lib/clang/18/include).
        # Required on Linux where the downloaded LLVM binary's intrinsic headers
        # are not on the system search path.
        "clang_include_dir": attr.string(default = ""),
    },
)
