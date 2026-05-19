import threading
import unittest
from http.server import HTTPServer

import requests

import server_lib


class TestMakeReply(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(server_lib.make_reply("World"), "Hello World")
        self.assertEqual(server_lib.make_reply("Bazel"), "Hello Bazel")
        self.assertEqual(server_lib.make_reply(""), "Hello ")


class TestGreeterHandler(unittest.TestCase):
    def setUp(self):
        self.server = HTTPServer(("127.0.0.1", 0), server_lib.GreeterHandler)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.daemon = True
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()

    def test_post_reply(self):
        reply = requests.post(f"http://127.0.0.1:{self.port}", data=b"World")
        self.assertEqual(reply.status_code, 200)
        self.assertEqual(reply.text, "Hello World")

    def test_post_empty(self):
        reply = requests.post(f"http://127.0.0.1:{self.port}", data=b"")
        self.assertEqual(reply.status_code, 200)
        self.assertEqual(reply.text, "Hello ")


if __name__ == "__main__":
    unittest.main()
