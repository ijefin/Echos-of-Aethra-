# Art Bible: Ecos de Aethra

> **Status**: Draft
> **Owned By**: art-director
> **Last Updated**: 2026-10-30
> **Art Director Sign-Off (AD-ART-BIBLE)**: SKIPPED 2026-10-30 — solo mode
> **Escopo desta versão**: seções 1–4, 6 e 8. Seções 5, 7 e 9 ainda `[To be designed]`.

`/art-bible` writes these nine sections in this order and replaces each
section's `[To be designed]` line as that section is approved. A section still
holding its placeholder is incomplete; a later run fills only those.

## 1. Visual Identity Statement

> **Histórico de estilo — 2026-10-31.** Uma revisão para "2D pintado em HD com rig de peças" foi aprovada e, no mesmo dia, **descartada** pelo usuário depois de ver um sprite de referência em pixel art (o Ladino, 48×48, 8 direções). **Vale pixel art**, agora no nível de detalhe desse sprite de referência, gerado em ferramenta de IA especializada em pixel art. O protótipo do rig HD ficou arquivado em `prototypes/hd-rig-showroom/`.

**Regra visual (uma linha):** *Aethra é uma ilha viva que brilha: cada elemento tem profundidade, está enraizado no chão e é banhado por luz quente — e a magia é a luz mais forte da cena.*

> Desempate geral: se uma escolha deixa a cena mais plana, solta ou apagada, ela está errada.

### Princípio 1 — Enraizado e em camadas (profundidade)
- **Serve:** pitch ("ilha mágica e viva") + "deslumbramento com uma ilha encantada".
- **Significa:** vista 3/4 (~45°), luz de cima-esquerda, sombra de contato e oclusão ambiente; copas, troncos e raízes desenhados com volume, não "colocados na grama"; camadas de primeiro plano, meio e fundo (lagos, desníveis, névoa).
- **Teste:** *Quando um objeto parecer solto ou plano, escolha a versão com sombra de contato, raízes/base integrada ao terreno e ao menos uma camada de sobreposição (folhagem, grama alta, desnível).*
- **Checável no output de IA:** base do objeto toca o chão com sombra; contorno colorido só na silhueta externa; luz sempre de cima-esquerda.

### Princípio 2 — A ilha respira (vida e densidade)
- **Serve:** pitch ("ilha mágica e *viva*") + "mistério" (há sempre algo a descobrir na cena).
- **Significa:** detalhe ambiental denso e animado: folhas caindo, grama balançando, borboletas, coelhos, esquilos, feixes de luz, água, fontes, fogueiras.
- **Teste:** *Quando uma área parecer vazia ou estática, adicione vida ambiente (partícula, criatura ou movimento sutil) antes de adicionar mais objetos estruturais, sem competir com o jogador ou com inimigos pela leitura.*
- **Checável:** toda tela tem ao menos 1 elemento animado de fundo e 1 fonte de luz/água; detalhes ambientais com menos contraste que personagem e perigos.

### Princípio 3 — Luz quente, magia luminosa (cor e poder divino)
- **Serve:** "sensação de se tornar digno de um poder divino" + pitch (santuários que despertam, escolha divina) + trilha mística.
- **Significa:** luz quente e manchada na floresta; rampas com mudança de matiz (sombras para azul/roxo, realces para amarelo); magia e santuários são as fontes mais brilhantes e saturadas, e iluminam o cenário ao redor. Santuário adormecido = frio e apagado; desperto = quente e brilhante.
- **Teste:** *Quando houver dúvida sobre qual elemento merece o maior brilho/saturação, dê-o ao poder divino (magia, santuário, classe do jogador); o resto do cenário recua em luz quente e suave.*
- **Checável:** rampas com hue shift (nunca só escurecer/clarear); o ponto mais luminoso da cena é uma fonte mágica; sombras nunca em preto ou cinza puro.

**Nota de pipeline:** o problema do placeholder atual ("muito desenhado e solto, profundidade zero") é o caso-teste do Princípio 1; use-o como critério de aprovação do primeiro lote de árvores geradas por IA.

## 2. Mood & Atmosphere

- **Regra-base:** a luz do mundo vem de cima-esquerda. Só magia, santuários e fogueira criam luz local própria. O que distingue os estados é temperatura, contraste e vida ambiente, não a hora do dia.

