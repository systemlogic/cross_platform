package grpcservice_test

import (
	"context"
	"io"
	"net"
	"testing"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	grpcservice "cross_platform/examples/go/grpc_service"
	pb "cross_platform/examples/proto/greeter"
)

func TestSayHello(t *testing.T) {
	s := &grpcservice.GreeterServer{}
	reply, err := s.SayHello(context.Background(), &pb.HelloRequest{Name: "World"})
	if err != nil {
		t.Fatal(err)
	}
	if reply.Message != "Hello, World!" {
		t.Errorf("got %q, want %q", reply.Message, "Hello, World!")
	}
}

func TestSayHelloEmptyName(t *testing.T) {
	s := &grpcservice.GreeterServer{}
	reply, err := s.SayHello(context.Background(), &pb.HelloRequest{Name: ""})
	if err != nil {
		t.Fatal(err)
	}
	if reply.Message != "Hello, !" {
		t.Errorf("got %q, want %q", reply.Message, "Hello, !")
	}
}

func TestGreeterIntegration(t *testing.T) {
	lis, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	srv := grpc.NewServer()
	pb.RegisterGreeterServer(srv, &grpcservice.GreeterServer{})
	go srv.Serve(lis) //nolint:errcheck
	defer srv.Stop()

	conn, err := grpc.NewClient(lis.Addr().String(),
		grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()

	client := pb.NewGreeterClient(conn)

	reply, err := client.SayHello(context.Background(), &pb.HelloRequest{Name: "Bazel"})
	if err != nil {
		t.Fatal(err)
	}
	if reply.Message != "Hello, Bazel!" {
		t.Errorf("SayHello: got %q, want %q", reply.Message, "Hello, Bazel!")
	}

	stream, err := client.SayHelloStream(context.Background(), &pb.HelloRequest{Name: "Bazel"})
	if err != nil {
		t.Fatal(err)
	}
	count := 0
	for {
		_, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatalf("stream recv: %v", err)
		}
		count++
	}
	if count != 5 {
		t.Errorf("SayHelloStream: got %d replies, want 5", count)
	}
}
