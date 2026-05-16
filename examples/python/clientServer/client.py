import sys

import requests


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "world"
    reply = requests.post("http://127.0.0.1:50051", data=name.encode())
    reply.raise_for_status()
    print("Greeter received:", reply.text)


if __name__ == "__main__":
    main()
