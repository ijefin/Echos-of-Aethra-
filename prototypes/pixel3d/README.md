# Protótipo: mundo 3D com visual de pixel art

**Status:** em andamento (atualizado 2026-11-04)

## Estado atual (resumo)
- **Vocações:** Mago, Guerreiro, Arqueiro (`data/classes.json`, `vocations.gd`). Escolha na primeira vez ou com **F2**.
- **Combate:** clique = ataque básico da vocação · **Q** / botão direito e **R** = habilidades (desbloqueiam nos níveis 2 e 3) · **Espaço** esquiva · **1/2** poções · **3** = core skill Luz (utevo vis lux).
- **Mundo:** 200×200 m, 5 regiões, caçadas por nível, 4 segredos, ciclo de 27 min (20 dia + 7 noite).
- **Conteúdo:** missão da Nessa + cadeia Sálvia → Rook → Bran (`data/quests.json`, `quests.gd`). **J** diário · **I** bolsa (grade estilo Tibia: arrastar ao slot ou duplo clique veste; arrastar do slot até a grade ou duplo clique no slot desequipa, bolsa cheia recusa com o slot tremendo; arma vestida tinge o modelo; online o servidor decide) · **C** personagem · **H** atalhos · **E** interagir.
- **Ouro e troca com a Nessa:** moedas caem dos monstros (mais nas caçadas de nível alto) e vêm das missões; ficam na 1ª célula da bolsa. Falar com a Nessa fora do aceite/entrega da missão abre a troca (poções à venda; ela compra o que não está vestido, preço pela raridade); duplo clique compra/vende, afastar fecha. Preços e moedas em `data/shop.json`, regras em `economy.gd`.
- **Online (entre jogadores):** arrastar um item da bolsa para o chão larga (todos veem o saquinho com o nome por 60 s; **E** pega); arrastar até outro jogador perto abre a troca para os dois (duplo clique põe/tira da oferta, ✓ confirma, ✕ cancela; mudar a oferta desfaz as confirmações; afastar cancela).
- **Monstros:** IA com estados, A*, aggro com linha de visão (`ai/`, parâmetros em `data/first_adventure.json` → `enemy`).
- **Rede:** servidor autoritativo em `net/` (ver `server/README.md`); ligação do cliente em andamento.

### Flags úteis
`--class=mage|warrior|archer` · `--hour=H` · `--at=x,z` · `--zoom=N` · `--light` · `--panel=vocation` · `--quest=id:passo` · `--level=N` · `--talk=npc` · `--secret=id` · `--give=id,id` · `--equip=id,id` · `--gold=N` · `--panel=bag|shop` · `--no_save` · `--mute` · `--shot=res://... --shot_delay=S`

### Testes (headless)
`godot --headless --path . -s res://prototypes/pixel3d/tools/<teste>.gd -- --no_save --mute`, com `<teste>` = `test_mage_combat`, `test_enemy_ai`, `test_world_reach`, `test_day_night`, `test_core_light`, `test_vocations`, `test_quests`, `test_floors`, `test_equip`, `test_shop`. Rede: `tests/unit/net/*.gd`, `bash tools/net_session_test.sh` e só a economia online `bash tools/net_trade_test.sh` (~1 min). Print da investida deslizando com 2 clientes: `bash tools/net_dash_shot.sh`; item largado visto pelo outro cliente: `bash tools/net_drop_shot.sh`.

## Hipótese
Um mundo 3D renderizado em baixa resolução (~430×240, escala inteira), com luz em
degraus, contorno por profundidade/normal e câmera presa à grade de pixels, fica bonito
como pixel art, deixa o personagem andar e atacar em **qualquer direção** sem sprites por
direção, e aguenta efeitos de fogo fortes (labaredas na silhueta + chamas de partícula)
para o conjunto do Piromante.

## Como rodar
```
godot --path . res://prototypes/pixel3d/pixel3d_demo.tscn
godot --path . res://prototypes/pixel3d/pixel3d_demo.tscn -- --auto --shot=res://production/qa/evidence/pixel3d-01.png --shot_delay=5
```
WASD anda · clique ataca na direção do mouse · Q ou botão direito teleporta · Espaço esquiva · roda do mouse zoom · F liga/desliga o Piromante · F10 sai.
`--pyro` começa com o Piromante; `--auto` anda em círculo e ataca sozinho.

### Iluminação revisada (2026-11-03)
- Luz local conserva o relevo toon, com atenuação contínua para eliminar discos duros.
- Lanternas com armação, núcleo emissivo quente, alcance 5,8 u e oscilação discreta.
  Só as duas mais próximas, a menos de 15 u, projetam sombras à noite.
