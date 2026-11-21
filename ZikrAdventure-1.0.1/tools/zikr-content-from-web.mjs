#!/usr/bin/env node
// ZKR-52: генерирует Packages/ZikrKit/Sources/ZikrContent/Resources/zikr-content.json из LEVELS и CHAPTERS
// в Web/index.html (единственный источник): названия уровней и главы (id, порог, название, год) на 6 языках.
// ZKR-53: для экрана «Путь Сиры» — город, место, фокус и текст глав, карточки мест глав (PLACES),
// расстояния (DIST) и подписи Сафа/Марва (SAFA_MARWA).
//   node tools/zikr-content-from-web.mjs          — записать файл
//   node tools/zikr-content-from-web.mjs --check  — проверить, что файл актуален (код выхода 1, если нет)
// Правило как у tr() в index.html: нет перевода → русский.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const htmlPath = path.join(root, 'ZikrAdventure/Web/index.html');
const outPath = path.join(root, 'Packages/ZikrKit/Sources/ZikrContent/Resources/zikr-content.json');
export const LANGS = ['ru', 'en', 'uz', 'tg', 'kk', 'ky'];

function readConst(script, name) {
  const start = script.indexOf(`const ${name} = [`);
  const end = script.indexOf('\n];', start);
  if (start < 0 || end < 0) throw new Error(`const ${name} = [ … ]; not found in index.html`);
  return vm.runInNewContext('(' + script.slice(start + `const ${name} = `.length, end + 2) + ')');
}

function readObject(script, name) {
  const start = script.indexOf(`const ${name} = {`);
  if (start < 0) throw new Error(`const ${name} = { … }; not found in index.html`);
  const open = start + `const ${name} = `.length;
  // Конец объекта — парная закрывающая скобка (строки с { } внутри текстов не встречаются вне кавычек).
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

const localized = (obj) => Object.fromEntries(LANGS.map((l) => [l, (obj && (obj[l] || obj.ru)) || '']));

export function build(html) {
  const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
  const levels = readConst(script, 'LEVELS').map((l) => ({ from: l.from, to: l.to, name: localized(l.name) }));
  const chapters = [...readConst(script, 'CHAPTERS')]
    .sort((a, b) => a.n - b.n)
    .map((c) => ({
      id: c.id, n: c.n, title: localized(c.title), year: localized(c.year),
      city: c.city || null, place: c.place || null, focus: c.focus || null,
      text: c.text ? localized(c.text) : null,
    }));
  const allPlaces = readObject(script, 'PLACES');
  const allDist = readObject(script, 'DIST');
  const places = {};
  for (const id of chapters.map((c) => c.place).filter(Boolean)) {
    const p = allPlaces[id];
    if (!p) throw new Error(`PLACES.${id} not found`);
    places[id] = {
      ar: p.ar, city: p.city, cat: p.cat, name: localized(p.name), sig: localized(p.sig), look: localized(p.look), sira: localized(p.sira),
      dist: (allDist[id] || []).map(([m, dir, sub]) => ({ m, dir: dir || null, sub: sub === undefined ? null : sub })),
    };
  }
  const safaMarwa = Object.fromEntries(LANGS.map((l) => [l, readObject(script, 'SAFA_MARWA')[l] || readObject(script, 'SAFA_MARWA').ru]));
  return { _generated: 'node tools/zikr-content-from-web.mjs — не править руками', levels, chapters, places, safaMarwa };
}

export function generate() {
  return JSON.stringify(build(fs.readFileSync(htmlPath, 'utf8')), null, 2) + '\n';
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const text = generate();
  if (process.argv.includes('--check')) {
    const current = fs.existsSync(outPath) ? fs.readFileSync(outPath, 'utf8') : '';
    if (current !== text) {
      console.error('zikr-content.json устарел: запустите node tools/zikr-content-from-web.mjs');
      process.exit(1);
    }
    console.log('PASS: zikr-content.json matches LEVELS + CHAPTERS + PLACES in index.html');
  } else {
    fs.writeFileSync(outPath, text);
    const doc = JSON.parse(text);
    console.log(`Wrote ${path.relative(root, outPath)}: ${doc.levels.length} levels, ${doc.chapters.length} chapters, ${Object.keys(doc.places).length} places × ${LANGS.length} languages`);
  }
}
