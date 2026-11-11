// ZKR-57: window.zikrNative.selectCity / saveCamera — запись нативного экрана «Карта».
// Карту рисует native, веб остаётся единственным писателем: selectCity = selectWorldCity (state.city),
// saveCamera = saveCam (state.cameras[id]). Плюс актуальность map-content.json (генератор --check).
//   node tests/map-native.cjs
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const html = fs.readFileSync(`${__dirname}/../ZikrAdventure/Web/index.html`, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
new vm.Script(script);

const slice = (from, to) => {
  const a = script.indexOf(from), b = script.indexOf(to, a);
  assert.ok(a >= 0 && b > a, `block ${from} … ${to} not found`);
  return script.slice(a, b);
};

function makeContext({ isApp = true, currentTab = 'zikr', mode = 'world' } = {}) {
  const calls = [];
  const ctx = vm.createContext({
    IS_APP: isApp, window: {}, console, Math, Number,
    CHAPTERS: [], state: { cameras: {}, city: null, settings: {} },
    cities: {}, currentTab, mapView: { mode, city: null, selected: null },
    persist: () => calls.push('persist'),
    renderMap: () => calls.push('renderMap'),
    stopCityLoop: () => calls.push('stopCityLoop'),
    dayKey: () => '2026-11-11',
  });
  vm.runInContext('let session = 0;', ctx);
  vm.runInContext(slice('const GEO = {', 'function renderMap()').replace(/^if \(mapView\.selected\).*$/m, ''), ctx);
  vm.runInContext('const SIZE = 40, HW = 32, HH = 16; const ZMIN = 1 / 2.6, ZMAX = 1 / 0.45;', ctx);
  vm.runInContext(slice('function clampCam(city)', 'function saveCam'), ctx);
  vm.runInContext(slice('/* ---- ZKR-50', 'function renderSettings()'), ctx);
  return { ctx, calls, api: vm.runInContext('window.zikrNative', ctx), get: (expr) => vm.runInContext(expr, ctx) };
}
const plain = (v) => JSON.parse(JSON.stringify(v));

assert.equal(makeContext({ isApp: false }).api, undefined, 'вне приложения API нет');

// selectCity: город или null → state.city + persist; viewBox обзорной карты как после selectWorldCity.
{
  const { ctx, calls, api, get } = makeContext();
  assert.equal(api.selectCity('mecca'), true);
  assert.equal(ctx.state.city, 'mecca'); assert.equal(ctx.mapView.selected, 'mecca');
  const [x, y] = get('proj(...GEO.cities.mecca)');
  assert.deepEqual(plain(get('worldVB')), [x - 170, y - 150, 340, 400]);
  assert.deepEqual(calls, ['persist'], 'веб-вкладка не «Карта» — без перерисовки');
  assert.equal(api.selectCity(null), true);
  assert.equal(ctx.state.city, null); assert.deepEqual(plain(get('worldVB')), [-440, -420, 800, 740]);
  assert.equal(api.selectCity('cairo'), false); assert.equal(api.selectCity(5), false); assert.equal(api.selectCity(undefined), false);
  assert.deepEqual(calls, ['persist', 'persist']);
}
{
  const { calls, api } = makeContext({ currentTab: 'map' });
  assert.equal(api.selectCity('medina'), true);
  assert.deepEqual(calls, ['persist', 'renderMap'], 'на веб-вкладке «Карта» обзор перерисовывается');
}

// Веб остался в режиме города (веб-explore до включения native): цикл останавливается, режим — обзор.
{
  const { ctx, calls, api } = makeContext({ mode: 'city' });
  assert.equal(api.selectCity('mecca'), true);
  assert.equal(ctx.mapView.mode, 'world'); assert.deepEqual(calls, ['stopCityLoop', 'persist']);
}

// saveCamera: числа → state.cameras[id] + persist; построенный город получает ту же камеру (clampCam).
{
  const { ctx, calls, api } = makeContext();
  assert.equal(api.saveCamera('mecca', 10, 620, 1.25), true);
  assert.deepEqual(plain(ctx.state.cameras), { mecca: { x: 10, y: 620, z: 1.25 } }); assert.deepEqual(calls, ['persist']);
  ctx.cities.medina = { id: 'medina', cam: { x: 0, y: 0, z: 1 } };
  assert.equal(api.saveCamera('medina', 5, 6, 99), true);
  assert.deepEqual(plain(ctx.state.cameras.medina), { x: 5, y: 6, z: 1 / 0.45 }, 'как clampCam');
  assert.equal(api.saveCamera('mecca', NaN, 1, 1), false);
  assert.equal(api.saveCamera('mecca', 1, 1, '2'), false);
  assert.equal(api.saveCamera('rome', 1, 1, 1), false);
  assert.equal(calls.length, 2);
}

// map-content.json совпадает с makeCity/TERRAIN/GEO в index.html.
execFileSync(process.execPath, [`${__dirname}/../tools/zikr-map-from-web.mjs`, '--check'], { stdio: 'inherit' });

console.log('PASS: map native API (selectCity / saveCamera) + map-content.json');

// map-draw.js (графика из index.html) выполняется поверх map-canvas-shim.js для всех объектов, тайлов,
// дальнего плана и земли — как это делает MapSpriteFactory в JavaScriptCore.
{
  const res = `${__dirname}/../Packages/ZikrKit/Sources/ZikrContent/Resources`;
  const ctx = vm.createContext({ Math, JSON });
  vm.runInContext(fs.readFileSync(`${res}/map-canvas-shim.js`, 'utf8'), ctx);
  vm.runInContext(fs.readFileSync(`${res}/map-draw.js`, 'utf8'), ctx);
  const content = JSON.parse(fs.readFileSync(`${res}/map-content.json`, 'utf8'));
  const kinds = new Set(['fill', 'stroke', 'fillRect', 'strokeRect', 'image', 'clip', 'save', 'restore', 'scale', 'translate', 'rotate',
    'begin', 'close', 'move', 'line', 'quad', 'ellipse']);
  let sprites = 0;
  for (const id of ['mecca', 'medina']) {
    const city = content.cities[id];
    ctx.__reset(['ch01', 'ch08'], false);
    for (const o of city.objects) {
      const s = JSON.parse(ctx.__sprite(o));
      if (o.kind === 'hotspot') { assert.equal(s, null); continue; }
      assert.ok(s.W > 0 && s.H > 0, `${id}/${o.id}`);
      const c = JSON.parse(ctx.__canvasJSON(s.canvas));
      assert.ok(c.ops.length > 2, `${o.id}: ops`); c.ops.forEach((op) => assert.ok(kinds.has(op[0]), `${o.id}: ${op[0]}`));
      sprites++;
    }
    city.far.forEach((el) => assert.ok(JSON.parse(ctx.__canvasJSON(ctx.__far(el))).ops.some((op) => op[0] === 'fill')));
    const g = JSON.parse(ctx.__ground(city.terrain, city.overlays, ['ch01'], false));
    assert.deepEqual([g.W, g.H, g.ox], [2560, 1280, 1280]);
    const ops = JSON.parse(ctx.__canvasJSON(g.canvas)).ops;
    assert.equal(ops.filter((op) => op[0] === 'image').length, 1600, 'все тайлы 40×40');
  }
  assert.equal(sprites, 84 + 109 - JSON.stringify(content).split('"hotspot"').length + 1);
  console.log(`PASS: map-draw.js renders ${sprites} sprites + far + ground through map-canvas-shim.js`);
}
