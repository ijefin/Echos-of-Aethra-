# Pipeline de itens

Como um item nasce: **dados** (`assets/data/items.json`), depois a **arte** (`assets/items/item_models.json` + modelo 3D), depois o **ícone** (gerado). O código fica em `src/items/` e não importa nada de `prototypes/`.

| Peça | Arquivo | Papel |
|---|---|---|
| `ItemDefinition` | `src/items/item_definition.gd` | Resource com um tipo de item (id, nome, lore, slot, vocações, atributos, raridade, pilha, valor, uso, tint, modelo, ícone). Também pode ser um `.tres`. |
| `ItemCatalog` | `src/items/item_catalog.gd` | Junta `items.json` e `item_models.json`; consultas `item`, `by_slot`, `by_kind`, `usable_by`, `by_rarity`, `with_model`. Injetável: o construtor recebe os dicionários. |
| `IconBaker` | `src/items/tools/icon_baker.gd` (+ `.tscn`) | Renderiza um modelo num SubViewport e devolve o ícone em pixel art. |
| Gerador | `src/items/tools/bake_item_icons.gd` | Gera `assets/items/icons/<id>.png` e a vitrine `assets/items/icons/models/<chave>.png`. |
| Comando | `tools/bake_item_icons.sh` | Gerador, depois `tools/items/sync_icon_fields.py` (grava `"icon"` em items.json), depois importa os PNGs. |
| Testes | `tests/unit/items/`, `bash tests/run_item_tests.sh` | Catálogo, pós-processo e enquadramento. |

## Criar um item novo

1. **Dados.** Adicione a entrada em `assets/data/items.json` → `"items"`. Formato: tab, CRLF e a ordem das chaves. O servidor e o protótipo leem este arquivo, então só **adicione** campos.
   ```json
   "war_axe": {
   	"name": "Machado de Guerra",
   	"slot": "weapon",
   	"rarity": "rare",
   	"classes": ["warrior"],
   	"two_handed": true,
   	"stats": {"attack_power": 8, "STR": 3},
   	"desc": "Pesado demais para quem nunca segurou uma linha de escudos.",
   	"color": [0.55, 0.55, 0.6]
   }
   ```
   | Campo | Obrigatório | Significado |
   |---|---|---|
   | `name` | sim | Nome mostrado. |
   | `slot` | só equipamento | `head`, `neck`, `weapon`, `chest`, `legs`, `feet`, `shield` (lista em `"slots"`). |
   | `classes` | não | Vocações que usam o item (`fire_mage`, `warrior`, `archer`). Vazio quer dizer todas. |
   | `stats` | não | Chaves de `"stat_names"` (mais `block`). |
   | `rarity` | não | `basic`, `common`, `rare` ou `epic`. Sem o campo, vale `basic`, e a loja paga por ele. |
   | `desc` | não | Lore curta, só história. Nada de tecla nem instrução. |
   | `kind` | não | `equipment` (é o padrão quando há slot), `consumable`, `key`, `ammo`, `material` ou `misc`. |
   | `stack` / `value` | não | Tamanho máximo da pilha e preço de referência em moedas. |
   | `use` | consumíveis | Efeito ao usar: `{"hp": 45}`, `{"mana": 35}`, `{"buff": "STR", "amount": 4, "duration": 60}`. |
   | `two_handed` | não | Marca a arma de duas mãos. A regra que esvazia o slot `shield` ainda não existe. |
   | `tint` | não | Multiplica a cor do modelo e do ícone (recolore um modelo reaproveitado). |
   | `color` | não | Cor do desenho de reserva da bolsa, usado quando o item não tem ícone. |
   | `model` / `icon` / `icon_view` | não | Sobrepõem o que vem de `item_models.json` e da convenção de ícone. |

   **Balanço de referência** (veja `src/game/data/shop.json` `_balance`):
   - Arma comum: ataque ou poder mágico de 3 a 4, mais 1 a 2 de atributo.
   - Arma rara: 6 a 8, mais 3.
   - Arma épica: cerca de 14, mais 6.
   - Escudo comum: armadura 4 a 6 e bloqueio 0,06 a 0,1.
   - Escudo raro: armadura 6 a 8 e bloqueio 0,1 a 0,12.
   - Poções: 45 de vida ou 35 de mana, por 10 e 12 moedas.

2. **Arte.** Em `assets/items/item_models.json`:
   - `"models"` é a biblioteca: `chave → {"path": "res://…glb", "view": {…}}`.
   - `"items"` liga o item à arte: `id → "chave"` ou `{"model": "chave", "view": {…}}`.
   - Na `view` vão `yaw`, `pitch` e `roll` em graus, `zoom` (acima de 1 aproxima) e `offset` `[x, y]` em fração do quadro.
   - Padrões para armas longas: `roll: 45`, para a lâmina apontar para cima e para a direita. Bestas: `pitch: -75`, vista de cima.

   Um modelo pode servir a vários itens: `iron_sword` e `guard_sword` usam o mesmo, e o `tint` os diferencia.
