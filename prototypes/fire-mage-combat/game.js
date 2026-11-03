// PROTOTYPE - NOT FOR PRODUCTION
// Clareira de treino do Mago de Fogo. Testa o combate e o game feel do quick spec
// design/quick-specs/class-combat-fire-mage-mvp-2026-10-30.md. Arte procedural placeholder.
'use strict';

const D = window.GAME_DATA;
const W = 640, H = 360, WORLD_W = 1600, WORLD_H = 1200;
const PAL = {
  outline: '#1A0F14', robeD: '#5A1220', robe: '#B8323A', robeL: '#E0574F', goldD: '#8C6420', gold: '#D9A441',
  woodD: '#3B2418', wood: '#5B3A29', eye: '#FFB347', ember: '#FF7A1A',
  fireW: '#FFF4C2', fireY: '#FFD65C', fireO: '#FF7A1A', fireR: '#C2361A', smokeD: '#3A2E33', smoke: '#6B5A5E',
};
const TIER_ORDER = { light: 0, medium: 1, heavy: 2 };

// ---------------------------------------------------------------- utilitários
function mulberry32(seed) {
  return function () {
    seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function hash2(x, y) {
  let h = (Math.imul(x, 374761393) + Math.imul(y, 668265263)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}
function makeNoise(seed, cell) {
  const r = mulberry32(seed), gw = Math.ceil(WORLD_W / cell) + 2, gh = Math.ceil(WORLD_H / cell) + 2;
  const grid = new Float32Array(gw * gh);
  for (let i = 0; i < grid.length; i++) grid[i] = r();
  return (x, y) => {
    const gx = x / cell, gy = y / cell, ix = gx | 0, iy = gy | 0;
    const fx = gx - ix, fy = gy - iy, sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
    const a = grid[iy * gw + ix], b = grid[iy * gw + ix + 1], c = grid[(iy + 1) * gw + ix], d = grid[(iy + 1) * gw + ix + 1];
    return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy;
  };
}
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
function makeCanvas(w, h) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const g = c.getContext('2d'); g.imageSmoothingEnabled = false;
  return [c, g];
}
function px(g, x, y, w, h, c) { g.fillStyle = c; g.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); }
function pxEllipse(g, cx, cy, rx, ry, c) {
  if (rx < 0.5 || ry < 0.5) return;
  g.fillStyle = c;
  const R = Math.round(ry);
  for (let dy = -R; dy <= R; dy++) {
    const w = Math.round(rx * Math.sqrt(Math.max(0, 1 - (dy * dy) / (ry * ry))));
    if (w <= 0) continue;
    g.fillRect(Math.round(cx) - w, Math.round(cy + dy), w * 2, 1);
  }
}
function pxRingE(g, cx, cy, rx, ry, thick, c) {
  g.fillStyle = c;
  const irx = rx - thick, iry = ry - thick, R = Math.round(ry), x0 = Math.round(cx);
  for (let dy = -R; dy <= R; dy++) {
    const wo = Math.round(rx * Math.sqrt(Math.max(0, 1 - (dy * dy) / (ry * ry))));
    const wi = (iry > 0 && Math.abs(dy) < iry) ? Math.round(irx * Math.sqrt(1 - (dy * dy) / (iry * iry))) : 0;
    const y = Math.round(cy + dy);
    if (wi <= 0) g.fillRect(x0 - wo, y, wo * 2, 1);
    else { g.fillRect(x0 - wo, y, wo - wi, 1); g.fillRect(x0 + wi, y, wo - wi, 1); }
  }
}

// ---------------------------------------------------------------- atributos e dano (spec §A e §B)
/** Monta os atributos derivados a partir de uma definição de classe em dados. */
function buildAttributes(def, level) {
  const primary = Object.assign({}, def.primary || {});
  const out = { level, primary };
  for (const stat of D.attributes.derived) {
    let v = (def.base && def.base[stat]) || 0;
    const co = (def.coeff && def.coeff[stat]) || {};
    for (const p in co) v += (primary[p] || 0) * co[p];
    v += level * ((def.growth && def.growth[stat]) || 0);
    out[stat] = v;
  }
  return out;
}
/** Fórmula de dano compartilhada. `rng` é injetado para ser determinístico. */
function computeDamage(ab, caster, target, falloff, rng) {
  const raw = ab.base + ab.scaling * caster.stats[ab.power_stat];
  const crit = rng() < caster.stats.crit_chance;
  const def = target.stats[ab.school === 'physical' ? 'armor' : 'resist'];
  const mitig = def / (def + D.combat.mitigation_K);
  return { amount: Math.round(raw * (crit ? D.combat.crit_damage_mult : 1) * (1 - mitig) * falloff), crit };
}
function aoeFalloff(d, radius) {
  const inner = radius * D.combat.aoe_inner_radius_ratio;
  if (d <= inner) return 1;
  return 1 - clamp((d - inner) / (radius - inner), 0, 1) * (1 - D.combat.aoe_falloff_min);
}
const aoeDist = (c, e) => Math.hypot(e.x - c.x, (e.y - c.y) / D.combat.aoe_y_squash);

// ---------------------------------------------------------------- sprites procedurais
function silhouette(src, color) {
  const [c, g] = makeCanvas(src.width, src.height);
  g.drawImage(src, 0, 0);
  g.globalCompositeOperation = 'source-in';
  g.fillStyle = color; g.fillRect(0, 0, c.width, c.height);
  return c;
}
function finishSprite(src, outline) {
  let img = src;
  if (outline) {
    const sil = silhouette(src, PAL.outline);
    const [c, g] = makeCanvas(src.width, src.height);
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) g.drawImage(sil, dx, dy);
    g.drawImage(src, 0, 0);
    img = c;
  }
  return { img, white: silhouette(img, '#FFFFFF') };
}

function drawMage(g, dir, anim, f) {
  const cx = 32, side = dir === 'right';
  const bob = ({ idle: [0, 1, 1, 0], walk: [0, -1, 0, -1, 0, -1], attack: [0, -1, -1, 0, 0, 0] })[anim][f] || 0;
  const sway = anim === 'walk' ? [1, 0, -1, 0, 1, 0][f] : 0;
  const step = anim === 'walk' ? [1, 0, -1, 0, 1, 0][f] : 0;
  const yT = 32 + bob, yB = 55;

  // pés
  if (side) { px(g, cx - 5 + step * 2, 55, 4, 2, PAL.woodD); px(g, cx + 1 - step * 2, 55, 4, 2, PAL.woodD); }
  else { px(g, cx - 5, 55 + (step > 0 ? -1 : 0), 3, 2, PAL.woodD); px(g, cx + 2, 55 + (step < 0 ? -1 : 0), 3, 2, PAL.woodD); }

  // robe
  for (let y = yT; y <= yB; y++) {
    const t = (y - yT) / (yB - yT);
    const hw = Math.round((side ? 5 : 6) + t * (side ? 6 : 8));
    const sx = Math.round(sway * t * 2);
    const L = cx - hw + sx, R = cx + hw + sx, trim = y >= yB - 1;
    px(g, L, y, R - L, 1, trim ? PAL.gold : PAL.robe);
    px(g, L, y, 2, 1, trim ? PAL.gold : PAL.robeL);
    px(g, R - 3, y, 3, 1, trim ? PAL.goldD : PAL.robeD);
  }
  px(g, cx - (side ? 6 : 7), yT + 9, side ? 12 : 14, 1, PAL.gold);
  if (dir === 'down') px(g, cx, yT + 10, 1, yB - yT - 12, PAL.robeD);

  // mangas
  if (side) { px(g, cx + 1, yT + 3, 6, 7, PAL.robe); px(g, cx + 5, yT + 3, 2, 7, PAL.robeD); px(g, cx + 1, yT + 9, 6, 1, PAL.gold); }
  else {
    px(g, cx - 10, yT + 2, 4, 8, PAL.robeL); px(g, cx - 10, yT + 9, 4, 1, PAL.gold);
    px(g, cx + 6, yT + 2, 4, 8, PAL.robeD); px(g, cx + 6, yT + 9, 4, 1, PAL.goldD);
  }

  // capuz
  const hb = yT + 2, tip = yT - 20, lean = side ? -5 : 0;
  for (let y = tip; y <= hb; y++) {
    const t = (y - tip) / (hb - tip);
    const hw = Math.max(1, Math.round(Math.sqrt(t) * 10));
    const ox = Math.round(lean * (1 - t));
    const L = cx - hw + ox;
    px(g, L, y, hw * 2, 1, PAL.robe);
    px(g, L, y, Math.min(2, hw), 1, PAL.robeL);
    if (hw > 2) px(g, L + hw * 2 - 3, y, 3, 1, PAL.robeD);
  }
  if (dir === 'down') {
    pxEllipse(g, cx, yT - 5, 6, 5, PAL.gold); pxEllipse(g, cx, yT - 5, 5, 4, PAL.outline);
    px(g, cx - 3, yT - 6, 2, 2, PAL.eye); px(g, cx + 1, yT - 6, 2, 2, PAL.eye);
  } else if (side) {
    pxEllipse(g, cx + 4, yT - 5, 4, 5, PAL.gold); pxEllipse(g, cx + 4, yT - 5, 3, 4, PAL.outline);
    px(g, cx + 5, yT - 6, 2, 2, PAL.eye);
  } else {
    px(g, cx, tip + 6, 1, hb - tip - 6, PAL.robeD);
  }

  // cajado
  const hy = yT + 8, hx = dir === 'down' ? cx - 13 : dir === 'up' ? cx + 11 : cx + 7;
  let sdx = 0, sdy = 0, charge = 0, flash = false;
  if (anim === 'attack') {
    const fdx = side ? 1 : 0, fdy = dir === 'down' ? 1 : dir === 'up' ? -1 : 0;
    if (f === 0) sdy = -3;
    else if (f === 1 || f === 2) { sdy = -5; charge = f; }
    else if (f === 3) { sdx = fdx * 6; sdy = fdy * 5 - 1; flash = true; }
    else if (f === 4) { sdx = fdx * 3; sdy = fdy * 2; }
  }
  const top = hy - 18 + sdy, bot = hy + 12 + sdy, sx = hx + sdx;
  px(g, sx, top, 2, bot - top, PAL.wood); px(g, sx + 1, top, 1, bot - top, PAL.woodD);
  px(g, sx - 1, hy + sdy - 1, 4, 3, PAL.woodD);
  px(g, sx - 1, top - 4, 4, 4, PAL.ember); px(g, sx, top - 3, 2, 2, PAL.fireY);
  if (anim === 'idle' && f === 2) px(g, sx, top - 3, 1, 1, PAL.fireW);
  if (charge) {
    const r = charge + 1;
    pxEllipse(g, sx + 1, top - 7, r + 1, r + 1, PAL.fireO); pxEllipse(g, sx + 1, top - 7, r, r, PAL.fireY);
    px(g, sx, top - 8, 2, 2, PAL.fireW);
  }
  if (flash) { pxEllipse(g, sx + 1, top - 5, 5, 5, PAL.fireY); pxEllipse(g, sx + 1, top - 5, 3, 3, PAL.fireW); }
}

