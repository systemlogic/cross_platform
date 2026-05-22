package com.example.greeter;

import io.grpc.stub.StreamObserver;

public class GreeterServiceImpl extends GreeterGrpc.GreeterImplBase {

    @Override
    public void sayHello(HelloRequest request, StreamObserver<HelloReply> responseObserver) {
        responseObserver.onNext(
            HelloReply.newBuilder()
                .setMessage("Hello, " + request.getName() + "!")
                .build());
        responseObserver.onCompleted();
    }

    @Override
    public void sayHelloStream(HelloRequest request, StreamObserver<HelloReply> responseObserver) {
        String name = request.getName();
        for (int i = 1; i <= 5; i++) {
            responseObserver.onNext(
                HelloReply.newBuilder()
                    .setMessage("Hello #" + i + ", " + name + "!")
                    .build());
        }
        responseObserver.onCompleted();
    }
}
