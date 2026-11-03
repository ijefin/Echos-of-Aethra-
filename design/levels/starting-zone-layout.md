# Zona Inicial: Praia do Naufrágio e Vale de Brisaclara

**Status:** rascunho aprovado (2026-11-03) · **Autor:** level-designer
**Tempo estimado:** 30–45 min (caminho crítico ~30 min, com opcionais ~45)
**Escala:** 1 u ≈ 1 m. Tela ≈ 22×12 u. Andar 4,2 u/s; esquiva cobre ~2,6 u; blink alcança 7 u.

## 1. Tamanho e regiões

Mapa de **160×160 u**, com x e z de -80 a +80, origem no centro e -z = norte. Os limites são naturais: mar ao sul (z > +72), escarpa de 4 u ao norte e ao leste (z < -76, x > +76) e floresta fechada com pedras ao oeste (x < -76).

| Região | Retângulo aprox. (x; z) | Bioma |
|---|---|---|
| R1 Praia do Naufrágio | -40..+40; +62..+76 | areia, destroços, palmeiras, porto militar |
| R2 Vila Brisaclara | -10..+30; +14..+50 | praça de pedra, casas |
| R3 Campos e Fazendas | -60..-12; +24..+62 | roças, cercas, pomar |
| R4 Floresta da Clareira | -80..-20; -26..+24 | verde e floração, lago |
| R5 Bosque Outonal | +30..+80; -24..+40 | laranja/vermelho |
| R6 Planalto do Eco | -40..+40; -76..-28 | bosque violeta, fadas, santuário |
| R7 Colinas Rochosas | +40..+80; -76..-24 | pinheiros, mina, penhascos |

**Rio Murmúrio** (largura 3,6 u): (-52,-80) → (-48,-50) → (-42,-18) → Lago Espelho → sai em (-29,-2) → (-10,6) → (6,8) → (24,6) → (50,6) → (80,2).

**Fenda do Eco**: abismo de (-30,-25) a (+78,-29), com largura de 4 a 6 u e um riacho no fundo, 3 u abaixo do chão. No oeste ela termina no rio e na escarpa. O planalto norte fica 1,5 u acima do resto do mapa.

## 2. Pontos de interesse

| ID | Ponto | Centro (x,z) | Raio | Notas |
|---|---|---|---|---|
| P1 | Destroços do navio | (-6,70) | 6 | spawn do jogador em (0,68) |
| P2 | Praça da vila + fonte | (10,30) | 6 | 4 lampiões nos cantos (±4,±4) |
| P3 | Poço | (-2,36) | 1,2 | NPC lavadeira |
| P4 | Casas (8) | (2,22) (18,22) (22,32) (20,40) (4,42) (-6,28) (-8,40) (12,46) | 3,5 cada | 2 com luz na janela |
| P5 | Moinho (marco, 9 u de altura) | (-18,30) | 3 | pás girando |
| P6 | Estábulo + cercado | estábulo (24,46), cercado (30,44) 10×7 | — | 3 cavalos, 1 NPC cavalariço |
| P7 | Roças (4 lotes 10×8) | (-28,44) (-40,44) (-28,54) (-40,54) | — | trigo, abóbora, repolho, girassol; 3 NPCs fazendeiros |
| P8 | Casa da fazenda + celeiro | (-48,36) / (-56,42) | 4 / 5 | quem dá a missão da gruta |
| P9 | Lagoa da fazenda | (-50,52) | 4 | patos |
| P10 | Campo de treino | (40,30) | 8 | 6 bonecos em (36..44, 26), alvo de blink |
| P11 | Valas de treino | (38,36) (42,36) (46,36) | — | larguras 2 / 3,5 / 5 u, comprimento 6 u |
| P12 | Lago Espelho | (-40,-6) | 11 | ilhota com baú em (-40,-6), r 2, alcançada por blink a partir de um píer (6 u) |
| P13 | Ponte de pedra principal | (6,8) | 6 de comprimento | |
| P14 | Ponte de madeira leste | (50,6) | 5 de comprimento | |
| P15 | Ponte quebrada da Fenda | (2,-27) | vão de 4 u | primeiro blink obrigatório |
| P16 | Entrada da Gruta do Musgo | (-62,-14) | 3 | boca na rocha, cogumelos brilhantes |
| P17 | Saída da gruta (planalto) | (-48,-36) | 2 | atalho de mão única |
| P18 | Entrada da Mina Abandonada | (60,-48) | 3 | trilhos e carrinho; opcional |
| P19 | Santuário O Chamado | (5,-62) | 9 | círculo de 6 pilares, coluna de luz de 30 u |
| P20 | Pilares do Santuário | (24,-60) → (30,-60) → (36,-58) | 1,5 cada | vãos de 5 / 6 / 6,5 u; baú no último |
| P21 | Mirante do Vale | (22,-32) | 3 | borda da fenda, vista da vila; banco |
| P22 | Mirante da Escarpa | (70,-66) | 3 | fim dos degraus de pedra (vãos de 5 e 6 u) |
| P23 | Árvore-Mãe violeta (marco) | (-22,-56) | 5 | árvore de 12 u, coração do Bosque das Fadas |
| P24 | Porto de Vigia (militar) | (30,70) | 8 | píer de 12 u mar adentro até (30,82); barco de patrulha; NPC soldado; 2 tendas, mastro com bandeira; porta para o Ato 2 |
| P25 | Cova das Raízes (caverna fácil) | (-28,14) | 2,5 | entrada sob as raízes de uma árvore G |
| P26 | Gruta da Maré (caverna fácil) | (-36,66) | 2,5 | fenda na rocha da praia, alaga com a maré (visual) |
| P27 | Bosque das Fadas | (-22,-56) | 16 | árvores mágicas, fadas, campânulas (ver §4.1) |