function buildMageFramesProcedural() {
  const out = {};
  for (const dir of ['down', 'up', 'right']) {
    out[dir] = {};
    for (const anim of ['idle', 'walk', 'attack']) {
      out[dir][anim] = [];
      for (let f = 0; f < D.anim[anim].frames; f++) {
        const [c, g] = makeCanvas(64, 64);
        drawMage(g, dir, anim, f);
        out[dir][anim].push(finishSprite(c, true));
      }
    }
  }
  return out;
}
function buildMageFramesFromSheet(img) {
  const cell = D.sprite.cell, out = {};
  ['down', 'up', 'right'].forEach((dir, di) => {
    out[dir] = {};
    for (const anim of ['idle', 'walk', 'attack']) {
      const row = D.sprite.rows[anim][di];
      out[dir][anim] = [];
      for (let f = 0; f < D.anim[anim].frames; f++) {
        const [c, g] = makeCanvas(cell, cell);
        g.drawImage(img, f * cell, row * cell, cell, cell, 0, 0, cell, cell);
        out[dir][anim].push(finishSprite(c, false));
      }
    }
  });
  return out;
}

const LEAF = ['#24502E', '#3A7A3A', '#5FA045', '#8CC85A'];
function makeTreeSprite(v) {
  const [c, g] = makeCanvas(96, 128);
  px(g, 42, 86, 12, 34, PAL.wood); px(g, 50, 86, 4, 34, PAL.woodD); px(g, 43, 86, 2, 34, '#7A5236');
  px(g, 38, 116, 20, 4, PAL.woodD); px(g, 40, 114, 16, 3, PAL.wood);
  if (v === 1) {
    for (let tier = 0; tier < 4; tier++) {
      const top = 14 + tier * 20, h = 34, maxw = 12 + tier * 7;
      for (let y = 0; y < h; y++) {
        const hw = Math.max(1, Math.round(maxw * (y / h)));
        px(g, 48 - hw, top + y, hw * 2, 1, LEAF[0]);
        px(g, 48 - hw, top + y, Math.max(1, Math.round(hw * 1.2)), 1, '#2F6A3C');
        px(g, 48 - hw, top + y, Math.max(1, Math.round(hw * 0.45)), 1, '#4E8F4E');
      }
    }
  } else {
    const blobs = v === 0
      ? [[48, 62, 30], [28, 72, 17], [68, 72, 17], [38, 44, 19], [60, 42, 17]]
      : [[48, 64, 24], [34, 54, 14], [62, 54, 14]];
    for (const [x, y, r] of blobs) pxEllipse(g, x, y, r, r * 0.9, LEAF[0]);
    for (const [x, y, r] of blobs) pxEllipse(g, x - 3, y - 4, r - 4, (r - 4) * 0.9, LEAF[1]);
    for (const [x, y, r] of blobs) if (r > 12) pxEllipse(g, x - 7, y - 8, r - 11, (r - 11) * 0.9, LEAF[2]);
    for (const [x, y, r] of blobs) if (r > 16) px(g, x - 11, y - 13, 3, 2, LEAF[3]);
    if (v === 2) {
      const rr = mulberry32(5);
      for (let i = 0; i < 10; i++) {
        const a = rr() * 6.28, d = rr() * 20;
        px(g, 48 + Math.cos(a) * d, 60 + Math.sin(a) * d * 0.8, 2, 2, PAL.fireR);
      }
    }
  }
  return finishSprite(c, true);
}
function makeRockSprite(v) {
  const [c, g] = makeCanvas(32, 24);
  if (v === 2) { pxEllipse(g, 11, 15, 8, 5, '#4A464F'); pxEllipse(g, 10, 14, 6, 3.5, '#6E6A72'); pxEllipse(g, 22, 17, 6, 4, '#4A464F'); pxEllipse(g, 21, 16, 4, 2.5, '#6E6A72'); px(g, 8, 12, 3, 1, '#9A97A0'); }
  else { const s = v === 0 ? 0.7 : 1; pxEllipse(g, 16, 15, 12 * s, 7 * s, '#4A464F'); pxEllipse(g, 15, 13, 10 * s, 5.5 * s, '#6E6A72'); pxEllipse(g, 12, 11, 5 * s, 2.5 * s, '#9A97A0'); }
  return finishSprite(c, true);
}
function makeBushSprite(v) {
  const [c, g] = makeCanvas(32, 24);
  const blobs = v === 1 ? [[9, 16, 7, 5], [23, 16, 7, 5], [16, 12, 9, 6]] : [[11, 15, 7, 6], [21, 15, 7, 6], [16, 10, 8, 6]];
  for (const [x, y, rx, ry] of blobs) pxEllipse(g, x, y, rx, ry, LEAF[0]);
  for (const [x, y, rx, ry] of blobs) pxEllipse(g, x - 1, y - 2, rx - 2, ry - 2, LEAF[1]);
  for (const [x, y, rx, ry] of blobs) pxEllipse(g, x - 3, y - 3, rx - 5, ry - 4, LEAF[2]);
  if (v === 2) for (const [x, y] of [[8, 12], [17, 8], [24, 14], [13, 17]]) px(g, x, y, 1, 1, '#F2EEDF');
  return finishSprite(c, true);
}
function makeDummySprite() {
  const [c, g] = makeCanvas(64, 64);
  px(g, 25, 55, 14, 3, PAL.woodD);
  px(g, 30, 36, 4, 20, PAL.wood); px(g, 32, 36, 2, 20, PAL.woodD);
  px(g, 17, 29, 30, 3, PAL.wood); px(g, 17, 31, 30, 1, PAL.woodD);
  pxEllipse(g, 32, 35, 9, 11, '#B8894A'); pxEllipse(g, 30, 33, 7, 9, '#D1A35E');
  px(g, 23, 40, 18, 1, '#7A5236');
  pxRingE(g, 32, 34, 5, 5, 2, PAL.fireR); px(g, 31, 33, 2, 2, PAL.fireR);
  pxEllipse(g, 32, 18, 6, 6, '#B8894A'); pxEllipse(g, 31, 17, 4, 4, '#D1A35E');
  px(g, 29, 17, 1, 1, PAL.woodD); px(g, 30, 18, 1, 1, PAL.woodD); px(g, 34, 17, 1, 1, PAL.woodD); px(g, 33, 18, 1, 1, PAL.woodD);
  px(g, 26, 22, 2, 2, '#E0C070'); px(g, 38, 23, 2, 2, '#E0C070'); px(g, 16, 28, 2, 3, '#E0C070'); px(g, 46, 28, 2, 3, '#E0C070');
  return finishSprite(c, true);
}
function makeSlimeSprite(f) {
  const [c, g] = makeCanvas(64, 64);
  const rx = f ? 14 : 12, ry = f ? 7 : 9, cy = f ? 51 : 49;
  pxEllipse(g, 32, cy, rx, ry, '#2E6B3A'); pxEllipse(g, 31, cy - 1, rx - 2, ry - 2, '#4FA35A');
  pxEllipse(g, 27, cy - ry + 3, 4, 1.5, '#8FD27A');
  px(g, 27, cy - 1, 2, 3, PAL.outline); px(g, 34, cy - 1, 2, 3, PAL.outline);
  return finishSprite(c, true);
}
function makeScorchSprite(v) {
  const [c, g] = makeCanvas(64, 40);
  for (let y = 0; y < 40; y++) for (let x = 0; x < 64; x++) {
    const dx = (x - 32) / 26, dy = (y - 20) / 13, rr = dx * dx + dy * dy;
    const edge = 1 + (hash2(x + v * 97, y + v * 31) - 0.5) * 0.5;
    if (rr < edge * 0.5) px(g, x, y, 1, 1, '#1A0F14');
    else if (rr < edge && hash2(x * 3 + v, y * 7) > 0.35) px(g, x, y, 1, 1, '#2E2226');
  }
  const r = mulberry32(v + 3);
  for (let i = 0; i < 3; i++) px(g, 22 + r() * 20, 14 + r() * 12, 1, 1, PAL.fireO);
  return { img: c };
}

