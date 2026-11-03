# Asset Specs — Character: Fire Mage

> **Source**: design/quick-specs/class-combat-fire-mage-mvp-2026-10-30.md (§E kit, §F game feel, §G contrato de animação)
> **Art Bible**: design/art/art-bible.md (seções 1–4, 6, 8) — revisado em 2026-10-30
> **Generated**: 2026-10-30 · **Revised**: 2026-10-30 (alinhado ao art bible)
> **Review**: modo Solo. art-director e technical-artist não foram consultados nesta revisão; specs derivados do art bible nesta sessão.
> **Status**: 7 assets specced / 7 approved / 0 in production / 0 done

## Bloco de estilo comum (colar ao fim de todo prompt, exceto VFX de fogo)

```
detailed pixel art, top-down 3/4 RPG view (high camera angle about 45 degrees), crisp clean pixel clusters, hue-shifted shading (shadows shift toward blue-purple, highlights toward warm yellow), no black or grey shadows, light from the top-left, colored outline only on the outer silhouette, limited palette, hard binary transparency, transparent background, game asset
```

## Pipeline de IA (art bible §8)

Gerar a 4–8× → reduzir com nearest-neighbor ao tamanho exato → quantizar na paleta mestra → limpeza manual (pixels órfãos, contorno só na silhueta, luz de cima-esquerda, hue shift) → alpha binário (exceto VFX/glow) → testes de silhueta, P&B e contra o chão do bioma. Guardar prompt + seed em `.txt` ao lado do master.

## Paleta provisória (compartilhada)

| Papel | Hex |
|---|---|
| Contorno | `#1A0F14` |
| Robe (sombra / base / luz) | `#5A1220` / `#B8323A` / `#E0574F` |
| Detalhe dourado | `#8C6420` / `#D9A441` |
| Madeira do cajado | `#3B2418` / `#5B3A29` |
| Olhos e brasa | `#FFB347` |
| Fogo (núcleo → borda) | `#FFF4C2` → `#FFD65C` → `#FF7A1A` → `#C2361A` |
| Fumaça | `#3A2E33` / `#6B5A5E` |

## Negative prompt (usar em todos)

```
blurry, anti-aliasing, soft gradients, smooth airbrushed shading, 3D render, realistic, photo, isometric tiles, side-scroller platformer view, pure overhead view showing only the top of the head, perspective distortion, inconsistent character between frames, different outfit, changing colors, extra limbs, missing staff, visible face details, cropped, overlapping frames, uneven spacing, text, numbers, watermark, signature, background scenery, baked ground shadow, jpeg artifacts, noise, dithering noise
```

---

## ASSET-001 — Spritesheet do Mago de Fogo

| Field | Value |
|---|---|
| Category | Sprite / 2D Art |
| Dimensions | Célula 64×64 · grade 6 colunas × 15 linhas = 384×960 px (revisado: era 384×576) |
| Layout | Linhas 0–2: `idle` down/up/right (4f) · 3–5: `walk` (6f) · 6–8: `attack` (6f) · **9–11: `hurt` (3f)** · **12–14: `death` (6f)**. Células não usadas ficam transparentes. `left` = espelho de `right` na engine |
| Pivô | (32, 58), nos pés. Personagem com ~44 px de altura, cabeça de 12–14 px (art bible §3) |
| Legibilidade | Rim light quente no topo-esquerda do capuz e ombros; trim dourado bem visível; ≥ 20% de diferença de luminância contra o chão (art bible §4, risco carmesim × verde) |
| Format | PNG 32-bit RGBA, fundo transparente, sem sombra no chão (a engine desenha uma elipse) |
| Naming | `spr_mage_fire_sheet.png` (proposta: não há `naming.*` configurado) |

**Visual Description:** Mago encapuzado num robe carmesim longo, com barra e punhos dourados. O capuz pontudo inclina levemente para trás e esconde o rosto em sombra, deixando só dois olhos laranja brilhando. O cajado curto de madeira escura fica na mão direita e tem um cristal-brasa no topo, que é o ponto de luz mais claro do sprite. A silhueta em triângulo continua legível de cima a 64 px.

