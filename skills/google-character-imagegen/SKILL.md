---
name: google-character-imagegen
description: Use when Codex should generate or iterate on game character art through Google image models. Supports configurable base URL, model ID, API version, protocol selection, backend selection, ZenMux environment variables, prompt templates for portraits/turnarounds/expression sheets, and a local helper script for Gemini Developer API or Vertex AI compatible endpoints.
---

# Google Character Imagegen

Generate character art with Google image APIs from inside Codex. This skill is for concept portraits, full-body sheets, turnaround sheets, expression sheets, and sprite-style concept references when the user wants Google-hosted image models instead of hand-made placeholder art.

## When To Use

- The user wants character art generated with Google APIs.
- The task needs configurable `base_url`, model ID, API version, protocol, or proxy routing.
- The user wants to route requests through ZenMux.
- The task needs a repeatable local command instead of ad hoc curl snippets.
- The user wants a reusable workflow for character prompt construction.

## Workflow

1. Decide the backend.
   Use `imagen` for text-to-image character generation and clean concept sheets.
   Use `gemini` for multimodal generation with reference images or iterative art direction.
2. Resolve configuration.
   Read `references/configuration.md` only if you need the config precedence or sample config shapes.
   The helper script supports CLI flags, env vars, `.env`-style files, and JSON config files.
   It can speak either `gemini-dev` or `vertex-ai` protocol families.
3. Build the prompt.
   Read `references/character-prompts.md` for templates.
   For `imagen`, keep prompts in English because Google documents Imagen prompt support around English prompts.
4. Run the helper.
   Use `scripts/google_character_imagegen.py`.
   Start with `--dry-run` when changing `base_url`, `model`, or backend wiring.
5. Inspect outputs.
   The script writes generated images plus a `request-metadata.json` file into the output directory.

## Quick Start

Text-to-image character sheet with Imagen:

```bash
python3 skills/google-character-imagegen/scripts/google_character_imagegen.py \
  --backend imagen \
  --subject "young herbalist ranger with a satchel and long braid" \
  --template turnaround \
  --style "stylized JRPG concept art" \
  --details "moss green cloak, leather boots, plant samples, practical travel gear" \
  --aspect-ratio 1:1 \
  --count 2
```

Reference-driven iteration with Gemini image output:

```bash
python3 skills/google-character-imagegen/scripts/google_character_imagegen.py \
  --backend gemini \
  --protocol vertex-ai \
  --model gemini-2.5-flash-image \
  --subject "village blacksmith protagonist" \
  --template expression-sheet \
  --style "clean 2D game concept art" \
  --input-image refs/blacksmith-moodboard.png \
  --input-image refs/apron-shape.png \
  --count 1
```

Explicit config override:

```bash
python3 skills/google-character-imagegen/scripts/google_character_imagegen.py \
  --config skills/google-character-imagegen/local.config.json \
  --base-url https://generativelanguage.googleapis.com \
  --model imagen-4.0-generate-001 \
  --subject "forest witch NPC" \
  --template portrait
```

## Configuration

Supported runtime knobs:

- `--base-url`: service root or version root, for example `https://generativelanguage.googleapis.com` or a compatible proxy base.
- `--protocol`: `gemini-dev` or `vertex-ai`.
- `--model`: exact model ID. Examples: `imagen-4.0-generate-001`, `imagen-4.0-fast-generate-001`, `gemini-2.5-flash-image`.
  The helper also accepts aliases:
  `nanobanana` -> Gemini 2.5 Flash Image
  `nanobanana2` / `nanobanana-pro` -> Gemini 3 Pro Image Preview
- `--api-version`: default `v1beta`.
- `--backend`: `imagen` or `gemini`.
- `--config`: JSON file with defaults.
- `--env-file`: `.env`-style file with defaults.

Supported environment variables:

- `GOOGLE_CHARACTER_IMAGEGEN_API_KEY`
- `GOOGLE_CHARACTER_IMAGEGEN_PROTOCOL`
- `GOOGLE_CHARACTER_IMAGEGEN_BASE_URL`
- `GOOGLE_CHARACTER_IMAGEGEN_MODEL`
- `GOOGLE_CHARACTER_IMAGEGEN_BACKEND`
- `GOOGLE_CHARACTER_IMAGEGEN_API_VERSION`
- `GOOGLE_CHARACTER_IMAGEGEN_OUT_DIR`
- `GOOGLE_CHARACTER_IMAGEGEN_PROVIDER`
- `GEMINI_API_KEY`
- `GOOGLE_API_KEY`
- `ZENMUX_API_KEY`
- `ZENMUX_GEMINI_BASE_URL`

CLI flags win over file/env defaults.

## Files

- `scripts/google_character_imagegen.py`
  Main helper for Google-compatible image generation requests.
- `references/google-api.md`
  Official-model notes and why the helper uses raw HTTP instead of the Python SDK for custom base URLs.
- `references/configuration.md`
  Config precedence, supported variables, and example config files.
- `references/character-prompts.md`
  Prompt templates for portraits, full body, turnaround, expression sheet, and sprite concept work.

## Constraints

- The helper assumes Gemini Developer API compatible endpoints.
- Custom `base_url` support is implemented at the HTTP layer for compatibility proxies and gateways.
- ZenMux-style Vertex AI compatible gateways are supported through `--protocol vertex-ai`.
- The helper is designed for generation flows, not full asset cleanup or sprite-sheet slicing.
- If a proxy returns a slightly different image payload shape, the script uses best-effort image extraction and still writes the raw response metadata.