// ---------------------------------------------------------------- mundo
function pathDist(x, y) {
  const a = Math.abs(y - (700 + Math.sin(x / 170) * 55));
  const b = Math.abs(x - (820 + Math.sin(y / 140) * 45));
  return Math.min(a, b);
}
function buildGround() {
  const [c, g] = makeCanvas(WORLD_W, WORLD_H);
  const img = g.createImageData(WORLD_W, WORLD_H), d = img.data;
  const n1 = makeNoise(7, 56), n2 = makeNoise(11, 14);
  const GRASS = [[52, 94, 48], [59, 107, 53], [68, 122, 60]], EDGE = [44, 82, 42];
  const DIRT = [[106, 76, 48], [122, 90, 58], [140, 106, 69]], PEBBLE = [150, 140, 130];
  for (let y = 0; y < WORLD_H; y++) for (let x = 0; x < WORLD_W; x++) {
    const i = (y * WORLD_W + x) * 4, h = hash2(x, y);
    const pd = pathDist(x, y) + (n2(x, y) - 0.5) * 12;
    let col;
    if (pd < 16) { const v = n1(x, y) + (h - 0.5) * 0.25; col = h > 0.985 ? PEBBLE : DIRT[v < 0.4 ? 0 : v < 0.65 ? 1 : 2]; }
    else if (pd < 18.5) col = EDGE;
    else { const v = n1(x, y) + (h - 0.5) * 0.18; col = GRASS[v < 0.42 ? 0 : v < 0.62 ? 1 : 2]; }
    d[i] = col[0]; d[i + 1] = col[1]; d[i + 2] = col[2]; d[i + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  const r = mulberry32(99);
  for (let k = 0; k < 1400; k++) {
    const x = (r() * WORLD_W) | 0, y = (r() * WORLD_H) | 0;
    if (pathDist(x, y) < 22) continue;
    px(g, x, y, 1, 2, '#7FB05A'); px(g, x + 2, y - 1, 1, 3, '#6FA04E'); px(g, x + 4, y, 1, 2, '#7FB05A');
  }
  for (let k = 0; k < 260; k++) {
    const x = (r() * WORLD_W) | 0, y = (r() * WORLD_H) | 0;
    if (pathDist(x, y) < 22) continue;
    px(g, x, y, 2, 2, r() < 0.5 ? '#E8D27A' : '#D9718A'); px(g, x, y, 1, 1, '#FFF4C2');
  }
  return c;
}

const trees = [], rocks = [], bushes = [];
function placeProps() {
  const r = mulberry32(2024);
  const far = (x, y, minD, list) => list.every(o => Math.hypot(o.x - x, o.y - y) >= minD);
  const inClearing = (x, y, rad) => Math.hypot(x - 800, (y - 540) * 1.2) < rad;
  for (let k = 0; k < 5000 && trees.length < 85; k++) {
    const x = 30 + r() * (WORLD_W - 60), y = 70 + r() * (WORLD_H - 80);
    if (inClearing(x, y, 250) || pathDist(x, y) < 34 || !far(x, y, 58, trees)) continue;
    trees.push({ type: 'tree', x, y, v: (r() * 3) | 0, r: 10 });
  }
  for (let k = 0; k < 3000 && rocks.length < 30; k++) {
    const x = 30 + r() * (WORLD_W - 60), y = 40 + r() * (WORLD_H - 50);
    if (inClearing(x, y, 170) || pathDist(x, y) < 26 || !far(x, y, 40, trees) || !far(x, y, 40, rocks)) continue;
    rocks.push({ type: 'rock', x, y, v: (r() * 3) | 0, r: 8 });
  }
  for (let k = 0; k < 3000 && bushes.length < 50; k++) {
    const x = 30 + r() * (WORLD_W - 60), y = 40 + r() * (WORLD_H - 50);
    if (inClearing(x, y, 150) || pathDist(x, y) < 24 || !far(x, y, 30, trees) || !far(x, y, 30, bushes) || !far(x, y, 26, rocks)) continue;
    bushes.push({ type: 'bush', x, y, v: (r() * 3) | 0 });
  }
}
const colliders = () => trees.concat(rocks);

// ---------------------------------------------------------------- entidades
const rngCombat = mulberry32(42); // RNG injetado da fórmula de dano
const enemies = [];
let target = null;

function makeCombatant(def, level) {
  const stats = buildAttributes(def, level);
  return { stats, hp: stats.max_hp, burn: { stacks: 0, t: 0, tick: 0 }, freeze: 0, flash: 0, squash: null, kb: null, alive: true };
}
const mageDef = D.classes.fire_mage;
const mage = Object.assign(makeCombatant(mageDef, 1), {
  kind: 'mage', name: mageDef.name, x: 800, y: 660, r: 8, dir: 'down', flip: false,
  state: 'idle', cur: null, castT: 0, windT: 0, recT: 0, gcd: 0, cds: {}, queued: null,
  anim: 'idle', animT: 0, shown: { anim: 'idle', f: 0 }, moving: false,
});
mage.res = mage.stats.max_resource;

function spawnDummy(x, y) {
  const def = D.enemies.training_dummy;
  enemies.push(Object.assign(makeCombatant(def, 1), { kind: 'dummy', name: def.name, x, y, home: { x, y }, r: 10, wobble: 9, wobbleAmp: 0, respawnT: 0 }));
}
function spawnSlimePack() {
  const def = D.enemies.slime;
  const alive = enemies.filter(e => e.kind === 'slime').length;
  for (let i = 0; i < 5 && alive + i < 15; i++) {
    const a = Math.random() * Math.PI * 2;
    const e = Object.assign(makeCombatant(def, 1), { kind: 'slime', name: def.name, x: mage.x + Math.cos(a) * 190, y: mage.y + Math.sin(a) * 150, r: 9, wobble: 9, wobbleAmp: 0, hop: Math.random() });
    resolveCollisions(e);
    enemies.push(e);
    emitSmoke(e.x, e.y - 8, 6);
  }
  msg('Slimes invocados — use o Anel de Fogo (4)!');
}
function resetDummies() {
  for (const e of enemies) if (e.kind === 'dummy') respawn(e);
  msg('Bonecos reiniciados');
}
function respawn(e) {
  Object.assign(e, { hp: e.stats.max_hp, alive: true, x: e.home.x, y: e.home.y, kb: null, freeze: 0, flash: 0 });
  e.burn.stacks = 0;
  emitSmoke(e.x, e.y - 20, 8);
}

function resolveCollisions(e) {
  for (const c of colliders()) {
    const dx = e.x - c.x, dy = e.y - c.y, d = Math.hypot(dx, dy), min = c.r + e.r;
    if (d < min && d > 0.001) { e.x = c.x + dx / d * min; e.y = c.y + dy / d * min; }
  }
  if (e === mage) for (const o of enemies) {
    if (!o.alive) continue;
    const dx = e.x - o.x, dy = e.y - o.y, d = Math.hypot(dx, dy), min = o.r + e.r;
    if (d < min && d > 0.001) { e.x = o.x + dx / d * min; e.y = o.y + dy / d * min; }
  }
  e.x = clamp(e.x, 16, WORLD_W - 16); e.y = clamp(e.y, 40, WORLD_H - 8);
}

// ---------------------------------------------------------------- feedback e partículas
const particles = [], effects = [], lights = [], decals = [], numbers = [];
let pendingHits = [], trauma = 0, message = null, rangePulse = 0;
const opts = { shake: 1, reduceFlashes: false, help: true };

function msg(text) { message = { text, t: 1.4 }; }
function emitEmbers(x, y, n, speed) {
  for (let i = 0; i < n && particles.length < 700; i++) {
    const a = Math.random() * Math.PI * 2, s = speed * (0.3 + Math.random() * 0.7);
    particles.push({ type: 'ember', x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s * 0.75 - 20, life: 0, max: 0.35 + Math.random() * 0.45, size: Math.random() < 0.3 ? 2 : 1 });
  }
}
function emitSmoke(x, y, n) {
  for (let i = 0; i < n && particles.length < 700; i++) {
    particles.push({ type: 'smoke', x: x + (Math.random() - 0.5) * 16, y: y + (Math.random() - 0.5) * 8, vx: (Math.random() - 0.5) * 20, vy: -12 - Math.random() * 14, life: 0, max: 0.6 + Math.random() * 0.5, size: 3 });
  }
}
function addLight(x, y, r, dur) { if (!opts.reduceFlashes) lights.push({ x, y, r, t: 0, dur }); }
function addScorch(x, y) { decals.push({ x, y, v: (Math.random() * 3) | 0, t: 0 }); if (decals.length > 30) decals.shift(); }

function registerHit(e, tier) { pendingHits.push({ e, tier }); }
/** Aplica o feel do frame: um único hit-stop, do maior tier, para todos os envolvidos. */
function flushHits() {
  if (!pendingHits.length) return;
  let top = 'light';
  for (const h of pendingHits) if (TIER_ORDER[h.tier] > TIER_ORDER[top]) top = h.tier;
  const T = D.feel.tiers[top];
  for (const { e, tier } of pendingHits) {
    const t = D.feel.tiers[tier];
    e.flash = Math.max(e.flash, t.flash);
    if (t.squash) e.squash = { amt: t.squash[0], dur: t.squash[1], t: 0 };
    if (T.hitstop > 0) e.freeze = Math.max(e.freeze, T.hitstop);
    if (e.wobbleAmp !== undefined) { e.wobble = 0; e.wobbleAmp = Math.max(t.wobble, e.wobbleAmp * 0.5); }
    emitEmbers(e.x, e.y - 22, t.embers, 60);
  }
  if (T.hitstop > 0) mage.freeze = Math.max(mage.freeze, T.hitstop);
  trauma = Math.min(1, trauma + T.shake);
  pendingHits = [];
}

function dealDamage(e, amount, tier, crit, kind) {
  if (!e.alive) return;
  e.hp -= amount;
  numbers.push({ x: e.x + (Math.random() - 0.5) * 12, y: e.y - (e.kind === 'slime' ? 26 : 46), text: (kind === 'ignite' ? 'IGNIÇÃO ' : '') + amount + (crit ? '!' : ''), tier, crit, kind, t: 0 });
  registerHit(e, tier);
  if (e.hp <= 0) {
    e.hp = 0; e.alive = false; e.burn.stacks = 0; e.kb = null;
    emitSmoke(e.x, e.y - 16, 10); emitEmbers(e.x, e.y - 16, 16, 90);
    if (e.kind === 'dummy') e.respawnT = D.enemies.training_dummy.respawn;
  }
}
function applyBurn(e, n) {
  if (!e.alive) return;
  const B = D.status.burn;
  if (e.burn.stacks === 0) e.burn.tick = B.tick_interval;
  e.burn.stacks = Math.min(B.max_stacks, e.burn.stacks + n);
  e.burn.t = B.duration;
}
function knockback(e, c, distPx) {
  if (!e.alive) return;
  let dx = e.x - c.x, dy = e.y - c.y, d = Math.hypot(dx, dy);
  if (d < 1) { const a = Math.random() * Math.PI * 2; dx = Math.cos(a); dy = Math.sin(a); d = 1; }
  e.kb = { sx: e.x, sy: e.y, dx: dx / d, dy: dy / d, dist: distPx, t: 0, dur: D.combat.knockback_duration };
}
function explodeAt(ab, c, tier) {
  for (const e of enemies) {
    if (!e.alive) continue;
    const d = aoeDist(c, e);
    if (d > ab.aoe.radius) continue;
    const r = computeDamage(ab, mage, e, aoeFalloff(d, ab.aoe.radius), rngCombat);
    dealDamage(e, r.amount, tier, r.crit);
    if (ab.burn_stacks) applyBurn(e, ab.burn_stacks);
    if (ab.knockback) knockback(e, c, ab.knockback);
  }
}

// ---------------------------------------------------------------- conjuração (spec §C e §D)
const isValidTarget = t => t && t.alive;
function faceVec(dx, dy) {
  if (Math.abs(dx) > Math.abs(dy)) { mage.dir = 'right'; mage.flip = dx < 0; }
  else if (dy !== 0) { mage.dir = dy > 0 ? 'down' : 'up'; mage.flip = false; }
}
function canStart() { return mage.state !== 'casting' && mage.state !== 'windup' && mage.gcd <= 0 && !mage.kb; }
const windupDur = () => D.anim.attack.release / D.anim.attack.fps;

function tryCast(id) {
  const ab = D.abilities[id];
  if (!canStart()) {
    const remaining = Math.max(mage.gcd,
      mage.state === 'casting' ? mage.cur.ab.cast_time - mage.castT : 0,
      mage.state === 'windup' ? windupDur() - mage.windT : 0);
    if (remaining <= D.combat.spell_queue_window) mage.queued = id;
    return;
  }
  if ((mage.cds[id] || 0) > 0) return msg(ab.name + ' em recarga');
  if (mage.res < ab.cost) return msg('Mana insuficiente');
  let t = null;
  if (ab.target === 'enemy') {
    if (!isValidTarget(target)) return msg('Sem alvo — aperte Tab');
    if (dist(mage, target) > ab.range) { rangePulse = 0.5; return msg('Fora de alcance'); }
    t = target;
    faceVec(t.x - mage.x, t.y - mage.y);
  }
  mage.cur = { id, ab, target: t };
  mage.gcd = D.combat.gcd;
  if (ab.cast_time > 0) { mage.state = 'casting'; mage.castT = 0; }
  else { mage.state = 'windup'; mage.windT = 0; }
}
function cancelCast() {
  mage.state = 'idle'; mage.cur = null; mage.gcd = 0;
  msg('Conjuração cancelada (andou)');
}
function staffTip() {
  const s = mage.flip ? -1 : 1;
  if (mage.dir === 'down') return { x: mage.x - 12, y: mage.y - 34 };
  if (mage.dir === 'up') return { x: mage.x + 12, y: mage.y - 46 };
  return { x: mage.x + 14 * s, y: mage.y - 40 };
}
function doRelease() {
  const { id, ab, target: t } = mage.cur;
  mage.state = 'recovery'; mage.recT = 0; mage.cur = null;
  if (ab.target === 'enemy' && !isValidTarget(t)) return msg('Alvo perdido');
  mage.res -= ab.cost;
  if (ab.cooldown) mage.cds[id] = ab.cooldown;
  const tip = staffTip();
  addLight(tip.x, tip.y, 28, 0.12); emitEmbers(tip.x, tip.y, 5, 45);
  if (ab.projectile) projectiles.push({ ab, x: tip.x, y: tip.y, target: t, last: { x: t.x, y: t.y }, t: 0 });
  else if (ab.ground) effects.push({ type: 'telegraph', ab, x: t.x, y: t.y, t: 0, dur: ab.ground.telegraph });
  else if (ab.target === 'self') {
    const c = { x: mage.x, y: mage.y };
    explodeAt(ab, c, ab.tier);
    effects.push({ type: 'nova', x: c.x, y: c.y, r: ab.aoe.radius, t: 0, dur: 0.35 });
    addLight(c.x, c.y - 10, 110, 0.18);
    for (let i = 0; i < 24; i++) { const a = i / 24 * Math.PI * 2; emitEmbersAt(c.x + Math.cos(a) * 30, c.y + Math.sin(a) * 22, Math.cos(a), Math.sin(a)); }
  }
}
function emitEmbersAt(x, y, dx, dy) {
  particles.push({ type: 'ember', x, y, vx: dx * 160, vy: dy * 120 - 10, life: 0, max: 0.4, size: 2 });
}

const projectiles = [];
function projectileHit(p) {
  const ab = p.ab, c = { x: p.last.x, y: p.last.y }, alive = p.target.alive;
  if (ab.aoe) {
    let tier = ab.tier;
    const ig = D.passives.ignite;
    if (ab.ignites && alive && p.target.burn.stacks >= ig.threshold) {
      const dmg = p.target.burn.stacks * ig.per_stack;
      p.target.burn.stacks = 0;
      dealDamage(p.target, dmg, ig.tier, false, 'ignite');
      tier = ig.tier;
      effects.push({ type: 'pillar', x: c.x, y: c.y, t: 0, dur: 0.35, small: true });
    }
    explodeAt(ab, c, tier);
    effects.push({ type: 'explosion', x: c.x, y: c.y, r: ab.aoe.radius, t: 0, dur: 0.45 });
    addLight(c.x, c.y - 10, tier === 'heavy' ? 130 : 95, 0.16);
    addScorch(c.x, c.y);
    emitSmoke(c.x, c.y - 10, 8);
  } else if (alive) {
    const r = computeDamage(ab, mage, p.target, 1, rngCombat);
    dealDamage(p.target, r.amount, ab.tier, r.crit);
    if (ab.burn_stacks) applyBurn(p.target, ab.burn_stacks);
    effects.push({ type: 'spark', x: p.x, y: p.y, t: 0, dur: 0.16 });
    addLight(p.x, p.y, 22, 0.08);
  } else {
    emitEmbers(p.x, p.y, 4, 30);
  }
}

// ---------------------------------------------------------------- update
const keys = new Set();
function updateMage(dt) {
  const st = mage.stats, fps = D.anim.attack.fps;
  mage.res = Math.min(st.max_resource, mage.res + st.resource_regen * dt);
  mage.gcd = Math.max(0, mage.gcd - dt);
  for (const k in mage.cds) mage.cds[k] = Math.max(0, mage.cds[k] - dt);

  let ix = 0, iy = 0;
  if (keys.has('KeyA') || keys.has('ArrowLeft')) ix--;
  if (keys.has('KeyD') || keys.has('ArrowRight')) ix++;
  if (keys.has('KeyW') || keys.has('ArrowUp')) iy--;
  if (keys.has('KeyS') || keys.has('ArrowDown')) iy++;
  const moving = ix !== 0 || iy !== 0;
  mage.moving = moving;

  if (mage.state === 'casting') {
    if (moving) cancelCast();
    else {
      mage.castT += dt;
      if (isValidTarget(mage.cur.target)) faceVec(mage.cur.target.x - mage.x, mage.cur.target.y - mage.y);
      if (mage.castT >= mage.cur.ab.cast_time) doRelease();
    }
  } else if (mage.state === 'windup') {
    mage.windT += dt;
    if (mage.windT >= windupDur()) doRelease();
  } else if (mage.state === 'recovery') {
    mage.recT += dt;
    if (moving || mage.recT >= (D.anim.attack.frames - D.anim.attack.release) / fps) mage.state = 'idle';
  }
  if (mage.queued && canStart()) { const q = mage.queued; mage.queued = null; tryCast(q); }

  if (mage.state !== 'casting' && moving) {
    const len = Math.hypot(ix, iy), sp = st.move_speed * dt;
    mage.x += ix / len * sp; mage.y += iy / len * sp;
    if (mage.state === 'idle' || mage.state === 'recovery') faceVec(ix, iy);
    resolveCollisions(mage);
  }

  let anim, f;
  if (mage.state === 'casting') { anim = 'attack'; f = mage.castT < 1 / fps ? 0 : 1 + (Math.floor(mage.castT * fps) % 2); }
  else if (mage.state === 'windup') { anim = 'attack'; f = Math.min(D.anim.attack.release - 1, Math.floor(mage.windT * fps)); }
  else if (mage.state === 'recovery') { anim = 'attack'; f = Math.min(D.anim.attack.frames - 1, D.anim.attack.release + Math.floor(mage.recT * fps)); }
  else {
    anim = moving ? 'walk' : 'idle';
    if (mage.anim !== anim) { mage.anim = anim; mage.animT = 0; }
    if (mage.freeze <= 0) mage.animT += dt;
    const a = D.anim[anim];
    f = Math.floor(mage.animT * a.fps) % a.frames;
  }
  if (mage.freeze <= 0) mage.shown = { anim, f };
}

function updateEnemy(dt, e) {
  if (!e.alive) {
    if (e.kind === 'dummy') { e.respawnT -= dt; if (e.respawnT <= 0) respawn(e); }
    return;
  }
  const b = e.burn, B = D.status.burn;
  if (b.stacks > 0) {
    b.t -= dt; b.tick -= dt;
    if (b.tick <= 0) { b.tick += B.tick_interval; dealDamage(e, b.stacks * B.tick_damage, 'light', false, 'burn'); }
    if (b.t <= 0) b.stacks = 0;
    if (Math.random() < b.stacks * dt * 4) particles.push({ type: 'ember', x: e.x + (Math.random() - 0.5) * 16, y: e.y - 20 - Math.random() * 16, vx: 0, vy: -30, life: 0, max: 0.6, size: 1 });
  }
  if (!e.alive) return;
  if (e.kb) {
    if (e.freeze <= 0) { // o knockback começa depois do hit-stop
      e.kb.t += dt;
      const k = Math.min(1, e.kb.t / e.kb.dur), ease = 1 - (1 - k) * (1 - k);
      e.x = e.kb.sx + e.kb.dx * e.kb.dist * ease; e.y = e.kb.sy + e.kb.dy * e.kb.dist * ease;
      resolveCollisions(e);
      if (k >= 1) e.kb = null;
    }
  } else if (e.kind === 'dummy') {
    const dx = e.home.x - e.x, dy = e.home.y - e.y, d = Math.hypot(dx, dy);
    if (d > 0.5) { const s = Math.min(d, 40 * dt); e.x += dx / d * s; e.y += dy / d * s; }
  } else if (e.kind === 'slime') {
    const dx = mage.x - e.x, dy = mage.y - e.y, d = Math.hypot(dx, dy);
    if (d > 24) { const s = e.stats.move_speed * dt; e.x += dx / d * s; e.y += dy / d * s; }
    for (const o of enemies) {
      if (o === e || !o.alive || o.kind !== 'slime') continue;
      const ox = e.x - o.x, oy = e.y - o.y, od = Math.hypot(ox, oy);
      if (od < 18 && od > 0.01) { e.x += ox / od * (18 - od) * 0.5; e.y += oy / od * (18 - od) * 0.5; }
    }
    resolveCollisions(e);
  }
  if (e.freeze <= 0) { e.wobble += dt; if (e.hop !== undefined) e.hop += dt; }
}

function updateProjectiles(dt) {
  for (let i = projectiles.length - 1; i >= 0; i--) {
    const p = projectiles[i];
    p.t += dt;
    if (p.target.alive) { p.last.x = p.target.x; p.last.y = p.target.y; }
    const tx = p.last.x, ty = p.last.y - (p.target.kind === 'slime' ? 10 : 24);
    const dx = tx - p.x, dy = ty - p.y, d = Math.hypot(dx, dy), step = p.ab.projectile.speed * dt;
    if (p.ab.projectile.size === 'big') {
      particles.push({ type: 'ember', x: p.x, y: p.y, vx: (Math.random() - 0.5) * 30, vy: (Math.random() - 0.5) * 30, life: 0, max: 0.35, size: 2 });
      if (Math.random() < 0.4) particles.push({ type: 'smoke', x: p.x, y: p.y, vx: 0, vy: -8, life: 0, max: 0.5, size: 2 });
    } else {
      particles.push({ type: 'ember', x: p.x, y: p.y, vx: 0, vy: 0, life: 0.15, max: 0.3, size: 1 });
    }
    if (d <= step + 2) { projectiles.splice(i, 1); projectileHit(p); }
    else { p.x += dx / d * step; p.y += dy / d * step; }
  }
}

function updateEffects(dt) {
  for (let i = effects.length - 1; i >= 0; i--) {
    const ef = effects[i];
    ef.t += dt;
    if (ef.type === 'telegraph' && ef.t >= ef.dur) {
      effects.splice(i, 1);
      const c = { x: ef.x, y: ef.y };
      explodeAt(ef.ab, c, ef.ab.tier);
      effects.push({ type: 'pillar', x: c.x, y: c.y, t: 0, dur: 0.55 });
      addLight(c.x, c.y - 40, 150, 0.22); addScorch(c.x, c.y); emitSmoke(c.x, c.y - 30, 12);
      for (let k = 0; k < 20; k++) particles.push({ type: 'ember', x: c.x + (Math.random() - 0.5) * 24, y: c.y - Math.random() * 90, vx: (Math.random() - 0.5) * 80, vy: -40 - Math.random() * 80, life: 0, max: 0.8, size: 2 });
      continue;
    }
    if (ef.t >= ef.dur) effects.splice(i, 1);
  }
  for (let i = lights.length - 1; i >= 0; i--) { lights[i].t += dt; if (lights[i].t >= lights[i].dur) lights.splice(i, 1); }
  for (let i = decals.length - 1; i >= 0; i--) { decals[i].t += dt; if (decals[i].t >= D.feel.scorch_duration) decals.splice(i, 1); }
  for (let i = numbers.length - 1; i >= 0; i--) { numbers[i].t += dt; if (numbers[i].t >= 0.9) numbers.splice(i, 1); }
}
function updateParticles(dt) {
  const drag = Math.pow(0.9, dt * 60);
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i];
    p.life += dt;
    if (p.life >= p.max) { particles.splice(i, 1); continue; }
    p.x += p.vx * dt; p.y += p.vy * dt;
    p.vx *= drag; p.vy = p.vy * drag - (p.type === 'ember' ? 25 : 6) * dt;
  }
}

