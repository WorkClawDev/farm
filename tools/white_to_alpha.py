#!/usr/bin/env python3
"""Scan image assets for near-white backgrounds and convert them to transparency.

Default behavior is conservative:
- Only flood-fills near-white pixels connected to the image border.
- Leaves interior highlights alone.
- Rewrites PNGs in place.
- Writes JPG/JPEG fixes to sibling PNG files because JPEG cannot store alpha.

Typical usage:
    python3 tools/white_to_alpha.py --dry-run
    python3 tools/white_to_alpha.py --root assets/sprites/houses --report logs/white_to_alpha_houses.txt
    python3 tools/white_to_alpha.py --root assets/sprites/items --rewrite-references
"""

from __future__ import annotations

import argparse
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image


TEXT_FILE_SUFFIXES = {".gd", ".tscn", ".tres", ".res", ".json", ".godot", ".md"}
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg"}


@dataclass
class ImageResult:
    path: Path
    output_path: Path
    total_pixels: int
    converted_pixels: int
    ratio: float
    created_png_copy: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert near-white backgrounds in game assets to transparent alpha."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("assets/sprites"),
        help="Root directory to scan for images.",
    )
    parser.add_argument(
        "--path",
        action="append",
        type=Path,
        default=[],
        help="Specific image file to process. May be passed multiple times.",
    )
    parser.add_argument(
        "--threshold",
        type=int,
        default=245,
        help="Minimum RGB channel value to consider a pixel near-white.",
    )
    parser.add_argument(
        "--variation",
        type=int,
        default=12,
        help="Maximum per-pixel channel spread allowed for near-white detection.",
    )
    parser.add_argument(
        "--min-ratio",
        type=float,
        default=0.01,
        help="Minimum converted-pixel ratio before an image is considered a match.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Scan and report candidates without writing files.",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=None,
        help="Optional report file to write the scan result to.",
    )
    parser.add_argument(
        "--rewrite-references",
        action="store_true",
        help="When a JPG/JPEG is converted to PNG, rewrite text references in the repo.",
    )
    parser.add_argument(
        "--reference-root",
        type=Path,
        default=Path("."),
        help="Project root to scan when rewriting references.",
    )
    parser.add_argument(
        "--delete-original-jpegs",
        action="store_true",
        help="Delete original JPG/JPEG files after successful PNG conversion.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Optional cap on how many images to inspect from the root.",
    )
    return parser.parse_args()


def iter_image_files(root: Path) -> Iterable[Path]:
    for path in sorted(root.rglob("*")):
        if path.suffix.lower() in IMAGE_SUFFIXES and path.is_file():
            yield path


def resolve_input_images(root: Path, explicit_paths: list[Path]) -> list[Path]:
    if explicit_paths:
        resolved: list[Path] = []
        seen: set[str] = set()
        for candidate in explicit_paths:
            path = candidate if candidate.is_absolute() else candidate
            if not path.exists() or not path.is_file():
                raise SystemExit(f"Input image does not exist: {candidate}")
            if path.suffix.lower() not in IMAGE_SUFFIXES:
                raise SystemExit(f"Unsupported image suffix: {candidate}")
            key = path.as_posix()
            if key not in seen:
                seen.add(key)
                resolved.append(path)
        return resolved
    return list(iter_image_files(root))


def is_near_white(pixel: tuple[int, int, int], threshold: int, variation: int) -> bool:
    r, g, b = pixel
    if r < threshold or g < threshold or b < threshold:
        return False
    return max(pixel) - min(pixel) <= variation


