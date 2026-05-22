"""GreeterServicer implementation — importable for testing."""
import time

import greeter_pb2
import greeter_pb2_grpc


class GreeterServicer(greeter_pb2_grpc.GreeterServicer):
    def SayHello(self, request, context):
        return greeter_pb2.HelloReply(message=f"Hello, {request.name}!")

    def SayHelloStream(self, request, context):
        for i in range(5):
            yield greeter_pb2.HelloReply(message=f"Hello #{i + 1}, {request.name}!")
            time.sleep(0.1)
