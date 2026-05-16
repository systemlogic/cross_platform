#pragma once

#include <string>
#include <sys/types.h>

// Build the reply string for a given client name.
std::string make_reply(const std::string& name);

// Read from fd until EOF or buf is full. Returns total bytes read.
ssize_t recv_all(int fd, char* buf, size_t max_len);

// Serve one accepted connection: read name, write reply, close fd.
void handle_client(int cli_fd);

// Accept and serve connections indefinitely on the given port.
void run_server(int port, int backlog);
