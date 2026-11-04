# Guia de construção de mundo

Módulo em `src/world/` (decisão: `docs/architecture/adr-0001-world-module.md`).
Comando do Godot abaixo = `godot --headless --path .` (omita `--headless` para janelas).

## 1. Criar uma peça nova (árvore, pedra, móvel)
1. Nova cena com raiz **WorldProp** (o script é `src/world/props/world_prop.gd`).
2. Preencha no Inspetor: `prop_id`, `category` (tree, rock, wall, roof, floor, door,
   furniture, decor), `footprint` (células ocupadas), `blocks_movement`.
3. Modelo = filhos `MeshInstance3D`. Para variações, agrupe cada uma em um `Node3D`
   chamado `Variant0`, `Variant1`... (só o de índice `variant` fica visível).
4. Colisão: adicione um `StaticBody3D` filho (camada 1) com `CollisionShape3D`
   (cilindro para árvores vira círculo no servidor). Sem ele, uma caixa automática
   é criada pelo `footprint`.
5. Salve em `assets/world/props/<categoria>/<nome>.tscn`. Exemplos: `assets/world/props/_placeholder/`.

## 2. Criar um kit de tiles
1. Uma cena por peça (uma `MeshInstance3D` cada) em `assets/world/tiles/<kit>/`.
2. Crie `assets/world/tiles/<kit>/<kit>.json` (modelo: `_placeholder/_placeholder.json`):
   `cell_size`, `scale` e `pieces` com `id`, `scene`, `collision` (`box`, `convex`,
   `trimesh` ou `none`).
3. Gere a biblioteca: `godot --headless --path . -s res://src/world/tools/build_mesh_library.gd`
   -> `assets/world/tiles/<kit>.meshlib` (todos os kits, ou passe o json após `--`).
4. No `GridMap`, use essa `.meshlib` e o mesmo `cell_size` do kit.

## 3. Criar uma região nova
1. Nova cena com raiz **WorldRegion**: defina `region_id`, `display_name`, `danger_level`,
   `bounds` (a caixa verde aparece no editor) e `ambience`.
2. Filhos por convenção: `Ground`, `Walls`, `Roofs` (GridMap), `Props`, `Markers`.
   `TileRegionBuilder` (`paint_rect`, `paint_line`, `paint_house`) pinta por código se preferir;
   exemplo completo em `src/world/tools/build_sample_assets.gd`.
3. Registre em `data/world/regions.json` (`scene`, `origin`, `bounds_center`, `bounds_size`,
   raios `load_radius` < `unload_radius`). O `WorldStreamer` cuida do resto:
   `streamer.setup(WorldCatalog.load_file(), func() -> Vector3: return jogador.global_position)`.
4. Conferir: abra `src/world/tools/world_preview.tscn` (aponte `region_scene` para a sua).

## 4. Posicionar marcadores
Adicione nós (Ctrl+A) em `Markers`: `SpawnPoint` (jogador/inimigo, `enemy_kind`, `level`,
`respawn_s`), `NpcSpot` (`npc_id`), `SecretSpot`, `HuntArea` (círculo ou caixa, níveis),
`StairLink`, `Landmark`, `QuestPoint`. Cada um mostra uma esfera colorida e rótulo só no editor.
Consulta em código (IA, missões, servidor):
```gdscript
var idx := WorldIndex.scan(region)
idx.player_spawns(); idx.get_all(&"npc"); idx.find(&"secret", &"hidden_stash")
idx.hunt_area_at(posicao)   # {} se fora de qualquer área
```
Nada de coordenadas em código: mova o marcador no editor.

## 5. Assar floresta
1. Adicione `PropScatter` na região; defina `scenes` (+ `weights`), `area_size`, `min_distance`,
   `scatter_seed`, `noise_threshold`.
2. Exclusões: `exclusion_rects`/`exclusion_circles` (espaço local), `exclusion_paths`
   (Path3D de trilhas + `trail_half_width`), `marker_root` + `marker_clear_radius`
   (raio livre em volta de spawns/NPCs), `avoid_props_root` (casas, poço).
3. Clique em **Assar floresta** no Inspetor. As peças viram filhos editáveis de `Baked`
   (mova/apague à mão; reassar substitui tudo). Mesma semente = mesmo resultado.

## 6. Exportar colisão para o servidor
```gdscript
var ex := WorldCollisionExporter.new()
ex.half = 100.0
var dados := ex.export_roots([regiao] as Array[Node], "minha_regiao")
ex.save(dados, "res://caminho/collision_surface.json")
```
Formato idêntico ao `collision_surface.json` do servidor (círculos, caixas, polígonos;
máscara 1 = cenário, 4 = água; andar -1 em `floors`). Peças com colisão devem usar camada 1
(cenário) ou 4 (água).

## Testes
`GODOT=<caminho do godot> tests/run_world_tests.sh`
