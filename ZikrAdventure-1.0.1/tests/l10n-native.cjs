// ZKR-50: нативные строки (Localizable.xcstrings) совпадают с UI в index.html,
// а L10nKey.swift содержит ровно ключи каталога.
//   node tests/l10n-native.cjs
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
execFileSync(process.execPath, [path.join(root, 'tools/l10n-from-web.mjs'), '--check'], { stdio: 'inherit' });

const catalog = JSON.parse(fs.readFileSync(path.join(root, 'ZikrAdventure/Resources/Localizable.xcstrings'), 'utf8'));
const catalogKeys = Object.keys(catalog.strings).sort();
const swift = fs.readFileSync(path.join(root, 'ZikrAdventure/App/Localization/L10nKey.swift'), 'utf8');
const swiftKeys = [...swift.matchAll(/case \w+ = "([^"]+)"/g)].map((m) => m[1]).sort();
assert.deepStrictEqual(swiftKeys, catalogKeys, 'L10nKey.swift и Localizable.xcstrings разошлись');

for (const [key, entry] of Object.entries(catalog.strings)) {
  for (const lang of ['ru', 'en', 'uz', 'tg', 'kk', 'ky']) {
    const value = entry.localizations[lang]?.stringUnit?.value;
    assert.ok(value && value.trim(), `${key} [${lang}] пустая строка`);
  }
}
console.log(`PASS: ${catalogKeys.length} native keys × 6 languages match index.html; L10nKey in sync`);
