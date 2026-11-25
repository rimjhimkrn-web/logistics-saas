#!/usr/bin/env python3
import http.server
import ssl
import sys

server = http.server.ThreadingHTTPServer(("0.0.0.0", 4173), http.server.SimpleHTTPRequestHandler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(sys.argv[1], sys.argv[2])
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