**Brief anchor:** direção provisória "pixel art HD, robe + capuz". Luz vinda do canto superior esquerdo, sombreamento cel em 2–3 tons, contorno de 1 px.

**Frames-chave:**
- `idle` (6 fps): bob de respiração de 1 px nos frames 2–3, brasa piscando, barra do robe balançando.
- `walk` (10 fps): ciclo de 6 frames (contato, passagem, contato, passagem). A barra do robe acompanha e o cajado balança pouco.
- `attack` (12 fps): f1 ergue o cajado · f2–f3 carga (precisam loopar para casts longos) · **f4 release** com flash `#FFF4C2` · f5 follow-through · f6 volta ao idle.

**Fluxo recomendado (Scenario.gg / Layer.ai):**
1. Gere primeiro a referência (Prompt 1.A) e escolha a melhor: ela vira a âncora.
2. Fixe o personagem: no Scenario, treine um modelo custom com 10–20 variações aprovadas. No Layer.ai, crie um Style a partir delas. Anexe a referência em toda geração e reaproveite seed e parâmetros.
3. Gere uma tira por linha (9 gerações com o template 1.B), não a folha inteira.
4. Gere em 4× (célula de 256 px) e reduza para 64 px com nearest neighbor.
5. Limpeza no Aseprite: reduzir para a paleta, alinhar o pivô (32, 58), corrigir pixels soltos e montar a grade 384×576.

**Prompt 1.A — Referência (turnaround)** (revisado para o art bible):
```
pixel art character turnaround reference sheet, single row of 3 views of the SAME character at the same scale: front view, back view, right side profile. A young fire mage in a long crimson robe (#B8323A) with bold, clearly visible gold trim (#D9A441) on hem, cuffs and belt, a tall pointed hood hiding the face in shadow with two glowing amber eyes (#FFB347), a short dark wooden staff topped with a glowing ember crystal (#FF7A1A). Head about one third of the body height (12-14 px head on a 44 px figure), slightly stylized proportions. A warm rim light on the top-left edges of the hood and shoulders so the crimson reads clearly against green grass. Strong triangular silhouette. detailed pixel art, top-down 3/4 RPG view (high camera angle about 45 degrees), crisp clean pixel clusters, hue-shifted shading (shadows shift toward blue-purple, highlights toward warm yellow), no black or grey shadows, light from the top-left, colored outline only on the outer silhouette, limited palette, hard binary transparency, transparent background, game asset
```

**Prompt 1.B — Tira de animação (template):**
```
pixel art sprite sheet, a single horizontal row of {N} animation frames on an evenly spaced square grid, same character in every frame, identical scale and position, feet aligned on the same baseline.
Character: the fire mage from the reference image: long crimson robe (#B8323A) with gold trim (#D9A441), tall pointed hood hiding the face in shadow, two glowing orange eyes (#FFB347), short dark wooden staff (#5B3A29) with a glowing ember crystal (#FF7A1A) in the right hand.
Animation: {ANIM}, facing {DIR}. {FRAMES}
Style: top-down 3/4 RPG view (high camera angle about 45 degrees), crisp hard-edged pixel art, 1px dark outline (#1A0F14), limited 24-color palette, flat cel shading, light from top-left, chibi proportions about 2.5 heads tall, game asset, transparent background
```

`{DIR}`: `down (toward the camera, face and front of robe visible)` · `up (away from the camera, back of hood and robe visible)` · `right (side profile, staff in front hand)`

