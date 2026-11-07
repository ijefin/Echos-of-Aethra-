# Character Races & Modular Equipment (Paperdoll) — Asset Specification

## 1. Visão Geral

Este documento orienta o agente **Claude Code / Art Director & Pixel Art Specialist** para a produção das spritesheets de raças jogáveis e camadas de equipamento visual (armaduras e robes) do MMORPG **Ecos de Aethra**.

O jogo utiliza visão top-down 2D em pixel art com perspectiva levemente inclinada (3/4 top-down). Os personagens vestem itens que devem se refletir visualmente no avatar in-game via renderização modular por camadas (paperdoll).

---

## 2. Padrão Técnico de Spritesheet

| Parâmetro | Valor |
|---|---|
| **Resolução da Célula** | 64 × 64 px |
| **Pivô de Renderização** | `(32, 58)` (base dos pés) |
| **Grid da Spritesheet** | 6 colunas × 9 linhas (layout padrão do jogo) |
| **Direções Base** | 4 direções lógicas: Baixo (Down), Cima (Up), Direita (Right) — Esquerda gerada por espelhamento horizontal |
| **Distribuição de Linhas** | - Linhas 0, 1, 2: `idle` (Down, Up, Right)<br>- Linhas 3, 4, 5: `walk` / `run` (Down, Up, Right)<br>- Linhas 6, 7, 8: `attack` / `action` (Down, Up, Right) |
| **Frames por Animação** | - `idle`: 4 frames (6 FPS)<br>- `walk`: 6 frames (10-12 FPS)<br>- `attack` / `cast`: 6 frames (12-14 FPS com frame 3 de impacto/release)<br>- `dash`: 3 frames (esticamento dinâmico) |

---

## 3. Raças Comuns

### 3.1 Humano (Human)
- **Silhueta**: Proporção áurea padrão, postura equilibrada.
- **Altura no sprite**: ~34 px da base dos pés ao topo da cabeça.
- **Tonalidades**: Pele clara a morena, traços neutros.

### 3.2 Elfo (Elf)
- **Silhueta**: Ligeiramente mais alto e esguio, postura ereta e ágil.
- **Altura no sprite**: ~36 px, orelhas pontiagudas visíveis nas vistas laterais e traseiras.
- **Tonalidades**: Pele pálida a bronzeada, olhos ligeiramente amendoados e brilhantes.

### 3.3 Anão (Dwarf)
- **Silhueta**: Mais baixo, tronco robusto e ombros largos, centro de gravidade baixo.
- **Altura no sprite**: ~28-30 px, maior largura de ombro (~18 px de largura visual).
- **Tonalidades**: Barba expressiva volumosa, postura pesada e firme.

---

## 4. Camadas Modulares de Equipamento (Paperdoll)

Para que armaduras e robes reflitam no personagem, cada conjunto de equipamento usa a mesma grade (64×64) e os mesmos frames de animação, desenhados diretamente alinhados sobre o corpo base:

1. **Camada 0 (Z -2)**: Capa / Detalhe posterior (opcional).
2. **Camada 1 (Z 0)**: Corpo da Raça (pele base).
3. **Camada 2 (Z 1)**: Traje Inferior (calças, perneiras, botas).
4. **Camada 3 (Z 2)**: Traje Superior (peitoral de placa, cota de malha, robe de tecido).
5. **Camada 4 (Z 3)**: Cabeça (cabelo, capacete, capuz).
6. **Camada 5 (Z 4)**: Arma / Cajado / Escudo.

### 4.1 Conjuntos Iniciais Prioritários

- **Robe de Tecido / Mago**:
  - Gola alta, caimento solto cobrindo pernas, mangas largas que acompanham a movimentação dos braços.
  - Paleta: Vermelho Carmesim/Dourado (Mago de Fogo) ou Azul Escuro/Prata.
- **Armadura de Placas / Guerreiro**:
  - Peitoral de ferro sólido com brilho metálico, ombreiras volumosas, joelheiras reforçadas.
  - Paleta: Cinza aço (STEEL), rebites de bronze e couro escuro.

---

## 5. Instruções para o Agente Claude

Quando for trabalhar nesta frente:
1. Gere os PNGs mantendo rigorosamente a paleta de cores e o grid 64×64 com pivô em `(32, 58)`.
2. As texturas devem ser salvas em `assets/art/chars/`:
   - `spr_base_human.png`
   - `spr_base_elf.png`
   - `spr_base_dwarf.png`
   - `spr_gear_robe_fire.png`
   - `spr_gear_armor_iron.png`
3. A integração no código será feita conectando as camadas como `Sprite2D` filhos do `PlayerAvatar` com sincronização automática do `frame` e `flip_h`.
