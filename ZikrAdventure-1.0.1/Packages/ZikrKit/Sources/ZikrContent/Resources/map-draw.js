// node tools/zikr-map-from-web.mjs — не править руками: программная графика карты из Web/index.html.
// Выполняется после map-canvas-shim.js (document, matchMedia, window, isOpen, state, SIZE).
const HW = 32, HH = 16;
const iso = (gx, gy) => [(gx - gy) * HW, (gx + gy) * HH];
const isDarkTheme = () => matchMedia("(prefers-color-scheme: dark)").matches;
const DPR = Math.min(window.devicePixelRatio || 1, 2);
function mkCanvas(w, h, scale = DPR) { const c = document.createElement("canvas"); c.width = Math.ceil(w * scale); c.height = Math.ceil(h * scale); const x = c.getContext("2d"); x.scale(scale, scale); return [c, x]; }
function hexTo(hex) { const n = parseInt(hex.slice(1), 16); return [n >> 16, (n >> 8) & 255, n & 255]; }
function shadeHex(hex, f) { const c = hexTo(hex).map((v) => Math.max(0, Math.min(255, Math.round(v * f)))); return "#" + c.map((v) => v.toString(16).padStart(2, "0")).join(""); }
const noise = (seed, salt) => (((seed * 1103515245 + salt * 12345) >>> 0) % 1000) / 1000;
function pal(hex) { return { top: shadeHex(hex, 1.08), left: shadeHex(hex, .9), right: shadeHex(hex, .72), edge: shadeHex(hex, .55) }; }
function makeCanvasFor(o, top) {
  const W = (o.w + o.d) * HW, H = (o.w + o.d) * HH + top;
  const [cv, cx] = mkCanvas(W, H);
  const p = (u, v, z = 0) => [(u - v) * HW + o.d * HW, top + (u + v) * HH - z];
  return { cv, cx, p, w: o.w, d: o.d, top, W, H };
}
function poly(cx, pts, fill, stroke, lw = .8) { cx.beginPath(); cx.moveTo(...pts[0]); for (const q of pts.slice(1)) cx.lineTo(...q); cx.closePath(); cx.fillStyle = fill; cx.fill(); if (stroke) { cx.strokeStyle = stroke; cx.lineWidth = lw; cx.lineJoin = "round"; cx.stroke(); } }
function box(c, u0, v0, u1, v1, z0, z1, pl) {
  const { cx, p } = c;
  poly(cx, [p(u0, v1, z0), p(u1, v1, z0), p(u1, v1, z1), p(u0, v1, z1)], pl.left, pl.edge);
  poly(cx, [p(u1, v0, z0), p(u1, v1, z0), p(u1, v1, z1), p(u1, v0, z1)], pl.right, pl.edge);
  poly(cx, [p(u0, v0, z1), p(u1, v0, z1), p(u1, v1, z1), p(u0, v1, z1)], pl.top, pl.edge);
}
function pyramid(c, u0, v0, u1, v1, au, av, h, pl) {
  const { cx, p } = c; const a = p(u0, v0), b = p(u1, v0), cc = p(u1, v1), dd = p(u0, v1), ap = p(au, av, h);
  poly(cx, [a, b, ap], pl.top); poly(cx, [a, dd, ap], pl.top);
  poly(cx, [dd, cc, ap], pl.left, pl.edge, .6); poly(cx, [cc, b, ap], pl.right, pl.edge, .6);
}
function ell(cx, x, y, rx, ry, fill) { cx.beginPath(); cx.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2); cx.fillStyle = fill; cx.fill(); }
function line(cx, a, b, color, w) { cx.beginPath(); cx.moveTo(...a); cx.lineTo(...b); cx.strokeStyle = color; cx.lineWidth = w; cx.lineCap = "round"; cx.stroke(); }
function diamondTop(c, u0, v0, u1, v1, z, fill, stroke) { poly(c.cx, [c.p(u0, v0, z), c.p(u1, v0, z), c.p(u1, v1, z), c.p(u0, v1, z)], fill, stroke); }