**Fogueiras (checkpoints):**
- F1 (4,62) praia
- F2 (-4,18) saída norte da vila
- F3 (-56,-10) frente à gruta
- F4 (8,-38) planalto, logo após a fenda
- F5 (52,-34) frente à mina (opcional)

**Interiores das cavernas** (cenas separadas ou montadas em y = -30):
- **Gruta do Musgo** (40×28 u, obrigatória): Entrada 8×8 → corredor de 3 u → Salão dos Cogumelos 14×12 (4 brotos nv 2, luz roxa por emissão) → Abismo com vão de 5 u (blink) → Câmara do Sino 8×8, com o item **Sino de Bronze** sobre um altar em (+16,-8) local → rampa até a saída P17 no planalto.
- **Mina Abandonada** (36×24 u, opcional): 3 salas em L (8×8, 12×10, 10×10). Na última fica o elite e um baú de armadura (conjunto 1).
- **Cova das Raízes** (16×12 u, novato): 1 sala com raízes no teto, 3 brotos nv 1 e um baú de poções no fundo. Sem vão nem armadilha. Saída = entrada.
- **Gruta da Maré** (14×10 u, novato): 2 salas pequenas (6×6 e 8×6), 4 caranguejos nv 1 e uma **Concha Cantante** (item para a NPC lavadeira, missão curta). Um vão de 2 u opcional leva a um nicho com moedas.

**Acampamentos de monstros:**

| ID | Local (x,z) | r | Composição | Nível |
|---|---|---|---|---|
| C1 Ninho de Brotos | (-56,26) | 6 | 4 corpo a corpo fracos | 1 |
| C2 Toca Outonal | (60,20) | 7 | 3 corpo a corpo + 2 à distância | 2 |
| C3 Patrulha da Fenda | (-14,-42) | 7 | 3 corpo a corpo + 2 à distância, patrulha em círculo de r 7 | 3 |
| C4 Acampamento da Mina | (62,-40) | 8 | 5 mistos + 1 elite | 4–5 (opcional) |

Nenhum acampamento fica a menos de 15 u de uma fogueira, e nenhum fica no caminho crítico antes de F2.

**Spots de XP livre (grind)**: áreas com respawn contínuo, sem missão. São sinalizados por um **totem de pedra com chama azul** (emissão, sem luz omni) e uma bandeirola azul visível a 1 tela. Ficam fora das estradas, a 12 u ou mais de uma fogueira.

| ID | Local (x,z) | r | Inimigos vivos | Respawn | Nível |
|---|---|---|---|---|---|
| G1 Prado dos Brotos | (-20,2) | 8 | 6 corpo a corpo fracos | 1 a cada 10 s, até 6 | 1–2 |
| G2 Clareira Rubra | (44,-10) | 8 | 4 corpo a corpo + 2 à distância | 1 a cada 12 s | 2–3 |
| G3 Ruínas do Planalto | (-34,-64) | 9 | 6 mistos | 1 a cada 12 s | 3–4 |

O spot só faz respawn se o jogador estiver a menos de 25 u, e para de vez se ele ficar mais de 60 s longe.

## 3. Rede de estradas

