"""gRPC Greeter server — implements SayHello (unary) and SayHelloStream (server streaming)."""
import sys
from concurrent import futures

import grpc
import greeter_pb2_grpc

from server_lib import GreeterServicer

_DEFAULT_PORT = 50051


def serve(port: int = _DEFAULT_PORT) -> None:
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    greeter_pb2_grpc.add_GreeterServicer_to_server(GreeterServicer(), server)
    address = f"[::]:{port}"
    server.add_insecure_port(address)
    server.start()
    print(f"Server listening on port {port}")
    server.wait_for_termination()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else _DEFAULT_PORT
    serve(port)
