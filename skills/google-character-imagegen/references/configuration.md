# Configuration

This skill supports configuration at four layers:

1. Built-in defaults in `scripts/google_character_imagegen.py`
2. Process environment variables
3. Optional `.env` file via `--env-file`
4. Optional JSON config via `--config`
5. Direct CLI flags

CLI flags take priority over everything else.

## Supported env vars

- `GOOGLE_CHARACTER_IMAGEGEN_API_KEY`
- `GOOGLE_CHARACTER_IMAGEGEN_PROTOCOL`
- `GOOGLE_CHARACTER_IMAGEGEN_BASE_URL`
- `GOOGLE_CHARACTER_IMAGEGEN_MODEL`
- `GOOGLE_CHARACTER_IMAGEGEN_BACKEND`
- `GOOGLE_CHARACTER_IMAGEGEN_API_VERSION`
- `GOOGLE_CHARACTER_IMAGEGEN_OUT_DIR`
- `GOOGLE_CHARACTER_IMAGEGEN_PROVIDER`
- `ZENMUX_API_KEY`
- `ZENMUX_GEMINI_BASE_URL`
- `GOOGLE_API_KEY`
- `GEMINI_API_KEY`

`GOOGLE_CHARACTER_IMAGEGEN_API_KEY` wins over the generic Google key variables.
If it is unset, `ZENMUX_API_KEY` is accepted before `GOOGLE_API_KEY` and `GEMINI_API_KEY`.

## Example `.env`

```dotenv
GOOGLE_CHARACTER_IMAGEGEN_API_KEY=your-key
GOOGLE_CHARACTER_IMAGEGEN_PROTOCOL=gemini-dev
GOOGLE_CHARACTER_IMAGEGEN_BASE_URL=https://generativelanguage.googleapis.com
GOOGLE_CHARACTER_IMAGEGEN_API_VERSION=v1beta
GOOGLE_CHARACTER_IMAGEGEN_BACKEND=imagen
GOOGLE_CHARACTER_IMAGEGEN_MODEL=imagen-4.0-generate-001
GOOGLE_CHARACTER_IMAGEGEN_OUT_DIR=output/google-character-imagegen
```

## Example JSON config

```json
{
  "base_url": "https://generativelanguage.googleapis.com",
  "protocol": "gemini-dev",
  "api_version": "v1beta",
  "backend": "imagen",
  "model": "imagen-4.0-generate-001",
  "out_dir": "output/google-character-imagegen"
}
```

## Base URL guidance

The helper expects either a Gemini Developer API compatible base URL or a Vertex AI compatible base URL.

Valid examples:

- `https://generativelanguage.googleapis.com`
- `https://generativelanguage.googleapis.com/v1beta`
- `https://your-api-gateway.example.com`
- `https://your-api-gateway.example.com/v1beta`

The script appends the API version automatically when the base URL does not already include a version segment.

- `https://zenmux.ai/api/vertex-ai`
- `https://zenmux.ai/api/vertex-ai/v1`

## Protocol guidance

- `gemini-dev`: for `generativelanguage`-style endpoints and compatible proxies.
- `vertex-ai`: for Vertex AI compatible gateways such as ZenMux.

The helper auto-detects `vertex-ai` when the base URL contains `/vertex-ai` or the model starts with `google/`.
When `vertex-ai` is selected and no version is provided, the helper defaults to `v1`.

## ZenMux example

```dotenv
ZENMUX_API_KEY=your-zenmux-key
ZENMUX_GEMINI_BASE_URL=https://zenmux.ai/api/vertex-ai
GOOGLE_CHARACTER_IMAGEGEN_PROTOCOL=vertex-ai
GOOGLE_CHARACTER_IMAGEGEN_BACKEND=gemini
GOOGLE_CHARACTER_IMAGEGEN_MODEL=google/gemini-2.5-flash-image
```

## Model guidance

Common starting points:

- `imagen-4.0-generate-001`: balanced text-to-image character generation.
- `imagen-4.0-fast-generate-001`: faster draft iteration.
- `imagen-4.0-ultra-generate-001`: higher-end text-to-image outputs when latency is less important.
- `gemini-2.5-flash-image`: multimodal image generation with reference images.
- `google/gemini-2.5-flash-image`: Vertex AI compatible form, suitable for ZenMux.
- `google/gemini-3-pro-image-preview`: higher-end Vertex AI compatible image model when available on the gateway.

Convenience alias:

- `nanobanana`: maps to the Gemini 2.5 Flash Image family for the selected protocol.
- `nanobanana2`: maps to the Gemini 3 Pro Image Preview family for the selected protocol.

## Notes

- For `imagen`, Google documents the flow around English prompts.
- For `gemini`, use reference images when you need consistency from one iteration to the next.
- The helper writes raw request and response metadata so proxy-specific payload differences are easier to debug.
