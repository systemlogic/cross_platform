"""Public API for the Python self-executable rules."""

load(":py_self_executable.bzl", _py_self_executable = "py_self_executable")
load(":toolchain.bzl", _PyRuntimeInfo = "PyRuntimeInfo")

py_self_executable = _py_self_executable
PyRuntimeInfo = _PyRuntimeInfo