**Via de Pedra (largura 3 u, meio-fio, centro gasto, poças):**
(0,66) → (2,56) → (6,44) → (10,36) → praça (10,30) → (8,20) → (6,12) → ponte (6,8) → (5,0) → (2,-12) → (2,-24) → [ponte quebrada] → (4,-32) → (8,-40) → (6,-52) → santuário (5,-58).

**Ramal do Porto (pedra, largura 2,4 u):** (2,56) → (14,60) → (24,66) → píer (30,70).

**Trilhas de terra (largura 1,6 u, sulcos de carroça e faixa de grama no meio):**
- T1 Vila→Fazendas: (4,30) → (-12,32) → (-24,38) → (-34,40) → (-46,38)
- T2 Fazendas→Gruta: (-46,38) → (-54,30) → (-56,14) → (-60,0) → (-62,-12)
- T3 Vila→Treino: (16,30) → (32,30)
- T4 Treino→Mina: (46,28) → (50,14) → ponte (50,6) → (54,-8) → (56,-22) (beira da fenda: vão de 4,5 u) → (54,-30) → (60,-46)
- T5 Lago: (4,-2) → (-14,-6) → (-26,-12) → píer (-30,-8)
- T6 Planalto: (-48,-36) → (-34,-44) → (-14,-46) → (6,-50)
- T7 Praia: (-34,68) → (34,68)
- T8 Cova das Raízes: (-12,32) → (-20,22) → (-28,16)

## 4. Regras de espalhamento

Densidade em árvores por 100 m². Tamanhos: P = 2,5–3,5 u, M = 4–6 u, G = 7–10 u (máx. 5%).

| Região | Árvores | Cores de copa (hex) | Flores no chão | Pedras/cercas | Animais |
|---|---|---|---|---|---|
| Praia | 0,2 (palmeiras) | #5e9e4a | — | destroços, conchas | 6 caranguejos, gaivotas |
| Vila | 0,3 | ipê-amarelo #f2c53d, ipê-rosa #e07ab0 | canteiros em frente às casas | cercas baixas | 4 galinhas, 2 gatos, pardais |
| Fazendas | 0,4 (pomar em fileiras) | #78b04a com frutos #d94a3a | girassol, papoula | cercas em todo o perímetro das roças | 3 vacas, 6 coelhos, 2 bandos de pássaros |
| Clareira | 3,0 (5,0 nas bordas) | #4f8a3c #6aa84f #3c6e47 + cerejeira #e8a0c0 (10%) | 8/100 m², branco e amarelo | 1,5 | 6 cervos, 10 coelhos, pássaros, borboletas |
| Outonal | 2,5 | #d9782d #c94f2a #e8b33a #8a3b2a + 15% verde | folhas caídas laranja | 1,0 | 4 cervos, 2 raposas, 4 coelhos |
| Violeta | 2,0 | #7b4fa8 #a070d0 #4d3a7a, folhas acesas #6fd0e0 | campânulas azuis emissivas | ruínas | fadas (ver §4.1), borboletas de luz |
| Colinas | 0,8 | pinheiro #2f5a46 #3f6d5a, árvores secas | quase nenhuma | 4,0 | aves de rapina |

### 4.1 Elementos novos

