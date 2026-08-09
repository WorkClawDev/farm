# Google API Notes

This skill is built around two families of compatible HTTP endpoints:

- Gemini Developer API compatible endpoints
- Vertex AI compatible endpoints such as ZenMux

## Official docs

- Gemini image generation guide:
  `https://ai.google.dev/gemini-api/docs/image-generation`
- Imagen guide for Gemini Developer API:
  `https://ai.google.dev/gemini-api/docs/imagen`
- Official Python SDK docs:
  `https://googleapis.github.io/python-genai/index.html`
- ZenMux Vertex AI generateContent docs:
  `https://docs.zenmux.ai/api/vertexai/generate-content.html`
- ZenMux image generation guide:
  `https://docs.zenmux.ai/guide/advanced/image-generation.html`

## Why this skill uses raw HTTP

The official Python SDK is a good default when you are calling the standard Google endpoint directly.
This skill uses raw HTTP because the user specifically wants configurable `base_url` and model IDs, including compatible proxy or gateway setups.

That keeps these flows configurable:

- direct Google endpoint
- API gateways
- proxy layers that preserve Google-compatible request shapes

## Backend guidance

Use `imagen` when:

- you want text-to-image generation
- you want clean concept-sheet style outputs
- you do not need reference images in the same request

Use `gemini` when:

- you want to provide reference images
- you want iterative visual direction from previous art
- you want a multimodal prompt with images plus text
- you want to route through ZenMux Vertex AI compatible endpoints

## Practical defaults

- Backend default: `imagen`
- Imagen default model: `imagen-4.0-generate-001`
- Gemini default model: `gemini-2.5-flash-image`
- Vertex AI Gemini default model: `google/gemini-2.5-flash-image`
- API version default: `v1beta`

If Google updates recommended model IDs later, change them in `scripts/google_character_imagegen.py`.
