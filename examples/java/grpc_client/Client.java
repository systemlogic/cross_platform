package com.example.greeter;

import io.grpc.ManagedChannel;
import io.grpc.netty.shaded.io.grpc.netty.NettyChannelBuilder;
import java.util.Iterator;
import java.util.concurrent.TimeUnit;

public class Client {
    public static void main(String[] args) throws Exception {
        String name = "world";
        String host = "localhost";
        int port = 50051;
        if (args.length > 0) name = args[0];
        if (args.length > 1) host = args[1];
        if (args.length > 2) port = Integer.parseInt(args[2]);

        ManagedChannel channel = NettyChannelBuilder
            .forAddress(host, port)
            .usePlaintext()
            .build();
        try {
            GreeterGrpc.GreeterBlockingStub stub = GreeterGrpc.newBlockingStub(channel);

            HelloReply reply = stub.sayHello(
                HelloRequest.newBuilder().setName(name).build());
            System.out.println("SayHello      : " + reply.getMessage());

            System.out.println("SayHelloStream:");
            Iterator<HelloReply> stream = stub.sayHelloStream(
                HelloRequest.newBuilder().setName(name).build());
            while (stream.hasNext()) {
                System.out.println("  " + stream.next().getMessage());
            }
        } finally {
            channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
        }
    }
}