- **Arbustos**: 2 tipos (folhagem #4a7a3a e #6b8f3a), 0,6–1,4 u.
  - Densidade: 4/100 m² na Clareira, 3 no Outonal, 1 nas Fazendas e 0,5 na Vila (só junto a cercas).
  - **Com frutinhas** (frutos vermelhos #c8344a ou azuis #4a5ad0): 20% dos arbustos.
  - Brilham de leve quando o jogador está a 2 u ou menos. Interação opcional: frutinha = cura pequena, renasce em 120 s.
  - Os arbustos não bloqueiam o blink (são decoração baixa).
- **Animais (total 60 na zona, ainda até 12 animados por tela)**:
  - Coelhos em grupos de 2–3, perto de arbustos.
  - Cervos em grupos de 2–4, nas bordas de clareira.
  - Pássaros: bandos de 5–8 que pousam no chão e levantam voo quando o jogador chega a 4 u.
  - Borboletas: partícula local, 6 por canteiro de flores, nas regiões Vila, Fazendas e Clareira.
- **Bosque das Fadas (P27, r 16 em volta da Árvore-Mãe)**:
  - Árvores mágicas: tronco claro #d8d0e8, copa #a070d0 com pontos emissivos #6fd0e0 e #f0a0e0. Densidade de 2,5, metade delas G.
  - Fadas: 12 no total. Pontos de luz de 0,3 u com rastro, voando em órbita lenta (r 2–4 u) em volta das árvores G. Ao se aproximar, elas sobem e circulam o jogador por 3 s.
  - Só emissão, **sem luz omni**. A única omni do bosque é a da Árvore-Mãe.
  - O chão tem musgo azul e cogumelos acesos.
- **Colmeias**: 1 a cada ~400 m² nas regiões Clareira e Outonal, sempre em árvore M ou G, presas a 2–3 u de altura no tronco.
  - Cada colmeia tem uma partícula de 8 abelhas (r 1,5 u) e um zumbido espacial (alcance de 6 u).
  - Atacar a colmeia solta 1 enxame fraco (nv 1) e dropa **mel** (cura média).
  - Teto de 10 colmeias na zona. Fixas, para o mapa ser previsível: (-34,10), (-48,-2), (-66,6), (-30,-16), (-58,18), (40,-14), (52,30), (66,10), (70,-4), (36,4).
- **Exclusões**:
  - Estradas: margem de 1,5 u.
  - Pontos de interesse: o raio do ponto + 1 u.
  - Água: 2 u.
  - Spots de grind: miolo de r 5 sem árvores.
  - **Pistas de blink:** corredor livre de 1,2 u de largura sobre cada vão e 3 u antes e depois dele.

Animais fogem quando o jogador chega a 5 u e voltam a se espalhar a 20 u.

## 5. Fluxo dos primeiros 30–45 min

| Min | Onde | O que acontece | Intensidade |
|---|---|---|---|
| 0–3 | Praia (P1→F1) | acorda e acende a fogueira; vê o Porto de Vigia ao leste (fechado: "o barco só sai com ordens") | 1 |
| 3–10 | Vila | NPCs; o fazendeiro (P8) pede o Sino; a lavadeira pede a Concha; o cavalariço manda ao treino | 1 |
| 10–15 | Treino P10/P11 | bonecos (ataque, esquiva); as valas de 2, 3,5 e 5 u **ensinam o blink** | 2 |
| 15–19 | T1→C1 ou T8→Cova das Raízes | primeira luta (nv 1); a caverna fácil apresenta o formato das cavernas | 3–4 |
| 19–29 | T2→F3→Gruta do Musgo | lago visto pelo caminho; dentro: salão (nv 2), abismo de 5 u, Sino | 6 |
| 29–31 | P17→T6 | sai **no planalto**: atalho que já mostra o bosque violeta e as fadas | 3 |
| 31–34 | volta pela fenda (blink a partir de (2,-24)) ou continua | entrega o Sino na vila → recompensa | 2 |
| 34–40 | ponte quebrada P15 → F4 → C3 | blink obrigatório; luta nv 3 | 7 |
| 40–45 | Santuário P19 | O Chamado: ganha a classe; o soldado do porto passa a liberar o barco (Ato 2) | 5 → pico narrativo |

**Opcionais:** Gruta da Maré, spots G1–G3, colmeias, C2 (nv 2), ilhota do lago, Pilares P20 (blink de 6,5 u, o limite do alcance), Mina com C4 (nv 4–5) e degraus até P22.

**Regras de blink para os vãos:**
- Obrigatórios: no máximo 5 u.
- Opcionais: até 6,5 u.
- Cair num vão: volta à borda e perde 10% do HP.

**Blink e água: A CONFIRMAR (decisão pendente do usuário/game-designer).**
Proposta: a água no nível do chão (lago, rio, lagoa) bloqueia o blink, como no protótipo. O riacho no fundo de uma fenda (3 u ou mais abaixo do chão) não bloqueia, porque o teste de colisão usa só a camada `blink_blocker` e exige chão no ponto de chegada.
Se a decisão for outra, os vãos P11, P15, P20, o da T4 e os das cavernas continuam valendo (são abismos). Só o píer da ilhota (P12) precisaria virar pedras de apoio.

## 6. Linhas de visão e marcos

A câmera é ortográfica e não mostra horizonte. Por isso os marcos precisam ser **altos**, para entrar pelo topo da tela antes de o jogador chegar até eles.
- **Coluna de luz do santuário:** 30 u de partículas verticais. Aparece no topo da tela a partir de z ≈ -20.
- **Moinho** (9 u, pás girando): marca a vila e o caminho para as fazendas.
- **Árvore-Mãe** (12 u, violeta, com fadas em volta): marca o planalto oeste.
- **Mastro do Porto** (10 u, bandeira vermelha): marca o porto.
- **Fumaça das fogueiras:** fita de 6 u, visível uma tela antes.
- **Totens azuis:** marcam os spots de grind.

Guias de chão:
- A Via de Pedra é o caminho crítico. As trilhas de terra são opcionais.
- Lampiões a cada 10 u na via, só dentro da vila, na ponte e no ramal do porto.
- Vagalumes levam da F3 até a boca da gruta.
- A correnteza do rio aponta para o leste, rumo ao treino.
- O vento leva pétalas para o norte, em direção à fenda.
- Os bonecos de treino ficam virados para as valas.
- O baú da ilhota fica à vista da trilha T5, para provocar o jogador.

## 7. Orçamento de performance (render de ~430×240)

**Luzes:**
- Sol direcional: o único com sombra.
- Omni por tela: no máximo 8, todas sem sombra (lampiões, fogueiras, janelas, Árvore-Mãe).
- Fadas, totens, frutinhas e cogumelos: só emissão.
- Cavernas: no máximo 3 omni; o resto vem de emissão.

**Instâncias** (o mapa é dividido em blocos de 16×16 u, 100 no total, e cada bloco é desenhado só quando está perto da tela):
- Grama: ~600 tufos por bloco (MultiMesh); ~3.000 visíveis, 60k no total.
- Árvores: ~1.400 no total (um MultiMesh por espécie e por bloco); até 60 na tela.
- Arbustos: ~2.500 no total; até 80 na tela.
- Flores: ~20k no total; ~1.200 visíveis.

**Atores e partículas:**
- Animais/NPCs: 60 no total, até 12 animados na tela. A lógica pausa quando estão a mais de 30 u do jogador.
- Monstros: só são criados quando o jogador chega a 25 u do acampamento ou do spot.
- Emissores ativos ao mesmo tempo: no máximo 6 (vagalumes, folhas, borboletas, fadas, abelhas), cada um local à sua região ou colmeia.
- Meta: menos de 300 chamadas de desenho e 16 ms por quadro no GPU médio.

## 8. Ato 2 – Ilha Espectral (macro)

**Como se chega:** depois de O Chamado, o **soldado do Porto de Vigia (P24)** leva o jogador no barco de patrulha (corte curto de viagem). O desembarque é no Cais Partido, na ponta sul da ilha. O barco fica lá como viagem rápida de volta à zona inicial.

**Tamanho:** 128×128 u (x e z de -64 a +64). É menor e mais vertical que a zona inicial: plataformas, pontes que somem e abismos de névoa, para usar o blink a fundo. É sempre noite.

| Região | Área aprox. (x; z) | Conteúdo |
|---|---|---|
| E1 Cais Partido | -20..+20; +48..+64 | desembarque, fogueira espectral, soldados feridos |
| E2 Vila Afogada | -60..-10; +10..+48 | casas meio submersas, aldeões-fantasma (NPCs), névoa baixa |
| E3 Pântano de Lumes | +10..+60; +10..+48 | lumes errantes que atraem para armadilhas, ilhotas ligadas por blink |
| E4 Bosque Ossário | -60..0; -30..+10 | árvores brancas mortas, acampamentos espectrais |
| E5 Escadaria das Névoas | 0..+60; -40..+10 | plataformas suspensas e pontes que aparecem e somem |
| E6 Farol Morto + Santuário 2 | -20..+20; -64..-40 | santuário do guardião (chefe); o farol é o marco de 25 u visível de toda a ilha |

**Pontos de interesse principais:**
- 3 fogueiras espectrais (chama azul).
- 1 caverna: Catacumba sob o Bosque Ossário.
- 2 acampamentos, nível 5–7.
- 1 spot de grind sinalizado.
- O farol, como marco único.
- Santuário 2, com o guardião do brief.

**Paleta noturna/espectral:**
- Céu e ambiente: #1a1f3a e #2a2850.
- Névoa: #6a7fb0 com 40% de opacidade.
- Água: #1e3a4a com espuma #8fd0d0.
- Árvores: tronco #d8d8d0, copa nenhuma ou #3a4a5a.
- Emissivos: ciano espectral #7ff0e0 e verde-fantasma #a0f0a0.
- Fogueiras e farol: azul #6fa0ff. Só o fogo do jogador é quente, como contraste proposital.
- Lua direcional fria (#9fb0e0) como única luz com sombra.
