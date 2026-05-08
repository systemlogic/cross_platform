# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Bazel Version Management

The required Bazel version is pinned in **`.bazelversion`** (currently `9.0.1`).

The project ships a `./bazel` wrapper script — use it instead of a system `bazel`:

```bash
./bazel build --config=macos_arm64 //examples/cc:hello
./bazel version
```

On first use the script downloads the exact Bazel binary declared in `.bazelversion`, caches it in `~/.cache/bazel-versions/`, and execs it. Subsequent invocations use the cache directly (no network). The script auto-detects OS and CPU (`darwin/linux`, `arm64/x86_64`).

To upgrade the project's Bazel version: edit `.bazelversion`, then run `./bazel` — the new version is downloaded automatically.

## Overview

This is a Bazel cross-compilation toolchain setup supporting four target configurations:

All toolchains are downloaded — no host compiler is used.

| Target | Toolchain | Downloaded from |
|--------|-----------|-----------------|
| Linux x86_64 | GCC 9 Bootlin `x86-64--glibc--stable-2024.02-1` | toolchains.bootlin.com |
| Linux ARM64 | GCC 9.2 `gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu` | developer.arm.com |
| macOS ARM64 | LLVM 18.1.8 `clang+llvm-18.1.8-arm64-apple-macos11` (exec: arm64) | github.com/llvm/llvm-project |
| macOS x86_64 | LLVM 18.1.8 same binary, `-target x86_64-apple-macos10.15` (cross) | github.com/llvm/llvm-project |

Linux GCC toolchains are patched after download (sysroot `libc.so` linker scripts rewritten to use `=`-relative paths). macOS LLVM toolchains use `-fuse-ld=lld` so `ld64.lld` from the downloaded package is used instead of the host linker. The macOS SDK (headers/libs) is still detected from the host via `xcrun --show-sdk-path` since Apple does not redistribute it separately.

## Build Commands

Platform and build-mode configs are independent and composable.

```bash
# Linux targets (downloads GCC 9 cross-compiler ~first run)
bazel build --config=x86_64     //examples/cc:hello
bazel build --config=arm64      //examples/cc:hello

# macOS targets (uses system Clang; exec host must be macOS)
bazel build --config=macos_arm64  //examples/cc:hello   # native or cross from x86_64
bazel build --config=macos_x86_64 //examples/cc:hello   # native or cross from arm64

# Combine platform + build mode
bazel build --config=macos_arm64  --config=release //examples/cc:hello
bazel build --config=x86_64       --config=debug   //examples/cc:hello
bazel build --config=macos_x86_64 --config=stats   //examples/cc:hello

# Build all targets for a platform
bazel build --config=macos_arm64 //...
```

### Build modes

| Config | `compilation_mode` | Extra flags | Use for |
|--------|--------------------|-------------|---------|
| *(none)* | `fastbuild` | — | Fast iteration |
| `debug` | `dbg` | `-DDEBUG_BUILD` | Debugging with full symbols |
| `release` | `opt` (`-O2 -DNDEBUG`) | `--strip-all` | Production binaries |
| `stats` | `dbg` | `-pg -DSTATS_ENABLED` | gprof profiling |

The first build downloads and extracts the toolchain archives (~hundreds of MB each). Subsequent builds use the Bazel cache.

## Architecture

### Toolchain Registration Flow

```
WORKSPACE
  └── external_tool/external_tool_repositories.bzl  (external_tool_workspace())
        └── toolchain_repositories.bzl               (gcc_9_x86_64_repository, gcc_9_arm64_repository)
              └── toolchain_archive_repository        (downloads + patches + symlinks BUILD file)

BUILD.bazel (root)
  ├── cc_toolchain_config (cc_toolchain_config.bzl)  — compiler flags, sysroot, tool paths
  ├── cc_toolchain         — wires config to file groups
  ├── toolchain            — declares exec/target constraints for Bazel toolchain resolution
  └── platform             — constraint_values for x86_64 and arm64
```

### Key Files

| File | Purpose |
|------|---------|
| `toolchain_repositories.bzl` | All repository rules: `toolchain_archive_repository` (generic download+patch+symlink), `macos_sdk_repository` (xcrun), and the four convenience wrappers (`gcc_9_x86_64_repository`, `gcc_9_arm64_repository`, `llvm_macos_arm64_repository`, `llvm_macos_x86_64_repository`) |
| `external_tool/external_tool_repositories.bzl` | Aggregates all repo instantiations; loaded by WORKSPACE |
| `external_tool/BUILD.gcc_9_*.bazel` | BUILD files injected into downloaded GCC repos; expose `all_files` filegroup |
| `external_tool/BUILD.llvm_macos.bazel` | BUILD file injected into downloaded LLVM repos; expose `all_files` filegroup |
| `cc_toolchain_config.bzl` | Starlark rule for Linux GCC toolchains; derives sysroot from `cpu` attr |
| `macos_toolchain_config.bzl` | Starlark rule for macOS LLVM toolchains; all tool paths are attributes; adds `-fuse-ld=lld` and `-isysroot` |
| `BUILD.bazel` (root) | Instantiates 4 macOS toolchain configs (exec-cpu × target-cpu) + 2 Linux configs, all `cc_toolchain`, `toolchain`, and `platform` targets |
| `WORKSPACE` | Calls `external_tool_workspace()` and `register_toolchains()` for the 4 macOS toolchains |
| `.bazelrc` | Platform and build-mode config shortcuts |

### Sysroot Convention

`cc_toolchain_config.bzl` derives the sysroot automatically from `cpu`:

- `arm64` / `aarch64` → `<sysroot_path>/aarch64-none-linux-gnu/libc`
- anything else → `<sysroot_path>/x86_64-buildroot-linux-gnu/sysroot`

The same sysroot is passed as `--sysroot=` to both compile and link actions, and also set as `builtin_sysroot`.

### Toolchain Constraints

Both toolchains have `exec_compatible_with` set to `linux/x86_64` (the build machine must be x86_64 Linux). The ARM64 toolchain has `target_compatible_with = arm64` — it is a cross-compiler only, not native.

## Adding a New Target Architecture

1. Add a `gcc_<arch>_repository()` function in `toolchain_repositories.bzl` pointing to the archive URL and its BUILD file.
2. Create `external_tool/BUILD.gcc_<arch>.bazel` (copy the existing pattern — expose `all_files`).
3. Call the new function from `external_tool/external_tool_repositories.bzl`.
4. Add a `cc_toolchain_config`, `cc_toolchain`, `toolchain`, and `platform` block in `BUILD.bazel`.
5. Extend `cc_toolchain_config.bzl`'s sysroot logic if the new arch needs a different subdirectory layout.
6. Add a `--config=<arch>` shortcut in `.bazelrc`.