- **idle**, N=4: `Frame 1 neutral stance. Frame 2 body bobs down 1 pixel, robe hem settles. Frame 3 same as frame 2 with the ember crystal glowing brighter. Frame 4 returns to neutral. Subtle, loopable breathing motion.`
- **walk**, N=6: `Loopable walk cycle. Frame 1 left foot forward contact. Frame 2 passing pose, body up 1 pixel. Frame 3 right foot forward contact. Frame 4 passing pose, body up 1 pixel. Frame 5 left foot forward contact. Frame 6 passing pose. Robe hem sways with each step, staff swings slightly.`
- **attack**, N=6: `Spell cast. Frame 1 raises the staff, ember crystal brightens. Frame 2 and frame 3 charge pose, a growing ball of flame gathers at the staff tip (these two frames must loop seamlessly). Frame 4 release: staff thrust forward toward the facing direction with a bright white-yellow flash (#FFF4C2) at the tip. Frame 5 follow-through, robe flares back. Frame 6 recovers to the neutral idle pose.`
- **hurt**, N=3 (novo, art bible §8): `Hit reaction. Frame 1 recoils backward away from the hit, hood tilts. Frame 2 small shake, robe compressed. Frame 3 returns to the neutral pose.`
- **death**, N=6 (novo, art bible §8): `Defeat. Frame 1 staggers. Frame 2 drops to one knee. Frame 3 the staff slips from the hand. Frame 4 kneeling, head bowed. Frame 5 collapses forward onto the ground. Frame 6 lying still, the ember crystal on the staff fades to dark.`

**Status:** Needed

---

## ASSET-002 — Fagulha (projétil + impacto)

| Field | Value |
|---|---|
| Category | VFX |
| Dimensions | Projétil 16×16 × 4f loop (64×16) · Impacto 32×32 × 4f (128×32) |
| Format | PNG RGBA, transparente |
| Naming | `vfx_fire_spark_proj.png`, `vfx_fire_spark_hit.png` |

**Visual Description:** Faísca pequena em forma de lágrima, com núcleo `#FFF4C2` e cauda curta laranja. A arte aponta para a direita e a engine gira para a direção do voo. O impacto é uma estrela de 4 pontas que se abre e se apaga em 4 brasas (tier leve).

**Prompt:**
```
pixel art VFX sprite sheet, single horizontal row, transparent background. Left part: 4 looping frames of a small fire spark projectile flying to the right, teardrop shape, white-yellow core (#FFF4C2), orange (#FF7A1A) short flickering tail. Right part: 4 frames of a small impact burst, a 4-point star flash expanding then breaking into 4 tiny embers that fade out. crisp hard-edged pixels, limited fire palette (#FFF4C2, #FFD65C, #FF7A1A, #C2361A), no outline on the flames, top-down game VFX, evenly spaced frames
```
**Status:** Needed

---

## ASSET-003 — Bola de Fogo (projétil + explosão)

| Field | Value |
|---|---|
| Category | VFX |
| Dimensions | Projétil 32×32 × 4f loop · Explosão 128×128 × 8f (cobre o raio de 56 px) |
| Format | PNG RGBA, transparente |
| Naming | `vfx_fireball_proj.png`, `vfx_fireball_explode.png` |

**Visual Description:** Esfera de fogo turbulenta, voando para a direita, com rastro de chama e fumaça. A explosão tem 8 frames: f1 flash branco, f2–f3 expansão até o raio total, f4–f6 anel de fumaça com 12 brasas, f7–f8 dissipação (tier médio).

**Prompt:**
```
pixel art VFX sprite sheet, transparent background, evenly spaced frames in one row. Part 1: 4 looping frames of a fireball projectile flying to the right, turbulent swirling flame sphere, white-yellow hot core, orange and deep red outer flames, short trailing flame tail with a wisp of dark smoke. Part 2: 8 frames of a top-down circular fire explosion seen from above: frame 1 bright white flash, frames 2-3 fireball expands to full radius, frames 4-6 expanding dark smoke ring (#3A2E33) with about 12 flying embers, frames 7-8 smoke dissipates and fades. crisp hard-edged pixel art, fire palette #FFF4C2 #FFD65C #FF7A1A #C2361A, smoke #3A2E33 #6B5A5E, punchy readable game VFX
```
**Status:** Needed

---

## ASSET-004 — Pilar de Chamas (telegraph + erupção)

| Field | Value |
|---|---|
| Category | VFX |
| Dimensions | Telegraph 128×128 × 8f (~13 fps, 0,6 s) · Erupção 128×192 × 10f |
| Format | PNG RGBA, transparente |
| Naming | `vfx_flame_pillar_telegraph.png`, `vfx_flame_pillar_erupt.png` |

