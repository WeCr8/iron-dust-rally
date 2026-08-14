# Asset licenses

The vertical slice includes original generated raster sheets and deterministic synthesized audio. No third-party art, music, fonts, celebrity likenesses, or legacy-game assets are included.

- Source code: MIT (`LICENSE`).
- Original future art/audio commissioned for this project: record the creator, source, license, and modification status here before merging.
- Generated content: retain the generator, prompt record, date, and applicable terms in `docs/asset-provenance/`.

## Included original assets

| Asset | Type | Source | Intended use |
| --- | --- | --- | --- |
| `game/assets/art/vehicles_atlas.png` | PNG with alpha | OpenAI image generation, 2026-08-13 | Four original numbered buggy sprites |
| `game/assets/art/environment_atlas.png` | PNG | OpenAI image generation, 2026-08-13 | Dirt/sand/hardpack, barriers, sign, rocks, plants, boost, dust |
| `game/assets/art/logo_ui_atlas.png` | PNG with alpha | OpenAI image generation, 2026-08-13 | Original title treatment, panels, button, boost frame, player badges |
| `game/assets/audio/*.wav` | PCM WAV | Deterministic synthesis by `tools/generate_audio.py`, 2026-08-13 | Engine loop, boost, pickup, countdown, impact, finish stinger |

Prompt records, dimensions, and integration notes are in `docs/asset-provenance/GENERATED_ASSETS.md`.

No asset may enter `game/assets/` without a provenance entry and a license compatible with commercial web distribution.
