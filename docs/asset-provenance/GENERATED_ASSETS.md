# Generated asset provenance

Generated 2026-08-13 for Iron Dust Rally. These are original clean-room assets; no legacy images, extracted files, celebrity references, screenshots, or other game assets were supplied as inputs.

## Vehicles atlas

- File: `game/assets/art/vehicles_atlas.png`
- Dimensions: 1238×1271, RGBA.
- Generator: OpenAI built-in image generation.
- Prompt summary: four original orthographic off-road buggies in a 2×2 sheet; coral/gold/teal/blue; roof numerals 1–4; transparent background; hand-painted desert arcade style; explicitly exclude brands, celebrity likenesses, existing racing-game designs, captions, and watermarks.
- Runtime slicing: two 619 px columns; two approximately 635 px rows. Godot currently consumes these regions through `AtlasTexture`.

## Environment atlas

- File: `game/assets/art/environment_atlas.png`
- Dimensions: 1254×1254, RGB.
- Generator: OpenAI built-in image generation.
- Prompt summary: original 3×3 top-down environment atlas containing dirt, sand, hardpack, turquoise/cream barrier, blank wooden sign, rocks, scrub, lightning-canister boost, and dust puff; no text, logo, watermark, copied track, or legacy asset.
- Integration: source atlas for extraction during environment-content tasks. Retained whole so no source pixels are lost.

## Logo and UI atlas

- File: `game/assets/art/logo_ui_atlas.png`
- Dimensions: 1536×1024, RGBA.
- Generator: OpenAI built-in image generation.
- Prompt summary: exact original title “IRON DUST RALLY”; desert-festival arcade identity; blank scoreboard/button, turquoise boost frame, numbered player badges; transparent background; no other words, brands, celebrity likeness, watermark, or resemblance request.
- Integration: source atlas for title/menu and HUD extraction. The procedural HUD remains available while UI scenes are built.

## Audio

- Files: `engine_loop.wav`, `boost.wav`, `pickup.wav`, `countdown.wav`, `impact.wav`, `finish_stinger.wav`.
- Generator: repository script `tools/generate_audio.py` using only Python standard-library waveform synthesis.
- Format: 44.1 kHz, mono, signed 16-bit PCM.
- Inputs: mathematical oscillators, seeded noise, amplitude envelopes; no samples or recorded source material.

Before release, visually inspect atlas crops, tune sprite region margins, normalize audio loudness, and conduct the provenance/legal review required by `docs/IP_CLEAN_ROOM.md`.
