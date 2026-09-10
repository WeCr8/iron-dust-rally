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

## Added 2026-09-10 - vertical slice update

### Derived art

| Asset | Type | Source | Intended use |
| --- | --- | --- | --- |
| `game/assets/art/vehicles_atlas_tint*.png` | PNG with alpha | Recoloured variants derived from the original `vehicles_atlas.png` above | Per-player vehicle tinting |

Derived from an asset already recorded in this file. No new third-party input.

### Synthesised voice lines - THIRD PARTY, review before relying on this

| Asset | Type | Source | Intended use |
| --- | --- | --- | --- |
| `game/assets/audio/generated/announcer/*.mp3` | MP3 | **ElevenLabs** text-to-speech via `game/tools/generate-audio.mjs` | Race announcer lines |
| `game/assets/audio/generated/codriver/*.mp3` | MP3 | **ElevenLabs** text-to-speech via `game/tools/generate-audio.mjs` | Co-driver pace notes |

Each clip ships a `*.receipt.json` beside it recording the exact requested text and a sha256,
so every spoken line is auditable against what was synthesised.

**This narrows the claim at the top of this file.** That statement was written when the project
contained only self-generated raster art and locally synthesised WAV audio. These MP3s are
produced by a third-party hosted service, and their usage rights follow **ElevenLabs' licence
terms for the account that generated them** - commercial use is tied to subscription tier.
Confirm the account tier permits the intended distribution before shipping or publishing these
files. Until that is confirmed, treat them as internal-only.

No third-party *art*, music, fonts, celebrity likenesses, or legacy-game assets are included.