- Cajado acompanha o encaixe animado da mão; alcance maior mantém iluminação
  do chão quando a corrida levanta a ponta. Brilho e iluminação usam o mesmo perfil.
- **L** alterna sem luz / sutil / acesa / intensa (perfis de demonstração; ainda
  não ligados ao inventário). **N** avança 3 horas. O HUD informa ambos.
- Realce frio sutil nos materiais do personagem à noite, sem luz extra no chão.
- Sombra de contato curta projetada sob os pés, complementando as sombras
  direcionais. Medição gráfica em `tools/inspect_grounding.gd`: pés no repouso
  em y≈0; corrida varia aproximadamente de -0,013 a 0,085 u (fase aérea natural).
  Evidências: `pixel3d-grounding-idle.png` e `pixel3d-grounding-running.png`.
- QA: `--hour=21 --weapon_glow=2 --shot=res://production/qa/evidence/X.png`;
  acrescentar `--walk --shot_delay=1.2` para captura determinística andando.
- Evidências: `pixel3d-lighting-night-v2.png`, `pixel3d-lighting-moving.png`,
  `pixel3d-lighting-day.png`. Execuções gráficas sem erros de script/shader.
- Direção para PvP: brilho sustentado contido, flashes curtos para ataques e
  silhueta legível. Ainda falta validar cenas com muitos jogadores/efeitos.

### Raios entre as copas (revisão)
- Substituídas as 70 faixas aleatórias por aberturas vinculadas às árvores.
  Fonte abaixo da folhagem, direção do sol e destino calculado no chão.
- Cada feixe ativo tem um SpotLight3D no mesmo eixo: ilumina chão, vegetação
  e objetos. Até três pares próximos, sem sombras locais adicionais.
- Bordas e interseções suaves por profundidade; feixe abre na descida.
  Some à noite e com sol muito baixo, evitando barras horizontais.
- Seleção favorece trilhas/bordas da floresta e evita água. Trajetória solar
  ajustada para uma diagonal mais legível na câmera ortográfica.
- QA gráfico sem erros, capturas `pixel3d-canopy-rays-final.png` e
  `pixel3d-canopy-rays-night.png`. Ponto de observação: `--at=2,-28 --hour=9`.

### Bosques e vida ambiente (2026-11-03)
- `pixel3d_forest.gd`: copas deformadas reutilizadas em cache, carvalhos largos,
  bétulas claras e pinheiros altos; galhos, raízes, madeira caída e cogumelos.
- Plantio por manchas de densidade, espaçamento variável entre troncos,
  clareiras e recuo de trilhas/água. Menos árvores coloridas isoladas ao acaso.
  Arbustos também seguem manchas em vez de espalhamento uniforme.
- `pixel3d_wildlife.gd`: famílias de raposas com filhotes, patos no lago e
  passarinhos com asas animadas. Passeiam, pausam e reagem à proximidade;
  atualização limitada a 32 u. Movimento verifica habitat e troncos próximos.
- Nuvens: deslocamento UV de (0.012, 0.007) para (0.0014, 0.0008) por segundo;
  escurecimento máximo de 50% para 7%, transição mais larga, aplicado depois
  da quantização toon para evitar grandes saltos na luminosidade.
- QA: execuções gráficas de dia/noite, até 12 s de movimentação ambiente,
  sem erros de script/shader. Capturas `pixel3d-forest-life-final.png`,
  `pixel3d-forest-pond-v2.png`, `pixel3d-forest-life-night.png`.
- Passeio: `--hour=10 --at=-12,8` (lago) e `--at=2,-25` (bosque).

### Sombras solares e lunares
- Sol e lua usam o mesmo arco de órbita, com a lua deslocada em 12 h e azimute
  oposto. Corrigida a lua presa à rotação (-58,150,0).
- Direção e comprimento das sombras são gerados pelas próprias luzes
  direcionais em movimento; lua nasce às 18 h e se põe às 6 h, com transição
  de intensidade perto do horizonte. Opacidade solar 0,82 e lunar 0,62.
- Tecla N atualiza também a posição dos feixes no próximo frame.
- QA: mesmo enquadramento `--at=2,-25` às 9, 15, 21 e 3 h; capturas
  `pixel3d-orbit-shadow-{09,15,21,03}.png`, observadas, sem erros do Godot.