function massif(c, o, base, opts = {}) {
  // Неровный горный массив (не «пирамида»): несколько вершин разной высоты.
  const seed = (o.v || 0) * 31 + o.x * 7 + o.y * 3, n = Math.max(3, Math.round((c.w + c.d) * 1.3));
  const peaks = [];
  for (let i = 0; i < n; i++) {
    const cu = .25 + noise(seed, i * 5) * (c.w - .5), cv = .25 + noise(seed, i * 5 + 1) * (c.d - .5);
    const ru = .45 + noise(seed, i * 5 + 2) * Math.min(1.4, c.w * .45), rv = .45 + noise(seed, i * 5 + 3) * Math.min(1.4, c.d * .45);
    const dist = Math.hypot((cu - c.w / 2) / c.w, (cv - c.d / 2) / c.d);
    peaks.push({ u0: Math.max(0, cu - ru), v0: Math.max(0, cv - rv), u1: Math.min(c.w, cu + ru), v1: Math.min(c.d, cv + rv), au: cu, av: cv, h: Math.max(o.h * .25, o.h * (1 - dist * 1.1) * (.55 + noise(seed, i * 5 + 4) * .45)), f: .9 + noise(seed, i + 60) * .2 });
  }
  const main = { u0: c.w * .15, v0: c.d * .1, u1: c.w * .85, v1: c.d * .85, au: c.w * (.42 + noise(seed, 90) * .16), av: c.d * (.38 + noise(seed, 91) * .14), h: o.h, f: 1 };
  peaks.push(main);
  peaks.sort((a, b) => (a.u1 + a.v1) - (b.u1 + b.v1)).forEach((pk) => {
    pyramid(c, pk.u0, pk.v0, pk.u1, pk.v1, pk.au, pk.av, pk.h, pal(shadeHex(base, pk.f)));
    line(c.cx, c.p(pk.au, pk.av, pk.h), c.p(pk.u0 + (pk.u1 - pk.u0) * .1, pk.v1), "rgba(255,255,255,.16)", 1);
  });
  return main;
}
function drawHouseBlock(c, u0, v0, u1, v1, h, variant, colors) {
  const cols = colors || ["#E3D2B4", "#D6BE98", "#CDB48C", "#E9DCC3", "#C9AE86"];
  const pl = pal(cols[((variant % cols.length) + cols.length) % cols.length]), roof = ((variant % 3) + 3) % 3;
  if (roof === 2) { box(c, u0, v0, u1, v1, 0, h * .65, pl); box(c, u0, v0, u0 + (u1 - u0) * .55, v0 + (v1 - v0) * .6, h * .65, h, pl); }
  else { box(c, u0, v0, u1, v1, 0, h, pl); box(c, u0, v1 - .05, u1, v1, h, h + 2, pl); box(c, u1 - .05, v0, u1, v1, h, h + 2, pl); }
  const win = "rgba(70,55,40,.7)", z0 = h * .3, z1 = h * .48;
  const v = v0 + (v1 - v0) * .5, u = u0 + (u1 - u0) * .5;
  poly(c.cx, [c.p(u1, v - .05, z0), c.p(u1, v + .05, z0), c.p(u1, v + .05, z1), c.p(u1, v - .05, z1)], win);
  poly(c.cx, [c.p(u - .05, v1, 0), c.p(u + .07, v1, 0), c.p(u + .07, v1, h * .42), c.p(u - .05, v1, h * .42)], "rgba(70,55,40,.8)");
}
function drawPalm(cx, x, y, h) {
  ell(cx, x, y, 7, 2.5, "rgba(0,0,0,.12)");
  const tx = x + 2, ty = y - h;
  cx.beginPath(); cx.moveTo(x, y); cx.quadraticCurveTo(x - 3, y - h * .5, tx, ty); cx.strokeStyle = "#8A6A45"; cx.lineWidth = 2.6; cx.lineCap = "round"; cx.stroke();
  [-170, -140, -110, -70, -40, -10, 25, 155].forEach((a, i) => {
    const r = a * Math.PI / 180, Ln = 12 + (i % 2) * 2;
    cx.beginPath(); cx.moveTo(tx, ty);
    cx.quadraticCurveTo(tx + Math.cos(r) * Ln * .6, ty + Math.sin(r) * Ln * .55 - 3, tx + Math.cos(r) * Ln, ty + Math.sin(r) * Ln * .55 + 6);
    cx.strokeStyle = i % 2 ? "#5E8A48" : "#4F7A3E"; cx.lineWidth = 2.6; cx.stroke();
  });
}
function drawTent(c, u0, v0, u1, v1, h, color) {
  const pl = pal(color); const { p, cx } = c; const um = (u0 + u1) / 2;
  poly(cx, [p(u0, v1), p(u1, v1), p(u1, v1, h * .35), p(um, v1, h), p(u0, v1, h * .35)], pl.left, pl.edge);
  poly(cx, [p(u1, v0), p(u1, v1), p(u1, v1, h * .35), p(u1, v0, h * .35)], pl.right, pl.edge);
  poly(cx, [p(u0, v1, h * .35), p(um, v1, h), p(um, v0, h), p(u0, v0, h * .35)], pl.top, pl.edge);
  poly(cx, [p(u1, v1, h * .35), p(um, v1, h), p(um, v0, h), p(u1, v0, h * .35)], pl.right, pl.edge);
}
function drawCamel(cx, x, y, s, flip) {
  cx.save(); cx.translate(x, y); if (flip) cx.scale(-1, 1); cx.scale(s, s);
  ell(cx, 0, 0, 10, 3, "rgba(0,0,0,.12)");
  cx.strokeStyle = "#7A5A3A"; cx.lineWidth = 1.6; cx.lineCap = "round";
  [[-5, 0], [-2, 0], [4, 0], [7, 0]].forEach(([lx]) => { cx.beginPath(); cx.moveTo(lx, -9); cx.lineTo(lx, 0); cx.stroke(); });
  cx.fillStyle = "#B48A5E"; cx.beginPath(); cx.moveTo(-7, -9); cx.quadraticCurveTo(-4, -19, 1, -12); cx.quadraticCurveTo(4, -17, 8, -10); cx.lineTo(8, -8); cx.lineTo(-7, -8); cx.closePath(); cx.fill();
  cx.beginPath(); cx.moveTo(7, -10); cx.quadraticCurveTo(12, -13, 12, -19); cx.lineTo(15, -19); cx.lineTo(14, -16); cx.lineTo(12, -16); cx.quadraticCurveTo(12, -10, 8, -8); cx.closePath(); cx.fill();
  cx.restore();
}

