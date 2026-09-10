#!/usr/bin/env node
/**
 * generate-placeholder-art - make the seven missing atlases exist, at the exact sizes the game
 * reads, so the project can actually load.
 *
 * WHY THIS EXISTS (2026-09-10)
 * ---------------------------
 * scripts/ui_atlas.gd `preload()`s seven PNGs that are not in the repo. In Godot a failed
 * preload is a PARSE-time error, not a missing-texture warning: the script does not compile, so
 * every one of its consts is unavailable and the game does not run at all. check-project.mjs
 * reports these as its seven CRITICAL findings.
 *
 * The fix is not a code change. That distinction matters more than it looks: an agent told to
 * "reduce the critical count in ui_atlas.gd" has one cheap move available - delete the preload
 * lines - which scores perfectly against the gate while deleting the terrain, the bollards and
 * the tyre walls. The counter would go to zero and the game would be worse. So this is done by
 * generating files, never by editing the script.
 *
 * WHAT THESE ARE, HONESTLY
 * Flat-colour placeholders. Not art, and not a substitute for it. Each region the code slices
 * is filled with its own solid colour and outlined, so when the game runs you can see at a
 * glance that every Rect2 lands where the code expects rather than reading past an edge - which
 * is the one thing a wrongly-sized atlas gets wrong and the one thing you cannot check by
 * reading the source. Replace them with real art from the asset pipeline; ASSET_LICENSES.md
 * records them as placeholders, not as commissioned work.
 *
 * Sizes and regions are not invented here - they are read from tools/asset-spec.mjs, which
 * derives them from the Rect2 calls in the code that consumes each atlas.
 *
 *   node tools/generate-placeholder-art.mjs            # report what it would write
 *   node tools/generate-placeholder-art.mjs --write    # write the files
 */
import { spawnSync } from 'node:child_process';
import zlib from 'node:zlib';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const WRITE = process.argv.includes('--write');

/* ---- minimal PNG writer (RGBA8). No dependency: this repo has no node_modules. ---- */
const CRC = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return (buf) => {
    let c = -1;
    for (let i = 0; i < buf.length; i++) c = t[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
    return (c ^ -1) >>> 0;
  };
})();

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(CRC(body), 0);
  return Buffer.concat([len, body, crc]);
}

function encodePng(w, h, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;    // bit depth
  ihdr[9] = 6;    // colour type: RGBA
  // 10,11,12 = compression, filter, interlace - all zero
  const stride = w * 4;
  const raw = Buffer.alloc((stride + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (stride + 1)] = 0;   // filter: none
    rgba.copy(raw, y * (stride + 1) + 1, y * stride, y * stride + stride);
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/* ---- read the derived spec rather than hardcoding sizes ---- */
const spec = spawnSync(process.execPath, [path.join(HERE, 'asset-spec.mjs')],
  { cwd: ROOT, encoding: 'utf8', windowsHide: true });
if (spec.status !== 0 && !spec.stdout) {
  console.error('asset-spec.mjs produced nothing; cannot size the atlases');
  process.exit(0);
}

const files = [];
let cur = null;
for (const line of (spec.stdout || '').split('\n')) {
  const f = /^(assets\/art\/[^\s]+\.png)\s*$/.exec(line);
  if (f) { cur = { file: f[1], w: 0, h: 0, regions: [] }; files.push(cur); continue; }
  if (!cur) continue;
  const c = /min canvas\s*:\s*(\d+) x (\d+)/.exec(line);
  if (c) { cur.w = Number(c[1]); cur.h = Number(c[2]); continue; }
  // Coordinates can be fractional - ui_atlas.gd slices some atlases as `width / 2.0`, which
  // the spec faithfully reports as 271.5. Parse the decimals, then floor the origin and ceil
  // the extent, so a placeholder region always covers at least what the game samples.
  const r = /^\s+([A-Z0-9_]+)\s+x=\s*([\d.]+)\s+y=\s*([\d.]+)\s+([\d.]+) x ([\d.]+)/.exec(line);
  if (r) cur.regions.push({
    name: r[1],
    x: Math.floor(+r[2]), y: Math.floor(+r[3]),
    w: Math.ceil(+r[4]), h: Math.ceil(+r[5]),
  });
}

// Distinct, deliberately synthetic colours - nobody should mistake these for finished art.
const PALETTE = [
  [198, 122, 66], [122, 148, 92], [176, 92, 108], [92, 128, 168],
  [186, 168, 84], [136, 104, 168], [96, 156, 148], [176, 140, 96],
];

let wrote = 0;
for (const f of files) {
  if (!f.w || !f.h) continue;
  const out = path.join(ROOT, f.file);
  if (fs.existsSync(out)) { console.log(`  skip   ${f.file} (already exists)`); continue; }

  const rgba = Buffer.alloc(f.w * f.h * 4);          // transparent by default
  const put = (x, y, [r, g, b], a = 255) => {
    if (x < 0 || y < 0 || x >= f.w || y >= f.h) return;
    const i = (y * f.w + x) * 4;
    rgba[i] = r; rgba[i + 1] = g; rgba[i + 2] = b; rgba[i + 3] = a;
  };

  f.regions.forEach((reg, idx) => {
    const col = PALETTE[idx % PALETTE.length];
    const edge = col.map((c) => Math.max(0, c - 60));
    for (let y = reg.y; y < reg.y + reg.h; y++) {
      for (let x = reg.x; x < reg.x + reg.w; x++) {
        const onEdge = x < reg.x + 3 || x >= reg.x + reg.w - 3
                    || y < reg.y + 3 || y >= reg.y + reg.h - 3;
        // A diagonal hatch reads as "placeholder" instantly, and makes it obvious in-game
        // if a region is being sampled at the wrong offset or scale.
        const hatch = ((x - reg.x) + (y - reg.y)) % 24 < 3;
        put(x, y, onEdge ? edge : hatch ? edge : col, 255);
      }
    }
  });

  if (WRITE) {
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.writeFileSync(out, encodePng(f.w, f.h, rgba));
    wrote++;
  }
  console.log(`  ${WRITE ? 'write ' : 'would '} ${f.file}  ${f.w}x${f.h}  ${f.regions.length} region(s)`);
}

console.log(`\n${WRITE ? `wrote ${wrote} placeholder atlas(es)` : `${files.length} atlas(es) would be written; pass --write`}`);
process.exit(0);
