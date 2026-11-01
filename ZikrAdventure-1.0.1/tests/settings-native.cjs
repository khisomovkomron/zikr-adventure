// ZKR-50: window.zikrNative — команды нативного экрана «Настройки».
// Веб остаётся единственным писателем настроек; здесь проверяется белый список ключей,
// границы цели и то, что каждая команда сохраняет состояние (persist → "save").
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const html = fs.readFileSync(`${__dirname}/../ZikrAdventure/Web/index.html`, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
new vm.Script(script);

const start = script.indexOf('/* ---- ZKR-50');
const end = script.indexOf('function renderSettings()');
assert.ok(start > 0 && end > start, 'ZKR-50 block not found before renderSettings');
const applyLangSrc = script.match(/function applyLang\(code\) \{[^\n]*\n/)[0];

function makeContext(isApp) {
  const calls = [];
  const ctx = vm.createContext({
    IS_APP: isApp,
    window: {},
    document: { documentElement: { lang: 'ru' } },
    LANG_CODES: ['ru', 'en', 'uz', 'tg', 'kk', 'ky'],
    DEFAULT_SETTINGS: { haptics: true, sound: false, animations: true, banners: true, goalOn: false, goal: 100, translit: true, translation: true, keepAwake: false, preview: false },
    state: { settings: { lang: 'ru', haptics: true, sound: false, animations: true, banners: true, goalOn: false, goal: 100, translit: true, translation: true, keepAwake: false, preview: false }, daily: { '2026-10-31': 5, '2026-11-01': 7 }, total: 12 },
    cities: {}, lastUnlockKey: { a: 1 }, mapView: { mode: 'city', selected: 'x' }, worldVB: [], WORLD_FULL: [0, 0, 1, 1], session: 3,
    currentTab: 'settings', suppressTabChange: false,
    freshState: () => ({ settings: {}, daily: {}, total: 0, onboarded: false }),
    dayKey: () => '2026-11-01',
    L: () => 'ru',
    kick: () => {},
    persist: () => calls.push('persist'),
    applyMotionClass: () => calls.push('motion'),
    updateWakeLock: () => calls.push('wake'),
    renderAll: () => calls.push('renderAll:' + ctx.suppressTabChange),
    renderSettings: () => calls.push('renderSettings'),
    notifyLangChange: () => calls.push('lang.change'),
  });
  vm.runInContext(applyLangSrc + script.slice(start, end), ctx);
  return { ctx, calls, api: vm.runInContext('window.zikrNative', ctx) };
}

// Вне приложения (браузер) API нет.
assert.equal(makeContext(false).api, undefined, 'zikrNative must exist only in the app');

{
  const { ctx, calls, api } = makeContext(true);
  assert.ok(Object.isFrozen(api), 'API object is frozen');
  assert.equal(api.setSetting('sound', true), true);
  assert.equal(ctx.state.settings.sound, true);
  assert.deepEqual(calls.splice(0), ['persist', 'motion', 'wake', 'renderSettings']);

  // Белый список и типы.
  for (const [k, v] of [['preview', true], ['lang', 'en'], ['__proto__', true], ['sound', 'yes'], ['goal', '50'], ['goal', NaN], ['goal', Infinity], ['goal', 12.5]]) {
    assert.equal(api.setSetting(k, v), false, `rejected ${k}=${String(v)}`);
  }
  assert.equal(calls.length, 0, 'rejected commands do not persist');

  // Цель: только границы 10…10000, без округления до шага 10 (как раньше).
  for (const [input, expected] of [[120, 120], [124, 124], [125, 125], [4, 10], [-5, 10], [-50, 10], [99999, 10000]]) {
    assert.equal(api.setSetting('goal', input), true);
    assert.equal(ctx.state.settings.goal, expected, `goal ${input}`);
  }
  calls.length = 0;

  // Язык.
  assert.equal(api.setLang('de'), false);
  assert.equal(api.setLang(1), false);
  assert.equal(api.setLang('tg'), true);
  assert.equal(ctx.state.settings.lang, 'tg');
  assert.equal(ctx.document.documentElement.lang, 'tg');
  assert.deepEqual(calls.splice(0), ['persist', 'lang.change', 'renderAll:true']);
  assert.equal(ctx.suppressTabChange, false);

  // Очистка истории оставляет только сегодняшний день.
  assert.equal(api.clearHistory(), true);
  assert.deepEqual(JSON.parse(JSON.stringify(ctx.state.daily)), { '2026-11-01': 7 });

  // Сброс настроек сохраняет язык (L()).
  ctx.state.settings.keepAwake = true;
  assert.equal(api.resetDefaults(), true);
  assert.equal(ctx.state.settings.keepAwake, false);
  assert.equal(ctx.state.settings.lang, 'ru');

  // Полный сброс сохраняет настройки и не показывает онбординг снова.
  ctx.state.settings.sound = true;
  assert.equal(api.resetProgress(), true);
  assert.equal(ctx.state.total, 0);
  assert.equal(ctx.state.onboarded, true);
  assert.equal(ctx.state.settings.sound, true);
  assert.equal(ctx.session, 0);
}

console.log('PASS: window.zikrNative — whitelist, goal bounds, language, history, defaults and reset verified.');
