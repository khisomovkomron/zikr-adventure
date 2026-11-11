#!/usr/bin/env node
// ZKR-52: генерирует Packages/ZikrKit/Sources/ZikrContent/Resources/zikr-content.json из LEVELS и CHAPTERS
// в Web/index.html (единственный источник): названия уровней и главы (id, порог, название, год) на 6 языках.
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

const localized = (obj) => Object.fromEntries(LANGS.map((l) => [l, (obj && (obj[l] || obj.ru)) || '']));

export function build(html) {
  const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
  const levels = readConst(script, 'LEVELS').map((l) => ({ from: l.from, to: l.to, name: localized(l.name) }));
  const chapters = [...readConst(script, 'CHAPTERS')]
    .sort((a, b) => a.n - b.n)
    .map((c) => ({ id: c.id, n: c.n, title: localized(c.title), year: localized(c.year) }));
  return { _generated: 'node tools/zikr-content-from-web.mjs — не править руками', levels, chapters };
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
    console.log('PASS: zikr-content.json matches LEVELS + CHAPTERS in index.html');
  } else {
    fs.writeFileSync(outPath, text);
    const doc = JSON.parse(text);
    console.log(`Wrote ${path.relative(root, outPath)}: ${doc.levels.length} levels, ${doc.chapters.length} chapters × ${LANGS.length} languages`);
  }
}
