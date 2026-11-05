#!/usr/bin/env python3
"""Strip the baked-in light background from crop stage sprites.

Several AI-generated crop stage PNGs (turnip/potato/corn/tomato) are 1024x1024
RGBA but fully opaque with a white/cream background, so in-game they render as
an opaque square. This flood-fills the border-connected background to alpha 0,
feathers the edge slightly, crops to content, pads to a square and downsizes to
SIZE px so FarmPlot can scale it to the plot.

Usage: python3 tools/make_crop_sprites_transparent.py assets/sprites/crops/turnip_stage*.png
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SIZE = 128
THRESH = 38
MARK = (1, 254, 3)


def process(path: str) -> None:
    src = Image.open(path).convert("RGBA")
    w, h = src.size
    rgb = src.convert("RGB")
    work = rgb.copy()
    seeds = []
    step = max(8, w // 64)
    for x in range(0, w, step):
        seeds += [(x, 0), (x, h - 1)]
    for y in range(0, h, step):
        seeds += [(0, y), (w - 1, y)]
    for s in seeds:
        px = work.getpixel(s)
        if px == MARK:
            continue
        if min(px) < 200:  # border pixel is not light background; leave it
            continue
        ImageDraw.floodfill(work, s, MARK, thresh=THRESH)
    r, g, b = work.split()
    bg = ImageChops.multiply(
        ImageChops.multiply(r.point(lambda v: 255 if v == MARK[0] else 0),
                            g.point(lambda v: 255 if v == MARK[1] else 0)),
        b.point(lambda v: 255 if v == MARK[2] else 0))
    alpha = ImageChops.invert(bg)
    # shrink 1px and feather so the light fringe does not halo on dark soil
    alpha = alpha.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1.5))
    out = src.copy()
    out.putalpha(ImageChops.multiply(alpha, src.getchannel("A")))
    bbox = out.getchannel("A").point(lambda v: 255 if v > 16 else 0).getbbox()
    if bbox:
        out = out.crop(bbox)
    side = max(out.size)
    pad = int(side * 0.04)
    canvas = Image.new("RGBA", (side + 2 * pad, side + 2 * pad), (0, 0, 0, 0))
    # bottom-align so the plant stands on the soil
    canvas.paste(out, ((canvas.width - out.width) // 2, canvas.height - pad - out.height))
    canvas = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    canvas.save(path, optimize=True)
    a = canvas.getchannel("A")
    transparent = sum(1 for v in a.getdata() if v == 0) / (SIZE * SIZE)
    print(f"{path}: {w}x{h} -> {SIZE}x{SIZE}, transparent {transparent:.0%}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        process(p)