const cam = { x: 0, y: 0 };
function update(dt) {
  for (const e of [mage, ...enemies]) {
    if (e.freeze > 0) e.freeze -= dt * 1000;
    if (e.flash > 0) e.flash -= dt * 1000;
    if (e.squash) { e.squash.t += dt * 1000; if (e.squash.t >= e.squash.dur) e.squash = null; }
  }
  updateMage(dt);
  for (const e of enemies) updateEnemy(dt, e);
  for (let i = enemies.length - 1; i >= 0; i--) if (enemies[i].kind === 'slime' && !enemies[i].alive) enemies.splice(i, 1);
  updateProjectiles(dt);
  updateEffects(dt);
  updateParticles(dt);
  flushHits();
  trauma = Math.max(0, trauma - D.feel.trauma_decay * dt);
  rangePulse = Math.max(0, rangePulse - dt);
  if (message) { message.t -= dt; if (message.t <= 0) message = null; }
  if (target && !target.alive) target = null;
  cam.x = clamp(Math.round(mage.x - W / 2), 0, WORLD_W - W);
  cam.y = clamp(Math.round(mage.y - 60 - H / 2), 0, WORLD_H - H);
}

// ---------------------------------------------------------------- render
const gameCv = document.getElementById('game'), ctx = gameCv.getContext('2d');
const uiCv = document.getElementById('ui'), ui = uiCv.getContext('2d');
ctx.imageSmoothingEnabled = false;
let scale = 1, dpr = 1;