**Visual Description:** Círculo de runas no chão, laranja translúcido, que enche de fora para dentro e pulsa (raio de 64 px). A erupção é uma coluna vertical de fogo: f1–f2 rachadura brilhando, f3–f5 pilar no pico (frame do hit-stop pesado), f6–f10 colapso em brasas e fumaça. A base é elíptica para respeitar a vista 3/4.

**Prompt:**
```
pixel art VFX sprite sheet, transparent background, evenly spaced frames in one row. Part 1: 8 frames of a magic warning circle on the ground seen from a top-down 3/4 angle (ellipse), glowing orange (#FF7A1A) fire runes, the circle fills from the outer edge toward the center and pulses brighter each frame. Part 2: 10 frames (tall frames) of a massive pillar of fire erupting upward from that circle: frames 1-2 glowing cracks in the ground, frames 3-5 tall roaring flame column at full height with white-hot core, frames 6-10 the column collapses into falling embers and rising dark smoke. crisp hard-edged pixel art, fire palette #FFF4C2 #FFD65C #FF7A1A #C2361A, heavy impactful game VFX
```
**Status:** Needed

---

## ASSET-005 — Anel de Fogo (nova ao redor do mago)

| Field | Value |
|---|---|
| Category | VFX |
| Dimensions | 192×192 × 8f (raio de 80 px) |
| Format | PNG RGBA, transparente |
| Naming | `vfx_fire_nova.png` |

**Visual Description:** Onda circular de fogo que sai do centro até a borda. O centro fica vazio, para o mago não ser coberto. A borda de ataque é mais clara e o interior apaga em brasas. Base elíptica.

**Prompt:**
```
pixel art VFX sprite sheet, 8 frames in one row, transparent background. A ring of fire shockwave expanding outward from an empty center, seen from a top-down 3/4 angle (ellipse): frame 1 small bright ring, frames 2-5 the ring expands outward with a bright white-yellow leading edge and orange-red flames behind it, frames 6-8 the ring reaches full size and breaks into scattered embers that fade. center stays empty and clear. crisp hard-edged pixel art, fire palette #FFF4C2 #FFD65C #FF7A1A #C2361A, readable game VFX
```
**Status:** Needed

---

## ASSET-006 — Decal de chão queimado

| Field | Value |
|---|---|
| Category | Environment / VFX |
| Dimensions | 64×64 × 3 variantes estáticas (192×64) |
| Format | PNG RGBA, transparente |
| Naming | `dec_scorch_01..03.png` |

**Visual Description:** Mancha de chão queimado, irregular e elíptica, em carvão a ~70 % de opacidade, com 2–3 brasas ainda acesas. Dura 3 s e a engine faz o fade.

**Nota (art bible §6):** é VFX transitório, isento da regra "nada laranja no chão" — as brasas só existem durante os 3 s do efeito. VFX de fogo (ASSET-002 a 007) também são isentos do alpha binário (§8) e são os únicos com glow.

**Prompt:**
```
pixel art top-down ground decal, 3 variations side by side, transparent background. irregular elliptical scorch mark, charred black and dark brown burned ground, soft-edged pixel clusters (no anti-aliasing), 2-3 tiny glowing orange embers remaining in each, seen from a top-down 3/4 angle. crisp hard-edged pixels, limited palette #1A0F14 #3A2E33 #FF7A1A
```
**Status:** Needed

---

## ASSET-007 — Status Queimadura (overlay no alvo)

| Field | Value |
|---|---|
| Category | VFX |
| Dimensions | 32×32 × 4f loop |
| Format | PNG RGBA, transparente |
| Naming | `vfx_burn_status.png` |

**Visual Description:** Chamas pequenas tremulando sobre o inimigo. A intensidade por acúmulo fica a cargo da engine (escala 1,0→1,4 e opacidade), não de arte extra.

**Prompt:**
```
pixel art VFX sprite sheet, 4 looping frames in one row, transparent background. small flickering flames licking upward, like a creature that is on fire, 3 small flame tongues with tiny rising embers, seamless loop. crisp hard-edged pixel art, fire palette #FFD65C #FF7A1A #C2361A, game status effect overlay
```
**Status:** Needed

> Hit flash, squash, screen shake e números de dano não são assets: saem de shader e código (quick spec §F).
