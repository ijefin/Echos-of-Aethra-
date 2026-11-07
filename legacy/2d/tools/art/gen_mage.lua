-- gen_mage.lua — gera o Mago (48x48) em camadas de paperdoll no Aseprite, modo batch.
-- Uso: aseprite.exe -b --script-param out=<pasta> --script gen_mage.lua
-- Camadas (mesma grade de frames, pivô nos pés): body (pelado + túnica de linho padrão) e
-- itens: weapon, robe, hat (aprendiz) e pyro_staff, pyro_robe, pyro_hood (Piromante).
-- Camadas *_emit: só os pixels que brilham (runas, gemas, chamas), sem contorno — o jogo
-- desenha em modo aditivo HDR e pulsa. Exporte cada camada com --layer.
-- Tags: idle_s/e/n (4 frames) e walk_s/e/n (6 frames). Oeste = espelho do leste (flip_h).
-- Paleta: art bible §4 (Carmesim do Manto, Ouro Divino, Brasa), sombras com hue shift, sem preto.

local W = 48
local HEX = {
  out = "24121c", flameOut = "8a2a12",
  r1 = "5e1a2e", r2 = "8a2436", r3 = "b8323a", r4 = "d9544a",
  g1 = "8a5a22", g2 = "d9a441", g3 = "f2d27a",
  s1 = "b86a52", s2 = "e8a77e", s3 = "f6cfa4",
  h1 = "2a1620", h2 = "4a2c26", h3 = "6e4430", h4 = "8a5a3a",
  t1 = "1e1630", t2 = "3a2c4e",
  b1 = "3a2018", b2 = "5e3622", b3 = "7e4e30",
  w1 = "4a2a18", w2 = "7a4a28",
  f1 = "c8401a", f2 = "ff7a1a", f3 = "ffb040", f4 = "fff4c2",
  eye = "2a1620", eyeL = "fff4c2",
  -- túnica de linho e calça (corpo base)
  l1 = "8a6a50", l2 = "c4a47c", l3 = "e2caa0",
  p1 = "2e2436", p2 = "463a52", p3 = "5e5068",
  -- vinho quase preto do Piromante (sombras do manto, obsidiana do cajado)
  k1 = "1a0c16", k2 = "34121f", k3 = "52182a",
}
local C = {}
for k, v in pairs(HEX) do
  C[k] = app.pixelColor.rgba(tonumber(v:sub(1, 2), 16), tonumber(v:sub(3, 4), 16), tonumber(v:sub(5, 6), 16), 255)
end

-- ---------------------------------------------------------------- canvas
-- Cada vista é desenhada uma vez por camada; P só pinta se a parte atual (L) for a
-- camada sendo gerada.
local grid, mats
local LAYER, cur = "body", "body"
local function L(name) cur = name end
local function clear() grid, mats = {}, {} end
-- Camada "<item>_emit" recebe só pixels "emit"/"flame" do item; os demais apagam o que
-- estiver embaixo (brilho nunca vaza por cima de pano opaco).
local function P(x, y, c, m)
  local emitPass = (LAYER == cur .. "_emit")
  if cur ~= LAYER and not emitPass then return end
  if x >= 0 and x < W and y >= 0 and y < W then
    local k = y * W + x
    if emitPass and m ~= "emit" and m ~= "flame" then
      grid[k] = nil; mats[k] = nil
      return
    end
    grid[k] = C[c]; mats[k] = m or "body"
  end
end
local function H(x0, x1, y, c, m) for x = x0, x1 do P(x, y, c, m) end end

-- Contorno colorido só na silhueta externa (chama ganha contorno de brasa escura).
-- `mask` = pixels do corpo já contornado: roupa por cima não desenha contorno ali, só
-- onde sai da silhueta do corpo — assim encaixa sem riscar o rosto/mãos.
local function outline(mask)
  local add = {}
  for y = 0, W - 1 do
    for x = 0, W - 1 do
      local k = y * W + x
      if not grid[k] and not (mask and mask[k]) then
        local nm
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
          local nx, ny = x + d[1], y + d[2]
          if nx >= 0 and nx < W and ny >= 0 and ny < W then
            local m = mats[ny * W + nx]
            if m == "body" then nm = "body" elseif (m == "flame" or m == "emit") and not nm then nm = "flame" end
          end
        end
        if nm then add[k] = (nm == "flame") and C.flameOut or C.out end
      end
    end
  end
  for k, c in pairs(add) do grid[k] = c end
end