def build_edge_mask(image: Image.Image, threshold: int, variation: int) -> list[bool]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixel_access = rgba.load()
    pixel_count = width * height
    mask = [False] * pixel_count
    visited = [False] * pixel_count
    queue: deque[tuple[int, int]] = deque()

    def index(x: int, y: int) -> int:
        return y * width + x

    def enqueue_if_candidate(x: int, y: int) -> None:
        idx = index(x, y)
        if visited[idx]:
            return
        visited[idx] = True
        r, g, b, a = pixel_access[x, y]
        if a == 0:
            return
        if is_near_white((r, g, b), threshold, variation):
            queue.append((x, y))
            mask[idx] = True

    for x in range(width):
        enqueue_if_candidate(x, 0)
        enqueue_if_candidate(x, height - 1)
    for y in range(height):
        enqueue_if_candidate(0, y)
        enqueue_if_candidate(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            idx = index(nx, ny)
            if visited[idx]:
                continue
            visited[idx] = True
            r, g, b, a = pixel_access[nx, ny]
            if a == 0:
                continue
            if is_near_white((r, g, b), threshold, variation):
                mask[idx] = True
                queue.append((nx, ny))

    return mask


def convert_image(
    path: Path, threshold: int, variation: int, min_ratio: float
) -> tuple[Image.Image | None, ImageResult | None]:
    image = Image.open(path).convert("RGBA")
    mask = build_edge_mask(image, threshold, variation)
    converted = sum(mask)
    total = image.size[0] * image.size[1]
    ratio = converted / total if total else 0.0

    if converted == 0 or ratio < min_ratio:
        return None, None

    width, height = image.size
    pixel_access = image.load()
    pixels = [pixel_access[x, y] for y in range(height) for x in range(width)]
    for idx, should_clear in enumerate(mask):
        if should_clear:
            r, g, b, _ = pixels[idx]
            pixels[idx] = (r, g, b, 0)

    image.putdata(pixels)
    output_path = path if path.suffix.lower() == ".png" else path.with_suffix(".png")
    return image, ImageResult(
        path=path,
        output_path=output_path,
        total_pixels=total,
        converted_pixels=converted,
        ratio=ratio,
        created_png_copy=output_path != path,
    )


def iter_text_files(root: Path) -> Iterable[Path]:
    for path in sorted(root.rglob("*")):
        if path.suffix.lower() in TEXT_FILE_SUFFIXES and path.is_file() and ".git/" not in path.as_posix():
            yield path


def rewrite_references(reference_root: Path, old_path: Path, new_path: Path) -> int:
    old_ref = old_path.as_posix()
    new_ref = new_path.as_posix()
    replacements = 0

    for path in iter_text_files(reference_root):
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if old_ref not in text:
            continue
        updated = text.replace(old_ref, new_ref)
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            replacements += 1

    return replacements


def write_report(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    args = parse_args()
    if not args.root.exists() and not args.path:
        raise SystemExit(f"Root path does not exist: {args.root}")

    scanned = 0
    matched = 0
    written = 0
    rewritten_refs = 0
    report_lines: list[str] = []

    image_inputs = resolve_input_images(args.root, args.path)

    for image_path in image_inputs:
        if args.limit > 0 and scanned >= args.limit:
            break
        scanned += 1

        converted_image, result = convert_image(
            image_path,
            threshold=args.threshold,
            variation=args.variation,
            min_ratio=args.min_ratio,
        )
        if result is None or converted_image is None:
            continue

        matched += 1
        line = (
            f"{result.path.as_posix()} -> {result.output_path.as_posix()} | "
            f"{result.converted_pixels}/{result.total_pixels} ({result.ratio:.2%})"
        )
        report_lines.append(line)

        if args.dry_run:
            continue

        converted_image.save(result.output_path)
        written += 1

        if result.created_png_copy and args.rewrite_references:
            rewritten_refs += rewrite_references(
                args.reference_root,
                result.path,
                result.output_path,
            )
            if args.delete_original_jpegs and result.path.exists():
                result.path.unlink()

    header = (
        f"Scanned {scanned} images, matched {matched}, wrote {written}, "
        f"updated references in {rewritten_refs} files"
    )
    output_lines = [header]
    if args.dry_run and matched:
        output_lines.append("Dry run only; no files were modified.")
    output_lines.extend(report_lines)
    print("\n".join(output_lines))

    if args.report:
        write_report(args.report, output_lines)


if __name__ == "__main__":
    main()
