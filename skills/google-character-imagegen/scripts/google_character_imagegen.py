#!/usr/bin/env python3
"""Generate game character images with Google-compatible image APIs."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_BASE_URL = "https://generativelanguage.googleapis.com"
DEFAULT_API_VERSION = "v1beta"
DEFAULT_VERTEX_API_VERSION = "v1"
DEFAULT_TIMEOUT = 180
DEFAULT_OUTPUT_DIR = Path("output/google-character-imagegen")
DEFAULT_MODELS = {
    ("gemini-dev", "imagen"): "imagen-4.0-generate-001",
    ("gemini-dev", "gemini"): "gemini-2.5-flash-image",
    ("vertex-ai", "gemini"): "google/gemini-2.5-flash-image",
}
MODEL_ALIASES = {
    "nanobanana": {
        "gemini-dev": "gemini-2.5-flash-image",
        "vertex-ai": "google/gemini-2.5-flash-image",
    },
    "nano-banana": {
        "gemini-dev": "gemini-2.5-flash-image",
        "vertex-ai": "google/gemini-2.5-flash-image",
    },
    "nano_banana": {
        "gemini-dev": "gemini-2.5-flash-image",
        "vertex-ai": "google/gemini-2.5-flash-image",
    },
    "nanobanana2": {
        "gemini-dev": "gemini-3-pro-image-preview",
        "vertex-ai": "google/gemini-3-pro-image-preview",
    },
    "nano-banana2": {
        "gemini-dev": "gemini-3-pro-image-preview",
        "vertex-ai": "google/gemini-3-pro-image-preview",
    },
    "nano_banana2": {
        "gemini-dev": "gemini-3-pro-image-preview",
        "vertex-ai": "google/gemini-3-pro-image-preview",
    },
    "nanobanana-pro": {
        "gemini-dev": "gemini-3-pro-image-preview",
        "vertex-ai": "google/gemini-3-pro-image-preview",
    },
}

TEMPLATE_PROMPTS = {
    "portrait": (
        "Create a single polished character portrait of {subject}. "
        "Focus on the face, hair, silhouette, and costume readability. "
        "{style_clause}{mood_clause}{details_clause}{background_clause}"
    ),
    "full-body": (
        "Create a full-body character concept of {subject}. "
        "Show the entire outfit and proportions clearly, with production-ready costume readability. "
        "{style_clause}{mood_clause}{details_clause}{background_clause}"
    ),
    "turnaround": (
        "Create a character turnaround sheet of {subject}. "
        "Show front, three-quarter, side, and back views on one composition. "
        "Keep costume details consistent across views and make the silhouette easy to read for a game art pipeline. "
        "{style_clause}{mood_clause}{details_clause}{background_clause}"
    ),
    "expression-sheet": (
        "Create a character expression sheet of {subject}. "
        "Show at least six distinct facial expressions in a consistent style, suitable for dialogue portraits and UI work. "
        "{style_clause}{mood_clause}{details_clause}{background_clause}"
    ),
    "sprite-concept": (
        "Create a sprite-ready character concept of {subject}. "
        "Prioritize clean shapes, readable outfit breakup, and simple accessories that can survive pixel-art reduction. "
        "{style_clause}{mood_clause}{details_clause}{background_clause}"
    ),
}


@dataclass
class ResolvedConfig:
    api_key: str
    protocol: str
    backend: str
    model: str
    base_url: str
    api_version: str
    out_dir: Path
    timeout: int
    provider: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate character images with Google-compatible Gemini/Imagen endpoints."
    )
    parser.add_argument("--backend", choices=("imagen", "gemini"))
    parser.add_argument(
        "--protocol",
        choices=("gemini-dev", "vertex-ai"),
        help="API protocol family. Defaults to auto-detect from base_url/model/env.",
    )
    parser.add_argument("--model", help="Model ID, with or without the models/ prefix.")
    parser.add_argument("--base-url", help="Service root or version root.")
    parser.add_argument("--api-version", help="API version, default v1beta.")
    parser.add_argument("--api-key", help="Explicit API key. Prefer env vars for normal use.")
    parser.add_argument("--provider", default="google", help="Vertex AI publisher/provider segment.")
    parser.add_argument("--config", help="JSON config file with default values.")
    parser.add_argument("--env-file", help="Optional .env file with default values.")
    parser.add_argument("--out-dir", help="Output directory.")
    parser.add_argument("--timeout", type=int, help="HTTP timeout in seconds.")
    parser.add_argument("--count", type=int, default=1, help="Number of images to request.")
    parser.add_argument(
        "--template",
        choices=tuple(TEMPLATE_PROMPTS.keys()),
        default="portrait",
        help="Character prompt template.",
    )
    parser.add_argument("--prompt", help="Full prompt. Overrides template generation.")
    parser.add_argument("--subject", help="Character subject or short concept brief.")
    parser.add_argument("--style", help="Visual style, for example stylized JRPG concept art.")
    parser.add_argument("--details", help="Costume, props, silhouette, or lore details.")
    parser.add_argument("--mood", help="Mood or personality cues.")
    parser.add_argument("--background", help="Background or backdrop guidance.")
    parser.add_argument("--negative", help="Optional avoid list. Best effort only.")
    parser.add_argument("--aspect-ratio", default="1:1", help="Image aspect ratio.")
    parser.add_argument("--image-size", default="1K", help="Image size for supported models.")
    parser.add_argument("--mime-type", default="image/png", help="Desired output mime type.")
    parser.add_argument(
        "--person-generation",
        default="allow_adult",
        choices=("dont_allow", "allow_adult", "allow_all"),
        help="Person generation setting for supported Google image endpoints.",
    )
    parser.add_argument(
        "--enhance-prompt",
        choices=("true", "false"),
        default="true",
        help="Whether Google prompt enhancement should stay enabled when supported.",
    )
    parser.add_argument("--seed", type=int, help="Optional generation seed.")
    parser.add_argument(
        "--input-image",
        action="append",
        default=[],
        help="Reference image path. Used with the gemini backend.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the resolved request without sending it.",
    )
    return parser.parse_args()


def load_env_file(path: str | None) -> dict[str, str]:
    if not path:
        return {}

    env: dict[str, str] = {}
    for raw_line in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env[key.strip()] = value.strip().strip("'").strip('"')
    return env


def load_json_config(path: str | None) -> dict[str, Any]:
    if not path:
        return {}
    return json.loads(Path(path).read_text(encoding="utf-8"))


def build_settings(args: argparse.Namespace) -> dict[str, Any]:
    env_file = load_env_file(args.env_file)
    json_config = load_json_config(args.config)
    process_env = dict(os.environ)

    settings: dict[str, Any] = {
        "api_key": "",
        "protocol": "",
        "backend": "imagen",
        "model": "",
        "base_url": DEFAULT_BASE_URL,
        "api_version": DEFAULT_API_VERSION,
        "out_dir": str(DEFAULT_OUTPUT_DIR),
        "timeout": DEFAULT_TIMEOUT,
        "provider": "google",
    }

    settings.update(
        {
            "api_key": process_env.get("GOOGLE_CHARACTER_IMAGEGEN_API_KEY")
            or process_env.get("ZENMUX_API_KEY")
            or process_env.get("GOOGLE_API_KEY")
            or process_env.get("GEMINI_API_KEY")
            or "",
            "protocol": process_env.get("GOOGLE_CHARACTER_IMAGEGEN_PROTOCOL", settings["protocol"]),
            "backend": process_env.get("GOOGLE_CHARACTER_IMAGEGEN_BACKEND", settings["backend"]),
            "model": process_env.get("GOOGLE_CHARACTER_IMAGEGEN_MODEL", settings["model"]),
            "base_url": process_env.get("GOOGLE_CHARACTER_IMAGEGEN_BASE_URL")
            or process_env.get("ZENMUX_GEMINI_BASE_URL")
            or process_env.get("GOOGLE_GEMINI_BASE_URL")
            or settings["base_url"],
            "api_version": process_env.get(
                "GOOGLE_CHARACTER_IMAGEGEN_API_VERSION", settings["api_version"]
            ),
            "out_dir": process_env.get("GOOGLE_CHARACTER_IMAGEGEN_OUT_DIR", settings["out_dir"]),
            "provider": process_env.get("GOOGLE_CHARACTER_IMAGEGEN_PROVIDER", settings["provider"]),
        }
    )

    if env_file:
        settings.update(
            {
                "api_key": env_file.get("GOOGLE_CHARACTER_IMAGEGEN_API_KEY")
                or env_file.get("ZENMUX_API_KEY")
                or env_file.get("GOOGLE_API_KEY")
                or env_file.get("GEMINI_API_KEY")
                or settings["api_key"],
                "protocol": env_file.get("GOOGLE_CHARACTER_IMAGEGEN_PROTOCOL", settings["protocol"]),
                "backend": env_file.get("GOOGLE_CHARACTER_IMAGEGEN_BACKEND", settings["backend"]),
                "model": env_file.get("GOOGLE_CHARACTER_IMAGEGEN_MODEL", settings["model"]),
                "base_url": env_file.get("GOOGLE_CHARACTER_IMAGEGEN_BASE_URL")
                or env_file.get("ZENMUX_GEMINI_BASE_URL")
                or env_file.get("GOOGLE_GEMINI_BASE_URL")
                or settings["base_url"],
                "api_version": env_file.get(
                    "GOOGLE_CHARACTER_IMAGEGEN_API_VERSION", settings["api_version"]
                ),
                "out_dir": env_file.get("GOOGLE_CHARACTER_IMAGEGEN_OUT_DIR", settings["out_dir"]),
                "provider": env_file.get("GOOGLE_CHARACTER_IMAGEGEN_PROVIDER", settings["provider"]),
            }
        )

    settings.update({k: v for k, v in json_config.items() if v not in (None, "")})

    cli_overrides = {
        "api_key": args.api_key,
        "protocol": args.protocol,
        "backend": args.backend,
        "model": args.model,
        "base_url": args.base_url,
        "api_version": args.api_version,
        "out_dir": args.out_dir,
        "timeout": args.timeout,
        "provider": args.provider,
    }
    settings.update({k: v for k, v in cli_overrides.items() if v not in (None, "")})

    backend = str(settings["backend"]).strip().lower()
    protocol = resolve_protocol(str(settings["base_url"]), str(settings["model"]), str(settings["protocol"]))
    if backend not in ("imagen", "gemini"):
        raise SystemExit(f"Unsupported backend: {backend}")
    if protocol == "vertex-ai" and backend != "gemini":
        raise SystemExit("The vertex-ai protocol currently supports the gemini backend in this helper.")

    model = str(settings["model"]).strip() or DEFAULT_MODELS[(protocol, backend)]
    api_version = str(settings["api_version"]).strip() or DEFAULT_API_VERSION
    if protocol == "vertex-ai" and api_version == DEFAULT_API_VERSION:
        api_version = DEFAULT_VERTEX_API_VERSION

    return {
        **settings,
        "protocol": protocol,
        "backend": backend,
        "model": normalize_model(model, protocol),
        "base_url": normalize_base_url(str(settings["base_url"]), api_version, protocol),
        "api_version": api_version,
        "out_dir": Path(str(settings["out_dir"])),
        "timeout": int(settings["timeout"]),
        "provider": str(settings["provider"]).strip() or "google",
    }


def resolve_protocol(base_url: str, model: str, explicit: str) -> str:
    explicit = explicit.strip().lower()
    if explicit:
        return explicit

    if "/vertex-ai" in base_url:
        return "vertex-ai"
    if model.startswith("google/"):
        return "vertex-ai"
    return "gemini-dev"


def normalize_model(model: str, protocol: str) -> str:
    model = model.strip()
    alias = MODEL_ALIASES.get(model.lower())
    if alias:
        model = alias[protocol]
    if protocol == "vertex-ai":
        return model
    if model.startswith("models/"):
        return model
    return f"models/{model}"


def normalize_base_url(base_url: str, api_version: str, protocol: str) -> str:
    root = base_url.strip().rstrip("/")
    if re.search(r"/v\d", root):
        return root
    if protocol == "vertex-ai":
        return f"{root}/{api_version}"
    return f"{root}/{api_version}"


def build_prompt(args: argparse.Namespace, backend: str) -> str:
    if args.prompt:
        return args.prompt.strip()

    if not args.subject:
        raise SystemExit("Either --prompt or --subject is required.")

    style_clause = f"Style: {args.style}. " if args.style else ""
    mood_clause = f"Mood: {args.mood}. " if args.mood else ""
    details_clause = f"Details: {args.details}. " if args.details else ""
    background_clause = (
        f"Background: {args.background}. " if args.background else "Background: clean studio backdrop. "
    )

    prompt = TEMPLATE_PROMPTS[args.template].format(
        subject=args.subject,
        style_clause=style_clause,
        mood_clause=mood_clause,
        details_clause=details_clause,
        background_clause=background_clause,
    ).strip()

    if args.negative:
        prompt += f" Avoid: {args.negative.strip()}."

    if backend == "imagen":
        prompt += " Use clear production concept art language in English."

    return " ".join(prompt.split())


def read_inline_image(path: str) -> dict[str, str]:
    file_path = Path(path)
    if not file_path.exists():
        raise SystemExit(f"Reference image not found: {file_path}")

    suffix = file_path.suffix.lower()
    mime = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
    }.get(suffix)
    if mime is None:
        raise SystemExit(f"Unsupported reference image type: {file_path.suffix}")

    data = base64.b64encode(file_path.read_bytes()).decode("utf-8")
    return {"mimeType": mime, "data": data}


def build_request_body(args: argparse.Namespace, config: ResolvedConfig, prompt: str) -> dict[str, Any]:
    enhance_prompt = args.enhance_prompt == "true"

    if config.protocol == "gemini-dev" and config.backend == "imagen":
        parameters: dict[str, Any] = {
            "sampleCount": args.count,
            "aspectRatio": args.aspect_ratio,
            "personGeneration": args.person_generation,
            "outputMimeType": args.mime_type,
            "imageSize": args.image_size,
            "enhancePrompt": enhance_prompt,
        }
        if args.seed is not None:
            parameters["seed"] = args.seed
        if args.negative:
            parameters["negativePrompt"] = args.negative
        return {
            "instances": [{"prompt": prompt}],
            "parameters": parameters,
        }

    parts: list[dict[str, Any]] = [{"text": prompt}]
    for image_path in args.input_image:
        parts.append({"inlineData": read_inline_image(image_path)})

    response_modalities = ["TEXT", "IMAGE"] if config.protocol == "vertex-ai" else ["IMAGE"]
    generation_config: dict[str, Any] = {
        "responseModalities": response_modalities,
        "candidateCount": args.count,
    }
    if config.protocol != "vertex-ai":
        image_config: dict[str, Any] = {
            "aspectRatio": args.aspect_ratio,
            "outputMimeType": args.mime_type,
            "personGeneration": args.person_generation,
        }
        if args.image_size:
            image_config["imageSize"] = args.image_size
        generation_config["imageConfig"] = image_config
    if args.seed is not None:
        generation_config["seed"] = args.seed

    return {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": generation_config,
    }


def build_endpoint(config: ResolvedConfig) -> str:
    if config.protocol == "vertex-ai":
        model_name = config.model
        provider = config.provider
        if "/" in model_name:
            provider, model_name = model_name.split("/", 1)
        return f"{config.base_url}/publishers/{provider}/models/{model_name}:generateContent"

    action = "predict" if config.backend == "imagen" else "generateContent"
    return f"{config.base_url}/{config.model}:{action}"


def send_request(
    endpoint: str,
    api_key: str,
    body: dict[str, Any],
    timeout: int,
) -> dict[str, Any]:
    url = f"{endpoint}?key={urllib.parse.quote(api_key)}"
    headers = {"Content-Type": "application/json"}
    if api_key and "/publishers/" in endpoint:
        url = endpoint
        headers["Authorization"] = f"Bearer {api_key}"
    payload = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=payload,
        headers=headers,
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Google image request failed: HTTP {exc.code}\n{details}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"Google image request failed: {exc.reason}") from exc


def parse_gemini_response(payload: dict[str, Any]) -> tuple[list[tuple[bytes, str]], list[str]]:
    images: list[tuple[bytes, str]] = []
    texts: list[str] = []

    for candidate in payload.get("candidates", []):
        for part in candidate.get("content", {}).get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                images.append((base64.b64decode(inline["data"]), inline.get("mimeType", "image/png")))
            elif part.get("text"):
                texts.append(part["text"])

    if not images:
        images.extend(find_images_recursively(payload))
    return images, texts


def parse_imagen_response(payload: dict[str, Any]) -> tuple[list[tuple[bytes, str]], list[str]]:
    images = find_images_recursively(payload.get("predictions", payload))
    return images, []


def find_images_recursively(value: Any) -> list[tuple[bytes, str]]:
    found: list[tuple[bytes, str]] = []

    if isinstance(value, dict):
        inline = value.get("inlineData") or value.get("inline_data")
        if isinstance(inline, dict) and inline.get("data"):
            maybe = decode_base64_image(inline.get("data"), inline.get("mimeType", "image/png"))
            if maybe:
                found.append(maybe)

        for key in ("bytesBase64Encoded", "imageBytes", "image_bytes", "b64Json"):
            if key in value:
                maybe = decode_base64_image(value[key], value.get("mimeType", "image/png"))
                if maybe:
                    found.append(maybe)

        if "data" in value and any(tag in "".join(value.keys()).lower() for tag in ("image", "inline", "bytes")):
            maybe = decode_base64_image(value["data"], value.get("mimeType", "image/png"))
            if maybe:
                found.append(maybe)

        for nested in value.values():
            found.extend(find_images_recursively(nested))

    elif isinstance(value, list):
        for item in value:
            found.extend(find_images_recursively(item))

    return dedupe_images(found)


def decode_base64_image(raw: Any, mime_type: str) -> tuple[bytes, str] | None:
    if not isinstance(raw, str):
        return None

    text = raw.strip()
    if not text or len(text) < 64:
        return None

    try:
        return base64.b64decode(text), mime_type or "image/png"
    except Exception:
        return None


def dedupe_images(images: list[tuple[bytes, str]]) -> list[tuple[bytes, str]]:
    unique: list[tuple[bytes, str]] = []
    seen: set[tuple[str, str]] = set()
    for blob, mime in images:
        key = (hashlib.sha256(blob).hexdigest(), mime)
        if key in seen:
            continue
        seen.add(key)
        unique.append((blob, mime))
    return unique


def extension_for_mime(mime_type: str) -> str:
    return {
        "image/png": ".png",
        "image/jpeg": ".jpg",
        "image/webp": ".webp",
    }.get(mime_type, ".bin")


def save_outputs(
    out_dir: Path,
    prompt: str,
    config: ResolvedConfig,
    request_body: dict[str, Any],
    response_body: dict[str, Any],
    images: list[tuple[bytes, str]],
    texts: list[str],
) -> list[Path]:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = out_dir / timestamp
    run_dir.mkdir(parents=True, exist_ok=True)

    saved_paths: list[Path] = []
    for index, (blob, mime_type) in enumerate(images, start=1):
        image_path = run_dir / f"image-{index}{extension_for_mime(mime_type)}"
        image_path.write_bytes(blob)
        saved_paths.append(image_path)

    metadata = {
        "timestamp_utc": timestamp,
        "backend": config.backend,
        "protocol": config.protocol,
        "base_url": config.base_url,
        "model": config.model,
        "provider": config.provider,
        "prompt": prompt,
        "request_body": request_body,
        "response_body": response_body,
        "saved_files": [str(path) for path in saved_paths],
        "text_parts": texts,
    }
    (run_dir / "request-metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    if texts:
        (run_dir / "response-text.txt").write_text("\n\n".join(texts), encoding="utf-8")

    return saved_paths


def print_dry_run(config: ResolvedConfig, prompt: str, endpoint: str, body: dict[str, Any]) -> None:
    preview = {
        "backend": config.backend,
        "protocol": config.protocol,
        "model": config.model,
        "base_url": config.base_url,
        "provider": config.provider,
        "endpoint": endpoint,
        "prompt": prompt,
        "request_body": body,
    }
    print(json.dumps(preview, ensure_ascii=False, indent=2))


def resolve_runtime_config(args: argparse.Namespace) -> ResolvedConfig:
    settings = build_settings(args)
    api_key = str(settings["api_key"]).strip()
    if not api_key and not args.dry_run:
        raise SystemExit(
            "Missing API key. Set GOOGLE_CHARACTER_IMAGEGEN_API_KEY, GOOGLE_API_KEY, or GEMINI_API_KEY."
        )

    return ResolvedConfig(
        api_key=api_key,
        protocol=str(settings["protocol"]),
        backend=str(settings["backend"]),
        model=str(settings["model"]),
        base_url=str(settings["base_url"]),
        api_version=str(settings["api_version"]),
        out_dir=Path(settings["out_dir"]),
        timeout=int(settings["timeout"]),
        provider=str(settings["provider"]),
    )


def main() -> int:
    args = parse_args()
    config = resolve_runtime_config(args)
    prompt = build_prompt(args, config.backend)
    endpoint = build_endpoint(config)
    request_body = build_request_body(args, config, prompt)

    if args.dry_run:
        print_dry_run(config, prompt, endpoint, request_body)
        return 0

    response_body = send_request(endpoint, config.api_key, request_body, config.timeout)
    if config.backend == "imagen":
        images, texts = parse_imagen_response(response_body)
    else:
        images, texts = parse_gemini_response(response_body)

    if not images:
        print(json.dumps(response_body, ensure_ascii=False, indent=2))
        raise SystemExit("The API response did not contain any decodable images.")

    saved = save_outputs(
        out_dir=config.out_dir,
        prompt=prompt,
        config=config,
        request_body=request_body,
        response_body=response_body,
        images=images,
        texts=texts,
    )

    print("Saved files:")
    for path in saved:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
