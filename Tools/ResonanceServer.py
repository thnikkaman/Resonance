#!/usr/bin/env python3
"""Small Tailscale-friendly Resonance test server.

Install metadata support:
    python3 -m pip install mutagen

Run:
    python3 Tools/ResonanceServer.py /path/to/Music --port 8080

The server publishes:
    /resonance/library.json
    /media/<relative path>
    /resonance/artwork/<key>

It intentionally has no login layer. Bind it only to a trusted LAN or Tailscale
interface while testing.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import mimetypes
import os
import re
import sys
import time
import urllib.parse
import uuid
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

try:
    import mutagen  # type: ignore
except ImportError:
    mutagen = None

SUPPORTED = {".flac", ".mp3", ".m4a", ".mp4", ".aac", ".wav", ".aiff", ".aif", ".caf"}
MIME_OVERRIDES = {".flac": "audio/flac", ".m4a": "audio/mp4", ".aac": "audio/aac", ".aiff": "audio/aiff", ".aif": "audio/aiff", ".caf": "audio/x-caf"}
ARTWORK: dict[str, tuple[bytes, str]] = {}
MANIFEST_CACHE: tuple[float, dict[str, Any]] | None = None


def first(tags: Any, *keys: str, default: str = "") -> str:
    if tags is None:
        return default
    for key in keys:
        value = tags.get(key)
        if isinstance(value, (list, tuple)) and value:
            value = value[0]
        if value is not None:
            text = str(value).strip()
            if text:
                return text
    return default


def integer_prefix(value: str, default: int = 0) -> int:
    match = re.match(r"\s*(\d+)", value or "")
    return int(match.group(1)) if match else default


def extract_artwork(raw: Any, path: Path) -> tuple[str | None, str | None]:
    data: bytes | None = None
    mime = "image/jpeg"
    try:
        pictures = getattr(raw, "pictures", None)
        if pictures:
            data = pictures[0].data
            mime = getattr(pictures[0], "mime", mime) or mime
        elif getattr(raw, "tags", None):
            for key, frame in raw.tags.items():
                if str(key).startswith("APIC"):
                    data = frame.data
                    mime = getattr(frame, "mime", mime) or mime
                    break
            if data is None:
                covers = raw.tags.get("covr")
                if covers:
                    data = bytes(covers[0])
                    imageformat = getattr(covers[0], "imageformat", None)
                    if imageformat == 14:
                        mime = "image/png"
    except Exception:
        data = None

    if not data:
        return None, None
    key = hashlib.sha256((str(path) + str(path.stat().st_mtime_ns)).encode()).hexdigest()[:24]
    ARTWORK[key] = (data, mime)
    return f"/resonance/artwork/{key}", None


def read_metadata(path: Path, root: Path) -> dict[str, Any]:
    relative = path.relative_to(root)
    artist_guess = relative.parts[-3] if len(relative.parts) >= 3 else "Unknown Artist"
    album_guess = relative.parts[-2] if len(relative.parts) >= 2 else "Unknown Album"
    title_guess = path.stem
    record: dict[str, Any] = {
        "id": str(uuid.uuid5(uuid.NAMESPACE_URL, relative.as_posix())),
        "title": title_guess,
        "artist": artist_guess,
        "albumArtist": artist_guess,
        "album": album_guess,
        "trackNumber": 0,
        "discNumber": 1,
        "releaseYear": 0,
        "duration": 0,
        "fileSize": path.stat().st_size,
        "path": "/media/" + urllib.parse.quote(relative.as_posix(), safe="/"),
    }

    if mutagen is None:
        return record

    try:
        easy = mutagen.File(path, easy=True)
        raw = mutagen.File(path, easy=False)
        tags = getattr(easy, "tags", None)
        record["title"] = first(tags, "title", default=title_guess)
        record["artist"] = first(tags, "artist", default=artist_guess)
        record["albumArtist"] = first(tags, "albumartist", "album artist", default=record["artist"])
        record["album"] = first(tags, "album", default=album_guess)
        record["trackNumber"] = integer_prefix(first(tags, "tracknumber"))
        record["discNumber"] = max(1, integer_prefix(first(tags, "discnumber"), 1))
        record["releaseYear"] = integer_prefix(first(tags, "date", "year"))
        info = getattr(raw, "info", None)
        if info is not None:
            record["duration"] = round(float(getattr(info, "length", 0) or 0), 3)
        artwork, artwork_base64 = extract_artwork(raw, path)
        if artwork:
            record["artwork"] = artwork
        if artwork_base64:
            record["artworkBase64"] = artwork_base64
    except Exception as exc:
        print(f"Metadata warning for {path}: {exc}", file=sys.stderr)
    return record


def build_manifest(root: Path, name: str) -> dict[str, Any]:
    global MANIFEST_CACHE
    now = time.time()
    if MANIFEST_CACHE and now - MANIFEST_CACHE[0] < 10:
        return MANIFEST_CACHE[1]

    ARTWORK.clear()
    tracks = [
        read_metadata(path, root)
        for path in sorted(root.rglob("*"))
        if path.is_file() and path.suffix.lower() in SUPPORTED
    ]
    manifest = {"version": 1, "name": name, "tracks": tracks}
    MANIFEST_CACHE = (now, manifest)
    return manifest


class Handler(BaseHTTPRequestHandler):
    server_version = "ResonanceServer/0.3.6"

    @property
    def root(self) -> Path:
        return self.server.music_root  # type: ignore[attr-defined]

    def do_HEAD(self) -> None:
        self.route(send_body=False)

    def do_GET(self) -> None:
        self.route(send_body=True)

    def route(self, send_body: bool) -> None:
        path = urllib.parse.urlparse(self.path).path
        if path == "/resonance/library.json":
            payload = json.dumps(
                build_manifest(self.root, self.server.library_name),  # type: ignore[attr-defined]
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8")
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            if send_body:
                self.wfile.write(payload)
            return

        if path.startswith("/resonance/artwork/"):
            key = path.rsplit("/", 1)[-1]
            entry = ARTWORK.get(key)
            if entry is None:
                build_manifest(self.root, self.server.library_name)  # type: ignore[attr-defined]
                entry = ARTWORK.get(key)
            if entry is None:
                self.send_error(HTTPStatus.NOT_FOUND)
                return
            data, mime = entry
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "public, max-age=3600")
            self.end_headers()
            if send_body:
                self.wfile.write(data)
            return

        if path.startswith("/media/"):
            relative = urllib.parse.unquote(path[len("/media/"):])
            candidate = (self.root / relative).resolve()
            try:
                candidate.relative_to(self.root.resolve())
            except ValueError:
                self.send_error(HTTPStatus.FORBIDDEN)
                return
            if not candidate.is_file():
                self.send_error(HTTPStatus.NOT_FOUND)
                return
            self.serve_file(candidate, send_body)
            return

        self.send_error(HTTPStatus.NOT_FOUND)

    def serve_file(self, path: Path, send_body: bool) -> None:
        size = path.stat().st_size
        start, end = 0, size - 1
        range_header = self.headers.get("Range")
        partial = False
        if range_header:
            match = re.fullmatch(r"bytes=(\d*)-(\d*)", range_header.strip())
            if match:
                left, right = match.group(1), match.group(2)
                if left:
                    start = int(left)
                    if right:
                        end = min(int(right), size - 1)
                elif right:
                    length = min(int(right), size)
                    start = max(0, size - length)
                    end = size - 1
                partial = 0 <= start <= end < size
        if range_header and not partial:
            self.send_response(HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
            self.send_header("Content-Range", f"bytes */{size}")
            self.end_headers()
            return

        length = end - start + 1
        self.send_response(HTTPStatus.PARTIAL_CONTENT if partial else HTTPStatus.OK)
        self.send_header("Content-Type", MIME_OVERRIDES.get(path.suffix.lower()) or mimetypes.guess_type(path.name)[0] or "application/octet-stream")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(length))
        if partial:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.end_headers()
        if not send_body:
            return
        with path.open("rb") as handle:
            handle.seek(start)
            remaining = length
            while remaining:
                chunk = handle.read(min(1024 * 256, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"[{self.log_date_time_string()}] {fmt % args}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve a private Resonance music library.")
    parser.add_argument("music_folder", type=Path)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--name", default="Home Music Library")
    args = parser.parse_args()
    root = args.music_folder.expanduser().resolve()
    if not root.is_dir():
        parser.error(f"Music folder does not exist: {root}")

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.music_root = root  # type: ignore[attr-defined]
    server.library_name = args.name  # type: ignore[attr-defined]
    print(f"Serving {root}")
    print(f"Manifest: http://{args.host}:{args.port}/resonance/library.json")
    if mutagen is None:
        print("mutagen is not installed; folder/file names will be used as metadata.", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
