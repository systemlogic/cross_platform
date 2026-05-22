"""Tests for GreeterServicer: unit tests and a live-server integration test."""
import unittest
from concurrent import futures
from unittest.mock import MagicMock

import grpc
import greeter_pb2
import greeter_pb2_grpc

from server_lib import GreeterServicer


class TestSayHello(unittest.TestCase):
    def setUp(self):
        self.servicer = GreeterServicer()
        self.ctx = MagicMock()

    def test_basic(self):
        reply = self.servicer.SayHello(greeter_pb2.HelloRequest(name="World"), self.ctx)
        self.assertEqual(reply.message, "Hello, World!")

    def test_empty_name(self):
        reply = self.servicer.SayHello(greeter_pb2.HelloRequest(name=""), self.ctx)
        self.assertEqual(reply.message, "Hello, !")

    def test_whitespace_name(self):
        reply = self.servicer.SayHello(greeter_pb2.HelloRequest(name="  "), self.ctx)
        self.assertEqual(reply.message, "Hello,   !")


class TestSayHelloStream(unittest.TestCase):
    def setUp(self):
        self.servicer = GreeterServicer()
        self.ctx = MagicMock()

    def test_stream_count(self):
        replies = list(self.servicer.SayHelloStream(greeter_pb2.HelloRequest(name="Bazel"), self.ctx))
        self.assertEqual(len(replies), 5)

    def test_stream_messages(self):
        name = "Bazel"
        replies = list(self.servicer.SayHelloStream(greeter_pb2.HelloRequest(name=name), self.ctx))
        for i, reply in enumerate(replies):
            self.assertEqual(reply.message, f"Hello #{i + 1}, {name}!")

    def test_stream_empty_name(self):
        replies = list(self.servicer.SayHelloStream(greeter_pb2.HelloRequest(name=""), self.ctx))
        self.assertEqual(len(replies), 5)
        self.assertEqual(replies[0].message, "Hello #1, !")


class TestGreeterIntegration(unittest.TestCase):
    def setUp(self):
        self.server = grpc.server(futures.ThreadPoolExecutor(max_workers=2))
        greeter_pb2_grpc.add_GreeterServicer_to_server(GreeterServicer(), self.server)
        port = self.server.add_insecure_port("[::]:0")
        self.server.start()
        self.channel = grpc.insecure_channel(f"localhost:{port}")
        self.stub = greeter_pb2_grpc.GreeterStub(self.channel)

    def tearDown(self):
        self.channel.close()
        self.server.stop(grace=None)

    def test_say_hello(self):
        reply = self.stub.SayHello(greeter_pb2.HelloRequest(name="World"))
        self.assertEqual(reply.message, "Hello, World!")

    def test_say_hello_stream(self):
        replies = list(self.stub.SayHelloStream(greeter_pb2.HelloRequest(name="World")))
        self.assertEqual(len(replies), 5)
        for i, reply in enumerate(replies):
            self.assertEqual(reply.message, f"Hello #{i + 1}, World!")


if __name__ == "__main__":
    unittest.main()
