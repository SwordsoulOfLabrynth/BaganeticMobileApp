#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import sys
import threading
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 4173

class NoCacheHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Serve the Baganetic admin over HTTP so Firebase sync works."
    )
    parser.add_argument("--host", default=DEFAULT_HOST, help="Host to bind to.")
    parser.add_argument(
        "--port", type=int, default=DEFAULT_PORT, help="Port to bind to."
    )
    parser.add_argument(
        "--no-browser",
        action="store_true",
        help="Do not open the admin automatically in a browser.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    os.chdir(ROOT)

    def handler(*handler_args, **handler_kwargs):
        return NoCacheHandler(
            *handler_args,
            directory=str(ROOT),
            **handler_kwargs,
        )

    server = ThreadingHTTPServer((args.host, args.port), handler)
    url = f"http://{args.host}:{args.port}/admin/index.html"

    print(f"Serving Baganetic admin from {ROOT}")
    print(f"Open: {url}")
    print("Press Ctrl+C to stop.")

    if not args.no_browser:
      threading.Timer(0.6, lambda: webbrowser.open(url)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping admin server...")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
