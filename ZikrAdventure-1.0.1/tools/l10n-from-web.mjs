#!/usr/bin/env node
// ZKR-50: генерирует ZikrAdventure/Resources/Localizable.xcstrings из словаря UI в Web/index.html
// (единственный источник текстов) + tools/l10n-native.json (строки только нативных экранов).
//   node tools/l10n-from-web.mjs          — записать файл
//   node tools/l10n-from-web.mjs --check  — проверить, что файл актуален (код выхода 1, если нет)
// Правила как у T() в index.html: нет ключа в языке → английский; "%1" → "%1$@".
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const htmlPath = path.join(root, 'ZikrAdventure/Web/index.html');
const nativePath = path.join(root, 'tools/l10n-native.json');
const outPath = path.join(root, 'ZikrAdventure/Resources/Localizable.xcstrings');

export const LANGS = ['ru', 'en', 'uz', 'tg', 'kk', 'ky'];
// ZKR-52: + экран «Зикр» (zikr, level, reset, banner, a11y и четыре строки path.* из progressCard()).
const NATIVE_EXTRA_KEYS = new Set(['info.privacy', 'path.title', 'path.next', 'path.remaining', 'path.opened']);
export const isNativeKey = (key) => /^(tab|common|set|auth|history|zikr|level|reset|banner|a11y)\./.test(key) || NATIVE_EXTRA_KEYS.has(key);

export function readWebUI(html) {
  const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
  const start = script.indexOf('const UI = {');
  const end = script.indexOf('\n};', start);
  if (start < 0 || end < 0) throw new Error('const UI = { … }; not found in index.html');
  return vm.runInNewContext('(' + script.slice(start + 'const UI = '.length, end + 2) + ')');
}

const toApple = (s) => s.replace(/%(\d)/g, '%$1$$@');

export function build(ui, native) {
  const strings = {};
  for (const key of Object.keys(ui.en).filter(isNativeKey)) {
    const localizations = {};
    for (const lang of LANGS) {
      const value = ui[lang]?.[key] ?? ui.en[key];
      localizations[lang] = { stringUnit: { state: 'translated', value: toApple(value) } };
    }
    strings[key] = { extractionState: 'manual', localizations };
  }
  for (const [key, entry] of Object.entries(native)) {
    if (key.startsWith('_')) continue;
    if (strings[key]) throw new Error(`${key}: already defined in index.html`);
    const localizations = {};
    for (const lang of LANGS) {
      const v = entry.values[lang] ?? entry.values.en;
      localizations[lang] = { stringUnit: { state: v.review ? 'needs_review' : 'translated', value: toApple(v.value) } };
    }
    strings[key] = { comment: entry.comment, extractionState: 'manual', localizations };
  }
  return { sourceLanguage: 'en', strings: sortKeys(strings), version: '1.0' };
}

function sortKeys(v) {
  if (Array.isArray(v)) return v.map(sortKeys);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map((k) => [k, sortKeys(v[k])]));
  return v;
}

// Формат как у Xcode (" : ", отступ 2 пробела), чтобы правка в Xcode не давала лишний diff.
export function serialize(doc) {
  return JSON.stringify(doc, null, 2).replace(/^(\s*"(?:[^"\\]|\\.)*"): /gm, '$1 : ') + '\n';
}

export function generate() {
  const ui = readWebUI(fs.readFileSync(htmlPath, 'utf8'));
  const native = JSON.parse(fs.readFileSync(nativePath, 'utf8'));
  return serialize(build(ui, native));
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const text = generate();
  if (process.argv.includes('--check')) {
    const current = fs.existsSync(outPath) ? fs.readFileSync(outPath, 'utf8') : '';
    if (current !== text) {
      console.error('Localizable.xcstrings устарел: запустите node tools/l10n-from-web.mjs');
      process.exit(1);
    }
    console.log('PASS: Localizable.xcstrings matches index.html + tools/l10n-native.json');
  } else {
    fs.writeFileSync(outPath, text);
    console.log(`Wrote ${path.relative(root, outPath)}: ${Object.keys(JSON.parse(text).strings).length} keys × ${LANGS.length} languages`);
  }
}
