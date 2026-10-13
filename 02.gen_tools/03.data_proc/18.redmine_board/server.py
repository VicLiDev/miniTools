#!/usr/bin/env python3
"""
RK Issue Board - Local proxy server
Usage: python3 server.py
Open http://localhost:8100 in browser.
"""

import argparse
import json
import os
import traceback

from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

REDMINE_URL = "https://redmine.rock-chips.com"
DEFAULT_PORT = 8100
BROWSER_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"


class KanbanHandler(SimpleHTTPRequestHandler):

    def do_GET(self):
        if self.path.startswith("/api/"):
            self.proxy_request()
        else:
            if self.path == "/":
                self.path = "/index.html"
            super().do_GET()

    def do_OPTIONS(self):
        if self.path.startswith("/api/"):
            self.send_response(204)
            self._cors_headers()
            self.end_headers()

    def proxy_request(self):
        api_key = self.headers.get("X-API-Key", "")
        if not api_key:
            self._send_json({"error": "Missing API key"}, 401)
            return

        rest_path = self.path[4:]
        target_url = f"{REDMINE_URL}{rest_path}"

        try:
            req = Request(target_url, headers={
                "X-Redmine-API-Key": api_key,
                "Content-Type": "application/json",
                "User-Agent": BROWSER_UA,
            })
            resp = urlopen(req, timeout=30)
            data = resp.read()
            self.send_response(200)
            self._cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(data)
        except HTTPError as e:
            try:
                body = e.read()
            except Exception:
                body = b""
            self.send_response(e.code)
            self._cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body)
        except Exception as e:
            traceback.print_exc()
            self._send_json({"error": str(e)}, 502)

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "X-API-Key, Content-Type")

    def _send_json(self, obj, code):
        self.send_response(code)
        self._cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(obj).encode())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="RK Issue Board proxy server")
    parser.add_argument("-p", "--port", type=int, default=DEFAULT_PORT, help=f"Port to listen on (default: {DEFAULT_PORT})")
    args = parser.parse_args()
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    server = HTTPServer(("0.0.0.0", args.port), KanbanHandler)
    print(f"RK Issue Board server running at http://localhost:{args.port}")
    print("Press Ctrl+C to stop")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        server.server_close()
