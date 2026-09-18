#!/usr/bin/env python3
"""Rebuild the macOS icon assets from the checked-in master artwork.

Requires Pillow. Run from any directory. iOS assets are intentionally separate.
"""
from pathlib import Path
import io
import struct
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024

def create_icon():
    # Keep the approved artwork as the source; only resize for packaging.
    with Image.open(ROOT / "Resources/IconSource/macOS-master.png") as source:
        if source.width != source.height:
            raise ValueError("The macOS icon master must be square")
        return source.convert("RGBA").resize((SIZE, SIZE), Image.Resampling.LANCZOS)

def main():
    image = create_icon()
    asset = ROOT / "Resources/Assets.xcassets/AppIcon.appiconset"
    iconset = ROOT / "dist/AppIcon.iconset"
    iconset.mkdir(parents=True, exist_ok=True)
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            suffix = "@2x" if scale == 2 else ""
            resized = image.resize((size*scale, size*scale), Image.Resampling.LANCZOS)
            resized.save(asset / f"mac-{size}{suffix}.png")
            resized.save(iconset / f"icon_{size}x{size}{suffix}.png")
    # Preserve the legacy generator's additional 64-point variants too.
    for scale in (1, 2):
        suffix = "@2x" if scale == 2 else ""
        image.resize((64*scale, 64*scale), Image.Resampling.LANCZOS).save(iconset / f"icon_64x64{suffix}.png")
    # Modern ICNS entries carry PNG payloads; writing these directly also works
    # in build sandboxes where iconutil cannot access image conversion services.
    entries = []
    for kind, size in ((b"icp4", 16), (b"icp5", 32), (b"icp6", 64),
                       (b"ic07", 128), (b"ic08", 256), (b"ic09", 512), (b"ic10", 1024)):
        buffer = io.BytesIO()
        image.resize((size, size), Image.Resampling.LANCZOS).save(buffer, format="PNG")
        payload = buffer.getvalue()
        entries.append(kind + struct.pack(">I", len(payload) + 8) + payload)
    payload = b"".join(entries)
    (ROOT / "dist/AppIcon.icns").write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)
    print("Updated all macOS icon sizes and dist/AppIcon.icns")

if __name__ == "__main__":
    main()
