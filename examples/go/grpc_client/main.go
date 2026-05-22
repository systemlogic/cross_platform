package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"os"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "cross_platform/examples/proto/greeter"
)

const (
	defaultHost = "localhost"
	defaultPort = "50051"
)

func main() {
	name := "world"
	host := defaultHost
	port := defaultPort

	if len(os.Args) > 1 {
		name = os.Args[1]
	}
	if len(os.Args) > 2 {
		host = os.Args[2]
	}
	if len(os.Args) > 3 {
		port = os.Args[3]
	}

	conn, err := grpc.NewClient(host+":"+port,
		grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("connect: %v", err)
	}
	defer conn.Close()

	client := pb.NewGreeterClient(conn)

	reply, err := client.SayHello(context.Background(), &pb.HelloRequest{Name: name})
	if err != nil {
		log.Fatalf("SayHello: %v", err)
	}
	fmt.Println("SayHello      :", reply.Message)

	stream, err := client.SayHelloStream(context.Background(), &pb.HelloRequest{Name: name})
	if err != nil {
		log.Fatalf("SayHelloStream: %v", err)
	}
	fmt.Println("SayHelloStream:")
	for {
		reply, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Fatalf("stream recv: %v", err)
		}
		fmt.Println(" ", reply.Message)
	}
}