let mageFrames, spriteSource = 'procedural';
const SPR = {};

function drawSprite(spr, x, y, pvx, pvy, o = {}) {
  ctx.save();
  ctx.translate(Math.round(x), Math.round(y));
  if (o.rot) ctx.rotate(o.rot);
  ctx.scale((o.flip ? -1 : 1) * (o.sx || 1), o.sy || 1);
  ctx.globalAlpha = o.alpha ?? 1;
  ctx.drawImage(spr.img, -pvx, -pvy);
  if (o.flash) { ctx.globalAlpha = (o.alpha ?? 1) * o.flash; ctx.drawImage(spr.white, -pvx, -pvy); }
  ctx.restore();
}
function squashOf(e) {
  if (!e.squash) return { sx: 1, sy: 1 };
  const k = e.squash.t / e.squash.dur, sy = e.squash.amt + (1 - e.squash.amt) * k;
  return { sx: 1 + (1 - sy) * 0.6, sy };
}
const flashOf = e => (e.flash > 0 ? (opts.reduceFlashes ? 0.35 : 1) : 0);

function drawEntity(e) {
  const sq = squashOf(e), fl = flashOf(e);
  if (e.kind === 'mage') {
    const fr = mageFrames[mage.dir][mage.shown.anim][mage.shown.f];
    drawSprite(fr, e.x, e.y, 32, 58, { flip: mage.flip, sx: sq.sx, sy: sq.sy, flash: fl });
    return;
  }
  const rot = e.wobbleAmp * Math.sin(e.wobble * 28) * Math.exp(-e.wobble * 7);
  const spr = e.kind === 'dummy' ? SPR.dummy : SPR.slime[Math.floor(e.hop * 4) % 2];
  drawSprite(spr, e.x, e.y, 32, 58, { rot, sx: sq.sx, sy: sq.sy, flash: fl });
  // chamas da Queimadura
  const fx = [-7, 6, -2, 9, -10], fy = e.kind === 'slime' ? [10, 12, 15, 8, 9] : [26, 30, 38, 20, 18];
  for (let i = 0; i < e.burn.stacks; i++) {
    const h = 3 + ((performance.now() / 80 + i * 3) | 0) % 3;
    const x = e.x + fx[i], y = e.y - fy[i];
    px(ctx, x, y - h, 2, h, PAL.fireO); px(ctx, x, y - h - 1, 2, 1, PAL.fireY);
  }
}

