package clientserver

import (
	"fmt"
	"io"
	"net"
)

func MakeReply(name string) string {
	return "Hello " + name
}

// HandleConn reads a name from conn, writes the reply, and closes it.
func HandleConn(conn net.Conn) {
	defer conn.Close()
	data, err := io.ReadAll(conn)
	if err != nil || len(data) == 0 {
		return
	}
	conn.Write([]byte(MakeReply(string(data))))
}

// RunServer listens on addr and serves clients indefinitely.
func RunServer(addr string) error {
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	defer ln.Close()
	fmt.Println("Server listening on", addr)
	for {
		conn, err := ln.Accept()
		if err != nil {
			continue
		}
		go HandleConn(conn)
	}
}
