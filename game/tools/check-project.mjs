#!/usr/bin/env node
/**
 * check-project - static health check for the Iron Dust Rally Godot project.
 *
 * WHY THIS EXISTS (2026-08-23)
 * ---------------------------
 * Godot is not installed on this fleet, so nothing can open the project and tell us whether
 * it is sound. That left real breakage invisible: the project has no `project.godot` at all,
 * which means it does not open in the editor AND its autoloads are unregistered - and five
 * scripts are referenced by name as globals (MenuInput, Tracks, Vehicles, TrackGeometry,
 * Racer) across ~26 call sites that would every one of them fail at runtime.
 *
 * These checks are all static, so they run anywhere, need no engine, and are cheap enough for
 * an agent to run on every pass. Each finding names the file and says what it breaks - a
 * report that says "3 problems" and not which ones is a report nobody can act on.
 *
 * Exit code is always 0: findings are the product, and a non-zero exit makes the fleet's cron
 * runner mark the job failed and suppress its delivery.
 */

import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || path.join(import.meta.dirname, '..'));
const findings = [];
const note = (severity, what, detail) => findings.push({ severity, what, detail });

const read = p => { try { return fs.readFileSync(p, 'utf8'); } catch { return ''; } };
const listFiles = (dir, ext) => {
  try { return fs.readdirSync(path.join(ROOT, dir)).filter(f => f.endsWith(ext)).map(f => path.join(dir, f)); }
  catch { return []; }
};

const scenes = listFiles('scenes', '.tscn');
const scripts = listFiles('scripts', '.gd');

// 1. The project file. Without it Godot has no project to open and no autoload table.
if (!fs.existsSync(path.join(ROOT, 'project.godot'))) {
  note('CRITICAL', 'project.godot is missing',
    'Godot cannot open this directory as a project, and every autoload registration lives in '
    + 'this file - so the globals below are all unbound at runtime.');
}

