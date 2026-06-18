package main

import (
	"fmt"
	"log"
	"net"
	"os"
	"strconv"
	"google.golang.org/grpc"

	grpcservice "cross_platform/examples/go/grpc_service"
	pb "cross_platform/examples/proto/greeter"
)

const defaultPort = 50051



func main() {
	port := defaultPort
	if len(os.Args) > 1 {
		p, err := strconv.Atoi(os.Args[1])
		if err != nil {
			log.Fatalf("invalid port %q: %v", os.Args[1], err)
		}
		port = p
	}

	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("listen: %v", err)
	}

	srv := grpc.NewServer()
	pb.RegisterGreeterServer(srv, &grpcservice.GreeterServer{})
	log.Printf("Server listening on port %d", port)
	if err := srv.Serve(lis); err != nil {
		log.Fatalf("serve: %v", err)
	}
}
