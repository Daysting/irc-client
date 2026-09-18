#!/usr/bin/env python3
"""Rebuild the macOS icon assets from a resolution-independent geometric design.

Requires Pillow. Run from any directory. iOS assets are intentionally separate.
"""
from pathlib import Path
import io
import struct
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024

def create_icon():
    # A softly lit indigo tile, a white conversation bubble, and an IRC channel mark.
    mask = Image.new("L", (SIZE, SIZE))
    ImageDraw.Draw(mask).rounded_rectangle((72, 64, 952, 944), radius=196, fill=255)
    tile = Image.new("RGBA", (SIZE, SIZE))
    pixels = tile.load()
    for y in range(SIZE):
        for x in range(SIZE):
            t = min(1, max(0, (x * .35 + y * .65) / SIZE))
            glow = max(0, 1 - ((x - 265)**2 + (y - 160)**2)**.5 / 700)
            pixels[x, y] = (int(33 + 43*t + 17*glow), int(111 - 61*t + 43*glow), int(206 + 13*t + 29*glow), 255)
    tile.putalpha(mask)
    shadow = Image.new("RGBA", (SIZE, SIZE))
    shadow.paste((15, 20, 55, 70), (0, 14, SIZE, SIZE+14), mask)
    image = shadow.filter(ImageFilter.GaussianBlur(18))
    image.alpha_composite(tile)
    bubble = Image.new("RGBA", (SIZE, SIZE))
    draw = ImageDraw.Draw(bubble)
    draw.rounded_rectangle((235, 245, 789, 680), radius=120, fill=(248, 253, 255, 255))
    draw.polygon([(320, 635), (320, 775), (471, 657)], fill=(248, 253, 255, 255))
    # Strong rounded strokes remain recognizable at 16 px.
    ink = (61, 97, 207, 255)
    def stroke(points, width=43):
        draw.line(points, fill=ink, width=width)
        for x, y in (points[0], points[-1]):
            r = width / 2
            draw.ellipse((x-r, y-r, x+r, y+r), fill=ink)
    stroke([(459, 355), (421, 567)])
    stroke([(590, 355), (552, 567)])
    stroke([(383, 418), (634, 418)])
    stroke([(370, 508), (621, 508)])
    image.alpha_composite(bubble)
    return image

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
