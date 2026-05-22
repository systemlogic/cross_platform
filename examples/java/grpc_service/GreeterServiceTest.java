package com.example.greeter;

import io.grpc.ManagedChannel;
import io.grpc.Server;
import io.grpc.netty.shaded.io.grpc.netty.NettyChannelBuilder;
import io.grpc.netty.shaded.io.grpc.netty.NettyServerBuilder;
import io.grpc.stub.StreamObserver;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.TimeUnit;

public class GreeterServiceTest {

    static void check(boolean cond, String msg) {
        if (!cond) {
            System.err.println("FAIL: " + msg);
            System.exit(1);
        }
    }

    // Collects onNext values for synchronous unit-testing of the service impl.
    static class Collector<T> implements StreamObserver<T> {
        final List<T> values = new ArrayList<>();
        boolean completed = false;

        @Override public void onNext(T v) { values.add(v); }
        @Override public void onError(Throwable t) { throw new RuntimeException(t); }
        @Override public void onCompleted() { completed = true; }
    }

    static void testSayHello() {
        GreeterServiceImpl impl = new GreeterServiceImpl();
        Collector<HelloReply> col = new Collector<>();
        impl.sayHello(HelloRequest.newBuilder().setName("World").build(), col);
        check(col.completed, "sayHello: completed");
        check(col.values.size() == 1, "sayHello: one reply");
        check("Hello, World!".equals(col.values.get(0).getMessage()),
              "sayHello: message=" + col.values.get(0).getMessage());
    }

    static void testSayHelloEmpty() {
        GreeterServiceImpl impl = new GreeterServiceImpl();
        Collector<HelloReply> col = new Collector<>();
        impl.sayHello(HelloRequest.newBuilder().setName("").build(), col);
        check("Hello, !".equals(col.values.get(0).getMessage()),
              "sayHelloEmpty: message=" + col.values.get(0).getMessage());
    }

    static void testSayHelloStream() {
        GreeterServiceImpl impl = new GreeterServiceImpl();
        Collector<HelloReply> col = new Collector<>();
        impl.sayHelloStream(HelloRequest.newBuilder().setName("Bazel").build(), col);
        check(col.completed, "stream: completed");
        check(col.values.size() == 5, "stream: count=" + col.values.size());
        check("Hello #1, Bazel!".equals(col.values.get(0).getMessage()),
              "stream[0]: " + col.values.get(0).getMessage());
        check("Hello #5, Bazel!".equals(col.values.get(4).getMessage()),
              "stream[4]: " + col.values.get(4).getMessage());
    }

    static void testIntegration() throws Exception {
        Server server = NettyServerBuilder.forPort(0)
            .addService(new GreeterServiceImpl())
            .build()
            .start();
        int port = server.getPort();

        ManagedChannel channel = NettyChannelBuilder
            .forAddress("127.0.0.1", port)
            .usePlaintext()
            .build();
        try {
            GreeterGrpc.GreeterBlockingStub stub = GreeterGrpc.newBlockingStub(channel);

            HelloReply reply = stub.sayHello(
                HelloRequest.newBuilder().setName("Bazel").build());
            check("Hello, Bazel!".equals(reply.getMessage()),
                  "integration sayHello: " + reply.getMessage());

            Iterator<HelloReply> stream = stub.sayHelloStream(
                HelloRequest.newBuilder().setName("Bazel").build());
            int count = 0;
            while (stream.hasNext()) {
                stream.next();
                count++;
            }
            check(count == 5, "integration stream count=" + count);
        } finally {
            channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
            server.shutdown().awaitTermination(5, TimeUnit.SECONDS);
        }
    }

    public static void main(String[] args) throws Exception {
        testSayHello();
        testSayHelloEmpty();
        testSayHelloStream();
        testIntegration();
        System.out.println("All tests passed.");
    }
}
