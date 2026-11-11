#!/usr/bin/env node
// ZKR-57: генерирует Packages/ZikrKit/Sources/ZikrContent/Resources/map-content.json из Web/index.html
// (единственный источник): раскладка карт городов (makeCity с тем же детерминированным noise), порядок
// отрисовки (buildCity: depth, cat/chapter мест), местность 40×40, наложения, дальний план, палитра TERRAIN
// и GEO обзорной карты. Нативный экран «Карта» рисует ровно эти объекты в том же порядке.
// Рядом — map-draw.js: те же функции программной графики из index.html (drawObject, tileSprite, farSprite,
// drawOverlay, renderGround) без изменений. Native выполняет их в JavaScriptCore поверх записывающего
// Canvas 2D (map-canvas-shim.js) и воспроизводит команды в Core Graphics: спрайты рисует код веба.
//   node tools/zikr-map-from-web.mjs          — записать файлы
//   node tools/zikr-map-from-web.mjs --check  — проверить, что файлы актуальны (код выхода 1, если нет)
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const htmlPath = path.join(root, 'ZikrAdventure/Web/index.html');
const outPath = path.join(root, 'Packages/ZikrKit/Sources/ZikrContent/Resources/map-content.json');
const drawPath = path.join(root, 'Packages/ZikrKit/Sources/ZikrContent/Resources/map-draw.js');
// Блоки программной графики index.html: [начало, конец) — конец не входит.
export const DRAW_BLOCKS = [
  ['const HW = 32, HH = 16;', '/* ============================================================\n   КАРТЫ ГОРОДОВ'],
  ['/* ---------- тайлы, наложения, дальний слой ---------- */', '/* ---------- модель сцены ---------- */'],
  ['const tileVariant = ', '/* ---------- камера и отрисовка ---------- */'],
];
export const CITIES = ['mecca', 'medina'];

function between(script, startMarker, endMarker) {
  const start = script.indexOf(startMarker);
  const end = script.indexOf(endMarker, start);
  if (start < 0 || end < 0) throw new Error(`index.html: "${startMarker}" … "${endMarker}" not found`);
  return script.slice(start, end);
}

function readObject(script, name) {
  const start = script.indexOf(`const ${name} = {`);
  if (start < 0) throw new Error(`const ${name} = { … }; not found in index.html`);
  const open = start + `const ${name} = `.length;
  let depth = 0, quote = null;
  for (let i = open; i < script.length; i++) {
    const c = script[i];
    if (quote) { if (c === '\\') i++; else if (c === quote) quote = null; continue; }
    if (c === '"' || c === "'" || c === '`') quote = c;
    else if (c === '{') depth++;
    else if (c === '}' && --depth === 0) return vm.runInNewContext('(' + script.slice(open, i + 1) + ')');
  }
  throw new Error(`const ${name}: unbalanced braces`);
}

function readConst(script, name) {
  const start = script.indexOf(`const ${name} = [`);
  const end = script.indexOf('\n];', start);
  if (start < 0 || end < 0) throw new Error(`const ${name} = [ … ]; not found in index.html`);
  return vm.runInNewContext('(' + script.slice(start + `const ${name} = `.length, end + 2) + ')');
}

const OBJECT_KEYS = ['id', 'kind', 'place', 'sub', 'x', 'y', 'w', 'd', 'h', 'v', 'layer', 'name', 'cat', 'interactive', 'anim', 'markAt', 'markH', 'chapter', 'depth', 'shadow'];

