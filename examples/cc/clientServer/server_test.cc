#include "examples/cc/clientServer/server_lib.h"

#include <cassert>
#include <cstring>
#include <string>
#include <sys/socket.h>
#include <unistd.h>

static void test_make_reply() {
    assert(make_reply("World") == "Hello World");
    assert(make_reply("Bazel") == "Hello Bazel");
    assert(make_reply("") == "Hello ");
}

static void test_recv_all() {
    int fds[2];
    assert(pipe(fds) == 0);

    const char* msg = "ping";
    write(fds[1], msg, strlen(msg));
    close(fds[1]);

    char buf[64]{};
    ssize_t n = recv_all(fds[0], buf, sizeof(buf) - 1);
    assert(n == 4);
    assert(std::string(buf, n) == "ping");
    close(fds[0]);
}

// Partial write: recv_all must accumulate across multiple reads.
static void test_recv_all_partial() {
    int fds[2];
    assert(pipe(fds) == 0);

    write(fds[1], "hel", 3);
    write(fds[1], "lo", 2);
    close(fds[1]);

    char buf[64]{};
    ssize_t n = recv_all(fds[0], buf, sizeof(buf) - 1);
    assert(n == 5);
    assert(std::string(buf, n) == "hello");
    close(fds[0]);
}

static void test_handle_client() {
    int sv[2];
    assert(socketpair(AF_UNIX, SOCK_STREAM, 0, sv) == 0);

    // Write name on sv[0] and signal EOF so handle_client's recv_all terminates.
    const char* name = "World";
    write(sv[0], name, strlen(name));
    shutdown(sv[0], SHUT_WR);

    // handle_client owns sv[1]: reads name, writes reply, closes sv[1].
    handle_client(sv[1]);

    char buf[64]{};
    ssize_t n = read(sv[0], buf, sizeof(buf) - 1);
    assert(n > 0);
    assert(std::string(buf, n) == "Hello World");
    close(sv[0]);
}

int main() {
    test_make_reply();
    test_recv_all();
    test_recv_all_partial();
    test_handle_client();
    return 0;
}
