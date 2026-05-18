#include "examples/cc/main/hello-greet.h"
#include <cassert>
#include <string>

int main() {
    assert(get_greet("World") == "Hello World");
    assert(get_greet("Bazel") == "Hello Bazel");
    assert(get_greet("") == "Hello ");
    return 0;
}
