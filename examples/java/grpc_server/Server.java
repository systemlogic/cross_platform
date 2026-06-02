package com.example.greeter;

import io.grpc.netty.shaded.io.grpc.netty.NettyServerBuilder;



public class Server {
    public static void main(String[] args) throws Exception {
        int port = 50051;
        if (args.length > 0) {
            port = Integer.parseInt(args[0]);
        }

        io.grpc.Server server = NettyServerBuilder.forPort(port)
            .addService(new GreeterServiceImpl())
            .build()
            .start();
        System.out.println("Server listening on port " + port);
        server.awaitTermination();
    }
}
