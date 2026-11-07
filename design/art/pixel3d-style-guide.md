# Guia de Estilo — 3D com visual de pixel art

**Status:** aprovado pelo usuário em 2026-11-03 ("o visual tá legal, gostei da estética, vamos gravar esse padrão").
**Escopo vigente:** direção visual do jogo oficial 3D. A documentação 2D foi arquivada; não é leitura necessária.
**Tuning:** valores abaixo descrevem a referência visual; confira o sistema afetado antes de alterá-los.
**Referência viva:** `src/game/` (shaders e parâmetros abaixo saem de lá). Pesquisa de técnicas: `docs/research/pixel3d-visual-techniques.md`.

## 1. Render
| Item | Valor | Por quê |
|---|---|---|
| Resolução interna | altura **360 px** de arte, escala inteira na janela (720p → 2×) | pixel nítido, mostra área boa |
| Câmera | **ortográfica**, pitch **-50°**, yaw 0 (norte = topo), segue o jogador com suavização | leitura de top-down sem perspectiva |
| Zoom | 1 px de arte = **1/26 u** (padrão), faixa 1/44 – 1/20 na roda do mouse (afastamento máximo reduzido 20% a pedido do usuário) | o usuário quer enxergar uma boa área |
| Câmera presa ao pixel | posição arredondada à grade do pixel no plano da câmera; o resto vira deslocamento da imagem final | sem tremer, rolagem suave |
| AA / filtro | MSAA e SSAA desligados; textura final com filtro **nearest** | pixel puro |

## 2. Luz e sombra
- **Toon em 3 faixas** (`toon_bands 3`, `toon_bias 0.35`) em todo material sólido; luz direcional sem divisão por π.
- **Sol:** cor (1.0, 0.92, 0.78), energia 1.0, rotação (-52°, -38°), sombras ortogonais duras.
- **Ambiente:** cor roxa fria (0.42, 0.36, 0.64), energia 0.5 — as sombras são roxas, nunca pretas.
- **Sombras de nuvem:** ruído global `cloud_noise` rolando devagar, escurece o sol até 7 % (`mix(0.93, 1.0, ...)` no shader atual).
- **Pós:** glow aditivo, limiar HDR 1.4 (folhagem clara não brilha; emissivos de magia ficam em 3–5), intensidade 0.9; saturação 1.15, contraste 1.06; tonemap linear.
- **Luzes pontuais** (lampiões, fogueiras, magia): quentes, alcance curto (2–4 u), piscando por seno; sem sombra. Máx. ~8 por tela.

## 3. Contorno
Pós-processo por profundidade e normal (`outline_post`):
- **Silhueta** (salto de profundidade > 0.9 u): escurece para 42 %.
- **Quina** (normal quebrando): clareia para 135 %.
- Grama e detalhes baixos **não** ganham contorno (por isso o limiar alto).

## 4. Paleta do mundo
| Elemento | Cores |
|---|---|
| Grama (3 tons por ruído) | (0.22,0.38,0.19) · (0.27,0.44,0.20) · (0.33,0.50,0.21) |
| Terra de trilha | (0.36,0.24,0.16) · (0.46,0.32,0.20); lama de margem (0.26,0.20,0.14) |
| Pedra de praça | (0.50,0.48,0.50) · (0.56,0.54,0.55), juntas a 60 % |
| Água | rasa (0.32,0.72,0.72) → funda (0.07,0.20,0.36) em 4 faixas; espuma (0.86,0.96,1.0) |
| Copas | **variar por bioma** — não só verde: outono (laranja/vermelho), flor (rosa), mágica (roxa), dourada |
| Madeira / ferro | (0.50,0.33,0.20) · (0.32,0.20,0.13) / (0.16,0.14,0.18) |

## 5. Vegetação e chão
- Chão: grama em 3 tons por ruído, trilhas de terra com borda misturada, praças com pedra em fiadas desencontradas.
- Grama 3D (MultiMesh): herda a cor e a luz do chão (normal "para cima"), vento, afasta do jogador.
- Árvores: low-poly facetado (6–8 lados), copas em esferas/cones, balançam ao vento. Tamanho e cor variados.
- Água: bacia afundando o chão, superfície com cor por profundidade, espuma recortada na margem, rio com correnteza seguindo a curva.

## 6. Efeitos (VFX)
- **Só magia e luz passam de 1 (HDR)** e acendem o bloom; o resto do mundo fica abaixo.
- Efeitos em **faixas** (3 degraus), nunca degradê liso — casa com a luz toon.
- **Personagem com poder elemental: runas e canais acesos correndo pela roupa** (`rune_flow`), não o corpo pegando fogo. Chama de verdade só em pontos (ponta do cajado).
- **Movimento:** teleporte = dissolve com borda acesa + fantasmas no trajeto + faíscas + onda de choque; esquiva = fantasmas. Cor do efeito = elemento (fogo laranja, neutro azul).
- Vida no ar: vagalumes, folhas, brasas — poucos e discretos.

## 7. Personagens
- Modelos 3D low-poly (CC0, KayKit/Quaternius) com toon + contorno; equipamento como peças presas aos ossos (paperdoll).
- Altura ~1,7 u (≈ 30 px de arte no zoom padrão). Silhueta legível de cima: cabeça/chapéu e arma grandes.
- Runas/emissivos pintados em máscara (UV2 ao longo do canal) quando houver modelo real.

## 8. Não fazer
- Sombras pretas, degradês lisos, bloom em superfícies comuns, texturas fotográficas.
- `texture()` com `fract()` em ruído (gera o "+" piscando) — usar `textureLod(..., 0.0)` ou repeat.
- Muitas luzes com sombra; efeitos que cobrem o personagem inteiro.
