package main

import (
	"log"

	clientserver "cross_platform/examples/go/clientServer"
)

func main() {
	if err := clientserver.RunServer(":50051"); err != nil {
		log.Fatal(err)
	}
}
