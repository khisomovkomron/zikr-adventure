// ZKR-59: golden-сценарии из настоящих функций index.html; runtime приложения их не использует.
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'ZikrAdventure/Web/index.html'), 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
const content = JSON.parse(fs.readFileSync(path.join(root, 'Packages/ZikrKit/Sources/ZikrContent/Resources/zikr-content.json')));
const slice = (a, b) => { const i = source.indexOf(a), j = source.indexOf(b, i); assert(i >= 0 && j > i); return source.slice(i, j); };
const now = 1795089600000; // 2026-11-19 12:00 UTC; clock rollback stays on the same local day.
const day = '2026-11-19';
function run(name, initial, commands) {
  const ctx = vm.createContext({ IS_APP: true, window: {}, CHAPTERS: content.chapters,
    detectLang: () => 'ru', LANG_CODES: ['ru','en','uz','tg','kk','ky'],
    Date: { now: () => ctx.now }, now, day, dayKey: () => ctx.day,
    currentTab: 'zikr', cities: {}, lastUnlockKey: {}, mapView: {}, WORLD_FULL: [], worldVB: [],
    document: { documentElement: {} }, localStorage: { setItem() {} },
    setTimeout() {}, clearTimeout() {}, pushCloud() {}, flushNative() {},
    applyMotionClass() {}, updateWakeLock() {}, renderAll() {}, renderSettings() {}, refreshZikr() {}, renderZikr() {},
    stopCityLoop() {}, closeOnboarding() {}, notifyLangChange() {}, kick() {}, renderMap() {},
    buildCity: () => ({objects: []}), openSheet() {}, chapterCard() {},
    selectTab: id => { ctx.currentTab = id; },
  });
  vm.runInContext(slice('const DEFAULT_SETTINGS', 'function sanitize(s)'), ctx);
  vm.runInContext('let state = freshState(); let session=0, saveTimer=null, suppressTabChange=false; const L=()=>state.settings.lang; const today=()=>state.daily[dayKey()]||0;', ctx);
  ctx.initial = initial;
  vm.runInContext('Object.assign(state, initial); state.updatedAt ??= null;', ctx);
  vm.runInContext(slice('function persist()', 'function flushNative()'), ctx);
  vm.runInContext('const CH = [...CHAPTERS].sort((a,b)=>a.n-b.n); const isOpen=id=>state.settings.preview||state.unlocked.includes(id);',ctx);
  vm.runInContext(slice('function evaluate(silent)', 'const nextChapter'),ctx);
  vm.runInContext(source.match(/const markViewed = [^\n]+/)[0],ctx);
  vm.runInContext(slice('/* ---- ZKR-52', 'function onZikr()'),ctx);
  vm.runInContext(slice('function chapterFocus(ch)', '/* ============================================================'),ctx);
  vm.runInContext(slice('function openCity(id', 'function renderCity()'),ctx);
  vm.runInContext(source.match(/function applyLang\(code\) \{[^\n]+/)[0],ctx);
  vm.runInContext('const GEO={cities:{mecca:[0,0],medina:[0,0]}};const proj=(...v)=>v;',ctx);
  vm.runInContext(slice('/* ---- ZKR-50', 'function renderSettings()'),ctx);
  const plain = () => JSON.parse(vm.runInContext('JSON.stringify(state)',ctx));
  const first = plain();
  const steps = commands.map(command => {
    ctx.now = command.now ?? now; ctx.day = command.day ?? day;
    const args = command.name === 'setSetting' ? [command.field, command.bool ?? command.int] :
      command.name === 'saveCamera' ? [command.text,command.camera.x,command.camera.y,command.camera.z] :
      ['setLang','markViewed','showChapter','explore','selectCity','reset'].includes(command.name) ? [command.text ?? null] : [];
    const result = ctx.window.zikrNative[command.name](...args);
    return {command: {...command, now: ctx.now}, expected: plain(), fresh: result?.fresh ?? []};
  });
  return {name, initial:first, steps};
}
const fixture = [
 run('tap-unlock-undo-reset', {total:9,daily:{[day]:9}}, [{name:'tap'},{name:'undo'},{name:'tap'},{name:'reset',text:'counter'},{name:'tap'},{name:'reset',text:'all'}]),
 run('midnight-clock-rollback', {total:4,daily:{'2026-11-18':4}}, [{name:'undo'},{name:'tap'},{name:'tap',day:'2026-11-20',now:now+86400000},{name:'tap',now:now-1000},{name:'clearHistory'}]),
 run('settings-onboarding-and-full-reset', {total:42,cameras:{mecca:{x:2,y:3,z:1}},city:'mecca'}, [
   {name:'setSetting',field:'goal',int:333},{name:'setSetting',field:'goal',int:20000},
   {name:'setSetting',field:'sound',bool:true},{name:'setLang',text:'ky'},{name:'resetDefaults'},
   {name:'completeOnboarding'},{name:'completeOnboarding'},{name:'resetProgress'}]),
 run('chapters-and-map', {total:5000,unlocked:['ch01','ch09','ch19']}, [
   {name:'markViewed',text:'ch01'},{name:'markViewed',text:'ch01'}, {name:'showChapter',text:'ch09'},
   {name:'explore',text:'ch19'},{name:'selectCity',text:'mecca'},
   {name:'saveCamera',text:'mecca',camera:{x:-20,y:15,z:1.4}},{name:'selectCity'},
   {name:'reset',text:'all'}]),
];
const output=JSON.stringify(fixture,null,2)+'\n';
const target=path.join(root,'Packages/ZikrKit/Tests/ZikrPersistenceTests/Fixtures/native-command-parity.json');
if(process.argv.includes('--check')) { assert.equal(fs.readFileSync(target,'utf8'),output,'Regenerate native command fixtures'); console.log('PASS: native command fixtures match current web actions'); }
else { fs.writeFileSync(target,output); console.log(`Generated ${fixture.reduce((n,x)=>n+x.steps.length,0)} parity steps`); }