/* Отрисовка объекта по типу. Возвращает спрайт {cv,W,H,ax,ay} или null (скрытая точка). */
function drawObject(o) {
  if (o.kind === "hotspot") return null;
  const tall = { kaaba: 40, mosqueNabawi: 34, quba: 30, qiblatayn: 34, arqam: 42, khadija: 32, house: 30, caveMountain: o.h + 10, uhudRidge: o.h + 10, fathHill: o.h + 28, rockHill: o.h + 8, mountain: o.h + 8, hill: o.h + 8, palm: 48, palmGrove: 48, tent: 26, camel: 30, stall: 26, lantern: 34, well: 30, trough: 14, bush: 16, graves: 12, maqam: 22, zamzam: 22, jumua: 12, baqi: 14, basalt: o.h + 6 };
  const top = tall[o.kind] || o.h + 10;
  const c = makeCanvasFor(o, top), cx = c.cx, p = c.p;
  const seed = (o.v || 0) * 13 + o.x * 7 + o.y * 3;
  switch (o.kind) {
    case "kaaba": {
      // Облик VII века: каменное здание с крышей под тёмным полосатым покрывалом
      box(c, 0, 0, c.w, c.d, 0, 2, pal("#CFC3AE"));
      const u0 = .35, v0 = .35, u1 = c.w - .35, v1 = c.d - .35, H = o.h;
      box(c, u0, v0, u1, v1, 2, H, pal("#2A2A30"));
      for (const z of [H * .45, H * .62]) {
        line(cx, p(u0, v1, z), p(u1, v1, z), "rgba(150,70,60,.55)", 1.2); line(cx, p(u1, v1, z), p(u1, v0, z), "rgba(150,70,60,.45)", 1.2);
      }
      line(cx, p(u0, v1, H * .52), p(u1, v1, H * .52), "rgba(90,120,90,.5)", 1);
      // Чёрный камень в восточном углу (в серебряной оправе)
      const [bx, by] = p(u1, v0, 2 + H * .17); ell(cx, bx, by, 2.8, 2.3, "#C9CCD2"); ell(cx, bx, by, 1.8, 1.5, "#111");
      // дверь на северо-восточной стене, приподнятая
      const dz = H * .22; poly(cx, [p(u1, v0 + .35, dz), p(u1, v0 + .75, dz), p(u1, v0 + .75, dz + H * .4), p(u1, v0 + .35, dz + H * .4)], "#6B4E2E");
      break;
    }
    case "maqam": {
      box(c, .3, .3, .7, .7, 0, 3, pal("#CFC3AE"));
      box(c, .38, .38, .62, .62, 3, o.h, pal("#E8DCC0"));
      const [x, y] = p(.5, .5, o.h); ell(cx, x - 2.5, y, 1.8, 1, "rgba(90,70,40,.6)"); ell(cx, x + 2.5, y, 1.8, 1, "rgba(90,70,40,.6)");
      break;
    }
    case "zamzam": case "well": {
      const [x, y] = p(c.w / 2, c.d / 2), rx = HW * .38, ry = HH * .38, h = o.h, st = o.kind === "zamzam" ? "#A89A86" : "#BFA985";
      cx.fillStyle = shadeHex(st, .8); cx.fillRect(x - rx, y - h * .6, rx * 2, h * .6);
      ell(cx, x, y, rx, ry, shadeHex(st, .8)); ell(cx, x, y - h * .6, rx, ry, st); ell(cx, x, y - h * .6, rx * .65, ry * .6, "#2E4A56");
      for (let i = 0; i < 6; i++) ell(cx, x - rx + i * rx * .4, y - h * .6 + (i % 2) * 1.5, 2.2, 1.3, shadeHex(st, .92));
      if (o.kind === "well") { line(cx, [x - rx, y - h * .6], [x - rx, y - h - 8], "#5C4630", 1.5); line(cx, [x + rx, y - h * .6], [x + rx, y - h - 8], "#5C4630", 1.5); line(cx, [x - rx - 2, y - h - 8], [x + rx + 2, y - h - 8], "#5C4630", 2); }
      else { line(cx, [x + rx * .6, y - h * .6], [x + rx * 1.1, y - h * .6 - 5], "#6B5238", 1.2); cx.fillStyle = "#6B5238"; cx.fillRect(x + rx * 1.1 - 2, y - h * .6 - 5, 4, 4); }
      break;
    }
    case "trough": box(c, .2, .35, .8, .65, 0, 5, pal("#B8A58A")); diamondTop(c, .28, .4, .72, .6, 5, "#4E6E78"); break;
    case "rockHill": case "hill": case "mountain": {
      const base = o.kind === "rockHill" ? "#8F8C88" : o.kind === "hill" ? "#B49A76" : (o.v % 2 ? "#8E7052" : "#9C7B58");
      massif(c, o, base); break;
    }
    case "basalt": massif(c, o, "#4B4541"); break;
    case "caveMountain": {
      const m = massif(c, o, "#9A7B5A");
      const [x, y] = p(m.au + .5, m.av + .6, m.h * .72); ell(cx, x, y, 4.5, 3, "#2A211A"); ell(cx, x - 1, y - 1, 2.5, 1.5, "#15110D");
      break;
    }
    case "uhudRidge": {
      // Хребет вытянут с запада на восток (вдоль экранной горизонтали)
      const pts = []; for (let t = .7; t <= c.w - .7; t += .75) pts.push(t);
      pts.map((t, i) => ({ u: t, v: c.d - t, h: o.h * (.55 + noise(seed, i) * .45) * (1 - Math.abs(t - c.w / 2) / c.w * .6), r: .9 + noise(seed, i + 9) * .5 }))
        .sort((a, b) => a.u + a.v - (b.u + b.v)).forEach((pk, i) => pyramid(c, Math.max(0, pk.u - pk.r), Math.max(0, pk.v - pk.r), Math.min(c.w, pk.u + pk.r), Math.min(c.d, pk.v + pk.r), pk.u + (noise(seed, i + 30) - .5) * .4, pk.v, pk.h, pal(shadeHex("#9A5A48", .9 + noise(seed, i + 40) * .2))));
      break;
    }
    case "fathHill": {
      const m = massif(c, { ...o, h: o.h }, "#8E7A62");
      const [x, y] = p(m.au, m.av + .4, m.h * .78); ell(cx, x, y, 9, 4, "#B8A58A");
      break;
    }
    case "khadija": {
      const wall = pal("#D3BC96"), room = pal("#DCC7A1");
      box(c, .1, .1, c.w - .1, .45, 0, 20, room); box(c, .1, .45, .45, c.d - .1, 0, 20, room);
      diamondTop(c, .45, .45, c.w - .1, c.d - .1, 0, "#C9B38C");
      box(c, c.w - .3, .45, c.w - .1, c.d - .1, 0, 9, wall); box(c, .45, c.d - .3, c.w - .3, c.d - .1, 0, 9, wall);
      const [x, y] = p(.28, .28, 20); ell(cx, x, y - 3, 6, 5, "#E6D8BD");
      break;
    }
    case "arqam": {
      const st = pal("#6E6A66"); box(c, .15, .15, c.w - .15, c.d - .15, 0, 20, st); box(c, .25, .25, c.w - .45, c.d - .45, 20, 34, st);
      for (const k of [.3, .6, .85]) { const v = .15 + (c.d - .3) * k; poly(cx, [p(c.w - .15, v - .03, 8), p(c.w - .15, v + .03, 8), p(c.w - .15, v + .03, 15), p(c.w - .15, v - .03, 15)], "#1F1D1B"); }
      for (const k of [.35, .7]) { const u = .15 + (c.w - .3) * k; poly(cx, [p(u - .03, c.d - .15, 8), p(u + .03, c.d - .15, 8), p(u + .03, c.d - .15, 15), p(u - .03, c.d - .15, 15)], "#1F1D1B"); }
      break;
    }
    case "house": drawHouseBlock(c, .12, .12, c.w - .12, c.d - .12, o.h, o.v); break;
    case "mosqueNabawi": {
      // двор ~30×35 м: стены из сырца, навес из пальмовых ветвей на стволах пальм, худжраты с востока
      const mud = pal("#C7A77C"), roof = "#8C7A4E";
      diamondTop(c, 0, 0, c.w, c.d, 0, "#D9C49E");
      box(c, 0, 0, c.w, .12, 0, 12, mud); box(c, 0, .12, .12, c.d, 0, 12, mud);
      for (let u = .35; u < c.w - .2; u += .45) { box(c, u - .04, .5, u + .04, .58, 0, 13, pal("#7A5A3A")); }
      poly(cx, [p(.12, .12, 14), p(c.w - .1, .12, 14), p(c.w - .1, .62, 14), p(.12, .62, 14)], roof, "rgba(60,45,25,.5)");
      for (let i = 0; i < 12; i++) line(cx, p(.2 + i * (c.w - .3) / 12, .14, 14), p(.2 + i * (c.w - .3) / 12, .6, 14), "rgba(70,90,40,.45)", 1);
      for (let k = 0; k < 4; k++) box(c, c.w - .55, .7 + k * .5, c.w - .1, 1.12 + k * .5, 0, 11, pal("#B89468"));
      box(c, .12, c.d - .12, c.w - .6, c.d, 0, 10, mud); box(c, c.w - .12, .12, c.w, .7, 0, 10, mud);
      break;
    }
    case "quba": {
      const st = pal("#B8A48A");
      diamondTop(c, 0, 0, c.w, c.d, 0, "#D6C6A6");
      box(c, 0, 0, c.w, .12, 0, 10, st); box(c, 0, .12, .12, c.d, 0, 10, st);
      for (let u = .4; u < c.w; u += .55) box(c, u - .04, c.d - .9, u + .04, c.d - .82, 0, 13, pal("#7A5A3A"));
      poly(cx, [p(.12, c.d - 1, 14), p(c.w - .12, c.d - 1, 14), p(c.w - .12, c.d - .15, 14), p(.12, c.d - .15, 14)], "#8C7A4E", "rgba(60,45,25,.5)");
      box(c, .12, c.d - .12, c.w, c.d, 0, 10, st); box(c, c.w - .12, .12, c.w, c.d - .12, 0, 10, st);
      break;
    }
    case "qiblatayn": {
      const mud = pal("#C4A57A"); box(c, .2, .2, c.w - .2, c.d - .2, 0, 18, mud);
      diamondTop(c, .2, .2, c.w - .2, c.d - .2, 18, "#8C7A4E", "rgba(60,45,25,.5)");
      const [x1, y1] = p(c.w - .2, c.d / 2, 9); ell(cx, x1, y1, 3, 5, "#6B4E2E");
      const [x2, y2] = p(c.w / 2, c.d - .2, 9); ell(cx, x2, y2, 3, 5, "#6B4E2E");
      break;
    }
    case "jumua": {
      const [x, y] = p(c.w / 2, c.d / 2); ell(cx, x, y, HW * c.w * .45, HH * c.d * .45, "#8F7B5C"); ell(cx, x, y - 2, HW * c.w * .4, HH * c.d * .4, "#DCCBA6");
      for (let i = 0; i < 5; i++) ell(cx, x - 18 + i * 9, y + 6 - (i % 2) * 8, 2, 1.2, "rgba(120,100,70,.6)");
      break;
    }
    case "baqi": {
      diamondTop(c, 0, 0, c.w, c.d, 0, "#CDB98F");
      for (let i = 0; i < 26; i++) { const u = .3 + noise(seed, i) * (c.w - .6), v = .3 + noise(seed, i + 50) * (c.d - .6); const [x, y] = p(u, v); cx.fillStyle = "#8A8378"; cx.fillRect(x - 1, y - 4, 2.2, 4); }
      break;
    }
    case "palm": { const [x, y] = p(c.w / 2, c.d / 2); drawPalm(cx, x, y, o.h); break; }
    case "bush": { const [x, y] = p(.5, .5); ell(cx, x, y - 3, 7, 4, "#7F8A5A"); ell(cx, x - 2, y - 5, 4, 2.5, "#98A26E"); break; }
    case "graves": for (let i = 0; i < 6; i++) { const [x, y] = p(.2 + (i % 3) * .3, .3 + Math.floor(i / 3) * .35); cx.fillStyle = "#7E766A"; cx.fillRect(x - 1, y - 4, 2.2, 4); } break;
    case "tent": drawTent(c, .15, .25, c.w - .15, c.d - .25, o.h, "#4A3B30"); break;
    case "stall": { box(c, .2, .3, .8, .7, 0, 8, pal("#B89468")); const { cx: x } = c; poly(x, [p(.1, .2, 14), p(.9, .2, 14), p(.9, .8, 11), p(.1, .8, 11)], "#B5553E", "rgba(0,0,0,.2)"); for (let i = 1; i < 4; i++) line(x, p(.1 + i * .2, .2, 14), p(.1 + i * .2, .8, 11), "rgba(240,220,190,.7)", 2); break; }
    case "camel": { const [x, y] = p(.5, .5); drawCamel(cx, x, y, 1, o.v % 2 === 1); break; }
    case "lantern": { const [x, y] = p(.5, .5), ty = y - o.h + 6; line(cx, [x, y], [x, ty], "#3E3528", 2); ell(cx, x, ty - 4, 9, 9, "rgba(227,194,116,.25)"); cx.fillStyle = "#C2A05A"; cx.fillRect(x - 3.5, ty - 9, 7, 9); cx.strokeStyle = "#3E3528"; cx.lineWidth = 1; cx.strokeRect(x - 3.5, ty - 9, 7, 9); break; }
  }
  return { cv: c.cv, W: c.W, H: c.H, ax: (c.w + c.d) * HH, ay: c.top + (c.w + c.d) * HH / 2 };
}
/* ---------- тайлы, наложения, дальний слой ---------- */
const TERRAIN = { sand: ["#E8D3A6", "#CDB27F", 4], darkSand: ["#D3B179", "#B5925B", 5], desert: ["#EBDAB5", "#D3BD90", 3], rockyGround: ["#C9B08A", "#98805F", 6], rock: ["#A68E6D", "#7B684F", 7], slope: ["#B89C74", "#8C7455", 5], urban: ["#DCCFB8", "#C2B498", 0], courtyard: ["#EDE4D2", "#D8CCB5", 0], garden: ["#B9BF8C", "#8D9A62", 6], basalt: ["#6A625B", "#433D38", 7] };
const tileCache = {};
function diamond(cx, w, h) { cx.beginPath(); cx.moveTo(w / 2, 0); cx.lineTo(w, h / 2); cx.lineTo(w / 2, h); cx.lineTo(0, h / 2); cx.closePath(); }
function tileSprite(type, variant) {
  const k = type + variant; if (tileCache[k]) return tileCache[k];
  const [fill, detail, count] = TERRAIN[type], f = [1, .97, 1.03][variant];
  const [cv, cx] = mkCanvas(64, 32);
  diamond(cx, 64, 32); cx.fillStyle = shadeHex(fill, f); cx.fill();
  cx.save(); diamond(cx, 64, 32); cx.clip();
  if (type === "urban" || type === "courtyard") { cx.strokeStyle = detail; cx.globalAlpha = .6; cx.lineWidth = .6; cx.beginPath(); for (let i = 1; i <= 3; i++) { const t = i / 4; cx.moveTo(64 * (.5 - t / 2), 32 * t / 2); cx.lineTo(64 * (1 - t / 2), 32 * (.5 + t / 2)); cx.moveTo(64 * (.5 + t / 2), 32 * t / 2); cx.lineTo(64 * t / 2, 32 * (.5 + t / 2)); } cx.stroke(); cx.globalAlpha = 1; }
  else if (type === "slope") { cx.strokeStyle = detail; cx.globalAlpha = .6; cx.beginPath(); for (let i = 0; i < 4; i++) { const x = 64 * (.25 + i * .15); cx.moveTo(x, 9.6); cx.lineTo(x - 4, 22.4); } cx.stroke(); cx.globalAlpha = 1; }
  [[.32, .46], [.55, .34], [.62, .6], [.43, .63], [.72, .47], [.48, .49], [.27, .52]].slice(0, count).forEach(([x, y], i) => { const big = type === "rock" || type === "basalt"; ell(cx, x * 64 + noise(variant + i, 7) * 6 - 3, y * 32, big ? 1.6 : 1.1, big ? 1 : .7, detail); });
  cx.restore(); diamond(cx, 64, 32); cx.strokeStyle = detail; cx.globalAlpha = .18; cx.lineWidth = .5; cx.stroke(); cx.globalAlpha = 1;
  return (tileCache[k] = cv);
}
function farSprite(el) {
  const k = "far" + el.id + el.v; if (tileCache[k]) return tileCache[k];
  const [cv, cx] = mkCanvas(el.w, el.h); const base = el.hills ? "#BFA682" : "#9C8468", peaks = el.hills ? 4 : 6;
  cx.beginPath(); cx.moveTo(0, el.h);
  for (let i = 0; i <= peaks; i++) { const x = el.w * i / peaks, pf = .35 + noise(el.v, i) * .6, y = el.hills ? el.h * (1 - pf * .7) : el.h * (1 - pf);
    if (!el.hills) { cx.lineTo(x, y); if (i < peaks) cx.lineTo(x + el.w / peaks / 2, el.h * (.55 + noise(el.v, i + 20) * .3)); } else cx.quadraticCurveTo(x - el.w / peaks / 2, y - 12, x, y); }
  cx.lineTo(el.w, el.h); cx.closePath(); cx.fillStyle = shadeHex(base, 1 + (1 - el.depth) * .25); cx.globalAlpha = .55 + el.depth * .35; cx.fill();
  cx.globalAlpha = 1; cx.globalCompositeOperation = "destination-in";
  const g = cx.createLinearGradient(0, 0, 0, el.h); g.addColorStop(0, "#000"); g.addColorStop(.55, "#000"); g.addColorStop(1, "rgba(0,0,0,0)"); cx.fillStyle = g; cx.fillRect(0, 0, el.w, el.h);
  cx.globalCompositeOperation = "source-over"; return (tileCache[k] = cv);
}
function drawOverlay(cx, ov, ox) {
  const pts = ov.pts.map(([x, y]) => { const [sx, sy] = iso(x, y); return [sx + ox, sy]; });
  const stroke = (color, w, dash, cap = "round") => { cx.beginPath(); cx.moveTo(...pts[0]); for (const q of pts.slice(1)) cx.lineTo(...q); cx.strokeStyle = color; cx.lineWidth = w; cx.setLineDash(dash || []); cx.lineCap = cap; cx.lineJoin = "round"; cx.stroke(); cx.setLineDash([]); };
  if (ov.type === "street") { stroke("#A79778", 15); stroke("#D8CBB0", 11); }
  else if (ov.type === "market") { stroke("#A79778", 17); stroke("#DCCDAE", 13); stroke("rgba(160,120,70,.35)", 13, [3, 9], "butt"); }
  else if (ov.type === "path") { stroke("rgba(245,235,215,.9)", 3.5, [2, 5]); }
  else if (ov.type === "route") { stroke("rgba(80,55,20,.35)", 6); stroke("#D9B45A", 3.5, [9, 7]); }
  else if (ov.type === "wadi") { stroke("rgba(150,130,95,.55)", 20); stroke("rgba(215,200,165,.9)", 12); }
  else if (ov.type === "trench") { stroke("#8E7A5A", 13); stroke("#4A3B2C", 7); stroke("rgba(255,255,255,.15)", 1.5, [4, 6]); }
}
const tileVariant = (x, y) => ((((x * 73856093) ^ (y * 19349663)) % 3) + 3) % 3;
const visible = (o) => !o.layer || isOpen(o.layer);
function renderGround(city) {
  const k = [...state.unlocked].sort().join("|") + (state.settings.preview ? "P" : "");
  if (city.groundKey === k && city.ground) return;
  const W = SIZE * 2 * HW, H = SIZE * 2 * HH, gs = Math.min(DPR, 1.5);
  const [cv, cx] = mkCanvas(W, H, gs), ox = SIZE * HW;
  for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) { const [sx, sy] = iso(x, y); cx.drawImage(tileSprite(city.terrainAt(x, y), tileVariant(x, y)), sx + ox - HW, sy, 64, 32); }
  city.overlays.filter((ov) => !ov.layer || isOpen(ov.layer)).sort((a, b) => (a.type === "route") - (b.type === "route")).forEach((ov) => drawOverlay(cx, ov, ox));
  Object.assign(city, { ground: cv, groundOx: ox, groundW: W, groundH: H, groundKey: k });
}
