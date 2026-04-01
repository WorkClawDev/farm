#!/usr/bin/env python3
"""
Scan project art for opaque white backgrounds and optionally convert them to transparent PNGs.

Typical usage:
  python3 tools/fix_white_backgrounds.py scan --roots assets/sprites/houses assets/sprites/items
  python3 tools/fix_white_backgrounds.py fix --paths assets/source_art/items/reference/crystal.jpg
  python3 tools/fix_white_backgrounds.py fix --report tools/reports/white_background_report.json --rewrite-refs
"""

from __future__ import annotations

import argparse
import json
import math
from collections import deque, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ROOTS = [
    "assets/sprites",
    "assets/tiles",
]
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp"}
TEXT_EXTS = {".gd", ".tscn", ".tres", ".res", ".json", ".godot", ".md", ".txt", ".cfg"}


@dataclass
class AssetStats:
    path: str
    width: int
    height: int
    suffix: str
    has_alpha: bool
    transparent_ratio: float
    white_ratio: float
    border_white_ratio: float
    border_opaque_ratio: float
    score: int
    reason: str


def relpath(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(PROJECT_ROOT.resolve()).as_posix()
    except ValueError:
        return resolved.as_posix()


def iter_image_paths(roots: Iterable[str]) -> Iterable[Path]:
    for root_str in roots:
        root = (PROJECT_ROOT / root_str).resolve()
        if not root.exists():
            continue
        if root.is_file() and root.suffix.lower() in IMAGE_EXTS:
            yield root
            continue
        for path in root.rglob("*"):
            if path.is_file() and path.suffix.lower() in IMAGE_EXTS:
                yield path


def is_whiteish(pixel: tuple[int, int, int, int], threshold: int) -> bool:
    r, g, b, a = pixel
    return a >= 250 and r >= threshold and g >= threshold and b >= threshold


def pixel_distance(pixel: tuple[int, int, int, int], bg_rgb: tuple[float, float, float]) -> float:
    r, g, b, _ = pixel
    return math.sqrt((r - bg_rgb[0]) ** 2 + (g - bg_rgb[1]) ** 2 + (b - bg_rgb[2]) ** 2)


def collect_stats(path: Path, white_threshold: int) -> AssetStats:
    img = Image.open(path).convert("RGBA")
    width, height = img.size
    pixels = img.load()
    total = width * height

    transparent = 0
    white = 0
    border = []
    for x in range(width):
        border.append(pixels[x, 0])
        border.append(pixels[x, height - 1])
    for y in range(1, height - 1):
        border.append(pixels[0, y])
        border.append(pixels[width - 1, y])

    border_opaque = 0
    border_white = 0
    for y in range(height):
        for x in range(width):
            px = pixels[x, y]
            if px[3] == 0:
                transparent += 1
            if is_whiteish(px, white_threshold):
                white += 1

    for px in border:
        if px[3] >= 250:
            border_opaque += 1
            if is_whiteish(px, white_threshold):
                border_white += 1

    transparent_ratio = transparent / total
    white_ratio = white / total
    border_opaque_ratio = border_opaque / len(border) if border else 0.0
    border_white_ratio = border_white / len(border) if border else 0.0

    score = 0
    reason_parts = []
    if path.suffix.lower() in {".jpg", ".jpeg"}:
        score += 1
        reason_parts.append("jpeg-no-alpha")
    if transparent_ratio == 0:
        score += 1
        reason_parts.append("opaque")
    if border_opaque_ratio > 0.95:
        score += 1
        reason_parts.append("opaque-border")
    if border_white_ratio > 0.70:
        score += 2
        reason_parts.append("mostly-white-border")
    elif border_white_ratio > 0.45:
        score += 1
        reason_parts.append("partly-white-border")
    if white_ratio > 0.50:
        score += 1
        reason_parts.append("large-white-area")

    reason = ",".join(reason_parts) if reason_parts else "not-suspicious"
    return AssetStats(
        path=relpath(path),
        width=width,
        height=height,
        suffix=path.suffix.lower(),
        has_alpha=transparent_ratio > 0.0,
        transparent_ratio=transparent_ratio,
        white_ratio=white_ratio,
        border_white_ratio=border_white_ratio,
        border_opaque_ratio=border_opaque_ratio,
        score=score,
        reason=reason,
    )


def scan_assets(roots: Iterable[str], white_threshold: int, min_score: int) -> list[AssetStats]:
    findings = []
    for path in sorted(iter_image_paths(roots)):
        stats = collect_stats(path, white_threshold)
        if stats.score >= min_score:
            findings.append(stats)
    return findings


def summarize_by_dir(findings: list[AssetStats]) -> dict[str, list[AssetStats]]:
    grouped: dict[str, list[AssetStats]] = defaultdict(list)
    for item in findings:
        grouped[str(Path(item.path).parent)].append(item)
    return dict(sorted(grouped.items()))


def print_findings(findings: list[AssetStats]) -> None:
    grouped = summarize_by_dir(findings)
    print(f"Suspicious assets: {len(findings)}")
    for directory, items in grouped.items():
        print(f"\n## {directory} ({len(items)})")
        for item in sorted(items, key=lambda row: (-row.score, row.path)):
            print(
                f"{item.score}\t{item.path}\t"
                f"size={item.width}x{item.height}\t"
                f"white={item.white_ratio:.3f}\t"
                f"border_white={item.border_white_ratio:.3f}\t"
                f"border_opaque={item.border_opaque_ratio:.3f}\t"
                f"transparent={item.transparent_ratio:.3f}\t"
                f"{item.reason}"
            )


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def estimate_background_color(img: Image.Image, white_threshold: int) -> tuple[float, float, float]:
    pixels = img.load()
    width, height = img.size
    border_pixels = []
    for x in range(width):
        border_pixels.append(pixels[x, 0])
        border_pixels.append(pixels[x, height - 1])
    for y in range(1, height - 1):
        border_pixels.append(pixels[0, y])
        border_pixels.append(pixels[width - 1, y])

    candidates = [px for px in border_pixels if is_whiteish(px, white_threshold)]
    if not candidates:
        return (255.0, 255.0, 255.0)

    total_r = sum(px[0] for px in candidates)
    total_g = sum(px[1] for px in candidates)
    total_b = sum(px[2] for px in candidates)
    count = len(candidates)
    return (total_r / count, total_g / count, total_b / count)


def remove_white_background(
    src_path: Path,
    dst_path: Path,
    white_threshold: int,
    tolerance: float,
    edge_tolerance: float,
) -> tuple[int, int]:
    img = Image.open(src_path).convert("RGBA")
    pixels = img.load()
    width, height = img.size
    bg_rgb = estimate_background_color(img, white_threshold)

    visited = [[False] * height for _ in range(width)]
    q: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        if 0 <= x < width and 0 <= y < height and not visited[x][y]:
            q.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    removed = 0
    while q:
        x, y = q.popleft()
        if visited[x][y]:
            continue
        visited[x][y] = True
        px = pixels[x, y]
        if px[3] < 10:
            continue
        if pixel_distance(px, bg_rgb) > tolerance:
            continue
        pixels[x, y] = (px[0], px[1], px[2], 0)
        removed += 1
        enqueue(x + 1, y)
        enqueue(x - 1, y)
        enqueue(x, y + 1)
        enqueue(x, y - 1)

    softened = 0
    for y in range(height):
        for x in range(width):
            px = pixels[x, y]
            if px[3] == 0:
                continue
            dist = pixel_distance(px, bg_rgb)
            if dist > edge_tolerance:
                continue
            near_transparent = False
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < width and 0 <= ny < height and pixels[nx, ny][3] == 0:
                    near_transparent = True
                    break
            if not near_transparent:
                continue
            alpha = min(px[3], max(0, int(255 * (dist / edge_tolerance))))
            if alpha < px[3]:
                pixels[x, y] = (px[0], px[1], px[2], alpha)
                softened += 1

    ensure_parent(dst_path)
    img.save(dst_path, "PNG")
    return removed, softened


def output_path_for(src_path: Path, explicit_output: str | None) -> Path:
    if explicit_output:
        out = Path(explicit_output)
        if out.is_dir() or explicit_output.endswith("/") or out.suffix == "":
            return out / (src_path.stem + ".png")
        return out
    if src_path.suffix.lower() == ".png":
        return src_path
    return src_path.with_suffix(".png")


def rewrite_references(replacements: dict[str, str]) -> int:
    changed_files = 0
    for path in PROJECT_ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in TEXT_EXTS:
            continue
        if ".git/" in path.as_posix():
            continue
        try:
            original = path.read_text(encoding="utf-8")
        except Exception:
            continue
        updated = original
        for old_path, new_path in replacements.items():
            updated = updated.replace(f"res://{old_path}", f"res://{new_path}")
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            changed_files += 1
    return changed_files


def load_report(path: str) -> list[AssetStats]:
    data = json.loads((PROJECT_ROOT / path).read_text(encoding="utf-8"))
    return [AssetStats(**item) for item in data]


def save_report(path: str, findings: list[AssetStats]) -> None:
    report_path = PROJECT_ROOT / path
    ensure_parent(report_path)
    report_path.write_text(
        json.dumps([asdict(item) for item in findings], ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def cmd_scan(args: argparse.Namespace) -> int:
    findings = scan_assets(args.roots, args.white_threshold, args.min_score)
    print_findings(findings)
    if args.report:
        save_report(args.report, findings)
        print(f"\nSaved report: {args.report}")
    return 0


def resolve_fix_targets(args: argparse.Namespace) -> list[AssetStats]:
    if args.report:
        return [item for item in load_report(args.report) if item.score >= args.min_score]
    if args.paths:
        findings = []
        for rel in args.paths:
            path = PROJECT_ROOT / rel
            if not path.exists():
                raise FileNotFoundError(rel)
            findings.append(collect_stats(path, args.white_threshold))
        return findings
    return scan_assets(args.roots, args.white_threshold, args.min_score)


def cmd_fix(args: argparse.Namespace) -> int:
    findings = resolve_fix_targets(args)
    replacements: dict[str, str] = {}
    converted = 0
    for item in findings:
        src_path = PROJECT_ROOT / item.path
        dst_path = output_path_for(src_path, args.output)
        removed, softened = remove_white_background(
            src_path=src_path,
            dst_path=dst_path,
            white_threshold=args.white_threshold,
            tolerance=args.tolerance,
            edge_tolerance=args.edge_tolerance,
        )
        converted += 1
        print(f"fixed\t{item.path}\t-> {relpath(dst_path)}\tremoved={removed}\tsoftened={softened}")
        if src_path.suffix.lower() != ".png":
            replacements[item.path] = relpath(dst_path)

    if args.rewrite_refs and replacements:
        changed_files = rewrite_references(replacements)
        print(f"rewrote_refs\tfiles={changed_files}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Scan and repair white opaque backgrounds in assets.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    scan_parser = subparsers.add_parser("scan", help="Scan assets and print suspicious files.")
    scan_parser.add_argument("--roots", nargs="+", default=DEFAULT_ROOTS)
    scan_parser.add_argument("--white-threshold", type=int, default=240)
    scan_parser.add_argument("--min-score", type=int, default=4)
    scan_parser.add_argument("--report", help="Optional JSON report path relative to repo root.")
    scan_parser.set_defaults(func=cmd_scan)

    fix_parser = subparsers.add_parser("fix", help="Convert suspicious files to transparent PNGs.")
    fix_parser.add_argument("--roots", nargs="+", default=DEFAULT_ROOTS)
    fix_parser.add_argument("--paths", nargs="*", help="Explicit relative image paths to convert.")
    fix_parser.add_argument("--report", help="Use findings from a JSON report generated by scan.")
    fix_parser.add_argument("--output", help="Optional explicit output file or directory.")
    fix_parser.add_argument("--white-threshold", type=int, default=240)
    fix_parser.add_argument("--min-score", type=int, default=4)
    fix_parser.add_argument("--tolerance", type=float, default=38.0)
    fix_parser.add_argument("--edge-tolerance", type=float, default=68.0)
    fix_parser.add_argument("--rewrite-refs", action="store_true", help="Rewrite exact res:// references from .jpg/.jpeg to generated .png files.")
    fix_parser.set_defaults(func=cmd_fix)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
