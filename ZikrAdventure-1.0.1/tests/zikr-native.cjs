// ZKR-52: window.zikrNative.tap / undo / reset / snapshot / explore — команды нативного экрана «Зикр».
// Веб остаётся единственным писателем счёта: каждая команда выполняет тот же код, что веб-экран
// (zikrTap / zikrUndo / zikrReset), сохраняет состояние (persist → "save") и возвращает снимок.
//   node tests/zikr-native.cjs
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const html = fs.readFileSync(`${__dirname}/../ZikrAdventure/Web/index.html`, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
new vm.Script(script);

const slice = (from, to) => {
  const a = script.indexOf(from), b = script.indexOf(to, a);
  assert.ok(a >= 0 && b > a, `block ${from} … ${to} not found`);
  return script.slice(a, b);
};

function makeContext({ isApp = true, total = 0, daily = {}, unlocked = [], tab = 'zikr' } = {}) {
  const calls = [];
  const ctx = vm.createContext({
    IS_APP: isApp, window: {}, console,
    CHAPTERS: [
      { id: 'ch01', n: 10, city: 'mecca', title: {}, year: {} },
      { id: 'ch02', n: 25, city: 'mecca', title: {}, year: {} },
      { id: 'ch19', n: 100000000, city: null, title: {}, year: {} },
    ],
    state: { total, daily: { ...daily }, unlocked: [...unlocked], viewed: ['ch01'], settings: { lang: 'ru' }, updatedAt: 5 },
    cities: { mecca: {} }, lastUnlockKey: { a: 1 }, currentTab: tab,
    persist: () => { ctx.state.updatedAt += 1; calls.push('persist'); },
    refreshZikr: () => calls.push('refreshZikr'),
    renderZikr: () => calls.push('renderZikr'),
    selectTab: (id) => calls.push('selectTab:' + id),
    explore: (ch) => calls.push('explore:' + ch.id),
    dayKey: () => '2026-11-11',
  });
  vm.runInContext('let session = 0; const today = () => state.daily[dayKey()] || 0;', ctx);
  vm.runInContext('const CH = [...CHAPTERS].sort((a, b) => a.n - b.n);', ctx);
  vm.runInContext(slice('function evaluate(silent)', 'const nextChapter'), ctx);
  vm.runInContext(slice('/* ---- ZKR-52', 'function onZikr()'), ctx);
  // Блок ZKR-50 (window.zikrNative) + снимок ZKR-52; функции настроек не вызываются.
  vm.runInContext(slice('/* ---- ZKR-50', 'function renderSettings()'), ctx);
  const raw = vm.runInContext('window.zikrNative', ctx);
  // Ответы — через JSON, как их получает native (evaluateJavaScript), и без кросс-realm массивов.
  const api = raw && Object.fromEntries(Object.keys(raw).map((k) => [k, (...a) => { const v = raw[k](...a); return v === undefined ? v : JSON.parse(JSON.stringify(v)); }]));
  return { ctx, calls, api };
}
const plain = (v) => JSON.parse(JSON.stringify(v));

// Вне приложения (браузер) API нет.
assert.equal(makeContext({ isApp: false }).api, undefined);

// tap: total+1, daily[today]+1, evaluate → свежие главы, persist, снимок.
{
  const { ctx, calls, api } = makeContext({ total: 9, daily: { '2026-11-11': 4 } });
  const r = api.tap();
  assert.equal(r.total, 10); assert.equal(r.today, 5); assert.equal(r.day, '2026-11-11');
  assert.deepEqual(r.fresh, ['ch01']); assert.deepEqual(r.unlocked, ['ch01']);
  assert.equal(r.updatedAt, ctx.state.updatedAt);
  assert.deepEqual(calls, ['persist', 'refreshZikr']);
  assert.equal(vm.runInContext('session', ctx), 1);
  assert.deepEqual(api.tap().fresh, [], 'глава открывается один раз');
}

// 200 нажатий подряд: без потерь, total и today совпадают.
{
  const { ctx, api } = makeContext();
  let last;
  for (let i = 0; i < 200; i++) last = api.tap();
  assert.equal(last.total, 200); assert.equal(last.today, 200);
  assert.equal(ctx.state.total, 200); assert.equal(ctx.state.daily['2026-11-11'], 200);
  assert.deepEqual(last.unlocked, ['ch01', 'ch02']);
}

// undo: −1 (не ниже 0), daily тоже; при 0 — null без записи.
{
  const { ctx, calls, api } = makeContext({ total: 3, daily: { '2026-11-11': 1 } });
  vm.runInContext('session = 2', ctx);
  assert.equal(api.undo().total, 2); assert.equal(ctx.state.daily['2026-11-11'], 0);
  assert.equal(api.undo().total, 1); assert.equal(ctx.state.daily['2026-11-11'], 0, 'daily не уходит ниже 0');
  assert.equal(vm.runInContext('session', ctx), 0);
  api.undo();
  const before = calls.length;
  assert.equal(api.undo(), null); assert.equal(calls.length, before, 'при 0 ничего не сохраняется');
}

// reset: counter — главы остаются, all — главы, просмотры и города сбрасываются; история остаётся.
{
  const { ctx, api } = makeContext({ total: 30, daily: { '2026-11-10': 7, '2026-11-11': 23 }, unlocked: ['ch01', 'ch02'] });
  const r = api.reset('counter');
  assert.equal(r.total, 0); assert.deepEqual(r.unlocked, ['ch01', 'ch02']);
  assert.deepEqual(plain(ctx.state.daily), { '2026-11-10': 7, '2026-11-11': 23 });
  const all = api.reset('all');
  assert.deepEqual(all.unlocked, []); assert.deepEqual(plain(ctx.state.viewed), []);
  assert.deepEqual(plain(Object.keys(ctx.cities)), []); assert.deepEqual(plain(vm.runInContext('lastUnlockKey', ctx)), {});
  assert.equal(api.reset('everything'), null, 'режим — только counter | all');
}

// explore: глава с городом — как bn-explore; без города — сначала «Путь Сиры».
{
  const { calls, api } = makeContext();
  assert.equal(api.explore('ch01'), true); assert.deepEqual(calls, ['explore:ch01']);
  assert.equal(api.explore('ch19'), true); assert.deepEqual(calls.slice(1), ['selectTab:path', 'explore:ch19']);
  assert.equal(api.explore('nope'), false);
}

// Веб-экран (выключатель false) использует те же функции.
for (const name of ['onZikr', 'onUndo']) {
  const body = slice(`function ${name}()`, '\n}');
  assert.ok(body.includes(name === 'onZikr' ? 'zikrTap()' : 'zikrUndo()'), `${name} не использует общий код`);
}
assert.ok(slice('function openResetDialog()', 'let bannerTimer').includes('zikrReset(m)'));
assert.ok(slice('function openHistory()', 'ЛИСТЫ И ДИАЛОГИ').includes('clearDailyHistory()'));

console.log('PASS: window.zikrNative tap/undo/reset/snapshot/explore; 200 taps без потерь; веб-экран использует тот же код.');