function drawEffect(ef) {
  const k = ef.t / ef.dur, x = ef.x, y = ef.y;
  if (ef.type === 'telegraph') {
    const R = ef.ab.aoe.radius, ry = D.combat.aoe_y_squash, pulse = 0.5 + 0.5 * Math.sin(ef.t * 30);
    ctx.globalAlpha = 0.22 + 0.15 * pulse;
    pxEllipse(ctx, x, y, R * k, R * k * ry, PAL.fireO);
    ctx.globalAlpha = 0.9;
    pxRingE(ctx, x, y, R, R * ry, 2, pulse > 0.5 ? PAL.fireY : PAL.fireO);
    for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2 + ef.t * 2; px(ctx, x + Math.cos(a) * (R - 6), y + Math.sin(a) * (R - 6) * ry, 2, 2, PAL.fireY); }
    ctx.globalAlpha = 1;
  } else if (ef.type === 'explosion') {
    const R = ef.r, ry = D.combat.aoe_y_squash;
    if (k < 0.12) pxEllipse(ctx, x, y - 8, R * 0.5, R * 0.4, PAL.fireW);
    else {
      const g = Math.min(1, (k - 0.12) / 0.3), rr = R * (0.55 + 0.45 * g) + Math.random() * 2;
      if (k < 0.7) {
        pxEllipse(ctx, x, y - 6, rr, rr * ry, PAL.fireR);
        pxEllipse(ctx, x, y - 8, rr * 0.8, rr * 0.6, PAL.fireO);
        pxEllipse(ctx, x, y - 10, rr * 0.5 * (1 - k), rr * 0.4 * (1 - k), PAL.fireY);
      }
      const sr = R * (0.6 + 0.6 * k);
      ctx.globalAlpha = Math.max(0, 1 - k);
      pxRingE(ctx, x, y - 4, sr, sr * ry, 4, PAL.smokeD);
      ctx.globalAlpha = 1;
    }
  } else if (ef.type === 'pillar') {
    const maxH = ef.small ? 60 : 110, width = ef.small ? 16 : 30;
    const h = maxH * (k < 0.3 ? k / 0.3 : k < 0.6 ? 1 : 1 - (k - 0.6) / 0.4);
    if (k < 0.2 && !ef.small) pxEllipse(ctx, x, y, 64 * 0.7, 64 * 0.7 * D.combat.aoe_y_squash, PAL.fireY);
    for (let j = 0; j < h; j += 2) {
      const tp = 1 - (j / maxH) * 0.6, jit = Math.sin(j * 0.35 + ef.t * 50) * 3, w = width * tp * (1 - k * 0.4);
      px(ctx, x - w / 2 + jit, y - j, w, 2, PAL.fireR);
      px(ctx, x - w * 0.35 + jit, y - j, w * 0.7, 2, PAL.fireO);
      px(ctx, x - w * 0.2 + jit, y - j, w * 0.4, 2, PAL.fireY);
      if (k < 0.5) px(ctx, x - w * 0.08 + jit, y - j, Math.max(1, w * 0.16), 2, PAL.fireW);
    }
  } else if (ef.type === 'nova') {
    const ease = 1 - (1 - k) * (1 - k), r = 8 + (ef.r - 8) * ease, ry = D.combat.aoe_y_squash, th = 10 * (1 - k * 0.5);
    ctx.globalAlpha = 1 - k * k;
    pxRingE(ctx, x, y - 4, r, r * ry, th, PAL.fireO);
    pxRingE(ctx, x, y - 4, r, r * ry, Math.max(2, th * 0.4), PAL.fireW);
    ctx.globalAlpha = 1;
  } else if (ef.type === 'spark') {
    const r = 2 + k * 7;
    ctx.globalAlpha = 1 - k;
    px(ctx, x - r, y, r * 2, 1, PAL.fireW); px(ctx, x, y - r, 1, r * 2, PAL.fireW);
    pxEllipse(ctx, x, y, 3 * (1 - k) + 1, 3 * (1 - k) + 1, PAL.fireY);
    ctx.globalAlpha = 1;
  }
}

