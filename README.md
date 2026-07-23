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

This is a Bazel cross-compilation toolchain setup. All toolchains are downloaded — no host compiler is used. The project uses **Bzlmod** (`MODULE.bazel`) for dependency and toolchain management.

Supported exec × target combinations:

| Exec platform | Target platform | Compiler | Source |
|---------------|-----------------|----------|--------|
| Linux x86_64 | Linux x86_64 | GCC 9 Bootlin `x86-64--glibc--stable-2024.02-1` | toolchains.bootlin.com |
| Linux x86_64 | Linux ARM64 | GCC 9.2 ARM cross-compiler `gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu` | developer.arm.com |
| Linux aarch64 | Linux ARM64 | ARM GNU GCC 14.2.rel1 `aarch64-aarch64-none-linux-gnu` | developer.arm.com |
| Linux aarch64 | Linux x86_64 | GCC 12 (Ubuntu 22.04 arm64 packages) + Bootlin x86_64 sysroot | ports.ubuntu.com + toolchains.bootlin.com |
| Linux x86_64 | macOS ARM64 | LLVM 18.1.8 `clang+llvm-18.1.8-x86_64-linux-gnu` | github.com/llvm/llvm-project |
| Linux x86_64 | macOS x86_64 | LLVM 18.1.8 `clang+llvm-18.1.8-x86_64-linux-gnu` | github.com/llvm/llvm-project |
| Linux aarch64 | macOS ARM64 | LLVM 18.1.8 `clang+llvm-18.1.8-aarch64-linux-gnu` | github.com/llvm/llvm-project |
| Linux aarch64 | macOS x86_64 | LLVM 18.1.8 `clang+llvm-18.1.8-aarch64-linux-gnu` | github.com/llvm/llvm-project |
| macOS ARM64 | macOS ARM64 | LLVM 18.1.8 `clang+llvm-18.1.8-arm64-apple-macos11` | github.com/llvm/llvm-project |
| macOS ARM64 | macOS x86_64 | LLVM 18.1.8 same binary, `-target x86_64-apple-macos10.15` | github.com/llvm/llvm-project |
| macOS x86_64 | macOS x86_64 | LLVM 17.0.6 `clang+llvm-17.0.6-x86_64-apple-darwin22.0` | github.com/llvm/llvm-project |
| macOS x86_64 | macOS ARM64 | LLVM 17.0.6 same binary, `-target arm64-apple-macos12` | github.com/llvm/llvm-project |

**Notes:**
- Linux GCC toolchains are patched after download (sysroot `libc.so` linker scripts rewritten to use `=`-relative paths).
- macOS LLVM toolchains use `-fuse-ld=lld` so `ld64.lld` from the downloaded package is used instead of the host linker.
- The macOS SDK (headers/libs) is detected from the host via `xcrun --show-sdk-path`, or supplied via the `MACOS_SDK_PATH` env var on non-macOS hosts. Apple does not redistribute the SDK separately.
- LLVM 18+ no longer ships macOS x86_64 pre-built binaries; 17.0.6 is the last release that does.
- The Linux aarch64 LLVM (`llvm_linux_aarch64`) bundles `libxml2.so.2` needed by `ld.lld`, either copying it from the host or downloading it from an Ubuntu 22.04 arm64 `.deb` as a hermetic fallback. It is still used for macOS cross-compilation from aarch64 exec machines.
- The aarch64 exec → Linux x86_64 toolchain (`gcc_x86_64_on_aarch64`) assembles GCC 12 from Ubuntu 22.04 arm64 `.deb` packages at repository-fetch time (hermetic, no apt-get). A wrapper script passes `-B` to redirect GCC's internal file search to the extracted repo path.

## Build Commands

Platform and build-mode configs are independent and composable.

```bash
# Linux targets
./bazel build --config=x86_64  //examples/cc:hello   # Linux x86_64
./bazel build --config=arm64   //examples/cc:hello   # Linux ARM64

# macOS targets
./bazel build --config=macos_arm64  //examples/cc:hello   # macOS ARM64
./bazel build --config=macos_x86_64 //examples/cc:hello   # macOS x86_64

# Combine platform + build mode
./bazel build --config=macos_arm64  --config=release //examples/cc:hello
./bazel build --config=x86_64       --config=debug   //examples/cc:hello
./bazel build --config=macos_x86_64 --config=stats   //examples/cc:hello

# Build all targets for a platform
./bazel build --config=macos_arm64 //...

# Run tests
./bazel test --config=macos_arm64 //examples/...
```

### Build modes

| Config | `compilation_mode` | Extra flags | Use for |
|--------|--------------------|-------------|---------|
| *(none)* | `fastbuild` | — | Fast iteration |
| `debug` | `dbg` | `-DDEBUG_BUILD` | Debugging with full symbols |
| `release` | `opt` (`-O2 -DNDEBUG`) | `--strip-all` | Production binaries |
| `stats` | `dbg` | `-pg -DSTATS_ENABLED` | gprof profiling |

The first build downloads and extracts the toolchain archives (~hundreds of MB each). Subsequent builds use the Bazel cache.

### Toolchain selection on Linux (`--extra_toolchains`)

Linux toolchains are pinned per-build via `--extra_toolchains` in `.bazelrc` (not registered globally) so they don't interfere with exec-platform resolution on non-Linux hosts:

- `--config=arm64` adds `gcc_arm64_toolchain` (x86_64 exec) and `gcc_arm64_native_toolchain` (aarch64 exec).
- `--config=x86_64` adds `gcc_x86_64_toolchain` (x86_64 exec) and `gcc_x86_64_on_linux_aarch64_toolchain` (aarch64 exec).

macOS toolchains are registered globally in `MODULE.bazel` and auto-selected by Bazel based on exec+target constraints.

### Per-target Linux arm64 transition (`transitions.bzl`)

An alternative to `--config=arm64` for cases where a single `BUILD` rule should always produce an arm64 binary without requiring a command-line flag.

`transitions.bzl` provides a `linux_arm64_binary` rule that applies a Starlark [configuration transition](https://bazel.build/extending/config#user-defined-transitions) mirroring `.bazelrc`'s `build:arm64` config — setting `//command_line_option:platforms` to `//platforms:arm64_platform`, `--cpu` to `arm64`, and registering both Linux arm64 toolchains:

```python
load("//:transitions.bzl", "linux_arm64_binary")

cc_binary(name = "hello-world", srcs = ["main.cc"], ...)

linux_arm64_binary(
    name = "hello-world_arm64",
    binary = ":hello-world",
)
```

Build without any config flag:

```bash
bazel build //examples/cc/main:hello-world_arm64
```

**Exec platform behavior:**
- On x86_64 exec: Bazel selects `gcc_arm64_toolchain` (GCC 9 ARM cross-compiler).
- On aarch64 exec: Bazel selects `gcc_arm64_native_toolchain` (ARM GCC 14.2).

## Parallel Cross-Platform Testing

`ansible/pipeline.yml` runs builds and tests for **x86_64**, **arm64** (Linux, in Docker), and **macos_arm64** (native, macOS host only) in parallel, and prints a pass/fail summary when all three finish.

```bash
cd ansible
ansible-playbook pipeline.yml

# Force a fresh docker_image pull + container recreation for x86_64/arm64
ansible-playbook pipeline.yml -e pipeline_env=build
```

**Requirements:** `community.docker` collection — `ansible-galaxy install -r requirements.yml` — and Docker Desktop with multi-arch / `binfmt_misc` support.

**How it works:**

- Linux builds run inside long-lived Docker containers (`cross_build_x86_64`, `cross_build_arm64`), created on first run and reused (never removed) on subsequent runs.
- Bazel output caches are persisted in named Docker volumes (`cross_build_x86_64_bazel_cache`, `cross_build_arm64_bazel_cache`) that survive container restarts and Bazel version changes.
- Each container is joined to the `buildbuddy-net` Docker network so it can reach the BuildBuddy remote cache at `grpc://buildbuddy-app:1985`.
- The macOS arm64 build runs natively on the host — no Docker.
- x86_64 runs under QEMU emulation on Apple Silicon, so Bazel JVM startup can take several minutes there.
- On macOS, the play first ensures the BuildBuddy on-prem cache is running (`ansible-playbook setup_buildbuddy.yml`). Inside each Linux container, required packages (`curl`, plus `libxml2-dev` for the arm64 container) are installed before the build.
- The three builds run as parallel background jobs; a single task tails all three logs live until every platform finishes, then the play reports each platform's result and fails if any build failed.
- `pipeline_env` controls container reuse: `dev` (default) reuses the existing x86_64/arm64 containers and image as-is, pulling/recreating only if they don't exist yet; `build` always pulls a fresh `docker_image` and recreates both containers from it.

**Container and volume names** (fixed, no timestamp — same names are reused every run):

| Arch | Container | Cache volume |
|------|-----------|--------------|
| x86_64 | `cross_build_x86_64` | `cross_build_x86_64_bazel_cache` |
| arm64 | `cross_build_arm64` | `cross_build_arm64_bazel_cache` |

### Host Setup (`ansible/setup.yml`)

`ansible/setup.yml` installs required host packages before building and is safe to run multiple times (no-op if all packages are already present). Currently installs `libxml2-dev` (Linux arm64), `curl` (all Linux), and `tmux` (macOS). On macOS it also automatically runs the BuildBuddy setup playbook.

```bash
cd ansible
ansible-playbook setup.yml
```

To add a new requirement, append an entry to `required_packages` inside `setup.yml`:

```yaml
- { name: "package_name", os: "Linux", arch: "arm64" }   # os: Linux | Darwin | "*"   arch: arm64 | aarch64 | x86_64 | "*"
```

## BuildBuddy On-Prem (Remote Cache)

`ansible/setup_buildbuddy.yml` starts a local [BuildBuddy](https://www.buildbuddy.io/) on-prem instance in Docker and wires it up as a remote cache and build-event stream for all Bazel invocations.

```bash
cd ansible
ansible-playbook setup_buildbuddy.yml                       # start (default)
ansible-playbook setup_buildbuddy.yml -e bb_command=stop
ansible-playbook setup_buildbuddy.yml -e bb_command=status
ansible-playbook setup_buildbuddy.yml -e bb_command=rm
```

On **macOS**, `pipeline.yml` and `setup.yml` both run this playbook automatically so the cache is always available before builds start.

### What it starts

| Container | Image | Ports |
|-----------|-------|-------|
| `buildbuddy-app` | `gcr.io/flame-public/buildbuddy-app-onprem:latest` | HTTP `8080`, gRPC `1985` |
| `buildbuddy-executor` | `gcr.io/flame-public/buildbuddy-executor-onprem:latest` | (Linux only) |

Both containers are placed on the `buildbuddy-net` Docker network. Cross-platform build containers created by `pipeline.yml` are also joined to this network, so they can reach the cache at `grpc://buildbuddy-app:1985`.

**Web UI:** `http://localhost:8080`

### `.bazelrc` wiring

The following flags are active for every build (no opt-in needed):

```
build --bes_results_url=http://buildbuddy-app:8080/invocation/
build --bes_backend=grpc://buildbuddy-app:1985
build --remote_cache=grpc://buildbuddy-app:1985
build --remote_timeout=10m
```

Remote execution (`--remote_executor`) is available on Linux (app + executor both running) but commented out by default. Cloud BuildBuddy (`app.buildbuddy.io`) config is also present but commented out — uncomment and add your API key to switch to the hosted service.

### Behaviour by OS

| OS | What starts | Cache | RBE |
|----|-------------|-------|-----|
| Linux (x86_64 / arm64) | app + executor | yes | yes (executor available) |
| macOS (arm64 / x86_64) | app only | yes | no |

## Code Coverage

`ansible/coverage_check.sh` measures **patch coverage** — the fraction of lines introduced by the last commit (`HEAD~1..HEAD`) that are exercised by tests — and enforces a configurable minimum threshold.

```bash
# Auto-detect platform, 75% threshold (default)
./ansible/coverage_check.sh

# Explicit platform and threshold
./ansible/coverage_check.sh --config macos_arm64 --threshold 80

# Keep the lcov report after a passing run
./ansible/coverage_check.sh --keep-report
```

It can also be run via the Ansible wrapper (`ansible-playbook ansible/coverage_check.yml`), which exposes the same options as extra-vars and asserts on the exit code.

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--config <cfg>` | auto-detected | Bazel platform config: `x86_64`, `arm64`, `macos_arm64`, `macos_x86_64` |
| `--threshold <pct>` | `75` | Minimum patch coverage % required per language |
| `--keep-report` | off | Retain the lcov report even on a passing run |

**Supported languages:** C/C++, Java, Go, Python. Only languages with changed files are evaluated; unsupported file types (headers-only changes, generated code) emit a warning and are skipped.

**How it works:**

1. Derives the diff from `git diff HEAD~1..HEAD` (last commit) — no patch file needed.
2. Identifies which languages have changed source files.
3. Runs `bazel query rdeps(//examples/..., set(<changed files>))` to discover precisely which targets depend on the changed files; falls back to broad `//examples/<lang>/...` globs if the query returns nothing.
4. Runs `./bazel coverage --config=<cfg> --combined_report=lcov` on the discovered targets only.
5. Parses the merged lcov report, filters to lines present in the patch, and computes per-language coverage.
6. Exits `0` (PASS) if all languages meet the threshold, `1` (FAIL) otherwise.

**Outputs:**

- `coverage_reports/<timestamp>/merged_coverage.dat` — merged lcov data (deleted on PASS unless `--keep-report`).
- `coverage_reports/<timestamp>/bazel_coverage.log` — raw Bazel output.

**Running coverage for a specific language manually:**

```bash
# C/C++
./bazel coverage --config=macos_arm64 --combined_report=lcov //examples/cc/...

# Java
./bazel coverage --config=macos_arm64 --combined_report=lcov //examples/java/...

# Go
./bazel coverage --config=macos_arm64 --combined_report=lcov //examples/go/...

# Python
./bazel coverage --config=macos_arm64 --combined_report=lcov //examples/python/...
```

The merged lcov report lands at `bazel-out/_coverage/_coverage_report.dat`.

## Affected Server Targets

`ansible/affected_server_targets.sh` identifies Bazel targets tagged `server` in `//examples/...` that are **transitively affected** by source-file changes in the last commit (`HEAD~1..HEAD`). Use it to determine which deployable service images need to be rebuilt and redeployed after a commit.

```bash
./ansible/affected_server_targets.sh
```

It also runs automatically as the first step of `ansible/pipeline.yml`, so every pipeline run prints which server targets are affected (and therefore being built/deployed) by the commit under test — no separate invocation needed.

**How it works:**

1. Collects changed source files (`*.go`, `*.py`, `*.java`, `*.cpp`, `*.c`, `*.h`) from `git diff HEAD~1..HEAD`.
2. Runs a `bazel query` to find all targets under `//examples/...` that **transitively depend** on those files and carry the `server` tag:
   ```
   attr(tags, 'server', rdeps(//examples/..., set(<changed files>)))
   ```
3. Prints the list of affected server targets — one per line — suitable for piping into a Docker build or deployment script.

**Tagging a target as deployable:**

Add `tags = ["server"]` to any binary rule whose output is packaged into a Docker image. The two existing server targets in this repo illustrate the pattern:

```python
# examples/go/grpc_server/BUILD
go_binary(
    name = "server",
    srcs = ["main.go"],
    tags = ["server"],
    ...
)

# examples/python/clientServer/BUILD
py_binary(
    name = "server",
    srcs = ["server.py"],
    tags = ["server"],
    ...
)
```

**Exit codes:**

| Code | Meaning |
|------|---------|
| `0` | Success — prints matched targets, or warns that none matched |
| `1` | Error — fewer than 2 commits, or `bazel query` failed |

If no server-tagged targets are transitively affected, the script exits `0` with a warning — this is expected for commits that only touch tests or non-server code.

**Example output** (from a commit touching `examples/go/grpc_server/main.go` and `examples/python/clientServer/server_lib.py`):

```
[affected] Diff: c53c3e3..db11931  (HEAD~1..HEAD)
[affected] Changed source files (2):
    examples/go/grpc_server/main.go
    examples/python/clientServer/server_lib.py

[affected] Running bazel query...
[affected]   Query: attr(tags, 'server', rdeps(//examples/..., set(examples/go/grpc_server/main.go examples/python/clientServer/server_lib.py)))

[affected] Affected server targets (2):
    //examples/go/grpc_server:server
    //examples/python/clientServer:server
```

## License Aggregation

The `license/` package provides a lightweight, hermetic license-compliance system built entirely in Starlark — no external tools or plugins required.

### Overview

| File | Purpose |
|------|---------|
| `license/defs.bzl` | `license_declaration` rule + `LicenseInfo` provider |
| `license/aspect.bzl` | `license_aspect` — propagates `LicensesInfo` through the transitive dep graph |
| `license/report.bzl` | `license_report` and `license_set` rules |
| `license/BUILD.bazel` | Pre-declared licenses for all known external dependencies |

### Declaring a license

```python
load("//license:defs.bzl", "license_declaration")

license_declaration(
    name = "my_lib_license",
    spdx_id    = "Apache-2.0",
    package_name    = "my-lib",
    package_version = "1.2.3",
    url        = "https://www.apache.org/licenses/LICENSE-2.0",
    copyright  = "Copyright 2024, Example Corp.",
)
```

All attributes except `spdx_id` are optional. The `spdx_id` must be a valid [SPDX identifier](https://spdx.org/licenses/).

### Generating a report

Add a `license_report` target next to the artifact whose dependency tree you want to audit:

```python
load("//license:report.bzl", "license_report")

license_report(
    name          = "server_licenses",
    target        = ":server",
    artifact_name = "Java gRPC Server",
    deps_licenses = [
        "//license:java_grpc_deps",   # Maven JARs (not auto-discovered by the aspect)
        "//license:project_license",  # first-party license
    ],
)
```

Build and read the report:

```bash
./bazel build //examples/java/grpc_server:server_licenses
cat bazel-bin/examples/java/grpc_server/server_licenses_license_report.txt
```

Sample output:

```
======================================================================
  LICENSE REPORT  :  Java gRPC Server (//examples/java/grpc_server:server)
======================================================================
  Unique license types : 3
  Total packages       : 14
======================================================================

[ Apache-2.0 ]  (12 packages)
----------------------------------------------------------------------
  - cross_platform (this project)
      Copyright : Copyright 2024, cross_platform contributors
      License   : https://www.apache.org/licenses/LICENSE-2.0
      Bazel     : //license:project_license
  - grpc-java / grpc-api 1.68.1
      Copyright : Copyright 2014, Google Inc.
      ...

[ BSD-3-Clause ]  (1 package)
----------------------------------------------------------------------
  - protobuf-java 4.29.3
      ...

[ CDDL-1.0 ]  (1 package)
----------------------------------------------------------------------
  - javax.annotation-api 1.3.2
      ...
======================================================================
```

### Grouping licenses with `license_set`

`license_set` bundles multiple `license_declaration` targets so they can be referenced as a single label in `deps_licenses`:

```python
load("//license:report.bzl", "license_set")

license_set(
    name = "go_grpc_deps",
    licenses = [
        "//license:golang_grpc",
        "//license:golang_protobuf",
    ],
)
```

### Pre-defined license sets

`//license:BUILD.bazel` contains ready-to-use declarations and sets for all external dependencies in this repo:

| Label | Contents |
|-------|----------|
| `//license:project_license` | First-party Apache-2.0 license for this repo |
| `//license:java_grpc_deps` | 13 Maven JARs: gRPC-Java 1.68.x, Protobuf-Java 4.29.x, Guava, etc. |
| `//license:go_grpc_deps` | `google.golang.org/grpc` v1.71.0 + `google.golang.org/protobuf` v1.36.10 |
| `//license:python_requests` | `requests`, `urllib3`, `certifi`, `charset-normalizer`, `idna` |
| `//license:python_torch_deps` | PyTorch 2.7.0, torchvision, NumPy, Pillow, and their transitive deps |
| `//license:python_data_deps` | pandas, pyarrow, fastparquet, python-dateutil, pytz, six |

### How the aspect works

`license_aspect` is an [aspect](https://bazel.build/extending/aspects) that propagates through `deps`, `runtime_deps`, `exports`, and `licenses` attributes. For each target carrying a `LicenseInfo` provider it serialises the metadata to a JSON string and accumulates it in a `depset` (which deduplicates entries reached via multiple paths). The `license_report` rule writes this collected data to a human-readable text file at build time — no network access or post-processing script needed.

External dependencies (Maven JARs, pip wheels, Go modules) are not Bazel targets that the aspect can traverse, so their licenses must be supplied explicitly via the `deps_licenses` attribute using the pre-defined sets in `//license:BUILD.bazel`.

### Existing report targets

| Target | Artifact |
|--------|---------|
| `//examples/java/grpc_server:server_licenses` | Java gRPC server |
| `//examples/go/grpc_server:server_licenses` | Go gRPC server |
| `//examples/python:demo_licenses` | Python requests demo |

## Architecture

### Toolchain Registration Flow (Bzlmod)

```
MODULE.bazel
  └── toolchain_extension.bzl  (toolchain_ext module extension)
        └── toolchain_repositories.bzl  (all repository rules)
              ├── toolchain_archive_repository  (generic: download + patch + symlink BUILD)
              ├── gcc_9_x86_64_repository / gcc_9_arm64_repository
              ├── gcc_14_arm64_aarch64_hosted_repository  (ARM GCC 14.2 aarch64-hosted, arm64 target)
              ├── gcc_x86_64_on_aarch64_repository  (Ubuntu GCC 12 arm64-hosted, x86_64 target)
              ├── llvm_macos_arm64/x86_64_repository
              ├── llvm_linux_x86_64_repository
              ├── llvm_linux_aarch64_repository  (custom: also bundles libxml2.so.2)
              ├── macos_sdk_repository  (xcrun / MACOS_SDK_PATH)
              ├── jdk_temurin_21_*_repository  (4 platforms)
              ├── protoc_*_repository  (4 platforms)
              ├── protoc_gen_go_*_repository  (4 platforms)
              ├── protoc_gen_go_grpc_*_repository  (4 platforms)
              ├── protoc_gen_grpc_java_*_repository  (4 platforms)
              ├── grpc_python_plugin_*_repository  (4 platforms)
              └── grpc_java_maven_repositories()  (13 Maven JARs)

BUILD.bazel (root)
  ├── cc_toolchain_config (cc_toolchain_config.bzl)          — Linux GCC toolchains (all Linux targets)
  ├── cc_macos_toolchain_config (macos_toolchain_config.bzl) — macOS LLVM toolchains
  ├── cc_toolchain / toolchain / platform targets
  ├── JDK runtime toolchains (jdk_*_toolchain)
  └── proto_toolchain (proto/proto_toolchain.bzl)

MODULE.bazel
  └── register_toolchains() for macOS CC, proto, and JDK toolchains
```

The `WORKSPACE` file is a stub — all repository and toolchain management has been migrated to Bzlmod.

### Key Files

| File | Purpose |
|------|---------|
| `transitions.bzl` | `linux_arm64_binary` rule: applies a per-target config transition to build Linux arm64 without `--config=arm64` |
| `ansible/pipeline.yml` | Parallel build+test runner: x86_64 + arm64 (Docker) + macos_arm64 (host), unattended |
| `ansible/affected_server_targets.sh` | Lists `server`-tagged targets affected by the last commit; run automatically as the first step of `pipeline.yml` |
| `ansible/coverage_check.sh` | Patch coverage checker: runs `bazel coverage`, filters to last-commit diff lines, enforces threshold |
| `ansible/coverage_check.yml` | Ansible wrapper around `coverage_check.sh`; exposes its options as extra-vars and asserts on exit code |
| `ansible/setup.yml` | Installs required host packages before building (idempotent); auto-starts BuildBuddy on macOS |
| `ansible/setup_buildbuddy.yml` | Starts/stops BuildBuddy on-prem in Docker (app + executor on Linux, app only on macOS); wires `buildbuddy-net` |
| `toolchain_extension.bzl` | Bzlmod module extension; instantiates all external repos; loaded by `MODULE.bazel` |
| `toolchain_repositories.bzl` | All repository rules: `toolchain_archive_repository`, `macos_sdk_repository`, GCC/LLVM/JDK/protoc/plugin wrappers, `grpc_java_maven_repositories` |
| `external_tool/external_tool_repositories.bzl` | Legacy WORKSPACE helper (retained but not the primary path); calls a subset of repos |
| `external_tool/BUILD.gcc_9_*.bazel` | BUILD files injected into downloaded GCC repos; expose `all_files` filegroup |
| `external_tool/BUILD.llvm_macos.bazel` | BUILD file for macOS LLVM repos |
| `external_tool/BUILD.llvm_linux.bazel` | BUILD file for Linux LLVM repos |
| `external_tool/BUILD.jdk.bazel` | BUILD file for Temurin JDK repos; exposes `:jdk` java_runtime target |
| `external_tool/BUILD.protoc.bazel` | BUILD file for protoc repos; exposes `:protoc` and `:well_known_protos` |
| `external_tool/BUILD.proto_plugin.bazel` | BUILD file for single-binary plugin repos (protoc-gen-go, protoc-gen-grpc-java, etc.) |
| `external_tool/BUILD.maven_jar.bazel` | BUILD file for Maven JAR repos; exposes `:jar` java_import |
| `cc_toolchain_config.bzl` | Starlark rule for all Linux GCC toolchains; derives sysroot from `cpu` attr; optional `gcc_builtin_include_dir` for relocated compilers |
| `macos_toolchain_config.bzl` | Starlark rule for macOS LLVM toolchains; uses `-target`, `-isysroot`, `-fuse-ld=lld` |
| `proto/proto_toolchain.bzl` | Custom proto toolchain rule carrying protoc + gRPC plugin paths |
| `proto/defs.bzl` | `proto_library` and `*_proto_library` macro rules consuming the proto toolchain |
| `python/python_extension.bzl` | Bzlmod extension for the custom hermetic Python toolchain |
| `BUILD.bazel` (root) | Instantiates all toolchain configs, `cc_toolchain`, `toolchain`, `platform`, JDK, and proto toolchain targets |
| `MODULE.bazel` | Declares Bazel deps; wires `toolchain_ext`; `register_toolchains()` for macOS CC + JDK + proto |
| `.bazelrc` | Platform and build-mode config shortcuts; `--extra_toolchains` for Linux |

### Sysroot Convention

**Linux GCC** (`cc_toolchain_config.bzl`) — sysroot subdirectory derived from `cpu` attr:
- `arm64` / `aarch64` → `<sysroot_path>/aarch64-none-linux-gnu/libc`
- anything else → `<sysroot_path>/x86_64-buildroot-linux-gnu/sysroot`

**Exception — `gcc_x86_64_on_aarch64` (aarch64 exec → Linux x86_64)**: compiler binaries come from the Ubuntu GCC 12 repo (`gcc_x86_64_on_aarch64`), but `sysroot_path` points to the Bootlin `gcc_9_x86_64` repo for glibc headers and libs. `gcc_builtin_include_dir` is set to `usr/lib/gcc-cross/x86_64-linux-gnu/12/include` inside the Ubuntu repo so Bazel tracks the versioned GCC internal headers from the relocated compiler installation.

**macOS LLVM** (`macos_toolchain_config.bzl`) — sysroot is the macOS SDK path; passed as `-isysroot`.

### Toolchain Constraints Summary

| Toolchain target name | exec | target |
|-----------------------|------|--------|
| `gcc_x86_64_toolchain` | Linux x86_64 | Linux x86_64 |
| `gcc_arm64_toolchain` | Linux x86_64 | Linux arm64 |
| `gcc_arm64_native_toolchain` | Linux aarch64 | Linux arm64 |
| `gcc_x86_64_on_linux_aarch64_toolchain` | Linux aarch64 | Linux x86_64 |
| `clang_macos_arm64_toolchain` | macOS arm64 | macOS arm64 |
| `clang_macos_x86_64_toolchain` | macOS arm64 | macOS x86_64 |
| `clang_macos_x86_64_on_macos_x86_64_toolchain` | macOS x86_64 | macOS x86_64 |
| `clang_macos_arm64_on_macos_x86_64_toolchain` | macOS x86_64 | macOS arm64 |
| `clang_macos_arm64_on_linux_x86_64_toolchain` | Linux x86_64 | macOS arm64 |
| `clang_macos_x86_64_on_linux_x86_64_toolchain` | Linux x86_64 | macOS x86_64 |
| `clang_macos_arm64_on_linux_aarch64_toolchain` | Linux aarch64 | macOS arm64 |
| `clang_macos_x86_64_on_linux_aarch64_toolchain` | Linux aarch64 | macOS x86_64 |

### Additional Toolchains

**JDK — Temurin 21.0.11+10** (4 repos: `jdk_macos_arm64`, `jdk_macos_x86_64`, `jdk_linux_x86_64`, `jdk_linux_aarch64`):
- Registered globally with higher priority than `local_jdk` so no host JVM is required.
- `.bazelrc` sets `--java_language_version=21 --java_runtime_version=21` globally.
- macOS archives include `Contents/Home` in `strip_prefix` so `bin/java` always lands at the repo root.

**Proto toolchain — protoc 29.3** (4 exec platforms):
- Each proto toolchain bundles: `protoc`, `protoc-gen-go` v1.35.2, `protoc-gen-go-grpc` v1.5.1, `protoc-gen-grpc-java` 1.68.0.
- Registered globally; no `target_compatible_with` since generated sources are not architecture-specific.
- Custom toolchain type at `//proto:toolchain_type`; rules in `proto/defs.bzl`.

**Python toolchain — CPython 3.12**:
- Custom hermetic toolchain in `python/`; downloaded via `python_ext` Bzlmod extension in `MODULE.bazel`.
- `rules_python` is also loaded for the standard `py_*` rules; bootstrap mode set to `script` to avoid requiring a system `python3`.

**Java gRPC Maven JARs** (13 JARs, no rules_jvm_external):
- Downloaded directly via `_maven_jar_repository` rule (Bazel's built-in http downloader).
- Managed by `grpc_java_maven_repositories()` in `toolchain_repositories.bzl`.
- Key constraint: `protoc` 29.x generates code requiring `protobuf-java` 4.x (not 3.x).

## AI / GPU — Matrix Multiplication with MPS (Metal Performance Shaders)

`examples/AI/matrix_multiplication` contains a PyTorch benchmark that compares matrix multiplication speed on the CPU versus Apple's **Metal Performance Shaders (MPS)** GPU backend. MPS is Apple's framework for running high-performance GPU compute on Apple Silicon (M-series chips); PyTorch exposes it through the `"mps"` device.

### What the benchmark does

1. Checks MPS availability and exits gracefully if not supported.
2. Allocates two random square matrices of size **16 384 × 16 384** (64 × 256) on CPU.
3. Runs `torch.matmul` on CPU via `run_cpu()` and records the wall-clock time.
4. Copies both matrices to the MPS device and runs `torch.matmul` via `run_mps()`.
5. Calls `torch.mps.synchronize()` inside `run_mps()` to wait for the GPU kernel to finish before stopping the timer.
6. Prints both times and the GPU speedup ratio.

```
============= CPU SPEED ===========
task on device cpu   took = 3.4200 sec
============= MPS (GPU) SPEED ===========
task on device mps:0 took = 0.3100 sec

gpu is 11.0x faster than cpu
```

> **Note:** actual numbers vary by chip generation (M1 / M2 / M3 / M4) and whether the matrix fits in the GPU's unified memory without paging.

### Constraints

The target is restricted to **macOS arm64** only:

```python
target_compatible_with = [
    "@platforms//os:macos",
    "@platforms//cpu:arm64",
]
```

It will not build on Linux or macOS x86_64.

### Build and run

```bash
# Build (macOS ARM64 only)
./bazel build --config=macos_arm64 //examples/AI/matrix_multiplication:matrix_multiplication

# Run
./bazel-bin/examples/AI/matrix_multiplication/matrix_multiplication
```

The binary bundles its own hermetic Python 3.12 interpreter and all `torch` / `torchvision` wheels — no system Python or `pip install` is needed.

### Dependencies

Declared in `examples/AI/matrix_multiplication/BUILD.bazel` as `@pip_*` targets pulled from the project's hermetic pip repository:

| Package | Role |
|---------|------|
| `torch` | Core tensor ops + MPS backend |
| `torchvision` | Pulled transitively; not used directly in this benchmark |
| `filelock`, `fsspec`, `jinja2`, `networkx`, `sympy`, … | Pure-Python runtime deps of `torch` |
| `numpy`, `pillow` | Required by `torchvision` |

### How MPS acceleration works

PyTorch dispatches `torch.matmul` to Apple's **MPSMatrixMultiplication** kernel when the tensors reside on an MPS device. The kernel runs on the GPU's matrix-multiply units (AMX / GPU shader cores), which are orders of magnitude faster than a CPU `gemm` for large matrices.

`torch.mps.synchronize()` is required before stopping the timer because GPU work is submitted asynchronously; without it the measured time reflects only submission latency, not completion.

## iOS / macOS Application Development (Swift + SwiftUI)

`examples/ios/` contains a minimal Swift/SwiftUI application and its unit test, built entirely with Bazel using `rules_apple` and `rules_swift`. No Xcode project file is required — Bazel drives the full build and test cycle, using the Xcode-backed toolchain from `apple_support`.

### Dependencies

Declared in `MODULE.bazel`:

| Module | Version | Role |
|--------|---------|------|
| `apple_support` | 2.2.0 | Xcode-backed CC toolchain (`local_config_apple_cc_toolchains`) |
| `rules_apple` | 4.5.3 | `ios_application`, `macos_application`, `*_unit_test` rules |
| `rules_swift` | 3.6.1 | `swift_library` rule; Swift compilation |

The Apple CC toolchains are registered at the highest priority in `.bazelrc`:

```
build --extra_toolchains=@local_config_apple_cc_toolchains//:all
```

This ensures Bazel selects the Xcode-backed compiler for any target carrying the Apple platform constraint (e.g. `@build_bazel_apple_support//constraints:apple`), while the LLVM-based toolchains still handle plain C/C++ targets.

### Prerequisites

- **macOS arm64** — both targets carry `target_compatible_with = [@platforms//os:macos, @platforms//cpu:arm64]`.
- **Xcode** must be installed and its command-line tools active (`xcode-select -p` should return a valid path). Bazel auto-discovers the SDK via `xcrun`.
- A valid `--apple_platform_type` is selected automatically from the rule (`macos`).

### Project structure

```
examples/ios/
├── BUILD.bazel          # Bazel build definitions
├── DemoApp.swift        # SwiftUI app entry point + ContentView
├── DemoTest.swift       # Unit test using Swift Testing (@Suite / @Test)
├── Info.plist           # iOS bundle Info.plist (phone/tablet orientations)
└── Info_macos.plist     # macOS bundle Info.plist (NSApplication)
```

### Build targets

| Target | Rule | Description |
|--------|------|-------------|
| `//examples/ios:AppLibrary` | `swift_library` | Shared Swift library compiled from `DemoApp.swift` |
| `//examples/ios:DemoMacApp` | `macos_application` | macOS desktop app bundle (bundle ID `com.buildbuddy.demomacapp`, min OS 15.0) |
| `//examples/ios:DemoTestLib` | `swift_library` | Swift library compiled from `DemoTest.swift` (`testonly`) |
| `//examples/ios:DemoMacTest` | `macos_unit_test` | Unit test bundle (min OS 15.0) |

### Build and run

```bash
# Build the macOS app bundle (macOS arm64 only)
./bazel build --config=macos_arm64 //examples/ios:DemoMacApp

# Build and launch the macOS app
./bazel run --config=macos_arm64 //examples/ios:DemoMacApp

# Run the unit tests
./bazel test --config=macos_arm64 //examples/ios:DemoMacTest

# Build all iOS targets
./bazel build --config=macos_arm64 //examples/ios/...

# Test all iOS targets
./bazel test --config=macos_arm64 //examples/ios/...
```

The built `.app` bundle lands at:

```
bazel-bin/examples/ios/DemoMacApp.app
```

Open it directly:

```bash
open bazel-bin/examples/ios/DemoMacApp.app
```

### Source overview

**`DemoApp.swift`** — SwiftUI entry point declared with `@main`. Renders a `ContentView` with a globe icon and "Hello, world!" text:

```swift
@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

**`DemoTest.swift`** — uses the Swift Testing framework (`import Testing`). `@Suite` / `@Test` replace XCTest's `class`/`func test` boilerplate:

```swift
@Suite
struct DemoTest {
    @Test
    func example() {
        #expect(1 + 1 == 2)
    }
}
```

### Info.plist files

| File | Used by | Key details |
|------|---------|-------------|
| `Info_macos.plist` | `DemoMacApp` | `NSApplication` principal class; `NSHighResolutionCapable = true` |
| `Info.plist` | Available for iOS targets | Portrait + landscape orientations; `LSRequiresIPhoneOS = true` |

### Adding an iOS simulator target

To add an iOS simulator build, extend `BUILD.bazel` with `ios_application` and `ios_unit_test` (already imported):

```python
ios_application(
    name = "DemoIOSApp",
    bundle_id = "com.buildbuddy.demoiosapp",
    families = ["iphone", "ipad"],
    infoplists = ["Info.plist"],
    minimum_os_version = "17.0",
    deps = [":AppLibrary"],
)

ios_unit_test(
    name = "DemoIOSTest",
    minimum_os_version = "17.0",
    deps = [":DemoTestLib"],
)
```

Then build/test against a simulator platform:

```bash
./bazel build --config=macos_arm64 \
  --apple_platform_type=ios \
  --ios_simulator_device="iPhone 16" \
  //examples/ios:DemoIOSApp
```

## Adding a New Target Architecture

1. Add a repository function in `toolchain_repositories.bzl` pointing to the archive URL.
2. Create `external_tool/BUILD.<arch>.bazel` (copy the existing pattern — expose `all_files`).
3. Call the new function from `toolchain_extension.bzl` and add the name to `use_repo()` in `MODULE.bazel`.
4. Add a `cc_toolchain_config`, `cc_toolchain`, `toolchain`, and `platform` block in `BUILD.bazel`.
5. Extend the appropriate toolchain config `.bzl` file if the new arch needs a different sysroot layout.
6. Add a `--config=<arch>` shortcut in `.bazelrc` with appropriate `--extra_toolchains` if Linux.

## Private Repository Access via SSH (`git insteadOf`)

Bazel fetches Go modules and other dependencies over HTTPS by default. If any dependency lives in a **private repository** (e.g. a private GitHub org, an internal GitLab instance), authentication must be supplied. The standard approach is to redirect HTTPS URLs to SSH using `git insteadOf` so that your SSH key is used instead of a password or token.

### One-time setup (per developer machine)

```bash
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

This rewrites every `https://github.com/<org>/<repo>` URL to `git@github.com:<org>/<repo>` transparently for all tools — including Bazel's repository rules and the `go` tool invoked by `rules_go`.

For a private GitLab or self-hosted instance, replace the hostname accordingly:

```bash
git config --global url."git@gitlab.example.com:".insteadOf "https://gitlab.example.com/"
```

Verify the rewrite is active:

```bash
git config --global --get-regexp url
# Expected output:
# url.git@github.com:.insteadof https://github.com/
```

### SSH key requirements

- Your SSH key must be added to `~/.ssh/` and loaded in `ssh-agent` (`ssh-add ~/.ssh/id_ed25519`).
- The corresponding public key must be registered in the private repo's hosting platform (GitHub → Settings → SSH Keys, GitLab → Preferences → SSH Keys, etc.).
- Confirm SSH access before running Bazel:
  ```bash
  ssh -T git@github.com   # Expected: "Hi <user>! You've successfully authenticated…"
  ```

### Go modules (`rules_go` / `gazelle`)

`rules_go` invokes the `go` tool to resolve modules listed in `go.mod`. The `go` tool honours `git insteadOf` rewrites, but also requires:

1. **`GONOSUMCHECK` / `GONOSUMDB`** — bypass the Go checksum database for private modules (it cannot reach private repos):
   ```bash
   export GONOSUMCHECK="github.com/my-org/*"
   export GONOSUMDB="github.com/my-org/*"
   ```

2. **`GOPRIVATE`** — disables the module proxy and sum-DB for matching paths:
   ```bash
   export GOPRIVATE="github.com/my-org/*"
   ```

   Add these to your shell profile (`~/.zshrc`, `~/.bashrc`) so they are inherited by every Bazel invocation.

3. Pass them to Bazel via `.bazelrc` (project-level, not committed if the org name is confidential) or `~/.bazelrc` (user-level):
   ```
   # ~/.bazelrc  (never committed)
   build --action_env=GONOSUMCHECK=github.com/my-org/*
   build --action_env=GONOSUMDB=github.com/my-org/*
   build --action_env=GOPRIVATE=github.com/my-org/*
   ```

### CI / Docker environments

Docker containers and CI agents do not inherit your host SSH agent. Options:

**Option A — mount SSH agent socket (recommended for local Docker)**

```bash
docker run --rm \
  -v "$SSH_AUTH_SOCK:/ssh-agent" \
  -e SSH_AUTH_SOCK=/ssh-agent \
  <image> \
  ./bazel build ...
```

**Option B — mount a read-only SSH key (CI)**

```bash
docker run --rm \
  -v "$HOME/.ssh/id_ed25519:/root/.ssh/id_ed25519:ro" \
  <image> \
  bash -c "ssh-add /root/.ssh/id_ed25519 && ./bazel build ..."
```

**Option C — use a deploy key or machine user token** for fully automated pipelines where SSH agent forwarding is impractical. Store the token in a CI secret and configure `git insteadOf` inside the container's entrypoint:

```bash
git config --global url."https://x-access-token:${GH_TOKEN}@github.com/".insteadOf \
  "https://github.com/"
```

### Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `no such host` / `authentication failed` fetching a Go module | SSH key not loaded or not registered | Run `ssh-add` and verify with `ssh -T git@github.com` |
| `verifying module: checksum mismatch` | Sum-DB checked a private module | Set `GONOSUMCHECK`/`GOPRIVATE` |
| Bazel repository rule fails with `couldn't connect` | `insteadOf` not set in the exec environment | Add `git config` in the container entrypoint or CI setup step |
| `Permission denied (publickey)` inside Docker | SSH agent not forwarded | Use Option A or B above |
