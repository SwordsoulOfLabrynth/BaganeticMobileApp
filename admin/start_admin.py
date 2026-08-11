#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import threading
import time
import webbrowser
from email.parser import BytesParser
from email.policy import default
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 4173
UPLOAD_ENDPOINT = "/admin/upload-pagoda-images"
PAGODA_ASSETS_DIR = ROOT / "assets" / "images" / "pagodas"
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_UPLOAD_BYTES = 12 * 1024 * 1024
MAX_IMAGE_BYTES = 8 * 1024 * 1024


def sanitize_path_segment(value: str, fallback: str) -> str:
    cleaned = re.sub(r'[<>:"/\\|?*\x00-\x1f]+', "-", value or "").strip()
    cleaned = re.sub(r"\s+", " ", cleaned).strip(" .")
    return cleaned or fallback


def sanitize_file_stem(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._ -]+", "-", value or "").strip(" .-_")
    cleaned = re.sub(r"\s+", "-", cleaned)
    return cleaned.lower() or "image"


def has_expected_image_signature(extension: str, payload: bytes) -> bool:
    if extension in {".jpg", ".jpeg"}:
        return payload.startswith(b"\xff\xd8\xff")
    if extension == ".png":
        return payload.startswith(b"\x89PNG\r\n\x1a\n")
    if extension == ".webp":
        return payload.startswith(b"RIFF") and payload[8:12] == b"WEBP"
    return False


def parse_multipart_form_data(content_type: str, body: bytes) -> tuple[dict[str, str], list[dict[str, object]]]:
    message = BytesParser(policy=default).parsebytes(
        f"Content-Type: {content_type}\r\nMIME-Version: 1.0\r\n\r\n".encode("utf-8") + body
    )

    if not message.is_multipart():
        raise ValueError("Expected multipart form data.")

    fields: dict[str, str] = {}
    files: list[dict[str, object]] = []

    for part in message.iter_parts():
        if part.get_content_disposition() != "form-data":
            continue

        field_name = part.get_param("name", header="content-disposition") or ""
        file_name = part.get_filename()
        payload = part.get_payload(decode=True) or b""

        if file_name:
            files.append(
                {
                    "field_name": field_name,
                    "filename": file_name,
                    "data": payload,
                }
            )
            continue

        charset = part.get_content_charset() or "utf-8"
        fields[field_name] = payload.decode(charset).strip()

    return fields, files

class NoCacheHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def send_json(self, status_code: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == UPLOAD_ENDPOINT:
            self.handle_pagoda_upload()
            return
        self.send_error(404, "Not Found")

    def handle_pagoda_upload(self) -> None:
        content_type = self.headers.get("Content-Type", "")
        if "multipart/form-data" not in content_type:
            self.send_json(400, {"error": "Expected multipart form data."})
            return

        content_length = int(self.headers.get("Content-Length", "0") or "0")
        if content_length <= 0:
            self.send_json(400, {"error": "No upload data was provided."})
            return
        if content_length > MAX_UPLOAD_BYTES:
            self.send_json(413, {"error": "Uploads are limited to 12 MB in total."})
            return
        body = self.rfile.read(content_length)

        try:
            fields, raw_files = parse_multipart_form_data(content_type, body)
        except Exception as error:
            self.send_json(400, {"error": str(error)})
            return

        folder_name = sanitize_path_segment(fields.get("pagodaFolder", ""), "New Pagoda")
        role = sanitize_path_segment(fields.get("role", "gallery"), "gallery").lower()
        if role not in {"primary", "gallery"}:
            role = "gallery"

        if not raw_files:
            self.send_json(400, {"error": "No files were provided."})
            return

        try:
            PAGODA_ASSETS_DIR.mkdir(parents=True, exist_ok=True)
            target_dir = PAGODA_ASSETS_DIR / folder_name
            target_dir.mkdir(parents=True, exist_ok=True)

            timestamp = int(time.time() * 1000)
            saved_files = []

            for index, item in enumerate(raw_files):
                original_name = Path(str(item.get("filename", ""))).name
                if not original_name:
                    continue

                extension = Path(original_name).suffix.lower()
                if extension not in ALLOWED_IMAGE_EXTENSIONS:
                    raise ValueError(
                        f"Unsupported file type for {original_name}. Use JPG, JPEG, PNG, or WEBP."
                    )

                file_data = bytes(item.get("data", b""))
                if not file_data:
                    raise ValueError(f"{original_name} is empty.")
                if len(file_data) > MAX_IMAGE_BYTES:
                    raise ValueError(f"{original_name} is larger than the 8 MB per-image limit.")
                if not has_expected_image_signature(extension, file_data):
                    raise ValueError(f"{original_name} does not match its declared image format.")

                safe_stem = sanitize_file_stem(Path(original_name).stem)
                file_name = f"{role}-{timestamp}-{index}-{safe_stem}{extension}"
                destination = target_dir / file_name
                destination.write_bytes(file_data)

                saved_files.append(
                    {
                        "url": f"assets/images/pagodas/{folder_name}/{file_name}",
                        "name": original_name,
                    }
                )

            if not saved_files:
                self.send_json(400, {"error": "No valid files were uploaded."})
                return

            self.send_json(200, {"folder": folder_name, "files": saved_files})
        except Exception as error:
            self.send_json(500, {"error": str(error)})


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
