#include "examples/cc/clientServer/server_lib.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstring>
#include <iostream>
#include <string>

std::string make_reply(const std::string& name) {
    return "Hello " + name;
}

ssize_t recv_all(int fd, char* buf, size_t max_len) {
    ssize_t total = 0;
    while (total < static_cast<ssize_t>(max_len)) {
        ssize_t n = read(fd, buf + total, max_len - total);
        if (n <= 0) break;
        total += n;
    }
    return total;
}

void handle_client(int cli_fd) {
    char buf[256]{};
    ssize_t n = recv_all(cli_fd, buf, sizeof(buf) - 1);
    if (n > 0) {
        std::string reply = make_reply(std::string(buf, n));
        write(cli_fd, reply.c_str(), reply.size());
    }
    close(cli_fd);
}

void run_server(int port, int backlog) {
    int srv = socket(AF_INET, SOCK_STREAM, 0);
    if (srv < 0) { perror("socket"); return; }

    int opt = 1;
    setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family      = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port        = htons(port);

    if (bind(srv, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        perror("bind"); close(srv); return;
    }
    listen(srv, backlog);
    std::cout << "Server listening on 0.0.0.0:" << port << std::endl;

    while (true) {
        int cli = accept(srv, nullptr, nullptr);
        if (cli < 0) { perror("accept"); continue; }
        handle_client(cli);
    }

    close(srv);
}
