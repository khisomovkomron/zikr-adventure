const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const html = fs.readFileSync(`${__dirname}/../ZikrAdventure/Web/index.html`, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
new vm.Script(script);
const methods = script.slice(script.indexOf('    completeOnboarding() {'), script.indexOf('    saveCamera('));
for (const page of [0, 1, 2]) {
  const original = { total: 123, daily: { '2026-11-18': 12 }, unlocked: ['a'], viewed: ['a'], cameras: { mecca: { x: 1, y: 2, z: 3 } }, settings: { lang: 'tg', sound: true }, onboarded: false };
  let saves = 0, closes = 0;
  const ctx = vm.createContext({ state: structuredClone(original), persist: () => saves++, closeOnboarding: () => closes++ });
  const api = vm.runInContext(`({${methods}})`, ctx);
  assert.deepEqual(JSON.parse(api.onboardingStatus()), { onboarded: false, language: 'tg' });
  assert.equal(api.completeOnboarding(), true);
  assert.equal(api.completeOnboarding(), true);
  assert.equal(saves, 1, 'completion is idempotent');
  assert.equal(closes, 2);
  assert.deepEqual(JSON.parse(JSON.stringify(ctx.state)), { ...original, onboarded: true });
}
const fn = script.slice(script.indexOf('function showOnboarding() {'), script.indexOf('function closeOnboarding()'));
vm.runInNewContext(fn + ';showOnboarding()', { window: { __ZIKR_NATIVE_ONBOARDING: true } });
console.log('PASS onboarding bridge: preserves progress, idempotent completion, native suppresses web UI');