function render() {
  const sh = opts.shake * D.feel.shake_max_px * trauma * trauma;
  const ox = Math.round((Math.random() * 2 - 1) * sh), oy = Math.round((Math.random() * 2 - 1) * sh);
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.fillStyle = '#3B6B35'; ctx.fillRect(0, 0, W, H);
  ctx.setTransform(1, 0, 0, 1, -cam.x + ox, -cam.y + oy);
  ctx.drawImage(SPR.ground, cam.x, cam.y, W, H, cam.x, cam.y, W, H);

  for (const d of decals) { ctx.globalAlpha = 0.7 * (1 - d.t / D.feel.scorch_duration); ctx.drawImage(SPR.scorch[d.v].img, Math.round(d.x - 32), Math.round(d.y - 20)); }
  ctx.globalAlpha = 1;
  for (const ef of effects) if (ef.type === 'telegraph') drawEffect(ef);

  const actors = [mage, ...enemies.filter(e => e.alive)];
  ctx.globalAlpha = 0.3;
  for (const e of actors) pxEllipse(ctx, e.x, e.y, e.kind === 'slime' ? 11 : 10, 4, '#000');
  ctx.globalAlpha = 1;
  if (target && target.alive) {
    const p = 0.5 + 0.5 * Math.sin(performance.now() / 120);
    pxRingE(ctx, target.x, target.y + 1, 15, 6, 2, rangePulse > 0 ? '#FF3030' : (p > 0.5 ? PAL.fireY : PAL.fireO));
  }

  const list = actors.concat(trees, rocks, bushes).sort((a, b) => a.y - b.y);
  for (const o of list) {
    if (o.type === 'tree') {
      const behind = mage.y < o.y && mage.y > o.y - 110 && Math.abs(mage.x - o.x) < 42;
      drawSprite(SPR.trees[o.v], o.x, o.y, 48, 120, { alpha: behind ? 0.5 : 1 });
    } else if (o.type === 'rock') drawSprite(SPR.rocks[o.v], o.x, o.y, 16, 20);
    else if (o.type === 'bush') drawSprite(SPR.bushes[o.v], o.x, o.y, 16, 22);
    else drawEntity(o);
  }

  for (const ef of effects) if (ef.type !== 'telegraph') drawEffect(ef);
  for (const p of projectiles) {
    if (p.ab.projectile.size === 'big') {
      const f = Math.random();
      pxEllipse(ctx, p.x, p.y, 6, 6, PAL.fireR); pxEllipse(ctx, p.x, p.y, 5, 5, PAL.fireO);
      pxEllipse(ctx, p.x - 1, p.y - 1, 3 + f, 3 + f, PAL.fireY); px(ctx, p.x - 1, p.y - 2, 2, 2, PAL.fireW);
    } else {
      pxEllipse(ctx, p.x, p.y, 3, 3, PAL.fireO); px(ctx, p.x - 1, p.y - 1, 2, 2, PAL.fireW);
    }
  }

  ctx.globalCompositeOperation = 'lighter';
  for (const p of particles) {
    const r = p.life / p.max;
    if (p.type === 'ember') {
      px(ctx, p.x, p.y, p.size, p.size, r < 0.3 ? PAL.fireW : r < 0.6 ? PAL.fireY : r < 0.85 ? PAL.fireO : PAL.fireR);
    }
  }
  for (const l of lights) {
    const a = 0.55 * (1 - l.t / l.dur);
    const g = ctx.createRadialGradient(l.x, l.y, 0, l.x, l.y, l.r);
    g.addColorStop(0, `rgba(255,190,90,${a})`); g.addColorStop(1, 'rgba(255,120,40,0)');
    ctx.fillStyle = g; ctx.fillRect(l.x - l.r, l.y - l.r, l.r * 2, l.r * 2);
  }
  ctx.globalCompositeOperation = 'source-over';
  for (const p of particles) {
    if (p.type !== 'smoke') continue;
    const r = p.life / p.max, s = p.size + r * 4;
    ctx.globalAlpha = 0.45 * (1 - r);
    px(ctx, p.x - s / 2, p.y - s / 2, s, s, r < 0.4 ? PAL.smokeD : PAL.smoke);
  }
  ctx.globalAlpha = 1;

  for (const e of enemies) {
    if (!e.alive || e.hp >= e.stats.max_hp) continue;
    const top = e.y - (e.kind === 'slime' ? 26 : 52);
    px(ctx, e.x - 12, top, 24, 3, PAL.outline);
    px(ctx, e.x - 11, top + 1, 22 * e.hp / e.stats.max_hp, 1, '#D9433A');
  }

  renderUI();
}

function bar(x, y, w, h, frac, col, back = '#2A1E22') {
  ui.fillStyle = PAL.outline; ui.fillRect(x - 1, y - 1, w + 2, h + 2);
  ui.fillStyle = back; ui.fillRect(x, y, w, h);
  ui.fillStyle = col; ui.fillRect(x, y, w * clamp(frac, 0, 1), h);
}
function text(s, x, y, size, col, align = 'left', stroke = true) {
  ui.font = `bold ${size}px "Courier New", monospace`;
  ui.textAlign = align; ui.textBaseline = 'middle';
  if (stroke) { ui.lineWidth = 2; ui.strokeStyle = PAL.outline; ui.strokeText(s, x, y); }
  ui.fillStyle = col; ui.fillText(s, x, y);
}
const ICON = {
  fire_spark: (x, y) => { ui.fillStyle = PAL.fireO; ui.fillRect(x - 3, y - 3, 6, 6); ui.fillStyle = PAL.fireW; ui.fillRect(x - 1, y - 1, 2, 2); },
  fireball: (x, y) => { ui.fillStyle = PAL.fireR; ui.beginPath(); ui.arc(x, y, 9, 0, 7); ui.fill(); ui.fillStyle = PAL.fireO; ui.beginPath(); ui.arc(x - 1, y - 1, 6, 0, 7); ui.fill(); ui.fillStyle = PAL.fireY; ui.beginPath(); ui.arc(x - 2, y - 2, 3, 0, 7); ui.fill(); },
  flame_pillar: (x, y) => { ui.fillStyle = PAL.fireR; ui.fillRect(x - 5, y - 11, 10, 20); ui.fillStyle = PAL.fireO; ui.fillRect(x - 3, y - 9, 6, 18); ui.fillStyle = PAL.fireY; ui.fillRect(x - 1, y - 7, 2, 15); },
  fire_nova: (x, y) => { ui.lineWidth = 3; ui.strokeStyle = PAL.fireO; ui.beginPath(); ui.ellipse(x, y, 10, 7, 0, 0, 7); ui.stroke(); ui.lineWidth = 1; ui.strokeStyle = PAL.fireW; ui.stroke(); },
};

