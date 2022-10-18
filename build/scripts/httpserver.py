#!/usr/bin/env python3
#!python3

# -*- coding: utf-8 -*-
# https://gist.github.com/HaiyangXu/ec88cbdce3cdbac7b8d5
# test on python 3.4 ,python of lower version  has different module organization.

from http.server import HTTPServer, BaseHTTPRequestHandler
import http.server
import socketserver

port = 8000

Handler = http.server.SimpleHTTPRequestHandler

Handler.extensions_map={
    '.manifest': 'text/cache-manifest',
    '.html': 'text/html',
    '.png': 'image/png',
    '.jpg': 'image/jpg',
    '.svg':	'image/svg+xml',
    '.css':	'text/css',
    '.js':	'application/x-javascript',
    '.iso': 'application/octet-stream',
    '': 'application/octet-stream', #default
    }

with socketserver.TCPServer(("", port), Handler) as httpd:
    print(f"Serving HTTP at port: {port}")
    httpd.serve_forever()
