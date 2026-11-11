// ZKR-57: записывающий Canvas 2D для map-draw.js (код графики карты из index.html, без изменений).
// Каждый холст (document.createElement("canvas")) копит команды; native (MapSpriteFactory) воспроизводит их
// в Core Graphics. Состояние стиля (fillStyle, lineWidth, globalAlpha, …) фиксируется в момент fill/stroke,
// поэтому save/restore здесь сохраняют и его; преобразования и обрезку хранит контекст CG.
var window = { devicePixelRatio: 2 };
var __dark = false;
var __open = [];
var state = { unlocked: [], settings: { preview: false } };
var SIZE = 40;
function matchMedia() { return { matches: __dark }; }
function isOpen(id) { return __open.indexOf(id) >= 0; }
var __canvases = [];
var __styleKeys = ['fillStyle', 'strokeStyle', 'lineWidth', 'lineCap', 'lineJoin', 'globalAlpha', 'globalCompositeOperation', '__dash'];
function __style(s) { return typeof s === 'string' ? s : { type: s.type, c: s.c, stops: s.stops }; }
function __Gradient(type, c) { this.type = type; this.c = c; this.stops = []; }
__Gradient.prototype.addColorStop = function (o, color) { this.stops.push([o, color]); };
function __Context(canvas) {
  this.canvas = canvas; this.ops = canvas.ops; this.__stack = [];
  this.fillStyle = '#000'; this.strokeStyle = '#000'; this.lineWidth = 1; this.lineCap = 'butt'; this.lineJoin = 'miter';
  this.globalAlpha = 1; this.globalCompositeOperation = 'source-over'; this.__dash = []; this.font = '10px sans-serif';
}
var P = __Context.prototype;
P.save = function () { var s = {}; for (var i = 0; i < __styleKeys.length; i++) s[__styleKeys[i]] = this[__styleKeys[i]]; this.__stack.push(s); this.ops.push(['save']); };
P.restore = function () { var s = this.__stack.pop(); if (!s) return; for (var k in s) this[k] = s[k]; this.ops.push(['restore']); };
P.scale = function (x, y) { this.ops.push(['scale', x, y]); };
P.translate = function (x, y) { this.ops.push(['translate', x, y]); };
P.rotate = function (a) { this.ops.push(['rotate', a]); };
P.setTransform = function (a, b, c, d, e, f) { this.ops.push(['setTransform', a, b, c, d, e, f]); };
P.beginPath = function () { this.ops.push(['begin']); };
P.closePath = function () { this.ops.push(['close']); };
P.moveTo = function (x, y) { this.ops.push(['move', x, y]); };
P.lineTo = function (x, y) { this.ops.push(['line', x, y]); };
P.quadraticCurveTo = function (a, b, x, y) { this.ops.push(['quad', a, b, x, y]); };
P.bezierCurveTo = function (a, b, c, d, x, y) { this.ops.push(['bezier', a, b, c, d, x, y]); };
P.rect = function (x, y, w, h) { this.ops.push(['rect', x, y, w, h]); };
P.ellipse = function (x, y, rx, ry, rot, a0, a1, ccw) { this.ops.push(['ellipse', x, y, rx, ry, rot, a0, a1, !!ccw]); };
P.arc = function (x, y, r, a0, a1, ccw) { this.ops.push(['ellipse', x, y, r, r, 0, a0, a1, !!ccw]); };
P.setLineDash = function (d) { this.__dash = (d || []).slice(); };
P.getLineDash = function () { return this.__dash.slice(); };
P.__paint = function () { return [this.globalAlpha, this.globalCompositeOperation]; };
P.__line = function () { return [this.lineWidth, this.lineCap, this.lineJoin, this.__dash.slice()]; };
P.fill = function () { this.ops.push(['fill', __style(this.fillStyle)].concat(this.__paint())); };
P.stroke = function () { this.ops.push(['stroke', __style(this.strokeStyle)].concat(this.__paint(), this.__line())); };
P.clip = function () { this.ops.push(['clip']); };
P.fillRect = function (x, y, w, h) { this.ops.push(['fillRect', x, y, w, h, __style(this.fillStyle)].concat(this.__paint())); };
P.strokeRect = function (x, y, w, h) { this.ops.push(['strokeRect', x, y, w, h, __style(this.strokeStyle)].concat(this.__paint(), this.__line())); };
P.clearRect = function (x, y, w, h) { this.ops.push(['clearRect', x, y, w, h]); };
P.drawImage = function (src, x, y, w, h) {
  this.ops.push(['image', src.__id, x, y, w === undefined ? src.width : w, h === undefined ? src.height : h].concat(this.__paint()));
};
P.createLinearGradient = function (x0, y0, x1, y1) { return new __Gradient('linear', [x0, y0, x1, y1]); };
P.createRadialGradient = function (x0, y0, r0, x1, y1, r1) { return new __Gradient('radial', [x0, y0, r0, x1, y1, r1]); };
var document = {
  createElement: function () {
    var c = { __id: __canvases.length, width: 300, height: 150, ops: [] };
    c.getContext = function () { return c.__ctx || (c.__ctx = new __Context(c)); };
    __canvases.push(c); return c;
  },
};
// Вызовы native. Ответ — JSON: {canvas, frame…}; команды холста — __canvasJSON(id).
function __reset(open, dark) { __open = open; __dark = dark; }
function __sprite(o) { var s = drawObject(o); return s ? JSON.stringify({ canvas: s.cv.__id, W: s.W, H: s.H, ax: s.ax, ay: s.ay }) : 'null'; }
function __far(el) { return farSprite(el).__id; }
function __ground(terrain, overlays, unlocked, preview) {
  state = { unlocked: unlocked, settings: { preview: preview } };
  var city = { terrainAt: function (x, y) { return terrain[y][x]; }, overlays: overlays, ground: null, groundKey: '' };
  renderGround(city);
  return JSON.stringify({ canvas: city.ground.__id, ox: city.groundOx, W: city.groundW, H: city.groundH });
}
function __canvasJSON(id) { var c = __canvases[id]; return JSON.stringify({ w: c.width, h: c.height, ops: c.ops }); }
