const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const html = fs.readFileSync(`${__dirname}/../ZikrAdventure/Web/index.html`, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
new vm.Script(script);
function run(file) {
 const source = fs.readFileSync(file, 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
 const elements = Object.fromEntries(['z-total','z-today','z-session','z-undo','z-reset','z-progress','z-goal'].map(k=>[k,{}]));
 const stored = new Map(); let messages=[];
 const context = vm.createContext({ console, navigator:{language:'en'}, window:{webkit:{messageHandlers:{zikr:{postMessage:m=>messages.push(m)}}}}, localStorage:{getItem:k=>stored.get(k),setItem:(k,v)=>stored.set(k,v)}, setTimeout:()=>1,clearTimeout:()=>{},document:{getElementById:k=>elements[k]}, LANGS:[['en','English','en-US']], CHAPTERS:[], $:s=>elements[s.slice(1)],fmt:String,T:(key,...args)=>key+':'+args.join('/'), evaluate:()=>[], progressCard:()=>'', vibrate:()=>{}, tapSound:()=>{},motionReduced:()=>true,announce:()=>{},dayKey:()=> '2026-10-14' });
 vm.runInContext(source.slice(source.indexOf('const STORE_KEY'),source.indexOf('/* ---------- язык')),context);
 vm.runInContext('let session=0; const today=()=>state.daily[dayKey()]||0;',context);
 if(source.includes('function goalCard()')) vm.runInContext(source.slice(source.indexOf('function goalCard()'),source.indexOf('function renderZikr()')),context);
 vm.runInContext(source.slice(source.indexOf('function refreshZikr()'),source.indexOf('function openResetDialog()')),context);
 vm.runInContext('state.settings.goalOn=true; state.settings.goal=100; for(let i=0;i<75;i++) onZikr();',context);
 assert.equal(elements['z-total'].textContent,'75'); assert.equal(elements['z-today'].textContent,'75'); assert.equal(elements['z-session'].textContent,'75');
 const goalUpdated=elements['z-goal'].innerHTML?.includes('75%')||false;
 vm.runInContext('onUndo()',context);assert.equal(elements['z-total'].textContent,'74');
 if(goalUpdated) {assert.ok(elements['z-goal'].innerHTML.includes('74%'));assert.equal(JSON.parse(messages.at(-1).data).total,74);}
 // Native backup older than a locally saved reset must not resurrect the old total.
 const reset=vm.runInContext('state.total=0; persist(); JSON.stringify(state)',context);
 const backup=JSON.stringify({total:74,updatedAt:1});
 stored.set('zikr-adventure.v2',reset);context.window.__ZIKR_NATIVE_STATE=JSON.parse(backup);
 const restored=vm.createContext({...context});
 vm.runInContext(source.slice(source.indexOf('const STORE_KEY'),source.indexOf('/* ---------- язык')),restored);
 return {goalUpdated, restoredTotal:vm.runInContext('state.total',restored)};
}
const original=run(`${__dirname}/../../ZikrAdventure-AppStore/ZikrAdventure/Web/index.html`);
const fixed=run(`${__dirname}/../ZikrAdventure/Web/index.html`);
assert.equal(original.goalUpdated,false);assert.equal(original.restoredTotal,74);
assert.equal(fixed.goalUpdated,true);assert.equal(fixed.restoredTotal,0);
console.log('PASS: original bugs reproduced; 75 taps, undo, immediate native save and reset restoration verified in 1.0.1. Full inline JavaScript syntax valid.');
