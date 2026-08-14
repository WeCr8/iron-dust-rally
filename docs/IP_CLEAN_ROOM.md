# Intellectual-property clean-room policy

The goal is a spiritual successor, not a duplicate or remake. Mechanics and genre conventions may inspire product decisions; protected expression must not be copied.

## Never include

- “Super Off Road,” “Ivan Stewart,” “Ironman” as a persona, or other legacy trademarks/names in the shipped title, UI, metadata, filenames, store copy, or marketing.
- Celebrity name, face, signature, voice imitation, biography, racing number/livery, or implied endorsement.
- Extracted/recreated sprites, tracks, vehicles, logos, cabinet art, fonts, sounds, music, code, text, or hidden data.
- Pixel-traced screenshots, near-identical track geometry, UI layout, upgrade economy tables, or recognizable audiovisual sequences.

## Allowed inspiration

- General top-down arcade racing mechanics.
- Local shared-screen competition, short laps, pickups, loose dirt handling, fictional upgrades, and fictional desert settings.
- Broad period/genre mood expressed through newly designed work.

## Review gate

For every external or generated asset, record source, author/tool, license/terms, date, and modifications in `ASSET_LICENSES.md` or `docs/asset-provenance/`. Review names with a trademark search before public launch. Obtain qualified legal review before commercial release; this document is an engineering policy, not legal advice.

## Agent refusal rule

If a task requests copying or close recreation, mark it blocked in `agent/tasks.json` and propose an original alternative. Never use online ROMs, gameplay rips, decompilations, extracted assets, or unauthorized archives as implementation inputs.
