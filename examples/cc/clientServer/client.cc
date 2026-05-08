#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstring>
#include <iostream>
#include <string>

static const char* kHost = "127.0.0.1";
static const int   kPort = 50051;

int main(int argc, char** argv) {
    std::string name = (argc > 1) ? argv[1] : "world";

    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) { perror("socket"); return 1; }

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port   = htons(kPort);
    inet_pton(AF_INET, kHost, &addr.sin_addr);

    std::cout << "Client connecting to " << kHost << ":" << kPort << std::endl;
    if (connect(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        perror("connect"); return 1;
    }

    // Send name; server reads until EOF on this side.
    write(fd, name.c_str(), name.size());
    shutdown(fd, SHUT_WR);

    char buf[256]{};
    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    if (n > 0) {
        std::cout << "Greeter received: " << std::string(buf, n) << std::endl;
    }

    close(fd);
    return 0;
}
