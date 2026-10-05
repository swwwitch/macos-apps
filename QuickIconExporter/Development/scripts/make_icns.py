#!/usr/bin/env python3
"""Build a modern PNG-backed ICNS container without Xcode tooling."""

from pathlib import Path
import struct
import sys


ENTRIES = (
    (b"icp4", "icon_16x16.png"),
    (b"icp5", "icon_32x32.png"),
    (b"icp6", "icon_32x32@2x.png"),
    (b"ic07", "icon_128x128.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic10", "icon_512x512@2x.png"),
)


def main() -> None:
    source = Path(sys.argv[1])
    destination = Path(sys.argv[2])
    chunks: list[bytes] = []

    for icon_type, filename in ENTRIES:
        png = (source / filename).read_bytes()
        if not png.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError(f"Not a PNG: {filename}")
        chunks.append(icon_type + struct.pack(">I", len(png) + 8) + png)

    payload = b"".join(chunks)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)


if __name__ == "__main__":
    main()
