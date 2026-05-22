"""gRPC Greeter client — calls SayHello (unary) and SayHelloStream (server streaming)."""
import sys

import grpc
import greeter_pb2
import greeter_pb2_grpc

_DEFAULT_HOST = "192.168.1.10"
_DEFAULT_PORT = 50051


def run(name: str = "world", host: str = _DEFAULT_HOST, port: int = _DEFAULT_PORT) -> None:
    with grpc.insecure_channel(f"{host}:{port}") as channel:
        stub = greeter_pb2_grpc.GreeterStub(channel)

        reply = stub.SayHello(greeter_pb2.HelloRequest(name=name))
        print("SayHello      :", reply.message)

        print("SayHelloStream:")
        for reply in stub.SayHelloStream(greeter_pb2.HelloRequest(name=name)):
            print("  ", reply.message)


if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "world"
    host = sys.argv[2] if len(sys.argv) > 2 else _DEFAULT_HOST
    port = int(sys.argv[3]) if len(sys.argv) > 3 else _DEFAULT_PORT
    run(name, host, port)