**Exploração (praia / floresta / lagos, de dia)**
- **Emoção-alvo:** deslumbramento curioso ("o que tem depois daquela clareira?"). **Energia:** média-baixa.
- **Luz:** quente-dourada (manhã ou fim de tarde), contraste médio; manchada na floresta, mais alta e clara na praia.
- **Elemento portador:** feixes de luz atravessando a copa + vida ambiente (borboletas, coelhos, folhas caindo).
- **Descritores:** luminoso, vivo, convidativo, sereno, encantado.

**Combate (PvE; PvP depois)**
- **Emoção-alvo:** tensão focada e domínio do próprio poder. **Energia:** alta.
- **Luz:** o ambiente perde 10–15% de saturação e o contraste sobe; a magia do jogador (brasa) e o perigo inimigo (violeta) dominam a cor. A hora do dia não muda.
- **Elemento portador:** a magia ilumina o chão ao redor; a vida ambiente foge (esquilos correm, pássaros voam).
- **Descritores:** tenso, legível, vibrante, perigoso, decisivo.

**Santuário adormecido**
- **Emoção-alvo:** mistério reverente com leve inquietação. **Energia:** baixa.
- **Luz:** fria e crepuscular, baixo contraste; um único feixe frio de cima-esquerda com poeira suspensa; névoa no chão.
- **Elemento portador:** runas apagadas na pedra; raízes engolindo a geometria.
- **Descritores:** silencioso, antigo, frio, solene, à espera.

**Santuário desperto / "O Chamado"**
- **Emoção-alvo:** assombro e sensação de ser digno. **Energia:** pico curto, depois calma.
- **Luz:** ouro quente nascendo do centro do santuário (exceção local à luz de cima-esquerda), contraste máximo; a cena vira de fria para quente.
- **Elemento portador:** runas acendendo em sequência e coluna de luz dourada sobre o jogador.
- **Descritores:** radiante, sagrado, triunfal, quente, transformador.

**Morte → renascer na fogueira**
- **Morte:** perda breve, sem punição; energia mínima. O mundo dessatura e esfria.
- **Renascer:** alívio e acolhimento; a fogueira é a única fonte quente, com faíscas subindo.
- **Descritores:** quieto, frio→quente, protegido, íntimo.

**Menus / HUD**
- **Emoção-alvo:** calma ritual. Pedra escura com ouro; HUD discreto na exploração, mais legível no combate.
- **Descritores:** sóbrio, entalhado, claro.

**Teste de distinção:** um screenshot de cada estado em P&B deve continuar identificável pelo contraste e pela fonte de luz.

## 3. Shape Language

**Gramática central** (liga à Seção 1: "enraizado", "ilha viva", "magia como luz mais forte")
- **Orgânico** (curvas, cachos, gotas) = **vida da ilha**. Serve "ilha mágica e viva" → acolhimento.
- **Geométrico antigo** (simetria, arcos, círculos concêntricos, 90°/45°, bordas gastas) = **o divino e os santuários**. Serve "força divina", "santuários antigos" → ordem, poder, reverência.
- **Angular assimétrico/quebrado** (espinhos, geometria de santuário rachada) = **o que acordou**. Serve "enfrentando o que acordou" → ameaça.

**Personagens (célula 64 px, personagem ~44 px)**
- **Teste de silhueta:** preenchida de preto a 1×, a classe é reconhecível em < 1 s.
- **Proporção:** cabeça de 12–14 px, levemente estilizada (aprovado pelo usuário em 2026-10-30) — legível no 3/4 e expressiva.
- **Um traço distintivo por arquétipo:**
  - **Mago de Fogo:** capuz pontudo (triângulo para cima) + cajado com brasa na ponta.
  - **Guerreiro:** bloco largo nos ombros (retângulo massivo) + lâmina larga.
  - **Paladino:** simetria vertical + escudo em losango (geometria do santuário).
  - **Arqueiro:** silhueta esguia e assimétrica + arco curvo saindo da massa.
- **Inimigos "despertos":** fragmentos geométricos quebrados com pontas; nunca curvas suaves.
- **Fauna benigna:** formas 100% arredondadas.

**Ambiente**
- **Árvores:** copa de 3–5 massas arredondadas sobrepostas; tronco que se abre em raízes na base (corrige "colocadas na grama"); sombra de contato elíptica.
- **Natureza sem linha reta:** pedras arredondadas, margens de lago em curvas suaves, tufos de grama que quebram as bordas dos tiles.
- **Santuários:** simetria bilateral, arcos, motivo solar concêntrico, erosão nas quinas. Estrutura geométrica invadida por forma orgânica = "antigo".

