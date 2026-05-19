from http.server import BaseHTTPRequestHandler, HTTPServer


def make_reply(name: str) -> str:
    return "Hello " + name


class GreeterHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        name = self.rfile.read(length).decode()
        reply = make_reply(name)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(reply.encode())

    def log_message(self, *args):
        pass


def run_server(host: str = "0.0.0.0", port: int = 50051) -> None:
    server = HTTPServer((host, port), GreeterHandler)
    print(f"Server listening on {host}:{port}")
    server.serve_forever()
