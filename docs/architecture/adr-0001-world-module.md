# ADR-0001: Módulo de mundo (regiões, peças, tiles, marcadores)

Status: Aceito (2026-11-04) · Código: `src/world/` · Guia: `docs/world/world-building-guide.md`

## Contexto

O mundo do protótipo (`src/game/`) é gerado por código (floresta, casas,
trilhas) a partir de coordenadas fixas. Isso impede criar cenários novos, cidades e
casas no editor, e obriga IA, missões e o servidor a conhecer coordenadas literais.
O jogo precisa de um módulo de produção reutilizável, independente do protótipo e do
estilo visual (pixel-art/toon é injetado pelo jogo).

## Alternativas

1. **Geração procedural em runtime** (como hoje). Prós: zero arte de cena, pouco
   armazenamento. Contras: não editável à mão, difícil de revisar, custo de CPU na
   carga, qualquer ajuste exige código.
2. **Cenas + GridMap + marcadores (escolhida).** Regiões são cenas `.tscn` editáveis;
   chão/paredes/telhados em `GridMap` com `MeshLibrary` gerada de kits CC0; peças soltas
   são cenas `WorldProp`; florestas são "assadas" (bake) por `PropScatter` como filhos
   editáveis. Padrão de mercado em Godot, sem dependências.
3. **Terreno/heightmap** (`HeightMapShape3D`, malha de relevo). Bom para relevo contínuo,
   mas o jogo é de cenário em células/andares e a colisão do servidor é 2D por pegada;
   fica como extensão futura (camada `Ground` pode ser trocada sem mudar o resto).
4. **Terrain3D / plugins de terceiros.** Poderosos, mas amarram o projeto a um GDExtension
   externo, a versões da engine (4.7) e a formatos próprios que o exportador de colisão
   do servidor teria de entender.

## Decisão

- **Região** = cena com raiz `WorldRegion` (`region_id`, `bounds`, `danger_level`, `ambience`).
  Convenção de filhos: `Ground/Walls/Roofs` (GridMap), `Props`, `Markers`.
- **Marcadores** (`SpawnPoint`, `NpcSpot`, `SecretSpot`, `HuntArea`, `StairLink`, `Landmark`,
  `QuestPoint`) são nós `@tool` com gizmo só no editor. O **`WorldIndex`** (RefCounted)
  varre a região e devolve dicionários; IA, missões e servidor consomem o índice, nunca
  coordenadas fixas.
- **Peças** = `WorldProp` (contrato fixo com a arte: `prop_id`, `category`, `footprint`,
  `blocks_movement`, `variant`/`Variant0..N`, `tint`, `apply_style`). Colisão na camada 1.
- **Estilo**: `WorldStyle` (Resource, no-op por padrão) aplicado na carga; o módulo não
  conhece shaders.
- **Streaming**: `WorldStreamer` (injetável) + `WorldCatalog` (`data/world/regions.json`),
  carga por `ResourceLoader.load_threaded_request`, histerese `load_radius < unload_radius`.
- **Tiles**: `MeshLibraryBuilder` gera `.meshlib` de `assets/world/tiles/<kit>/<kit>.json`;
  `TileGrid`/`OccupancyGrid`/`TileRegionBuilder` para convenções e pintura.
- **Floresta**: `PropScatter` (Poisson + ruído + exclusões, semente) com bake.
- **Servidor**: `WorldCollisionExporter` gera o mesmo JSON de `collision_surface.json`
  (versão 2) a partir de StaticBody das camadas 1/4 e de GridMap.
- O módulo **não importa nada de `src/game/` ou `legacy/`** (verificado por teste de integração).

## Consequências

- (+) Cenários, cidades e casas novos são cenas/dados; sem tocar em código.
- (+) Um único formato de consulta (WorldIndex) para IA/missões/servidor.
- (+) Troca de arte (placeholder -> kits reais) sem mudar ids nem cenas de região.
- (-) Arquivos `.tscn` de floresta assada são grandes e geram diffs ao reassar
  (mitigação: semente fixa, reassar só ao mudar parâmetros).
- (-) GridMap não faz relevo; relevo exigirá a alternativa 3 depois.
- (-) A colisão do servidor é aproximada (círculos/caixas/polígonos convexos na faixa
  de altura do jogador), como no protótipo.
- O cenário atual em `src/game/` permanece procedural; sua integração com regiões é trabalho futuro.

Nota de manutenção (2026-11-06): o 3D foi adotado e movido para `src/game/`.
A fronteira de independência deste módulo permanece; apenas o caminho foi atualizado.
