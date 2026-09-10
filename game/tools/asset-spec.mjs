#!/usr/bin/env node
/**
 * asset-spec - derive what each MISSING art file must actually be, from the code that uses it.
 *
 * WHY THIS EXISTS (2026-08-23)
 * ---------------------------
 * Ten referenced art files do not exist anywhere - not in the project, not in
 * iron-dust-racing-game-assets.zip, not on the laptop. There is a skill for generating Iron
 * Dust Rally art, and it is careful about palette, provenance and QA. What it cannot know is
 * the one thing that decides whether a generated file is usable: the exact canvas size and the
 * regions the game slices out of it. A 1024x1024 atlas is worthless if the code reads a region
 * at y=881 height 290.
 *
 * HOW REGIONS ARE ATTRIBUTED
 * A first version of this attributed every Rect2 in a script to every atlas that script loads.
 * ui_atlas.gd loads nine atlases, so all ten files came back with the same meaningless
 * "1530 x 1309" bound. The real file is sectioned - each `const X_TEXTURE := preload(...)` is
 * followed by exactly the regions belonging to it, until the next texture const. So regions are
 * attributed POSITIONALLY, to the nearest preceding texture declaration. That matches how the
 * file is actually written and gives each atlas its own honest dimensions.
 *
 * Named constants used inside a Rect2 (ENV_CELL, BOLLARD_CELL) are resolved first, since
 * `Rect2(0, 0, ENV_CELL, ENV_CELL)` carries no numbers of its own.
 */

import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || path.join(import.meta.dirname, '..'));
const read = p => { try { return fs.readFileSync(p, 'utf8'); } catch { return ''; } };

const scriptDir = path.join(ROOT, 'scripts');
const scripts = fs.existsSync(scriptDir) ? fs.readdirSync(scriptDir).filter(f => f.endsWith('.gd')) : [];

// asset -> { users:Set, regions:[{x,y,w,h,name}] }
const assets = new Map();
const touch = rel => {
  if (!assets.has(rel)) { assets.set(rel, { users: new Set(), regions: [] }); }
  return assets.get(rel);
};

for (const scriptName of scripts) {
  const body = read(path.join(scriptDir, scriptName));
  if (!/res:\/\/assets\/art\//.test(body)) { continue; }

  // Resolve simple numeric consts so Rect2(0, 0, ENV_CELL, ENV_CELL) can be evaluated.
  const consts = new Map();
  for (const m of body.matchAll(/^\s*const\s+([A-Z][A-Z0-9_]*)\s*:?=\s*(-?[\d.]+)\s*$/gm)) {
    consts.set(m[1], Number(m[2]));
  }
  const num = tok => {
    const t = tok.trim();
    if (/^-?[\d.]+$/.test(t)) { return Number(t); }
    if (consts.has(t)) { return consts.get(t); }
    return null;   // an expression we cannot resolve; the region is skipped, not guessed at
  };

  let current = null;                       // the atlas most recently declared above this line
  for (const line of body.split('\n')) {
    const tex = line.match(/preload\s*\(\s*"res:\/\/(assets\/art\/[A-Za-z0-9_]+\.png)"/);
    if (tex) { current = tex[1]; touch(current).users.add(scriptName); continue; }
    if (!current) { continue; }

    for (const r of line.matchAll(/Rect2\(([^)]*)\)/g)) {
      const parts = r[1].split(',');
      if (parts.length !== 4) { continue; }
      const [x, y, w, h] = parts.map(num);
      if ([x, y, w, h].some(v => v === null)) { continue; }
      const named = line.match(/^\s*const\s+([A-Z][A-Z0-9_]*)/);
      touch(current).regions.push({ x, y, w, h, name: named ? named[1] : '' });
    }
  }
}

const missing = [...assets.entries()].filter(([rel]) => !fs.existsSync(path.join(ROOT, rel)));

console.log('Iron Dust Rally - specification for MISSING art assets');
console.log(`root: ${ROOT}`);
console.log(`${missing.length} referenced file(s) do not exist\n`);

for (const [rel, info] of missing.sort((a, b) => a[0].localeCompare(b[0]))) {
  const rs = info.regions;
  console.log(rel);
  console.log(`  used by      : ${[...info.users].join(', ')}`);

  if (!rs.length) {
    console.log('  min canvas   : no resolvable regions - the file is used whole, so its size is a design choice\n');
    continue;
  }

  const needW = Math.ceil(Math.max(...rs.map(r => r.x + r.w)));
  const needH = Math.ceil(Math.max(...rs.map(r => r.y + r.h)));
  console.log(`  min canvas   : ${needW} x ${needH} px  (anything smaller and the game reads past the edge)`);
  console.log(`  regions      : ${rs.length}`);

  const sizes = new Set(rs.map(r => `${r.w}x${r.h}`));
  if (sizes.size === 1) {
    console.log(`  layout       : uniform ${[...sizes][0]} cells - a regular grid is safe`);
  } else {
    console.log('  layout       : irregular - each region must land exactly where the code expects:');
  }
  for (const r of rs) {
    console.log(`      ${(r.name || '(inline)').padEnd(24)} x=${String(r.x).padStart(6)} y=${String(r.y).padStart(6)}`
      + `  ${r.w} x ${r.h}`);
  }
  console.log('');
}

console.log('Every candidate must still pass the asset-qa gates: numerical alpha (not a visual');
console.log('checkerboard), no watermarks or stray text, effects contained within their own cell,');
console.log('and for terrain, all four edges tested for seams rather than eyeballed.');

process.exit(0);