local function toImage(mask, glowOnly)
  if not glowOnly then outline(mask) end
  local img = Image(W, W, ColorMode.RGB)
  for k, c in pairs(grid) do img:drawPixel(k % W, k // W, c) end
  return img
end

-- ---------------------------------------------------------------- partes
local function staffShaft(sx, y0, y1)
  for y = y0, y1 do P(sx, y, "w2"); P(sx + 1, y, "w1") end
  P(sx, y0 + 6, "g2"); P(sx + 1, y0 + 7, "g1") -- anel dourado
end

-- Cabeça do cajado: garra dourada + chama em 4 variações (f = 0..3).
local function staffHead(cx, by, f)
  P(cx - 2, by + 1, "g2"); P(cx + 2, by + 1, "g1"); H(cx - 1, cx + 1, by + 1, "f1", "flame")
  H(cx - 1, cx + 1, by + 2, "g2"); P(cx + 1, by + 2, "g1")
  P(cx - 1, by + 3, "g2"); P(cx, by + 3, "g1")
  local sway = ({ 0, 1, 0, -1 })[f + 1]
  local tall = ({ 0, 1, 1, 0 })[f + 1]
  local rows = { { -2, 2 }, { -2, 2 }, { -2, 2 }, { -1, 2 }, { -1, 1 }, { 0, 1 }, { 0, 0 } }
  if tall == 1 then rows[#rows + 1] = { 0, 0 } end
  for i, r in ipairs(rows) do
    local s = (i >= 4) and sway or 0
    for x = cx + r[1] + s, cx + r[2] + s do P(x, by - (i - 1), "f2", "flame") end
  end
  for i = 1, 5 do
    local s = (i >= 4) and sway or 0
    local a = (i <= 3) and -1 or 0
    local b = (i <= 4) and 1 or 0
    for x = cx + a + s, cx + b + s do P(x, by - (i - 1), "f3", "flame") end
  end
  P(cx, by - 1, "f4", "flame"); P(cx, by - 2, "f4", "flame"); P(cx + ((f % 2 == 0) and 0 or 1), by - 3, "f4", "flame")
  P(cx - 2, by, "f1", "flame"); P(cx + 2, by, "f1", "flame")
end

local function bootFront(x, y, dark)
  H(x, x + 3, y, "b1")
  H(x, x + 3, y + 1, dark and "b1" or "b2"); P(x, y + 1, dark and "b2" or "b3")
  H(x, x + 3, y + 2, dark and "b1" or "b2"); P(x, y + 2, dark and "b2" or "b3")
  H(x, x + 3, y + 3, "b1")
end

local function bootSide(x, y, far)
  local base, lite = far and "b1" or "b2", far and "b2" or "b3"
  H(x, x + 3, y, "b1")
  H(x, x + 3, y + 1, base); P(x, y + 1, lite)
  H(x, x + 4, y + 2, base); P(x, y + 2, lite)
  H(x, x + 4, y + 3, "b1")
end

-- Saia do manto (frente/costas), barra dourada e cinto.
local function skirtFrontBack(o, back)
  for y = 32, 41 do
    local x0, x1 = 17, 30
    if y >= 38 then x0, x1 = 16, 31 end
    H(x0, x1, y + o, "r3")
    P(x0, y + o, "r4"); P(x0 + 1, y + o, "r4")
    P(x1, y + o, "r2"); P(x1 - 1, y + o, "r1")
  end
  H(16, 31, 42 + o, "g2"); P(16, 42 + o, "g3"); P(31, 42 + o, "g1"); P(30, 42 + o, "g1")
  for y = 36, 41 do P(20, y + o, "r2"); P(27, y + o, "r2") end
  if back then
    for y = 35, 41 do P(23, y + o, "r2") end
    H(17, 30, 33 + o, "b2"); P(17, 33 + o, "b3"); P(30, 33 + o, "b1")
  else
    for y = 34, 41 do P(22, y + o, "g2"); P(23, y + o, "t2"); P(24, y + o, "t1"); P(25, y + o, "g1") end
    H(17, 30, 33 + o, "b2"); P(17, 33 + o, "b3"); P(30, 33 + o, "b1")
    P(23, 33 + o, "g3"); P(24, 33 + o, "g2")
  end
end

-- Manga vertical de 2 px com linha interna escura e punho dourado.
local function sleeve(x, y0, y1, innerX, lightLeft)
  for y = y0, y1 do
    P(x, y, lightLeft and "r4" or "r3"); P(x + 1, y, lightLeft and "r3" or "r2")
    P(innerX, y, "r1")
  end
  P(x, y1, "g2"); P(x + 1, y1, "g1")
end

local function mantleFrontBack(o, back)
  local spans = { { 26, 19, 28 }, { 27, 17, 30 }, { 28, 16, 31 }, { 29, 15, 32 }, { 30, 15, 32 } }
  for _, s in ipairs(spans) do
    local y, x0, x1 = s[1] + o, s[2], s[3]
    H(x0, x1, y, "r3")
    P(x0, y, "r4"); P(x0 + 1, y, "r4"); P(x1, y, "r2"); P(x1 - 1, y, "r2")
  end
  H(15, 32, 31 + o, "g2"); P(15, 31 + o, "g3"); P(32, 31 + o, "g1"); P(31, 31 + o, "g1")
  if back then
    H(19, 28, 26 + o, "r2")
    H(20, 27, 27 + o, "r2"); P(21, 28 + o, "r2"); P(26, 28 + o, "r2"); P(22, 29 + o, "r2"); P(25, 29 + o, "r2")
    H(23, 24, 30 + o, "r2")
  else
    H(22, 25, 26 + o, "t1"); P(23, 26 + o, "s1"); P(24, 26 + o, "s1")
    H(23, 24, 27 + o, "g2")
    P(22, 28 + o, "g2"); P(23, 28 + o, "f3"); P(24, 28 + o, "f2"); P(25, 28 + o, "g1")
    H(23, 24, 29 + o, "g1")
    P(19, 29 + o, "r2"); P(28, 29 + o, "r2"); P(18, 30 + o, "r2"); P(29, 30 + o, "r2")
  end
end

local function hairTopFront(o)
  P(20, 8 + o, "h3"); P(25, 8 + o, "h2"); P(28, 8 + o, "h2")
  H(19, 21, 9 + o, "h3"); H(24, 26, 9 + o, "h2"); H(28, 29, 9 + o, "h2")
  H(18, 29, 10 + o, "h2"); H(17, 30, 11 + o, "h2")
  for y = 12, 16 do H(16, 31, y + o, "h2"); P(31, y + o, "h1"); P(30, y + o, "h1") end
  H(19, 21, 10 + o, "h3"); H(18, 22, 11 + o, "h3"); H(17, 20, 12 + o, "h3"); P(17, 13 + o, "h3")
  P(19, 11 + o, "h4"); P(18, 12 + o, "h4"); P(20, 10 + o, "h4")
  H(22, 28, 16 + o, "h1")
end

local function headFront(o)
  hairTopFront(o)
  H(18, 29, 17 + o, "s1")
  for _, x in ipairs({ 18, 19, 22, 25, 28, 29 }) do P(x, 17 + o, "h2") end
  for y = 18, 21 do
    H(18, 29, y + o, "s2"); P(28, y + o, "s1"); P(29, y + o, "s1")
    P(16, y + o, "h2"); P(17, y + o, "h3"); P(30, y + o, "h1"); P(31, y + o, "h1")
  end
  H(20, 27, 18 + o, "s1"); P(19, 18 + o, "s2")
  for y = 22, 23 do
    H(18, 29, y + o, "s2"); P(28, y + o, "s1"); P(29, y + o, "s1")
    P(17, y + o, "h2"); P(30, y + o, "h1")
  end
  H(19, 28, 24 + o, "s2"); P(27, 24 + o, "s1"); P(28, 24 + o, "s1")
  H(21, 26, 25 + o, "s2"); P(25, 25 + o, "s1"); P(26, 25 + o, "s1")
  P(19, 19 + o, "s3"); P(19, 20 + o, "s3")
  -- olhos 2x2 com brilho
  P(20, 20 + o, "eyeL"); P(21, 20 + o, "eye"); P(20, 21 + o, "eye"); P(21, 21 + o, "eye")
  P(26, 20 + o, "eyeL"); P(27, 20 + o, "eye"); P(26, 21 + o, "eye"); P(27, 21 + o, "eye")
  P(19, 22 + o, "r4"); P(28, 22 + o, "r4") -- bochechas
  H(23, 24, 23 + o, "s1")
end

local function headBack(o)
  -- espetos espelhados (vistos de costas)
  P(27, 8 + o, "h3"); P(22, 8 + o, "h2"); P(19, 8 + o, "h2")
  H(26, 28, 9 + o, "h3"); H(21, 23, 9 + o, "h2"); H(18, 19, 9 + o, "h2")
  H(18, 29, 10 + o, "h2"); H(17, 30, 11 + o, "h2")
  for y = 12, 23 do H(16, 31, y + o, "h2"); P(30, y + o, "h1"); P(31, y + o, "h1") end
  H(17, 30, 24 + o, "h2"); P(29, 24 + o, "h1"); P(30, 24 + o, "h1")
  H(19, 28, 25 + o, "h1")
  H(19, 22, 10 + o, "h3"); H(18, 23, 11 + o, "h3"); H(17, 21, 12 + o, "h3"); H(17, 18, 13 + o, "h3"); P(17, 14 + o, "h3")
  P(20, 11 + o, "h4"); P(18, 12 + o, "h4")
  for y = 14, 17 do P(20, y + o, "h1") end
  for y = 19, 23 do P(22, y + o, "h1") end
  for y = 16, 20 do P(26, y + o, "h1") end
  for y = 21, 23 do P(27, y + o, "h1") end
  P(24, 13 + o, "h3"); P(24, 14 + o, "h3"); P(19, 18 + o, "h3")
  for y = 17, 21 do P(17, y + o, "h3") end
end

local function headSide(o)
  P(19, 8 + o, "h2"); P(23, 8 + o, "h3")
  H(18, 20, 9 + o, "h2"); H(22, 25, 9 + o, "h3")
  H(17, 28, 10 + o, "h2"); H(16, 29, 11 + o, "h2")
  for y = 12, 16 do H(16, 30, y + o, "h2") end
  H(21, 26, 10 + o, "h3"); H(19, 25, 11 + o, "h3"); H(18, 22, 12 + o, "h3"); P(19, 11 + o, "h4"); P(22, 10 + o, "h4")
  H(16, 20, 16 + o, "h1"); P(29, 13 + o, "h1"); P(30, 14 + o, "h1"); P(30, 15 + o, "h1"); P(30, 16 + o, "h1")
  H(16, 24, 17 + o, "h2"); H(25, 30, 17 + o, "s1"); P(28, 17 + o, "h2"); P(16, 17 + o, "h1")
  for y = 18, 21 do H(16, 22, y + o, "h2"); H(23, 30, y + o, "s2"); P(16, y + o, "h1") end
  H(24, 29, 18 + o, "s1"); P(25, 18 + o, "s2")
  for y = 22, 23 do H(17, 21, y + o, "h2"); H(22, 29, y + o, "s2"); P(17, y + o, "h1") end
  H(18, 20, 24 + o, "h1"); H(22, 28, 24 + o, "s2"); P(22, 24 + o, "s1"); P(23, 24 + o, "s1")
  H(23, 26, 25 + o, "s1")
  -- orelha
  P(23, 19 + o, "s1"); P(23, 20 + o, "s1"); P(24, 20 + o, "s1"); P(23, 21 + o, "s1")
  for y = 18, 23 do P(22, y + o, "s1") end
  P(17, 19 + o, "h3"); P(18, 20 + o, "h3"); P(17, 18 + o, "h3")
  -- olho e boca
  P(27, 20 + o, "eyeL"); P(28, 20 + o, "eye"); P(27, 21 + o, "eye"); P(28, 21 + o, "eye")
  P(26, 22 + o, "r4"); P(29, 23 + o, "s1")
end

-- ---------------------------------------------------------------- corpo base
-- Calça das duas pernas (frente/costas); a bota cobre a partir de 43 - lift.
local function legsFront(o, la, lb)
  H(19, 28, 37 + o, "p2"); P(19, 37 + o, "p3"); P(28, 37 + o, "p1")
  for y = 38 + o, 42 - la do H(19, 22, y, "p2"); P(19, y, "p3"); P(22, y, "p1") end
  for y = 38 + o, 42 - lb do H(25, 28, y, "p2"); P(25, y, "p3"); P(28, y, "p1") end
end

local function legSide(dx, lift, o, far)
  for y = 37 + o, 42 - lift do
    H(22 + dx, 25 + dx, y, far and "p1" or "p2")
    if not far then P(22 + dx, y, "p3") end
  end
end

-- Túnica de linho padrão (o que ele veste sem armadura), cinto de couro.
local function tunicFrontBack(o, back)
  H(22, 25, 26 + o, "s1")
  for y = 27, 36 do
    local x0, x1 = 18, 29
    if y >= 34 then x0, x1 = 17, 30 end
    H(x0, x1, y + o, "l2"); P(x0, y + o, "l3"); P(x1, y + o, "l1"); P(x1 - 1, y + o, "l1")
  end
  H(17, 30, 34 + o, "b2"); P(17, 34 + o, "b3"); P(30, 34 + o, "b1")
  H(17, 30, 36 + o, "l1")
  if back then
    for y = 29, 33 do P(23, y + o, "l1") end
  else
    P(22, 27 + o, "l1"); P(25, 27 + o, "l1"); P(23, 28 + o, "l1"); P(24, 28 + o, "l1")
    P(23, 34 + o, "g2"); P(24, 34 + o, "g1")
  end
end

local function tunicSide(o)
  H(23, 25, 26 + o, "s1")
  for y = 27, 36 do
    local x0, x1 = 20, 27
    if y >= 34 then x0, x1 = 19, 28 end
    H(x0, x1, y + o, "l2"); P(x0, y + o, "l3"); P(x1, y + o, "l1")
  end
  H(19, 28, 34 + o, "b2"); P(19, 34 + o, "b3"); P(28, 34 + o, "g2")
  H(19, 28, 36 + o, "l1")
end

-- Braço caído: 4 px de manga de linho, depois antebraço de pele.
local function arm(x, y0, y1, lite)
  for y = y0, y1 do
    local sleeveRow = y < y0 + 4
    P(x, y, sleeveRow and (lite and "l3" or "l2") or "s2")
    P(x + 1, y, sleeveRow and (lite and "l2" or "l1") or "s1")
  end
end

-- ---------------------------------------------------------------- conjunto do Piromante
-- Nível alto: manto longo carmesim e vinho, gola alta, ombreiras de pano com ponta,
-- runas de brasa acesas (pixels "emit" vão para a camada de brilho).

-- Cajado de obsidiana com anéis de ouro e runas acesas.
local function pyroShaft(sx, y0, y1)
  for y = y0, y1 do P(sx, y, "k3"); P(sx + 1, y, "k1") end
  for _, r in ipairs({ 6, 16, 26 }) do P(sx, y0 + r, "g2"); P(sx + 1, y0 + r, "g1") end
  P(sx, y0 + 11, "f2", "emit"); P(sx, y0 + 21, "f2", "emit")
end

-- Gaiola de ouro com cristal de brasa flutuando (sobe e desce) e chama alta por cima.
local function pyroStaffHead(cx, by, f)
  H(cx - 1, cx + 1, by + 3, "g1")
  H(cx - 2, cx + 2, by + 2, "g2"); P(cx + 2, by + 2, "g1")
  for i = 0, 4 do P(cx - 3, by + 1 - i, "g2"); P(cx + 3, by + 1 - i, "g1") end
  P(cx - 2, by - 4, "g2"); P(cx + 2, by - 4, "g1")
  local cy = by - 1 - (f % 2)
  P(cx, cy - 2, "f3", "emit")
  H(cx - 1, cx + 1, cy - 1, "f3", "emit"); P(cx, cy - 1, "f4", "emit")
  H(cx - 1, cx + 1, cy, "f2", "emit"); P(cx, cy, "f4", "emit")
  P(cx, cy + 1, "f1", "emit")
  local sway = ({ 0, 1, 0, -1 })[f + 1]
  local rows = { { -1, 1 }, { -1, 1 }, { -1, 1 }, { 0, 1 }, { 0, 0 }, { 0, 0 } }
  for i, r in ipairs(rows) do
    local s = (i >= 3) and sway or 0
    for x = cx + r[1] + s, cx + r[2] + s do P(x, by - 5 - (i - 1), (i <= 2) and "f3" or "f2", "flame") end
  end
  P(cx, by - 5, "f4", "flame")
  P(cx + sway, by - 11, "f1", "flame")
end

-- Manto do Piromante (frente/costas). ly1/ry1 = fim das mangas esquerda/direita da tela.
local function pyroRobeFrontBack(o, back, ly1, ry1)
  for y = 32, 43 do
    local x0, x1 = 16, 31
    if y >= 38 then x0, x1 = 15, 32 end
    H(x0, x1, y + o, "r2"); P(x0, y + o, "r3"); P(x0 + 1, y + o, "r3"); P(x1, y + o, "k2"); P(x1 - 1, y + o, "r1")
  end
  for y = 37, 42 do P(19, y + o, "r1"); P(28, y + o, "r1") end
  H(15, 32, 43 + o, "f1", "emit")
  H(15, 32, 44 + o, "g2"); P(15, 44 + o, "g3"); P(32, 44 + o, "g1")
  H(16, 31, 33 + o, "k1"); P(16, 33 + o, "k2")
  if back then
    -- sigilo de chama nas costas
    local flame = { { 33, 24, 24 }, { 34, 23, 24 }, { 35, 22, 25 }, { 36, 22, 25 }, { 37, 21, 26 }, { 38, 22, 25 }, { 39, 23, 24 } }
    for _, r in ipairs(flame) do H(r[2], r[3], r[1] + o, "f1", "emit") end
    for y = 35, 38 do P(23, y + o, "f3", "emit"); P(24, y + o, "f2", "emit") end
    P(23, 37 + o, "f4", "emit")
  else
    for y = 34, 42 do H(22, 25, y + o, "k2"); P(22, y + o, "k1"); P(25, y + o, "k1") end
    for _, y in ipairs({ 35, 37, 39, 41 }) do P(23, y + o, "f2", "emit"); P(24, y + o, "f3", "emit") end
    P(23, 33 + o, "f3", "emit"); P(24, 33 + o, "f4", "emit")
  end
  -- mangas em sino com punho de ouro
  for y = 31, ly1 - 1 do H(13, 16, y, "r2"); P(13, y, "r3"); P(16, y, "r1") end
  H(12, 16, ly1, "g2"); P(12, ly1, "g3")
  for y = 31, ry1 - 1 do H(31, 34, y, "r2"); P(31, y, "r1"); P(34, y, "k2") end
  H(31, 35, ry1, "g2"); P(35, ry1, "g1")
  -- capa de ombros com pontas e ouro
  local spans = { { 26, 18, 29 }, { 27, 15, 32 }, { 28, 13, 34 }, { 29, 13, 34 }, { 30, 14, 33 } }
  for _, sp in ipairs(spans) do
    local y, x0, x1 = sp[1] + o, sp[2], sp[3]
    H(x0, x1, y, "k3"); P(x0, y, "r1"); P(x0 + 1, y, "r1"); P(x1, y, "k2")
  end
  H(14, 33, 30 + o, "g2"); P(14, 30 + o, "g3"); P(33, 30 + o, "g1")
  P(12, 29 + o, "g2"); P(35, 29 + o, "g1")
  P(16, 28 + o, "f2", "emit"); P(31, 28 + o, "f2", "emit")
  if back then
    -- gola alta por trás da nuca
    for y = 23, 25 do H(15, 32, y + o, "k3"); P(15, y + o, "r1"); P(32, y + o, "k2") end
    H(15, 32, 23 + o, "g2")
  else
    for y = 21, 26 do P(15, y + o, "k3"); P(16, y + o, "r1"); P(31, y + o, "r1"); P(32, y + o, "k3") end
    P(15, 21 + o, "g3"); P(16, 21 + o, "g2"); P(31, 21 + o, "g2"); P(32, 21 + o, "g1")
    H(22, 25, 26 + o, "k1"); H(22, 25, 27 + o, "k1")
    P(22, 28 + o, "g2"); P(23, 28 + o, "f3", "emit"); P(24, 28 + o, "f2", "emit"); P(25, 28 + o, "g1")
  end
end

local function pyroRobeSide(o, st)
  local sw = (st.dxA >= 3 or st.dxB >= 3) and 1 or 0
  for y = 32, 43 do
    local x0, x1 = 18, 29
    if y >= 38 then x0, x1 = 17, 30 + sw end
    H(x0, x1, y + o, "r2"); P(x0, y + o, "r3"); P(x1, y + o, "k2"); P(x1 - 1, y + o, "r1")
  end
  for y = 36, 42 do P(22, y + o, "r1") end
  for y = 34, 42, 2 do P(28, y + o, "f2", "emit") end
  H(17, 30 + sw, 43 + o, "f1", "emit")
  H(17, 30 + sw, 44 + o, "g2"); P(17, 44 + o, "g3")
  H(18, 29, 33 + o, "k1"); P(28, 33 + o, "f3", "emit")
  local spans = { { 26, 19, 28 }, { 27, 18, 29 }, { 28, 17, 30 }, { 29, 17, 30 }, { 30, 18, 29 } }
  for _, sp in ipairs(spans) do
    local y, x0, x1 = sp[1] + o, sp[2], sp[3]
    H(x0, x1, y, "k3"); P(x0, y, "r1"); P(x1, y, "k2")
  end
  H(18, 29, 30 + o, "g2"); P(18, 30 + o, "g3")
  P(29, 28 + o, "f2", "emit")
  -- gola alta atrás da cabeça
  for y = 20, 26 do P(17, y + o, "k3"); P(18, y + o, "r1") end
  P(17, 20 + o, "g2"); P(18, 20 + o, "g2")
  -- manga em sino do braço estendido
  for y = 31, 34 do H(22, 27, y + o, "r2"); P(22, y + o, "r1") end
  H(23, 27, 31 + o, "r3"); H(22, 27, 34 + o, "k2")
  for y = 31, 34 do P(28, y + o, "g2") end
  P(28, 32 + o, "f3", "emit")
end

-- Capuz fundo com tiara de ouro e gema de brasa na testa; cobre o cabelo todo.
local HOOD_TOP = { { 7, 20, 27 }, { 8, 18, 29 }, { 9, 17, 30 }, { 10, 16, 31 } }

local function hoodRow(y, x0, x1)
  H(x0, x1, y, "r2"); P(x0, y, "r3"); P(x1, y, "k2")
end

local function pyroHoodFrontBack(o, back)
  for _, r in ipairs(HOOD_TOP) do hoodRow(r[1] + o, r[2], r[3]) end
  for y = 11, 25 do
    if back or y <= 16 then
      hoodRow(y + o, 15, 32)
    else
      hoodRow(y + o, 15, 17); hoodRow(y + o, 30, 32)
      P(17, y + o, "g1"); P(30, y + o, "g1")
    end
  end
  if back then
    for y = 9, 24 do P(24, y + o, "r1") end
    P(18, 9 + o, "r3"); P(17, 10 + o, "r3")
    H(15, 32, 25 + o, "g2")
  else
    H(18, 29, 14 + o, "r1")
    H(18, 29, 15 + o, "g2"); P(18, 15 + o, "g3"); P(29, 15 + o, "g1")
    P(23, 15 + o, "f3", "emit"); P(24, 15 + o, "f4", "emit")
    P(23, 14 + o, "f2", "emit")
    H(18, 29, 16 + o, "k1")
  end
end

local function pyroHoodSide(o)
  local top = { { 7, 18, 24 }, { 8, 16, 26 }, { 9, 15, 28 }, { 10, 15, 29 } }
  for _, r in ipairs(top) do hoodRow(r[1] + o, r[2], r[3]) end
  for y = 11, 16 do hoodRow(y + o, 15, 30) end
  for y = 17, 25 do hoodRow(y + o, 15, 24); P(24, y + o, "g1") end
  hoodRow(26 + o, 15, 21)
  for y = 11, 25 do P(18, y + o, "r1") end
  H(25, 30, 14 + o, "r1")
  H(24, 30, 15 + o, "g2"); P(30, 15 + o, "g1")
  P(29, 15 + o, "f3", "emit"); P(28, 15 + o, "f2", "emit")
  H(25, 30, 16 + o, "k1")
end

-- ---------------------------------------------------------------- chapéu de mago
-- Cone carmesim com ponta caída, faixa dourada e gema de brasa; aba cobre o topo do cabelo.
local HAT_FRONT = {
  { 1, 27, 28 }, { 2, 25, 27 }, { 3, 24, 26 }, { 4, 23, 26 }, { 5, 22, 26 }, { 6, 21, 26 }, { 7, 20, 27 },
  { 8, 19, 28 }, { 9, 18, 29 }, { 10, 17, 29 }, { 11, 17, 30 }, { 12, 17, 30 }, { 13, 16, 31 },
}
local HAT_SIDE = {
  { 1, 17, 18 }, { 2, 18, 20 }, { 3, 19, 21 }, { 4, 19, 22 }, { 5, 20, 23 }, { 6, 20, 24 }, { 7, 20, 25 },
  { 8, 19, 26 }, { 9, 18, 27 }, { 10, 17, 28 }, { 11, 16, 29 }, { 12, 16, 30 }, { 13, 16, 30 },
}

local function hatCone(rows, o, mirror, gemX)
  for _, r in ipairs(rows) do
    local y, x0, x1 = r[1] + o, r[2], r[3]
    if mirror then x0, x1 = 47 - r[3], 47 - r[2] end
    if r[1] >= 12 then
      H(x0, x1, y, "g2"); P(x0, y, "g3"); P(x1, y, "g1")
    else
      H(x0, x1, y, "r3"); P(x0, y, "r4")
      if x1 - x0 >= 4 then P(x0 + 1, y, "r4") end
      if x1 - x0 >= 3 then P(x1 - 1, y, "r2") end
      P(x1, y, "r1")
    end
  end
  if gemX then
    P(gemX, 12 + o, "f3"); P(gemX + 1, 12 + o, "f2"); P(gemX, 13 + o, "f2"); P(gemX + 1, 13 + o, "f1")
  end
end

local function hatFrontBack(o, back)
  hatCone(HAT_FRONT, o, back, (not back) and 23 or nil)
  H(15, 32, 14 + o, "r3"); P(15, 14 + o, "r4"); P(16, 14 + o, "r4"); P(31, 14 + o, "r2"); P(32, 14 + o, "r1")
  H(14, 33, 15 + o, "r2"); P(14, 15 + o, "r3"); P(33, 15 + o, "r1")
  H(15, 32, 16 + o, "r1")
end

local function hatSide(o)
  hatCone(HAT_SIDE, o, false, 28)
  H(15, 30, 14 + o, "r3"); P(15, 14 + o, "r4"); P(30, 14 + o, "r2")
  H(14, 30, 15 + o, "r2"); P(14, 15 + o, "r3"); P(30, 15 + o, "r1")
  H(15, 29, 16 + o, "r1")
end

-- ---------------------------------------------------------------- vistas
-- st = { bob, liftA, liftB, dxA, dxB, flame, arm }. Cada vista desenha todas as camadas;
-- só a camada atual (LAYER) pinta.
local function drawSouth(st)
  local o = st.bob
  L("body")
  bootFront(19, 43 - st.liftA); bootFront(25, 43 - st.liftB)
  legsFront(o, st.liftA, st.liftB)
  tunicFrontBack(o, false)
  arm(15, 27 + o, 34 + o, true); arm(31, 27 + o, 35 + o + st.arm, false)
  H(12, 14, 35 + o, "s2"); H(12, 14, 36 + o, "s1"); P(12, 35 + o, "s3") -- mão no cajado
  H(32, 33, 36 + o + st.arm, "s2"); H(32, 33, 37 + o + st.arm, "s1")
  headFront(o)
  L("weapon")
  staffShaft(12, 15 + o, 45 + o); staffHead(13, 11 + o, st.flame)
  L("robe")
  skirtFrontBack(o, false)
  sleeve(14, 31 + o, 34 + o, 16, true)
  sleeve(32, 31 + o, 35 + o + st.arm, 31, false)
  mantleFrontBack(o, false)
  L("hat")
  hatFrontBack(o, false)
  L("pyro_staff")
  pyroShaft(12, 15 + o, 45 + o); pyroStaffHead(13, 11 + o, st.flame)
  L("pyro_robe")
  pyroRobeFrontBack(o, false, 34 + o, 35 + o + st.arm)
  L("pyro_hood")
  pyroHoodFrontBack(o, false)
end

local function drawNorth(st)
  local o = st.bob
  L("body")
  bootFront(19, 43 - st.liftB, true); bootFront(25, 43 - st.liftA, true)
  legsFront(o, st.liftB, st.liftA)
  tunicFrontBack(o, true)
  arm(15, 27 + o, 35 + o + st.arm, true); arm(31, 27 + o, 34 + o, false)
  H(14, 15, 36 + o + st.arm, "s2"); H(14, 15, 37 + o + st.arm, "s1")
  H(33, 35, 35 + o, "s2"); H(33, 35, 36 + o, "s1")
  headBack(o)
  L("weapon")
  staffShaft(34, 15 + o, 45 + o); staffHead(35, 11 + o, st.flame)
  L("robe")
  skirtFrontBack(o, true)
  sleeve(14, 31 + o, 35 + o + st.arm, 16, true)
  sleeve(32, 31 + o, 34 + o, 31, false)
  mantleFrontBack(o, true)
  L("hat")
  hatFrontBack(o, true)
  L("pyro_staff")
  pyroShaft(34, 15 + o, 45 + o); pyroStaffHead(35, 11 + o, st.flame)
  L("pyro_robe")
  pyroRobeFrontBack(o, true, 35 + o + st.arm, 34 + o)
  L("pyro_hood")
  pyroHoodFrontBack(o, true)
end

local function drawEast(st)
  local o = st.bob
  L("body")
  bootSide(22 + st.dxB, 43 - st.liftB, true); legSide(st.dxB, st.liftB, o, true)
  bootSide(22 + st.dxA, 43 - st.liftA, false); legSide(st.dxA, st.liftA, o, false)
  tunicSide(o)
  -- braço estendido segurando o cajado
  H(23, 25, 32 + o, "l2"); H(23, 25, 33 + o, "l1"); P(23, 32 + o, "l3")
  H(26, 28, 32 + o, "s2"); H(26, 28, 33 + o, "s1")
  H(29, 31, 32 + o, "s2"); H(29, 31, 33 + o, "s1"); P(29, 32 + o, "s3")
  headSide(o)
  L("weapon")
  staffShaft(31, 15 + o, 45 + o); staffHead(32, 11 + o, st.flame)
  L("robe")
  for y = 32, 41 do
    local x0, x1 = 19, 28
    if y >= 38 then x0, x1 = 18, 29 end
    H(x0, x1, y + o, "r3"); P(x0, y + o, "r4"); P(x0 + 1, y + o, "r4"); P(x1, y + o, "r2"); P(x1 - 1, y + o, "r2")
  end
  for y = 36, 41 do P(23, y + o, "r2") end
  local sw = (st.dxA >= 3 or st.dxB >= 3) and 1 or 0
  if sw == 1 then for y = 40, 41 do P(30, y + o, "r2") end end
  H(18, 29 + sw, 42 + o, "g2"); P(18, 42 + o, "g3"); P(29, 42 + o, "g1")
  H(19, 28, 33 + o, "b2"); P(19, 33 + o, "b3"); P(28, 33 + o, "g2")
  local spans = { { 26, 20, 27 }, { 27, 19, 28 }, { 28, 18, 29 }, { 29, 18, 29 }, { 30, 18, 29 } }
  for _, s in ipairs(spans) do
    local y, x0, x1 = s[1] + o, s[2], s[3]
    H(x0, x1, y, "r3"); P(x0, y, "r4"); P(x0 + 1, y, "r4"); P(x1, y, "r2")
  end
  H(24, 26, 26 + o, "t1"); P(26, 27 + o, "g2"); P(27, 28 + o, "f2")
  H(18, 29, 31 + o, "g2"); P(18, 31 + o, "g3"); P(29, 31 + o, "g1")
  for y = 32, 33 do H(23, 28, y + o, "r3"); P(23, y + o, "r1"); P(28, y + o, "g2") end
  H(24, 27, 32 + o, "r4"); H(24, 27, 34 + o, "r1")
  L("hat")
  hatSide(o)
  L("pyro_staff")
  pyroShaft(31, 15 + o, 45 + o); pyroStaffHead(32, 11 + o, st.flame)
  L("pyro_robe")
  pyroRobeSide(o, st)
  L("pyro_hood")
  pyroHoodSide(o)
end

-- ---------------------------------------------------------------- animações
local IDLE_BOB = { 0, 0, 1, 1 }
local WALK_BOB = { 1, 0, 0, 1, 0, 0 }
local DX_A = { 4, 2, -1, -4, -1, 2 }
local LIFT_A = { 0, 0, 0, 0, 2, 1 }
local function wrap(t, i) return t[((i - 1) % #t) + 1] end

local function idleState(i)
  return { bob = IDLE_BOB[i], liftA = 0, liftB = 0, dxA = 0, dxB = 0, flame = (i - 1) % 4, arm = 0 }
end
local function walkState(i)
  local liftB = wrap(LIFT_A, i + 3)
  return {
    bob = WALK_BOB[i], flame = (i - 1) % 4,
    dxA = DX_A[i], dxB = wrap(DX_A, i + 3),
    liftA = LIFT_A[i], liftB = liftB,
    arm = (LIFT_A[i] > 0) and 1 or 0,
  }
end

local anims = {
  { "idle_s", 4, idleState, drawSouth, 0.2 },
  { "idle_e", 4, idleState, drawEast, 0.2 },
  { "idle_n", 4, idleState, drawNorth, 0.2 },
  { "walk_s", 6, walkState, drawSouth, 0.11 },
  { "walk_e", 6, walkState, drawEast, 0.11 },
  { "walk_n", 6, walkState, drawNorth, 0.11 },
}

-- Ordem das camadas no arquivo (de baixo para cima). O Piromante começa oculto para a
-- prévia mostrar o aprendiz; o export por --layer ignora a visibilidade.
local STACK = {
  "weapon", "pyro_staff", "pyro_staff_emit", "body", "robe", "pyro_robe", "pyro_robe_emit",
  "hat", "pyro_hood", "pyro_hood_emit",
}
local HIDDEN = { pyro_staff = true, pyro_staff_emit = true, pyro_robe = true, pyro_robe_emit = true, pyro_hood = true, pyro_hood_emit = true }

local out = app.params["out"] or "."
local spr = Sprite(W, W, ColorMode.RGB)
local layers = {}
for i, name in ipairs(STACK) do
  local layer = (i == 1) and spr.layers[1] or spr:newLayer()
  layer.name = name
  layer.isVisible = not HIDDEN[name]
  layers[name] = layer
end
local total = 0
for _, a in ipairs(anims) do total = total + a[2] end
for _ = 2, total do spr:newEmptyFrame() end

local f = 1
for _, a in ipairs(anims) do
  local first = f
  for i = 1, a[2] do
    local st = a[3](i)
    -- Corpo primeiro: a silhueta dele vira a máscara de contorno das roupas.
    LAYER = "body"; clear(); a[4](st)
    spr:newCel(layers.body, f, toImage(nil), Point(0, 0))
    local mask = {}
    for k in pairs(grid) do mask[k] = true end
    for _, name in ipairs(STACK) do
      if name ~= "body" then
        LAYER = name; clear(); a[4](st)
        spr:newCel(layers[name], f, toImage(mask, name:sub(-5) == "_emit"), Point(0, 0))
      end
    end
    spr.frames[f].duration = a[5]
    f = f + 1
  end
  local tag = spr:newTag(first, f - 1)
  tag.name = a[1]
end

spr:saveAs(out .. "/mage.aseprite")
