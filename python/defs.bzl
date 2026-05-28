"""Public API for the Python rules."""

load(":py_self_executable.bzl", _py_self_executable = "py_self_executable")
load(":py_runnable.bzl", _py_runnable = "py_runnable")
load(":toolchain.bzl", _PyRuntimeInfo = "PyRuntimeInfo")

py_self_executable = _py_self_executable
py_runnable = _py_runnable
PyRuntimeInfo = _PyRuntimeInfo
