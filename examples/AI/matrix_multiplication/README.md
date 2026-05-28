# Comparing performance CPU, MPS, CUDA

```
 ./bazel run --config=macos_arm64 examples/AI/matrix_multiplication
WARNING: Repository '@@+python_ext+cpython' will be fetched again since the file 'python/lib/python3.12/importlib' has been modified externally. External modifications can lead to incorrect builds.
INFO: Analyzed target //examples/AI/matrix_multiplication:matrix_multiplication (1 packages loaded, 1844 targets configured).
INFO: Found 1 target...
Target //examples/AI/matrix_multiplication:matrix_multiplication up-to-date:
  bazel-bin/examples/AI/matrix_multiplication/matrix_multiplication
INFO: Elapsed time: 12.785s, Critical Path: 0.03s
INFO: 1 process: 5 action cache hit, 1 internal.
INFO: Build completed successfully, 1 total action
INFO: Running command line: bazel-bin/examples/AI/matrix_multiplication/matrix_multiplication
task on device mps:0 took = 32.0921 sec
task on device cpu took = 232.9594 sec

gpu is 7.3x faster than cpu
samar@Unknown_de:75:47:07:45:cb cross_platform % bazel-bin/examples/AI/matrix_multiplication/matrix_multiplication
task on device mps:0 took = 36.4244 sec
task on device cpu took = 233.7751 sec

gpu is 6.4x faster than cpu
```

# Running a matrix multiplication on cuda

```
samar@Unknown_de:75:47:07:45:cb cross_platform % bazel-bin/examples/AI/matrix_multiplication/matrix_multiplication
task on device mps:0 took = 17.9537 sec
task on device cpu took = 233.7751 sec

cuda is 15.1x faster than cpu
```
