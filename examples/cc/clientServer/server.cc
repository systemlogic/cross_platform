#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstring>
#include <iostream>
#include <string>

static const int kPort    = 50051;
static const int kBacklog = 8;

// Read bytes until peer closes write-end or buffer is full.
static ssize_t recv_all(int fd, char* buf, size_t max_len) {
    ssize_t total = 0;
    while (total < static_cast<ssize_t>(max_len)) {
        ssize_t n = read(fd, buf + total, max_len - total);
        if (n <= 0) break;
        total += n;
    }
    return total;
}

int main() {
    int srv = socket(AF_INET, SOCK_STREAM, 0);
    if (srv < 0) { perror("socket"); return 1; }

    int opt = 1;
    setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family      = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port        = htons(kPort);

    if (bind(srv, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        perror("bind"); return 1;
    }
    listen(srv, kBacklog);
    std::cout << "Server listening on 0.0.0.0:" << kPort << std::endl;

    while (true) {
        int cli = accept(srv, nullptr, nullptr);
        if (cli < 0) { perror("accept"); continue; }

        char buf[256]{};
        ssize_t n = recv_all(cli, buf, sizeof(buf) - 1);
        if (n > 0) {
            std::string reply = "Hello " + std::string(buf, n);
            write(cli, reply.c_str(), reply.size());
        }
        close(cli);
    }

    close(srv);
    return 0;
}
