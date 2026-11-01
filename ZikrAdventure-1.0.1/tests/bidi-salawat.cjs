// ZKR-63 / ZKR-50: после ﷺ (U+FDFA, bidi-класс AL) пробелы/знаки препинания и цифра
// переупорядочиваются в LTR-тексте («Payg‘ambar ﷺ 622-yilda» → «622 ﷺ…»).
// За ﷺ в таких местах должен стоять U+200E (LRM).
//   node tests/bidi-salawat.cjs
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'ZikrAdventure/Web/index.html'), 'utf8');
const info = JSON.parse(fs.readFileSync(path.join(root, 'Packages/ZikrKit/Sources/ZikrContent/Resources/info-content.json'), 'utf8'));

const unsafe = /\uFDFA[\p{P}\p{Zs}]*\p{Nd}/u;
assert.ok(unsafe.test('Payg‘ambar \uFDFA 622-yilda'), 'detector catches the bug');
assert.ok(!unsafe.test('Payg‘ambar \uFDFA\u200E 622-yilda'), 'LRM makes it safe');

// Все строковые литералы во встроенном скрипте index.html (с раскрытыми \uXXXX).
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const literals = [...script.matchAll(/"((?:[^"\\\n]|\\.)*)"/g)].map((m) => vm.runInNewContext(m[0]));
const bad = literals.filter((s) => unsafe.test(s));
assert.deepStrictEqual(bad, [], 'index.html: ﷺ before a digit without LRM');

// Фраза о хиджре 622 года (Мечеть Пророка) в uz/kk/ky.
const placesStart = script.indexOf('nabawi: {');
const nabawi = vm.runInNewContext('({' + script.slice(placesStart, script.indexOf('\nbaqi:', placesStart)).replace(/,\s*$/, '') + '})').nabawi;
for (const lang of ['uz', 'kk', 'ky']) {
  assert.ok(nabawi.sira[lang].includes('\uFDFA\u200E 622'), `nabawi.sira [${lang}] has LRM after ﷺ before 622`);
}

let infoCount = 0;
for (const [lang, texts] of Object.entries(info.languages)) {
  for (const [key, text] of Object.entries(texts)) {
    infoCount += 1;
    assert.ok(!unsafe.test(text), `info-content.json ${lang}/${key}: ﷺ before a digit without LRM`);
  }
}
console.log(`PASS: ${literals.length} index.html strings and ${infoCount} Info texts have no ﷺ+digit bidi reordering; 622 phrase fixed in uz/kk/ky`);
