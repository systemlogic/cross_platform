package clientserver_test

import (
	"io"
	"net"
	"testing"

	clientserver "cross_platform/examples/go/clientServer"
)

func TestMakeReply(t *testing.T) {
	tests := []struct{ name, want string }{
		{"World", "Hello World"},
		{"Bazel", "Hello Bazel"},
		{"", "Hello "},
	}
	for _, tc := range tests {
		if got := clientserver.MakeReply(tc.name); got != tc.want {
			t.Errorf("MakeReply(%q) = %q, want %q", tc.name, got, tc.want)
		}
	}
}

func TestHandleConn(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		clientserver.HandleConn(conn)
	}()

	conn, err := net.Dial("tcp", ln.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	conn.Write([]byte("World"))
	conn.(*net.TCPConn).CloseWrite()

	reply, err := io.ReadAll(conn)
	conn.Close()
	if err != nil {
		t.Fatal(err)
	}
	if string(reply) != "Hello World" {
		t.Errorf("got %q, want %q", string(reply), "Hello World")
	}
	<-done
}
