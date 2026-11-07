# PROTOTYPE - NOT FOR PRODUCTION — Mago de Fogo · Clareira de Treino

**Status:** in-progress (2026-10-30)

## Hipótese

O kit do Mago de Fogo, com tab-target, GCD de 0,75 s, spell queue, Queimadura e Ignição, mais o
game feel em tiers (hit-stop local, flash, shake, squash, partículas), fica **fluido e com impacto**
num MMORPG 2D top-down. Também queremos ver se o Pilar de Chamas "pesa" mais que a Bola de Fogo.

Fonte: `design/quick-specs/class-combat-fire-mage-mvp-2026-10-30.md`. Valores em `data.js`.

## Como rodar

Abra `index.html` direto no navegador (duplo clique). Não precisa de servidor nem instalação.

| Tecla | Ação |
|---|---|
| WASD / setas | Andar (andar cancela a Bola de Fogo durante o cast) |
| Tab / clique | Trocar ou selecionar alvo · Esc limpa |
| 1 / 2 / 3 / 4 | Fagulha · Bola de Fogo · Pilar de Chamas · Anel de Fogo |
| E | Invocar 5 slimes que perseguem o mago (teste do Anel de Fogo) |
| R | Reiniciar os bonecos |
| K / F / H | Ligar/desligar shake · reduzir flashes · ajuda |

Combo de teste: **Fagulha → Bola de Fogo → Bola de Fogo** = Ignição (3 acúmulos).

## Usando as artes geradas na IA

Coloque a spritesheet do ASSET-001 (384×576, layout em `design/assets/specs/fire-mage-assets.md`) em
`assets/spr_mage_fire_sheet.png`. O protótipo usa o PNG automaticamente no lugar do mago procedural,
e o rodapé passa a mostrar `sprites: PNG (ASSET-001)`. O resto da arte (árvores, bonecos, VFX) continua
procedural por enquanto.

## Limitações conhecidas

- Sem rede. O hit-stop congela só a animação e adia o início do knockback, e o resto da simulação continua.
- Os inimigos não atacam: é um campo de treino.
- A arte é placeholder procedural, para validar feel e leitura, não o visual final.

## Findings

_(preencher depois do playtest)_
