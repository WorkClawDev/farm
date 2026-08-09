#!/usr/bin/env python3
"""Convert a generated sprite concept sheet into a game-ready horizontal sprite sheet."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a transparent sprite sheet from a white-background concept image."
    )
    parser.add_argument("--input", required=True, help="Source image path.")
    parser.add_argument("--output", required=True, help="Destination PNG path.")
    parser.add_argument("--frame-size", type=int, default=32, help="Square output frame size.")
    parser.add_argument(
        "--expected-frames",
        type=int,
        default=8,
        help="Expected number of horizontal frame groups.",
    )
    parser.add_argument(
        "--white-threshold",
        type=int,
        default=245,
        help="RGB threshold for removable white background.",
    )
    parser.add_argument(
        "--column-threshold",
        type=int,
        default=4,
        help="Minimum non-white pixels needed for a column to count as foreground.",
    )
    parser.add_argument(
        "--padding",
        type=int,
        default=2,
        help="Transparent padding added around the cropped sprite before scaling.",
    )
    return parser.parse_args()


def is_near_white(pixel: tuple[int, int, int, int], threshold: int) -> bool:
    r, g, b, a = pixel
    return a > 0 and r >= threshold and g >= threshold and b >= threshold


def remove_edge_white_to_alpha(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    visited = set()
    queue: list[tuple[int, int]] = []

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.pop()
        if (x, y) in visited or x < 0 or y < 0 or x >= width or y >= height:
            continue
        visited.add((x, y))
        px = pixels[x, y]
        if not is_near_white(px, threshold):
            continue
        pixels[x, y] = (px[0], px[1], px[2], 0)
        queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))

    return rgba


def find_frame_ranges(image: Image.Image, threshold: int, column_threshold: int) -> list[tuple[int, int]]:
    width, height = image.size
    pixels = image.load()
    runs: list[tuple[int, int]] = []
    in_run = False
    start = 0

    for x in range(width):
        count = 0
        for y in range(height):
            if not is_near_white(pixels[x, y], threshold) and pixels[x, y][3] > 0:
                count += 1
        active = count >= column_threshold
        if active and not in_run:
            in_run = True
            start = x
        elif not active and in_run:
            runs.append((start, x - 1))
            in_run = False

    if in_run:
        runs.append((start, width - 1))

    return runs


def crop_frame(image: Image.Image, x0: int, x1: int, padding: int) -> Image.Image:
    width, height = image.size
    box = image.crop((x0, 0, x1 + 1, height))
    bbox = box.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Frame crop contains no visible pixels.")
    left, top, right, bottom = bbox
    sprite = box.crop((left, top, right, bottom))
    out = Image.new("RGBA", (sprite.width + padding * 2, sprite.height + padding * 2), (0, 0, 0, 0))
    out.alpha_composite(sprite, (padding, padding))
    return out


def fit_to_square(image: Image.Image, frame_size: int) -> Image.Image:
    width, height = image.size
    scale = min(frame_size / max(width, 1), frame_size / max(height, 1))
    resized = image.resize(
        (max(1, int(round(width * scale))), max(1, int(round(height * scale)))),
        Image.Resampling.NEAREST,
    )
    canvas = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
    x = (frame_size - resized.width) // 2
    y = frame_size - resized.height
    canvas.alpha_composite(resized, (x, y))
    return canvas


def main() -> int:
    args = parse_args()
    src = Image.open(args.input).convert("RGBA")
    cleaned = remove_edge_white_to_alpha(src, args.white_threshold)
    frame_ranges = find_frame_ranges(cleaned, args.white_threshold, args.column_threshold)

    if len(frame_ranges) != args.expected_frames:
        raise SystemExit(
            f"Expected {args.expected_frames} frame groups, found {len(frame_ranges)} in {args.input}: {frame_ranges}"
        )

    frames = [
        fit_to_square(crop_frame(cleaned, start, end, args.padding), args.frame_size)
        for start, end in frame_ranges
    ]

    sheet = Image.new("RGBA", (args.frame_size * len(frames), args.frame_size), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * args.frame_size, 0))

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