function renderUI() {
  ui.setTransform(1, 0, 0, 1, 0, 0);
  ui.clearRect(0, 0, uiCv.width, uiCv.height);
  ui.setTransform(scale * dpr, 0, 0, scale * dpr, 0, 0);

  // números de dano (espaço de mundo → tela)
  for (const n of numbers) {
    const k = n.t / 0.9, sx = n.x - cam.x, sy = n.y - cam.y - k * 26;
    let size = n.kind === 'burn' ? 7 : n.tier === 'heavy' ? 12 : n.tier === 'medium' ? 10 : 8;
    if (n.crit) size *= n.t < 0.1 ? 1.7 : 1.4;
    const col = n.kind === 'burn' ? '#E07A3A' : n.kind === 'ignite' ? PAL.fireY : n.tier === 'heavy' ? PAL.fireY : n.tier === 'medium' ? '#FF9A3A' : '#E8B48A';
    ui.globalAlpha = k > 0.7 ? (1 - k) / 0.3 : 1;
    text(n.text, sx, sy, Math.round(size), col, 'center');
  }
  ui.globalAlpha = 1;

  // quadro do jogador
  const st = mage.stats;
  text(`${mage.name} · Nv ${st.level}`, 8, 10, 8, '#F2E6D8');
  bar(8, 18, 120, 6, mage.hp / st.max_hp, '#D9433A');
  bar(8, 27, 120, 6, mage.res / st.max_resource, '#3A7BD9');
  text(`${Math.round(mage.hp)}/${st.max_hp}`, 132, 21, 6, '#F2E6D8');
  text(`${Math.floor(mage.res)}/${st.max_resource}`, 132, 30, 6, '#9CC2F5');
  text(`Poder mágico ${st.spell_power} · Crit ${(st.crit_chance * 100).toFixed(0)}%`, 8, 40, 6, '#B8A898');

  // quadro do alvo
  if (target && target.alive) {
    const d = Math.round(dist(mage, target));
    text(target.name, 320, 10, 8, '#F2E6D8', 'center');
    bar(250, 17, 140, 6, target.hp / target.stats.max_hp, '#D9433A');
    text(`${target.hp}/${target.stats.max_hp}`, 320, 20, 6, '#F2E6D8', 'center');
    for (let i = 0; i < D.status.burn.max_stacks; i++) {
      ui.fillStyle = PAL.outline; ui.fillRect(286 + i * 14, 27, 12, 5);
      ui.fillStyle = i < target.burn.stacks ? (target.burn.stacks >= D.passives.ignite.threshold ? PAL.fireY : PAL.fireO) : '#3A2E33';
      ui.fillRect(287 + i * 14, 28, 10, 3);
    }
    const igReady = target.burn.stacks >= D.passives.ignite.threshold;
    text(igReady ? 'IGNIÇÃO PRONTA — Bola de Fogo!' : `Queimadura ×${target.burn.stacks}`, 320, 38, 6, igReady ? PAL.fireY : '#E8B48A', 'center');
    text(`${d}px`, 396, 20, 6, d > D.abilities.fireball.range ? '#FF6060' : '#B8A898');
  }

  // barra de conjuração
  if (mage.state === 'casting') {
    const ab = mage.cur.ab;
    bar(240, 290, 160, 6, mage.castT / ab.cast_time, PAL.fireO);
    text(`${ab.name}  ${(ab.cast_time - mage.castT).toFixed(1)}s`, 320, 284, 7, '#F2E6D8', 'center');
  }

  // hotbar
  const ids = mageDef.abilities, size = 34, gap = 20, x0 = (W - (ids.length * size + (ids.length - 1) * gap)) / 2, y0 = H - 50;
  ids.forEach((id, i) => {
    const ab = D.abilities[id], x = x0 + i * (size + gap), y = y0, cd = mage.cds[id] || 0;
    ui.fillStyle = PAL.outline; ui.fillRect(x - 1, y - 1, size + 2, size + 2);
    ui.fillStyle = '#2A1E22'; ui.fillRect(x, y, size, size);
    ICON[id](x + size / 2, y + size / 2);
    if (mage.res < ab.cost) { ui.fillStyle = 'rgba(30,60,160,0.5)'; ui.fillRect(x, y, size, size); }
    if (cd > 0) {
      ui.fillStyle = 'rgba(0,0,0,0.65)'; ui.fillRect(x, y, size, size * (cd / ab.cooldown));
      text(cd.toFixed(cd < 1 ? 1 : 0), x + size / 2, y + size / 2, 9, '#F2E6D8', 'center');
    } else if (mage.gcd > 0) {
      ui.fillStyle = 'rgba(0,0,0,0.35)'; ui.fillRect(x, y, size, size * (mage.gcd / D.combat.gcd));
    }
    if (mage.queued === id) { ui.strokeStyle = PAL.fireY; ui.lineWidth = 2; ui.strokeRect(x + 1, y + 1, size - 2, size - 2); }
    text(ab.label, x + 4, y + 5, 7, '#F2E6D8');
    if (ab.cost) text(String(ab.cost), x + size - 3, y + size - 5, 6, '#9CC2F5', 'right');
    text(ab.name, x + size / 2, y + size + 7, 5, '#D8C8B8', 'center');
  });

  // mensagens e ajuda
  if (message) { ui.globalAlpha = Math.min(1, message.t * 2); text(message.text, 320, 262, 8, '#FFE0B0', 'center'); ui.globalAlpha = 1; }
  if (opts.help) {
    const lines = [
      'WASD/setas  andar', 'Tab  trocar alvo · clique  selecionar', 'Esc  limpar alvo',
      '1 Fagulha   2 Bola de Fogo', '3 Pilar de Chamas   4 Anel de Fogo',
      'E  invocar slimes · R  reiniciar bonecos',
      `K  screen shake: ${opts.shake ? 'ligado' : 'desligado'}`, `F  reduzir flashes: ${opts.reduceFlashes ? 'sim' : 'não'}`,
      'H  esconder ajuda', '', 'Combo: Fagulha > Bola > Bola = IGNIÇÃO',
    ];
    ui.fillStyle = 'rgba(20,12,16,0.72)'; ui.fillRect(W - 170, 6, 164, lines.length * 9 + 8);
    lines.forEach((l, i) => text(l, W - 164, 14 + i * 9, 6, i === lines.length - 1 ? PAL.fireY : '#E8DCCC', 'left', false));
  }
  text(`sprites: ${spriteSource} · ${fps} fps`, 8, H - 8, 6, '#B8A898');
}

// ---------------------------------------------------------------- entrada e loop
addEventListener('keydown', e => {
  if (['Tab', 'Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) e.preventDefault();
  keys.add(e.code);
  const ab = mageDef.abilities.find(id => D.abilities[id].key === e.code);
  if (ab) { tryCast(ab); return; }
  if (e.repeat) return;
  if (e.code === 'Tab') cycleTarget();
  else if (e.code === 'Escape') target = null;
  else if (e.code === 'KeyE') spawnSlimePack();
  else if (e.code === 'KeyR') resetDummies();
  else if (e.code === 'KeyK') { opts.shake = opts.shake ? 0 : 1; msg(`Screen shake ${opts.shake ? 'ligado' : 'desligado'}`); }
  else if (e.code === 'KeyF') { opts.reduceFlashes = !opts.reduceFlashes; msg(`Reduzir flashes: ${opts.reduceFlashes ? 'sim' : 'não'}`); }
  else if (e.code === 'KeyH') opts.help = !opts.help;
});
addEventListener('keyup', e => keys.delete(e.code));
addEventListener('blur', () => keys.clear());
gameCv.addEventListener('mousedown', e => {
  const r = gameCv.getBoundingClientRect();
  const wx = (e.clientX - r.left) / scale + cam.x, wy = (e.clientY - r.top) / scale + cam.y;
  let best = null, bd = 1e9;
  for (const en of enemies) {
    if (!en.alive || Math.abs(wx - en.x) > 16 || wy < en.y - 50 || wy > en.y + 6) continue;
    const d = Math.abs(wy - (en.y - 20));
    if (d < bd) { bd = d; best = en; }
  }
  if (best) target = best;
});
function cycleTarget() {
  const list = enemies.filter(e => e.alive && dist(e, mage) <= D.combat.target_acquire_range).sort((a, b) => dist(a, mage) - dist(b, mage));
  if (!list.length) { target = null; return msg('Nenhum alvo por perto'); }
  target = list[(list.indexOf(target) + 1) % list.length];
}

function resize() {
  dpr = window.devicePixelRatio || 1;
  const s = Math.min(innerWidth / W, innerHeight / H);
  scale = s >= 1 ? Math.floor(s) : s;
  const cw = W * scale, ch = H * scale;
  for (const c of [gameCv, uiCv]) {
    c.style.width = cw + 'px'; c.style.height = ch + 'px';
    c.style.left = (innerWidth - cw) / 2 + 'px'; c.style.top = (innerHeight - ch) / 2 + 'px';
  }
  uiCv.width = Math.round(cw * dpr); uiCv.height = Math.round(ch * dpr);
}

let last = performance.now(), fps = 0, fpsAcc = 0, fpsN = 0;
function frame(now) {
  const dt = clamp((now - last) / 1000, 0, 0.05);
  last = now;
  fpsAcc += dt; fpsN++;
  if (fpsAcc >= 0.5) { fps = Math.round(fpsN / fpsAcc); fpsAcc = 0; fpsN = 0; }
  update(dt);
  render();
  requestAnimationFrame(frame);
}

function init() {
  SPR.ground = buildGround();
  SPR.trees = [0, 1, 2].map(makeTreeSprite);
  SPR.rocks = [0, 1, 2].map(makeRockSprite);
  SPR.bushes = [0, 1, 2].map(makeBushSprite);
  SPR.dummy = makeDummySprite();
  SPR.slime = [0, 1].map(makeSlimeSprite);
  SPR.scorch = [0, 1, 2].map(makeScorchSprite);
  mageFrames = buildMageFramesProcedural();
  placeProps();
  for (const [x, y] of [[770, 520], [800, 505], [830, 520], [785, 548], [815, 548], [650, 600], [950, 600]]) spawnDummy(x, y);

  const sheet = new Image();
  sheet.onload = () => { mageFrames = buildMageFramesFromSheet(sheet); spriteSource = 'PNG (ASSET-001)'; };
  sheet.src = D.sprite.sheet;

  addEventListener('resize', resize);
  resize();
  msg('Aperte Tab para mirar num boneco e 1-4 para lançar');
  requestAnimationFrame(frame);
}
init();