**Herói vs. suporte**
- **Herói** (jogador, inimigos, interativos, núcleo do santuário): contorno externo escuro (base #1A0F14), contraste máximo, forma mais simples e fechada.
- **Suporte** (decoração): contorno tingido da cor local, contraste menor, detalhe interno maior, massa mais solta.
- **Teste:** quando um objeto de cenário competir com o jogador, simplifique o cenário, não o jogador.

**UI**
- Molduras de pedra entalhada com cantos chanfrados de 2 px (geometria do santuário = interface do "poder divino"). Bordas de 1–2 px na resolução 640×360.
- **Ícones:** habilidades em losango, itens em círculo, alertas de perigo em formas angulares/triangulares.
- **Mensagem:** o que é seu e o que é sagrado é ordenado e estável; o que ameaça é quebrado e pontudo.

## 4. Color System

**Cores primárias**

| Nome | Hex | Significado |
|---|---|---|
| Carmesim do Manto | #B8323A | Identidade do jogador (Mago de Fogo) |
| Ouro Divino | #D9A441 | Divino, recompensa, santuário desperto, acento de UI |
| Brasa | #FF7A1A (núcleo #FFF4C2) | Magia do jogador, fogueira, calor que protege |
| Verde Vivo | #3B6B35 | Mundo vivo, neutro, a base que descansa o olho |
| Água Serena | #3E8FA8 | Água, calma, mana/energia |
| Violeta Desperto | #8E3FB0 (núcleo #E05ACF) | O que acordou: perigo, inimigos, telegraphs |
| Pedra Antiga | #6E6A78 | Santuário adormecido, ruína, UI base |

**Por que cada cor significa o que significa**
- **Quente = seu e seguro:** o fogo é ao mesmo tempo o poder do jogador e a fogueira de renascer; a ilha recebe o escolhido com calor.
- **Ouro = digno:** é a cor que o santuário ganha ao despertar e a mesma das recompensas. Ganhar ouro = ganhar favor divino.
- **Violeta saturado = perigo:** complemento do verde, salta da floresta; frio como o santuário adormecido, mas corrompido. Escolhido pelo usuário em 2026-10-30 (alternativa ciano descartada por colidir com a água).
- **Regra:** violeta saturado (S > 50%) é exclusivo de perigo. As sombras roxas do hue shift ficam sempre com S < 35% e sem brilho próprio.

**Temperatura por bioma**
- **Praia do naufrágio:** luz quente e clara, sombras azul-ciano; a maior luminosidade do jogo.
- **Floresta da clareira:** luz amarelo-quente manchada, sombras verde-azuladas e roxas suaves; alto contraste nos feixes.
- **Santuário adormecido:** frio, pouca saturação (Pedra Antiga + sombras roxas profundas). Ao despertar, Ouro + Brasa tomam conta.
- **Morte:** dessaturar 40–60%; a fogueira mantém saturação total.

**Paleta de UI (onde diverge do mundo)**
- **Base:** painéis #1A0F14 / Pedra Antiga escura; acentos Ouro Divino; texto creme #FFF4C2.
- **Diferenças:** cores chapadas com no máximo 3 tons, sem hue shift complexo, sem verde de folhagem (a UI não se confunde com o cenário). Violeta só em marcadores de inimigo/perigo.

**Regra de rampa (hue shift)**
- 4–5 tons por rampa. Cada passo para o escuro gira 10–20° para azul/roxo; cada passo para o claro gira para amarelo. Saturação no pico nos tons médios.
- Proibido sombra preta ou cinza puro.
- **Restrição de prompt:** "hue-shifted shading, no black shadows, warm highlights".

**Daltonismo — riscos e cues de reserva**
- **Manto carmesim × grama** (protan/deutan): luminância quase igual (~0,12 vs ~0,13) — risco **crítico**. Reserva: rim light quente na borda superior-esquerda do personagem, contorno escuro, trim dourado bem visível, sombra de contato. Separação mínima de 20% de luminância contra o chão.
- **Fogo laranja × folhagem** (protan/deutan): reserva em luminância (núcleo #FFF4C2 muito claro), glow que ilumina o chão, partículas em movimento.
- **HP carmesim × verde de cura** (protan/deutan): reserva em ícone, posição fixa e padrão; nunca diferenciar só pela cor.
- **Violeta × água azul** (protan/deutan): reserva em forma — telegraph com borda tracejada/angular e pulso; água com ondulação suave.
- **Ouro × Brasa** (protan/deutan, baixa visão): reserva em forma (brilho em estrela/moeda vs chama) e comportamento (recompensa flutua parada, fogo tremula).
- **PvP futuro:** cores de time nunca vermelho/verde; usar azul/laranja + marcador de forma sob os pés.

## 5. Character Design Direction

[To be designed] — the player character's visual archetype, how players tell
enemies, NPCs and allies apart at a glance, expression and pose style, and how
much detail survives at game camera distance (LOD philosophy).

## 6. Environment Design Language

**Arquitetura e cultura**
- **Povo dos santuários:** cultura antiga que servia à força divina. Pedra clara gasta, simetria, arcos, motivo solar concêntrico, incrustações de ouro (apagadas no santuário adormecido, acesas no desperto).
- **O tempo venceu a geometria:** raízes, musgo e terra invadem a pedra. Quanto mais orgânico sobre o geométrico, mais antigo.
- **Restos pela ilha:** degraus semienterrados, pilares tombados, trilhas de lajes como fio guia até os santuários.
- *Lore detalhada do povo = narrativa; aqui só forma.*

**Filosofia de textura**
- Pixel art estilizada, pintada em clusters. Sem PBR, sem fotobash, sem ruído.
- Dithering só em gradientes grandes (feixes de luz, profundidade da água, névoa).
- **Por quê:** a 640×360 cada pixel conta; clusters limpos leem melhor e são verificáveis na arte de IA.

**Árvores**
- **Variedade mínima no MVP:** 3 espécies (copa larga, copa alta e estreita, árvore-ancestral gigante) × 2–3 tamanhos + variantes espelhadas.
- **Copa:** 3 camadas de massa (sombra / média / luz), clusters de realce em cima-esquerda, furos de céu ou luz na borda.
- **Ancoragem no chão:** tronco com 2–4 raízes abrindo na base, tufos de grama sobre as raízes, sombra de contato escura no pé, sombra da copa projetada para baixo-direita.

**Lagos e água**
- **Margem:** faixa de areia/lama molhada de 2–4 px + espuma ou ondulação animada.
- **3 faixas de profundidade:** raso turquesa claro, médio Água Serena (#3E8FA8), fundo azul-roxo de baixa saturação.
- **Reflexos:** árvores e santuários refletidos invertidos, dessaturados e ondulados.
- **Decoração:** brilhos animados de 1–2 px, ninfeias em grupos de 3–5, juncos em touceiras só na margem.

**Fonte**
- Bacia circular concêntrica no estilo dos santuários, motivo solar no centro.
- Água corrente animada, musgo nas juntas da pedra, brilho suave de Água Serena.

**Fogueira (checkpoint)**
- **Composição:** anel de pedras, toras cruzadas, chama em Brasa com núcleo #FFF4C2, faíscas subindo, halo quente iluminando o chão em ~3 tiles.
- **Leitura de "seguro":** em mini-clareira aberta, com toras para sentar e fauna ambiente por perto.
- **Regra de exclusão:** nunca violeta num raio de 6 tiles.
- **Diferença do fogo do jogador:** anel de pedra + loop estável separam a fogueira da magia de combate.

**Praia do naufrágio**
- Casco partido em diagonal, velas rasgadas, cordas, caixotes, tábuas.
- Uma trilha de destroços leva da praia para a floresta — a primeira direção que o jogador recebe, sem texto.
- Areia com faixa molhada e ondas animadas.

**Santuários**
- **Exterior:** tomado pela vegetação. **Interior:** geometria nua e simétrica, um único feixe de luz.
- **Rachaduras com violeta residual:** só onde há perigo real ("violeta = de onde veio a ameaça").

**Narrativa ambiental (sem texto)**
- **Fauna como sinal:** some perto de zonas despertas; volta depois que a ameaça é vencida.
- **Rastros das criaturas:** marcas de garra, árvores quebradas e trilhas pisoteadas apontam a origem dos inimigos.
- **Presença de quem veio antes:** oferendas antigas nos altares, lajes de trilha que reaparecem perto dos santuários.

**Densidade de props por área**
- **Praia:** esparsa (~15% de cobertura), respiro e horizonte aberto; destroços concentram o foco.
- **Floresta:** densa (40–60%), sempre com corredor andável ≥ 2 tiles e camada de primeiro plano nas bordas.
- **Clareira:** média nas bordas, centro livre para combate e fogueira.
- **Margem de lago:** média, densa só nas touceiras de junco; água limpa.
- **Santuário:** exterior médio e tomado de vegetação; interior esparso e simétrico.

**Legibilidade do personagem (risco carmesim × verde, Seção 4)**
- **Contraste do chão:** onde o jogador anda, a textura varia no máximo 2 tons de valor; luminância média-escura para o rim light do manto se destacar.
- **Cores proibidas no chão:** nada vermelho, carmesim ou laranja na camada de chão ou decoração baixa (sem flor vermelha, sem cogumelo vermelho, sem fruta vermelha em arbusto baixo). Flores em branco, amarelo ou azul.
- **Textura vs. ação:** detalhe fino de textura só fora das áreas de combate.

## 7. UI/HUD Visual Direction

[To be designed] — diegetic versus screen-space HUD, typography (personality,
weight, size hierarchy, minimum readable size), iconography style, UI animation
feel, and any art-direction versus readability conflict and how it was decided.

## 8. Asset Standards

*Lado artístico: art-director. Lado técnico: technical-artist (Godot 4.7.2, Forward+, 2D). Itens marcados "pré-4.5" vêm do comportamento de Godot 4.0–4.3 e não foram verificados em 4.7 — `docs/engine-reference/godot/` não cobre batching 2D nem limites de luz 2D.*

> **Personagens — padrão vigente (2026-10-31, decisão do usuário).** Sprites de personagem em **pixel art 48×48 px, 8 direções**, animados por frames, gerados no PixelLab (ou ferramenta equivalente) no nível do Ladino de referência (`assets/art/chars/rogue/`). Direções W/SW/NW podem ser espelhos de E/SE/NE. Pivô nos pés (≈ 24, 46). Spec de produção das 6 classes: `design/assets/specs/class-sprites-pixel-spec.md`. A revisão "2D pintado em HD com rig de peças" do mesmo dia foi **descartada** (ver §1); o protótipo dela está arquivado em `prototypes/hd-rig-showroom/`.

**Regra-mestra de escala**
- **1 pixel de arte = 1 pixel de jogo, em escala inteira.** O mundo roda num SubViewport com `stretch_shrink` inteiro (altura ÷ 360: 720p = 2×, 1080p = 3×, 1440p = 4×) e `snap_2d_transforms_to_pixel=true`. **Revisado em 2026-10-30 a pedido do usuário:** sem letterbox — o SubViewport cresce para preencher a janela, então telas maiores ou mais largas mostram mais mundo. A UI (HUD, menus) é desenhada por cima em resolução nativa, com fonte do sistema, para o texto ficar nítido.
- Proibido escalar sprite por valor não inteiro, girar sprite de pixel art (exceto partículas e VFX) ou usar sub-pixel.

**Formatos e nomenclatura**
- **Masters:** `.aseprite` (ou PSD em camadas). **Exportação:** PNG RGBA 8-bit sRGB; proibido JPG/WebP com perda.
- **Paleta mestra** travada em `.gpl` + `.hex`, versionada.
- **Nomes:** snake_case ASCII puro, sem acento, sem hífen (decisão do usuário, 2026-10-30; segue `naming.files` do `project.yaml`). Padrão `[categoria]_[nome]_[variante].png`; categorias `char`, `enemy`, `env`, `prop`, `tile`, `vfx`, `ui`, `icon`, `spr`. Ex.: `env_tree_oak.png`, `spr_mage_fire_sheet.png`, `tile_shore_water.png`.
- Shaders: `canvas_env_*`, `canvas_fx_*`, `canvas_post_*`.

**Importação (todo PNG de pixel art)**
- Filtro Nearest herdado do projeto (`default_texture_filter=0`), sem override por nó; mipmaps off; compressão Lossless; `Detect 3D` off; `Fix Alpha Border` pode ficar on.
- **Alpha binário** (0 ou 255) em personagens, tiles, árvores e props. Alpha suave só em VFX e glow.

**Tamanhos**
- **Tile:** 32×32. **Personagem:** célula 64×64, figura ~44 px, cabeça 12–14 px. **Chefe:** 128×128.
- **Props:** pequeno 32×32, médio 64×64, grande 96×128.
- **Árvores:** comum até 144×192; árvore-ancestral até 176×224 (decisão do usuário, 2026-10-30 — teto técnico aceito pelo technical-artist; o art-director havia proposto 128×192).
- **Ícones:** 16×16 e 24×24. **UI:** 9-slice com bordas de 1–2 px.

**Pipeline de arte gerada por IA**
1. Gerar a 4–8× do tamanho final.
2. Reduzir com nearest-neighbor ao tamanho exato.
3. Travar na paleta mestra (quantizar).
4. Limpeza manual: pixels órfãos, contorno colorido só na silhueta externa, luz de cima-esquerda, hue shift nas rampas.
5. Alpha binário (exceto VFX/glow).
6. Aprovação: teste de silhueta, teste P&B, teste contra o chão do bioma.
- Guardar prompt + seed num `.txt` ao lado do master.

**Orçamento de frames (8–12 fps)**
- **Jogador:** idle 4 · andar 6 por direção (4 direções; esquerda = espelho da direita) · conjurar/ataque 6–8 · dano 2–3 · morte 6.
- **Inimigo comum:** idle 4 · mover 4–6 · ataque 5–6 · dano 2 · morte 5. **Chefe:** 8–12 por ação.
- **Ambiente:** fauna 4–6 · folhagem 4 · água em tile 4–8 · fogueira 6–8 · fonte 6 · VFX 6–10.

**Tiles e terrenos (TileMapLayer)**
- **Camadas:** chão, decalques de chão, água, objetos (y-sort pela base).
- **Transições:** grama↔terra, grama↔areia, areia↔água, grama↔água.
- **Modos de terreno:** margens de água em *Match Corners and Sides* (47 tiles); grama/terra em *Match Corners* (16 tiles).
- 3–4 variantes do tile de preenchimento com sorteio por peso; água em tiles animados; tiles de falésia/desnível para profundidade.
- O chão atual em PNG único (1600×1200, ~7,3 MiB) é substituído por TileMapLayer.

**Iluminação — modelo híbrido** (decisão do usuário, 2026-10-30)
- Halo pintado no sprite como base, para garantir paleta e hue shift.
- PointLight2D suave só em fontes-chave: cajado, magia, fogueira, santuário. Vagalumes sem sombra e com raio pequeno; sombra 2D só no cajado.
- Glow (WorldEnvironment) restrito a VFX e fontes HDR; nunca em cenário comum.
- *Conflito registrado:* o art-director temia que luz dinâmica lavasse a paleta (preferia só luz pintada); o technical-artist aceitava luz dinâmica com limite. Escolha: híbrido.

**Orçamentos técnicos** (adotados como regra pelo usuário, 2026-10-30; o projeto define 60 fps / 16,6 ms / < 500 draw calls)
- **Atlas:** ≤ 1024×1024 por bioma (tileset); teto absoluto de 2048×2048 por textura; árvores e props da mesma camada de y-sort no mesmo atlas de ambiente.
- **Luzes:** ≤ 16 PointLight2D visíveis na tela.
- **Partículas:** ≤ 64 por emissor de ambiente, ≤ 400 na tela; textura ≤ 16×16 num atlas de FX; emissores fora da tela com `emitting=false`.
- **Materiais e batching:** um ShaderMaterial por variante, nunca por instância — material não compartilhado quebra o batch (pré-4.5). Variação por instância via `modulate` ou hash da posição no mundo dentro do shader.
- **Memória (RGBA8 = 4 B/px):** sheet 384×576 ≈ 0,84 MiB; árvore 176×224 ≈ 154 KiB; atlas 1024² = 4 MiB, 2048² = 16 MiB; buffer HDR 2D 640×360 ≈ 1,8 MiB. Teto de memória do projeto: não configurado.
- NOT SOURCEABLE: suporte a `instance uniform` em shaders `canvas_item` no 4.7; limite de luzes por item no 4.7.

**Conflitos esperados com arte de IA (checar em todo lote)**
- Saída em 1024 px+ reduzida gera pixels de tamanhos misturados → redesenhar/quantizar na grade nativa.
- Bordas de alpha suave/antialias viram franja com Nearest → limpar para alpha binário.
- Paleta de IA com milhares de cores → quantizar na paleta mestra.
- Arte de chão pintada como imagem única → conflita com TileMapLayer.

## 9. Reference Direction

[To be designed] — 3–5 references (games, films, art styles or artists). For
each: the specific element to take from it, and what to avoid so the result
does not read as a copy.