3. **Ícone.** Rode `bash tools/bake_item_icons.sh --missing`. Ele abre uma janela do Godot por alguns segundos, porque precisa de GPU. Depois **olhe** o PNG.
   - `--items id1 id2` gera só esses itens. Sem argumentos, gera tudo.
   - Padrões do render ficam no bloco `"bake"`: 32 px de arte ampliados para 64 px, câmera ortográfica 3/4 (yaw 35°, pitch −30°), sol e ambiente do guia pixel3d, materiais toon, alfa duro e contorno de 1 px.
4. **Testes.** Rode `bash tests/run_item_tests.sh`. O teste do catálogo com os dados reais confere que todo modelo e todo ícone apontado existe. Rode também `bash tools/net_unit_tests.sh`, porque o servidor lê items.json.

Para usar no código:

```gdscript
var cat := ItemCatalog.load_default()
var def := cat.item(&"war_axe")
def.get_icon()        # Texture2D, ou null
def.get_model()       # PackedScene, ou null
cat.usable_by("warrior", &"shield")
```

## O que já existe

- **Biblioteca:** 61 modelos CC0 com vitrine em `assets/items/icons/models/`.
  - KayKit Adventurers: espadas, machados, adaga, cajado, varinha, bestas, flechas, aljava, 9 escudos, grimórios, bomba e canecas.
  - KayKit Dungeon: garrafas, moedas, chave, molho de chaves, baús, pratos, velas, tochas e estandartes.
- **Itens com ícone:** 32. São 7 antigos (espadas, cajados, escudo redondo, grimório do Piromante) e 25 novos.
- **Sem modelo, ainda com o desenho por código:**
  - Todo capacete, peitoral, calça, bota e colar.
  - Os arcos (`hunting_bow`, `yew_bow`): não há arco no pacote, e besta não serve.
  - O `ember_orb`.

## Falta modelar no Blender

| Slot | Itens que já existem em items.json | Sugestão |
|---|---|---|
| Cabeça | `mage_hat`, `apprentice_hood`, `pyromancer_hood`, `knight_helm`, `leather_hood` | chapéu pontudo, capuz de pano, elmo fechado, capuz de couro |
| Peito | `apprentice_robe`, `ember_robe`, `pyromancer_robe`, `mist_mantle`, `chain_mail`, `lair_cuirass`, `leather_vest`, `wolfhide_jerkin` | um torso "no cabide" por item: robe, cota, couraça, colete |
| Calças | `linen_trousers`, `pyromancer_trousers` | calça dobrada ou em pé |
| Botas | `wanderer_boots`, `pyromancer_boots`, `crypt_greaves` | par de botas em 3/4 |
| Luvas | nenhum ainda; o slot `hands` ainda não existe em `"slots"` | par de luvas |
| Anéis | nenhum ainda; o slot `ring` ainda não existe | aro e gema, com a gema em material separado para receber o `tint` |
| Amuletos | `ember_amulet`, `pyromancer_amulet`, `elder_fang_charm` | corrente curta e pingente: gema, presa, brasa |
| Arcos | `hunting_bow`, `yew_bow` | arco curto e arco longo |
| Orbe | `ember_orb` | esfera num suporte |

### Padrão para os modelos novos (mercado: um asset por item)

- **Um `.glb` por item** em `assets/items/models/<slot>/<id>.glb`. O nome do arquivo é igual ao id, em snake_case.
- **Escala real em metros** (1 u = 1 m), como os kits KayKit. Um elmo tem cerca de 0,3 m e uma espada de uma mão cerca de 0,9 m.
- **Pivô no ponto de pega ou de fixação**:
  - Arma: no cabo, onde a mão fecha. Lâmina para +Y.
  - Escudo: no centro do braçal, face para +Z.
  - Capacete: na base, onde encaixa na cabeça.
  - Botas e calças: na sola ou na cintura.

  Com o pivô assim, o mesmo `.glb` serve ao ícone e ao paperdoll (preso ao osso).
- **Frente para +Z e Y para cima.** O padrão do glTF já faz isso ao exportar do Blender com "+Y Up".
- **Low-poly com 1 material** e a textura em atlas de paleta, no estilo KayKit, de 64 px ou mais. Sem normal map: o toon e o contorno do jogo cuidam do volume.
- **Partes recoloríveis** (tecido, gema) num material separado, para o `tint` agir só nelas quando isso for desejado.
- **De 300 a 1.500 triângulos** por item. A partir de cerca de 2 m de câmera não aparece diferença.
- **Depois de exportar:** adicione a chave em `item_models.json` `"models"`, ligue o item em `"items"` e rode `bash tools/bake_item_icons.sh --items <id>`.

## Decisões e próximos passos

- Os ícones vêm de um **render 3D**, não de desenho à mão. Assim o ícone sempre bate com o modelo do mundo e do personagem, e um item novo custa um comando. Desenho à mão continua possível: um PNG em `icon` sobrepõe o gerado.
- Os itens novos ainda **não** caem de monstros nem estão em lojas.
- As poções da bolsa continuam sendo os contadores `hp` e `mana` do protótipo. `health_potion` e `mana_potion` são as definições de catálogo para a migração.
- Ainda não existe: a regra de `two_handed`, os efeitos de `use` fora de vida e mana, e os slots `hands` e `ring`.