// 2. Globals used but not registered. In Godot a name like `Tracks.get_all()` only resolves
//    because project.godot maps that name to a script. Unregistered, it is a hard crash.
const projectText = read(path.join(ROOT, 'project.godot'));
const registered = new Set([...projectText.matchAll(/^\s*([A-Za-z_]\w*)\s*=\s*"\*?res:\/\//gm)].map(m => m[1]));
const globalUse = new Map();
for (const s of scripts) {
  const body = read(path.join(ROOT, s));

  // A name is only "global" if nothing in THIS file already binds it. GDScript's usual way of
  // reaching another script is `const Thing = preload("res://...")` at the top of the file, and
  // a name bound that way is fully resolved - reporting it as an unregistered autoload is a
  // false alarm. TrackGeometry was exactly this: bound by preload in both files that use it.
  const locallyBound = new Set(
    [...body.matchAll(/^\s*(?:const|var)\s+([A-Za-z_]\w*)\s*(?::=|=|:\s*\w+\s*=)\s*(?:preload|load)\s*\(/gm)]
      .map(m => m[1]));

  for (const m of body.matchAll(/\b([A-Z][A-Za-z0-9_]*)\s*\./g)) {
    const name = m[1];
    if (locallyBound.has(name)) { continue; }
    // Skip Godot's own built-in singletons and common built-in types.
    if (/^(Input|OS|Engine|Time|JSON|Vector[23]|Color|Node|Resource|Callable|Signal|String|Array|Dictionary|Math|ProjectSettings|DisplayServer|RenderingServer|SceneTree|Object|Variant|Transform[23]D|Basis|Quaternion|AABB|Rect2|PackedScene|Image|Texture2D|Font|Theme|Tween|Timer|Label|Button|Control|Sprite2D|Area2D|Camera[23]D|CharacterBody[23]D|RigidBody[23]D|StaticBody[23]D|CollisionShape[23]D|AnimationPlayer|AudioStreamPlayer)$/.test(name)) { continue; }
    globalUse.set(name, (globalUse.get(name) || 0) + 1);
  }
}
for (const [name, count] of [...globalUse].sort((a, b) => b[1] - a[1])) {
  const looksLikeOurs = scripts.some(s => path.basename(s, '.gd').replace(/_/g, '').toLowerCase() === name.toLowerCase());
  if (looksLikeOurs && !registered.has(name)) {
    note('CRITICAL', `global "${name}" is used ${count}x but not registered as an autoload`,
      `scripts/${name.replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase()}.gd exists, but nothing binds the name - every call site fails at runtime.`);
  }
}

// 3. Broken resource references, in both directions.
for (const scene of scenes) {
  for (const m of read(path.join(ROOT, scene)).matchAll(/path="res:\/\/([^"]+)"/g)) {
    if (!fs.existsSync(path.join(ROOT, m[1]))) {
      note('CRITICAL', `${scene} references a file that does not exist`, `res://${m[1]}`);
    }
  }
}
for (const script of scripts) {
  for (const m of read(path.join(ROOT, script)).matchAll(/res:\/\/([A-Za-z0-9_\-/.]+\.(tscn|gd|png|tres))/g)) {
    if (!fs.existsSync(path.join(ROOT, m[1]))) {
      note('CRITICAL', `${script} references a file that does not exist`, `res://${m[1]}`);
    }
  }
}

// 4. Editor leftovers. Harmless individually, but .bak files next to real scripts are how a
//    stale copy gets edited by mistake.
// Catch any shadow copy of a live script, not just ".bak". main.gd.pre-rallyracer was a stale
// copy of the exact file whose Racer.new() bug was being fixed - it still contains the broken
// call, and an editor that opens it by name-completion will silently work on the wrong file.
const baks = [];
const walk = d => {
  let entries = [];
  try { entries = fs.readdirSync(path.join(ROOT, d), { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    const rel = path.join(d, e.name);
    if (e.isDirectory()) { walk(rel); }
    // .uid and .import are Godot's own sidecar metadata and belong next to the file.
    else if (/\.(gd|tscn|tres)\.(?!uid$|import$)[A-Za-z0-9_.-]+$/.test(e.name) || e.name.endsWith('.bak')) { baks.push(rel); }
  }
};
walk('.');
if (baks.length) {
  note('WARNING', `${baks.length} stale copy/copies of live project files`,
    baks.join(', ') + ' - these shadow the real file and can be edited by mistake');
}

// 5. Scripts nothing points at. Not necessarily wrong - an autoload is referenced by name, not
//    by path - so this is only reported once autoloads are accounted for.
const referenced = new Set();
for (const scene of scenes) {
  for (const m of read(path.join(ROOT, scene)).matchAll(/path="res:\/\/([^"]+)"/g)) { referenced.add(m[1].replace(/\\/g, '/')); }
}
// A script pulled in by another script's preload/load is referenced just as surely as one
// attached to a scene - track_geometry.gd is reached only this way.
for (const s of scripts) {
  for (const m of read(path.join(ROOT, s)).matchAll(/(?:preload|load)\s*\(\s*"res:\/\/([^"]+)"/g)) {
    referenced.add(m[1].replace(/\\/g, '/'));
  }
}
// A script is NOT an orphan if project.godot registers it as an autoload, or if it declares a
// class_name that the rest of the code constructs. Guessing the global from the filename is not
// enough on its own: ui_atlas.gd registers as "UIAtlas", but a naive guess yields "UiAtlas" and
// so reported a live autoload as dead. racer.gd was the same story via `class_name RallyRacer`.
const autoloadPaths = new Set(
  [...projectText.matchAll(/^\s*[A-Za-z_]\w*\s*=\s*"\*?res:\/\/([^"]+)"/gm)].map(m => m[1]));

const orphans = scripts
  .map(s => s.replace(/\\/g, '/'))
  .filter(s => !referenced.has(s))
  .filter(s => !autoloadPaths.has(s))
  .filter(s => {
    const declared = read(path.join(ROOT, s)).match(/^\s*class_name\s+([A-Za-z_]\w*)/m);
    if (declared && globalUse.has(declared[1])) { return false; }
    const guess = path.basename(s, '.gd').split('_').map(w => w[0].toUpperCase() + w.slice(1)).join('');
    return !globalUse.has(guess);
  });
if (orphans.length) {
  note('INFO', `${orphans.length} script(s) neither attached to a scene nor used as a global`, orphans.join(', '));
}

// ---------------------------------------------------------------- report
const order = { CRITICAL: 0, WARNING: 1, INFO: 2 };
findings.sort((a, b) => order[a.severity] - order[b.severity]);

console.log(`Iron Dust Rally — static project check`);
console.log(`root: ${ROOT}`);
console.log(`${scenes.length} scenes, ${scripts.length} scripts\n`);

if (!findings.length) {
  console.log('No problems found.');
} else {
  for (const f of findings) {
    console.log(`${f.severity.padEnd(8)} ${f.what}`);
    console.log(`         ${f.detail}\n`);
  }
  const crit = findings.filter(f => f.severity === 'CRITICAL').length;
  console.log(`${findings.length} finding(s), ${crit} critical`);
}

process.exit(0);
