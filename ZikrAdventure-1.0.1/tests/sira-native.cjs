// ZKR-53: window.zikrNative.markViewed / showChapter — запись нативного экрана «Путь Сиры».
// Лист главы рисует native, веб остаётся единственным писателем: команды вызывают те же
// markViewed / openCity / chapterFocus, что веб-кнопки «Читать» (chapterCard / placeCard) и «На карте» (data-go).
//   node tests/sira-native.cjs
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const html = fs.readFileSync(`${__dirname}/../ZikrAdventure/Web/index.html`, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
new vm.Script(script);

const slice = (from, to) => {
  const a = script.indexOf(from), b = script.indexOf(to, a);
  assert.ok(a >= 0 && b > a, `block ${from} … ${to} not found`);
  return script.slice(a, b);
};
const line = (from) => slice(from, '\n');

function makeContext({ isApp = true, unlocked = [], viewed = [], preview = false } = {}) {
  const calls = [];
  const ctx = vm.createContext({
    IS_APP: isApp, window: {}, console,
    CHAPTERS: [
      { id: 'ch01', n: 10, city: 'mecca', place: null, focus: 'kaaba', title: {}, year: {} },
      { id: 'ch05', n: 250, city: 'mecca', place: 'hira', title: {}, year: {} },
      { id: 'ch06', n: 500, city: 'mecca', place: 'safamarwa', title: {}, year: {} },
      { id: 'ch19', n: 100000000, city: null, place: null, title: {}, year: {} },
    ],
    state: { total: 0, daily: {}, unlocked: [...unlocked], viewed: [...viewed], settings: { lang: 'ru', preview }, updatedAt: 5 },
    cities: {}, lastUnlockKey: {}, currentTab: 'path',
    persist: () => { ctx.state.updatedAt += 1; calls.push('persist'); },
    openCity: (id, focus) => calls.push(`openCity:${id}:${focus}`),
    selectTab: (id) => calls.push('selectTab:' + id),
    explore: (ch) => calls.push('explore:' + ch.id),
    dayKey: () => '2026-11-11',
  });
  vm.runInContext('let session = 0; const today = () => state.daily[dayKey()] || 0;', ctx);
  vm.runInContext('const CH = [...CHAPTERS].sort((a, b) => a.n - b.n);', ctx);
  vm.runInContext(line('const isOpen = '), ctx);
  vm.runInContext(line('const markViewed = '), ctx);
  vm.runInContext(line('function chapterFocus(ch)'), ctx);
  vm.runInContext(slice('/* ---- ZKR-50', 'function renderSettings()'), ctx);
  const api = vm.runInContext('window.zikrNative', ctx);
  return { ctx, calls, api };
}
const plain = (v) => JSON.parse(JSON.stringify(v));

assert.equal(makeContext({ isApp: false }).api, undefined, 'вне приложения API нет');

// markViewed: открытая глава — в viewed один раз (persist → "save"), закрытая и неизвестная — false без записи.
{
  const { ctx, calls, api } = makeContext({ unlocked: ['ch01'] });
  assert.equal(api.markViewed('ch01'), true);
  assert.deepEqual(plain(ctx.state.viewed), ['ch01']); assert.deepEqual(calls, ['persist']);
  assert.equal(api.markViewed('ch01'), true); assert.deepEqual(calls, ['persist'], 'повторно не сохраняется');
  assert.equal(api.markViewed('ch05'), false, 'закрытая глава');
  assert.equal(api.markViewed('nope'), false);
  assert.deepEqual(plain(ctx.state.viewed), ['ch01']); assert.deepEqual(calls, ['persist']);
}

// Предпросмотр: все главы открыты (isOpen) — «Читать» отмечает просмотр, как placeCard в вебе.
{
  const { ctx, api } = makeContext({ preview: true });
  assert.equal(api.markViewed('ch05'), true); assert.deepEqual(plain(ctx.state.viewed), ['ch05']);
}

// showChapter = data-go: markViewed + openCity(city, chapterFocus(ch)).
{
  const { ctx, calls, api } = makeContext({ unlocked: ['ch01', 'ch05', 'ch06', 'ch19'] });
  assert.equal(api.showChapter('ch01'), true); assert.deepEqual(calls, ['persist', 'openCity:mecca:kaaba']);
  assert.equal(api.showChapter('ch05'), true); assert.deepEqual(calls.slice(2), ['persist', 'openCity:mecca:nur'], 'hira → nur');
  assert.equal(api.showChapter('ch06'), true); assert.deepEqual(calls.slice(4), ['persist', 'openCity:mecca:safa'], 'safamarwa → safa');
  assert.deepEqual(plain(ctx.state.viewed), ['ch01', 'ch05', 'ch06']);
  assert.equal(api.showChapter('ch19'), false, 'без города кнопки «На карте» нет');
  assert.equal(api.showChapter('nope'), false);
  assert.equal(calls.length, 6);
}
{
  const { calls, api } = makeContext();
  assert.equal(api.showChapter('ch01'), false, 'закрытая глава'); assert.deepEqual(calls, []);
}

// Веб-экран (выключатель false) пишет так же: «Читать» → chapterCard/placeCard → markViewed, «На карте» → data-go.
assert.ok(slice('function chapterCard(', '\n}').includes('markViewed(ch.id)'));
assert.ok(slice('function placeCard(', '\n}').includes('markViewed(ch.id)'));
assert.ok(slice('function renderPath()', 'ИНФОРМАЦИЯ И НАСТРОЙКИ').includes('markViewed(ch.id); openCity(ch.city, chapterFocus(ch))'));

console.log('PASS: window.zikrNative markViewed/showChapter (открытые главы, предпросмотр, hira→nur, safamarwa→safa); веб-экран пишет так же.');
