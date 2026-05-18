package main

import (
	"fmt"
	"io"
	"net"
	"os"
)

func main() {
	name := "world"
	if len(os.Args) > 1 {
		name = os.Args[1]
	}

	conn, err := net.Dial("tcp", "127.0.0.1:50051")
	if err != nil {
		fmt.Fprintln(os.Stderr, "connect:", err)
		os.Exit(1)
	}
	defer conn.Close()

	conn.Write([]byte(name))
	conn.(*net.TCPConn).CloseWrite()

	reply, _ := io.ReadAll(conn)
	fmt.Println("Greeter received:", string(reply))
}
