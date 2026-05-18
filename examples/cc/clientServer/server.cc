#include "examples/cc/clientServer/server_lib.h"

static const int kPort    = 50051;
static const int kBacklog = 8;

int main() {
    run_server(kPort, kBacklog);
    return 0;
}
