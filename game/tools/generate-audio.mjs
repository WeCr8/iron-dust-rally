#!/usr/bin/env node
/**
 * generate-audio - synthesise Iron Dust Rally's reviewed voice lines via ElevenLabs.
 *
 * WHY THIS EXISTS (2026-08-23)
 * ---------------------------
 * Iron Dust Rally currently has no audio of any kind - no AudioStreamPlayer, no audio
 * directory, no .ogg/.wav references anywhere in the scripts or scenes. This produces the
 * asset files only. It deliberately does NOT wire playback into the game: the reindustrialize
 * pipeline this is modelled on states the rule plainly - generate, review by ear, and only
 * then wire playback, so the build stays silent, deterministic and E2E-friendly until someone
 * decides otherwise.
 *
 * Design carried over from that pipeline, because it was right:
 *   - text lives in a reviewed manifest, never in game code, so every spoken line is
 *     auditable in one place before it is ever synthesised
 *   - writes are atomic (.partial then rename) so an interrupted run cannot leave a truncated
 *     mp3 that looks valid to the loader
 *   - every file gets a sha256 receipt recording exactly what was requested
 *
 * One thing added here: this SKIPS any clip whose text has not changed since its receipt was
 * written. The account is on a 30k-character monthly cap, and re-running the script should not
 * silently re-spend the budget on lines that are already correct. Use --force to override.
 *
 *   node tools/generate-audio.mjs                 # plan only, makes no network request
 *   node tools/generate-audio.mjs --generate      # synthesise anything new or changed
 *   node tools/generate-audio.mjs --generate --force        # re-synthesise everything
 *   node tools/generate-audio.mjs --generate --ids=welcome,countdown_go
 *
 * The API key is read from the environment ONLY. It is never written to a receipt, a log line,
 * or any file this script produces.
 */

import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..');
const MANIFEST = path.join(ROOT, 'audio', 'announcer-manifest.json');
const OUT_DIR = path.join(ROOT, 'assets', 'audio', 'generated');

const argv = process.argv.slice(2);
const generate = argv.includes('--generate');
const force = argv.includes('--force');
const idsArg = argv.find(a => a.startsWith('--ids='));
const only = idsArg ? new Set(idsArg.slice(6).split(',').map(s => s.trim()).filter(Boolean)) : null;

const manifest = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
const sha256 = buf => createHash('sha256').update(buf).digest('hex');

let clips = manifest.clips;
if (only) {
  clips = clips.filter(c => only.has(c.id));
  const missing = [...only].filter(id => !manifest.clips.some(c => c.id === id));
  if (missing.length) { console.error(`unknown clip id(s): ${missing.join(', ')}`); process.exit(2); }
}

// Decide what actually needs work, so the plan and the run agree on scope.
const planned = [];
for (const clip of clips) {
  const receiptPath = path.join(OUT_DIR, clip.role, `${clip.id}.receipt.json`);
  const mp3Path = path.join(OUT_DIR, clip.role, `${clip.id}.mp3`);
  let reason = 'new';
  if (fs.existsSync(receiptPath) && fs.existsSync(mp3Path)) {
    try {
      const prev = JSON.parse(fs.readFileSync(receiptPath, 'utf8'));
      if (prev.textSha256 === sha256(clip.text) && !force) { reason = null; }
      else { reason = force ? 'forced' : 'text changed'; }
    } catch { reason = 'unreadable receipt'; }
  }
  if (reason) { planned.push({ ...clip, reason, mp3Path, receiptPath }); }
}

const chars = planned.reduce((a, c) => a + c.text.length, 0);
console.log(`${generate ? 'GENERATE' : 'PLAN'}: ${planned.length} of ${clips.length} clip(s) need work (${chars} characters)`);
for (const c of planned) { console.log(`  ${c.role.padEnd(9)} ${c.id.padEnd(20)} [${c.reason}]  ${JSON.stringify(c.text)}`); }
if (!planned.length) { console.log('  everything is already current'); }

if (!generate) {
  console.log('\nplan only - no network request was made. Re-run with --generate to synthesise.');
  process.exit(0);
}

const apiKey = process.env.ELEVENLABS_API_KEY;
if (!apiKey) {
  console.error('\nELEVENLABS_API_KEY is not set. Export it from your secret store for this shell only;');
  console.error('do not add it to this repository.');
  process.exit(2);
}
const apiBase = (process.env.ELEVENLABS_API_BASE || 'https://api.elevenlabs.io').replace(/\/$/, '');
if (!apiBase.startsWith('https://')) { console.error('ELEVENLABS_API_BASE must be https'); process.exit(2); }

let ok = 0, failed = 0;
for (const clip of planned) {
  const voice = manifest.voices[clip.role];
  if (!voice) { console.error(`  FAIL ${clip.id}: manifest has no voice for role "${clip.role}"`); failed++; continue; }

  const body = {
    text: clip.text,
    model_id: clip.modelId || manifest.modelId,
    ...(voice.settings ? { voice_settings: voice.settings } : {}),
  };
  const url = `${apiBase}/v1/text-to-speech/${encodeURIComponent(voice.voiceId)}`
    + `?output_format=${encodeURIComponent(manifest.outputFormat)}&enable_logging=${manifest.enableLogging}`;

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'xi-api-key': apiKey, 'content-type': 'application/json', accept: 'audio/mpeg' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(120000),
    });
    if (!res.ok) { console.error(`  FAIL ${clip.id}: HTTP ${res.status} ${(await res.text()).slice(0, 200)}`); failed++; continue; }

    const bytes = Buffer.from(await res.arrayBuffer());
    // An ElevenLabs error can still arrive as 200 with a tiny body; a real mp3 starts ID3 or 0xFFFB.
    const looksLikeMp3 = bytes.slice(0, 3).toString('latin1') === 'ID3' || (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0);
    if (!looksLikeMp3 || bytes.length < 1000) { console.error(`  FAIL ${clip.id}: response is not a usable mp3 (${bytes.length} bytes)`); failed++; continue; }

    fs.mkdirSync(path.dirname(clip.mp3Path), { recursive: true });
    const tmp = `${clip.mp3Path}.partial`;
    fs.writeFileSync(tmp, bytes);
    fs.renameSync(tmp, clip.mp3Path);

    fs.writeFileSync(clip.receiptPath, JSON.stringify({
      id: clip.id,
      role: clip.role,
      generatedAt: new Date().toISOString(),
      voiceId: voice.voiceId,
      modelId: body.model_id,
      outputFormat: manifest.outputFormat,
      text: clip.text,
      textSha256: sha256(clip.text),
      audioSha256: sha256(bytes),
      bytes: bytes.length,
    }, null, 2) + '\n', 'utf8');

    console.log(`  ok   ${clip.role.padEnd(9)} ${clip.id.padEnd(20)} ${bytes.length} bytes`);
    ok++;
  } catch (err) {
    console.error(`  FAIL ${clip.id}: ${err.message}`);
    failed++;
  }
}

console.log(`\n${ok} generated, ${failed} failed. Files under ${path.relative(ROOT, OUT_DIR)}/`);
console.log('Listen to every line before wiring any of it into the game.');
process.exit(failed ? 1 : 0);
