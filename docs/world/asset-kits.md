# Kits de peças do mundo

## Kits

| Kit | Pasta | Licença | Uso |
|---|---|---|---|
| KayKit Dungeon Remastered 1.0 | `assets/third_party/kaykit_dungeon_remastered/` | CC0 | paredes, portas, janelas, pisos, escadas, móveis, tochas, estandartes |
| KayKit Medieval Hexagon Pack 1.0 | `assets/third_party/kaykit_medieval_hexagon/` | CC0 | cercas, ponte, poço, árvores, pedras, adereços de rua, casas inteiras (provisórias), muralha |
| KayKit Adventurers (personagens) | `assets/third_party/kaykit_adventurers/` | CC0 | referência de altura (Knight) |

Origem, data e o que foi copiado: `SOURCE.md` de cada pasta. Entram só glTF/GLB,
texturas e `LICENSE.txt` (OBJ/FBX/PDF estão no `.gitignore`).

## Escala e grade

- **Célula: 1,5 m.** Os dois kits usam a mesma grade (`cell_size` em `<kit>.json`).
- **Dungeon: escala 0,75.** O Knight mede 2,467 u e o jogo o põe a 1,8 m (0,7296);
  arredondado para 0,75 para a parede de 4 u virar 3,0 m = 2 células. Pé-direito 3 m,
  piso pequeno 1,5 m, piso grande 3 m, parede com 0,75 m de espessura.
- Parede = peça de **aresta**: centrada na origem, comprida em X, ocupando 2 células;
  gire 90° para as laterais. Os cantos ficam livres (a vitrine usa `pillar` variante 1).
- **Hexagon: escala base 3,6** (caixa de 0,21 u = caixa pequena do Dungeon, 0,75 m), com
  escala própria por peça (cercas 2,6 para medir 3 m; casas 6; muralha 3). O pacote é de
  tabuleiro, então as peças são recentralizadas em XZ e as cercas giradas 90°. Os cantos da
  muralha são de hexágono (120°): servem de provisório.
- Rotações válidas: 0/90/180/270.

## Como adicionar peça ou kit

1. Copie os glTF/GLB para `assets/third_party/<kit>/` (+ `LICENSE.txt` e `SOURCE.md`) e rode
   `godot --headless --path . --import`.
2. Meça: `godot --headless --path . -s res://tools/world/measure_models.gd -- <pasta ou arquivo>`.
3. Edite `assets/world/tiles/<kit>/mapping.json` (kit novo: copie um existente). Por peça:
   `prop_id` (único entre todos os kits), `category`, `variants` (arquivos; o primeiro é o
   padrão), `blocks`, e opcionais `scale`, `yaw`, `footprint` (senão vem da AABB),
   `collision` (`box` | `trunk` | `doorway` com `opening`/`lintel` | `corner` com `thickness`).
4. Gere: `godot --headless --path . -s res://tools/world/import_kit.gd -- res://assets/world/tiles/<kit>/mapping.json`
   (passe todas as tabelas juntas para checar `prop_id` repetido). Sai em
   `assets/world/props/<categoria>/<prop_id>.tscn` e atualiza `<kit>.json`.
   Peça removida da tabela: apague a `.tscn` à mão.
5. Confira: `godot --path . -s res://tools/world/kit_showcase.gd -- --shot` (janelado) grava
   `production/qa/evidence/world-kit-*.png` (+ `-pixel`).

## Peças-chave para modelar no Blender (faltam nos kits)

Na grade do Dungeon (aresta 3 m, pé-direito 3 m, espessura 0,75 m, origem no centro da aresta, base em y = 0):

- **Telhados**: duas águas (módulo 3 m), canto/espigão, cumeeira, beiral/empena.
- **Parede de madeira / enxaimel** + variantes com porta e com janela.
- **Porta que abre** (folha separada com pivô na dobradiça, para animar).
- **Lampião de poste** (com ponto para OmniLight).
- **Estrada / calçamento modular** (reta, curva, cruzamento, borda com grama) em 1,5 m e 3 m.
- **Chaminé** (encaixa na cumeeira).
- **Placa de loja** (suporte de parede + placa trocável por textura).
- **Fonte de praça** (peça central de 2x2 ou 3x3 células).
