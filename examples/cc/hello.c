#include <stdio.h>

int main() {
    printf("Hello from Bazel GCC 9 Toolchain!\n");

#ifdef __aarch64__
    printf("Arch: ARM64\n");
#else
    printf("Arch: x86_64\n");
#endif

#if defined(DEBUG_BUILD)
    printf("Build mode: debug\n");
#elif defined(NDEBUG)
    printf("Build mode: release\n");
#elif defined(STATS_ENABLED)
    printf("Build mode: stats\n");
#else
    printf("Build mode: fastbuild (default)\n");
#endif

    return 0;
}
