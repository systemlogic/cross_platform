import sys
from grpc_tools import protoc
sys.exit(protoc.main(sys.argv[1:]))
