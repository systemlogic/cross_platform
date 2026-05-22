package grpcservice

import (
	"context"
	"fmt"
	"time"

	pb "cross_platform/examples/proto/greeter"
)

type GreeterServer struct {
	pb.UnimplementedGreeterServer
}

func (s *GreeterServer) SayHello(_ context.Context, req *pb.HelloRequest) (*pb.HelloReply, error) {
	return &pb.HelloReply{Message: fmt.Sprintf("Hello, %s!", req.Name)}, nil
}

func (s *GreeterServer) SayHelloStream(req *pb.HelloRequest, stream pb.Greeter_SayHelloStreamServer) error {
	for i := range 5 {
		if err := stream.Send(&pb.HelloReply{Message: fmt.Sprintf("Hello #%d, %s!", i+1, req.Name)}); err != nil {
			return err
		}
		time.Sleep(100 * time.Millisecond)
	}
	return nil
}
