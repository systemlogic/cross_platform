#include <stdio.h>

int main() {
    printf("Hello from Bazel GCC 9 Toolchain!\n");
    #ifdef __aarch64__
        printf("Running on ARM64\n");
    #else
        printf("Running on x86_64\n");
    #endif
    return 0;
}