export function build(html) {
  const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
  const noiseLine = script.match(/^const noise = .*$/m);
  if (!noiseLine) throw new Error('const noise = … not found in index.html');
  const geometry = between(script, 'const SIZE = 40, CEN = 20;', '/* ---------- тайлы');
  const ctx = vm.createContext({ console: { warn: () => {} }, Math });
  vm.runInContext(`${noiseLine[0]}\n${geometry}\nthis.makeCity = makeCity; this.SIZE = SIZE;`, ctx);
  const PLACES = readObject(script, 'PLACES');
  const chapters = [...readConst(script, 'CHAPTERS')].sort((a, b) => a.n - b.n);
  const chapterOfPlace = {};
  chapters.forEach((c) => { if (c.place) chapterOfPlace[c.place] = c.id; });
  const cities = {};
  for (const id of CITIES) {
    const def = ctx.makeCity(id);
    // buildCity(): глубина, категория и глава мест, тень; затем стабильная сортировка по глубине.
    def.objects.forEach((o) => {
      o.depth = (o.x + o.w - 1) + (o.y + o.d - 1) + (o.x + o.w - 1) * 0.001 + (o.place ? 0.5 : 0.2);
      if (o.place) { o.cat = PLACES[o.place].cat; o.interactive = true; o.chapter = chapterOfPlace[o.place] || null; }
      o.shadow = !['hotspot', 'baqi', 'jumua', 'graves', 'bush', 'trough'].includes(o.kind);
    });
    def.objects.sort((a, b) => a.depth - b.depth);
    const terrain = [];
    for (let y = 0; y < ctx.SIZE; y++) { const row = []; for (let x = 0; x < ctx.SIZE; x++) row.push(def.terrainAt(x, y)); terrain.push(row); }
    cities[id] = {
      focus: def.focus, base: def.base,
      // h у невидимой точки (hotspot) не задан — 0: спрайта у неё нет, маркер стоит по markAt / markH.
      objects: def.objects.map((o) => ({ h: 0, ...o })).map((o) => Object.fromEntries(OBJECT_KEYS.filter((k) => o[k] !== undefined && o[k] !== null).map((k) => [k, o[k]]))),
      overlays: def.overlays.map((ov) => ({ type: ov.type, pts: ov.pts, layer: ov.layer })),
      terrain,
      far: def.far.map((f) => ({ id: f.id, off: f.off, w: f.w, h: f.h, depth: f.depth, v: f.v, hills: !!f.hills })),
    };
  }
  const TERRAIN = readObject(script, 'TERRAIN');
  const terrainTypes = Object.fromEntries(Object.entries(TERRAIN).map(([k, [fill, detail, count]]) => [k, { fill, detail, count }]));
  const GEO = readObject(script, 'GEO');
  const geo = { ...GEO, cities: Object.fromEntries(Object.entries(GEO.cities).map(([k, [lon, lat, ar]]) => [k, { lon, lat, ar }])) };
  return { _generated: 'node tools/zikr-map-from-web.mjs — не править руками', size: ctx.SIZE, terrainTypes, cities, geo };
}

export function generate() {
  return JSON.stringify(build(fs.readFileSync(htmlPath, 'utf8'))) + '\n';
}

export function generateDraw() {
  const script = fs.readFileSync(htmlPath, 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
  const blocks = DRAW_BLOCKS.map(([a, b]) => between(script, a, b).trimEnd());
  return '// node tools/zikr-map-from-web.mjs — не править руками: программная графика карты из Web/index.html.\n'
    + '// Выполняется после map-canvas-shim.js (document, matchMedia, window, isOpen, state, SIZE).\n'
    + blocks.join('\n') + '\n';
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const text = generate(), draw = generateDraw();
  if (process.argv.includes('--check')) {
    const read = (p) => (fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : '');
    if (read(outPath) !== text || read(drawPath) !== draw) {
      console.error('map-content.json / map-draw.js устарели: запустите node tools/zikr-map-from-web.mjs');
      process.exit(1);
    }
    console.log('PASS: map-content.json + map-draw.js match index.html');
  } else {
    fs.writeFileSync(outPath, text);
    fs.writeFileSync(drawPath, draw);
    const doc = JSON.parse(text);
    console.log(`Wrote ${path.relative(root, outPath)}: ` + CITIES.map((c) => `${c} ${doc.cities[c].objects.length} objects, ${doc.cities[c].overlays.length} overlays`).join('; '));
  }
}