### Mata fechada e acampamentos
- `pixel3d_camps.gd` concentra os três acampamentos e suas trilhas. As mesmas
  coordenadas são enviadas aos shaders do terreno/grama e usadas para reservar
  espaço no plantio; trilhas conectam às estradas sem cruzar água.
- Densidade por setores: mata fechada no noroeste, oeste e sudeste; bosques
  mais abertos ao redor das clareiras. Espaçamento de 2,35–4 u, mínimo 3,5 u
  perto dos acampamentos. Geração atual: 440 árvores, 3 acampamentos, 6 barracas.
- Cada acampamento tem fogueira animada com luz quente, pedras, panela/tripé,
  bancos de tronco, barracas com estacas/cordas, mesa, caixas, mochila,
  manta enrolada, pilha de lenha, placa e bandeirolas com vento.
- Barracas, bancos, caixas, mesas e fogueiras têm colisão. São elementos de
  ambiente; ainda não há ações de sentar, dormir ou cozinhar.
- `tools/inspect_woodlands.gd`: 104 amostras de colisão nos acessos externos
  às clareiras, nenhuma bloqueada. Execuções gráficas dia/noite sem erros.
- Capturas: `pixel3d-woodland-camp-day.png`, `pixel3d-woodland-camp-night.png`,
  `pixel3d-woodland-camp-02.png`, `pixel3d-woodland-camp-03.png`,
  `pixel3d-dense-woodland.png`.
- Passeio: `--at=-14,-27 --zoom=20 --hour=10` (acampamento noroeste),
  `--at=-29,-39` (mata fechada), `--at=18,19` e `--at=-32,33` (demais campos).

### Gruta natural + som ambiente (Claude, 2026-11-03)
- Luz das copas removida (`SHAFTS := 0` em `pixel3d_sky.gd`) a pedido do usuário.
- `adventure_cave.gd`: gruta irregular por campo de distância (5 salões + túneis com ruído),
  paredes de rocha (altas no fundo, baixas no sul), musgo, raízes, cogumelos, cristais,
  ruínas antigas (colunas partidas, coluna caída, lajotas quebradas em `cave_floor.gdshader`),
  braseiros sempre acesos, 3 cachoeirinhas (`waterfall.gdshader`) e piscina. 8 guardiões em
  2 bandos (`cave_guardians` 8). Rótulos da saída só no andar certo.
- Som: `tools/gen_ambience.py` gera 48 WAVs por síntese em `audio/`; `pixel3d_ambience_audio.gd`
  sorteia pássaros (dia), grilos que trocam de lugar + corujas + sapos (noite), gotas e
  cachoeiras (gruta), rio e fonte; WAV carregado em runtime (`load_from_file`). `--mute` desliga.
- QA: `godot --path . -s res://prototypes/pixel3d/tools/capture_cave.gd` → `pixel3d-cave-*.png`.

## O que tem
- `shaders/outline_post` — contorno escuro na silhueta, claro nas quinas (pós-processo).
- `shaders/toon*` — luz em degraus, sombra roxa do ambiente.
- `shaders/ground` + `grass` — chão com trilhas e tufos de grama que balançam e se afastam do jogador.
- `shaders/flame_shell` — labaredas na silhueta (segunda passada nas roupas).
- `shaders/flame_particle` — chama em forma de lágrima para partículas.
- `shaders/water` — lago, rio (correnteza pela fita) e fonte: raso→fundo por profundidade, espuma de margem.
- `shaders/rune_flow` — canais de brasa correndo pela roupa do Piromante.
- `shaders/ghost` + dissolve no `toon` — teleporte: some em pixels acesos, fantasmas, faíscas, onda de choque.
- `pixel3d_dressing.gd` — lago, rio com ponte, praça com fonte, lampiões piscando, vagalumes e folhas.
- Sombras de nuvem (ruído global `cloud_noise` na luz) e ajuste de cor no Environment.
- Mago da KayKit (CC0, `assets/third_party/kaykit_adventurers/`) com animações do pacote (parado, corrida, conjurar, esquiva) e material toon sobre a paleta dele.
- `pixel3d_life.gd` — vitórias-régias, peixes (nadam e pulam), sapos (pulam na água), respingos e ondinhas.
- Mapa 120×120, árvores em biomas de cor (verde, outono, florada, violeta, dourada), copas vazadas perto do jogador, flores em manchas.
- Linha de comando extra: `--zoom=N` (px por unidade), `--pitch=-38`, `--at=x,z`. Com `--shot`, teclado/mouse são ignorados.

## Achados
_(preencher ao concluir)_
