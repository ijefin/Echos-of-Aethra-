# MMORPG — Game Design Document (GDD)

> **Versão:** 0.1 — 03/11/2026  
> **Estado:** Documento vivo de planejamento, aberto a revisões  
> **Projeto:** MMORPG action top-down 2D, PvE/PvP, fantasia  
> **Legenda:** ✅ decidido · 🧪 proposta para testar · ❓ pendente de definição

---

## 1. Visão do jogo

### 1.1 Conceito

MMORPG em mundo aberto **contínuo**, com perspectiva top-down, combate action com mira e habilidades direcionais, exploração, progressão por **provações de ascensão**, ecossistemas de monstros organizados em linhagens e masmorras secretas instanciadas descobertas por pergaminhos.

O jogo deve produzir sensações de **descoberta**, **perigo**, **superação**, **conquista** e **rivalidade**. A diferença entre um inimigo comum e uma criatura ancestral deve ser visível em sua silhueta, tamanho, efeitos, comportamento e presença no mundo — não apenas nos números de HP/dano.

### 1.2 Estado atual do protótipo ✅

- Cenário florestal top-down já apresentado, com vegetação, caminhos, água, iluminação, praça e fonte.
- Personagem navegável com movimentação.
- Ataque de bola de fogo acionado pelo mouse.
- Controles exibidos no protótipo: WASD, ataque por clique, teleporte com Q/botão direito, esquiva com Espaço, zoom pela roda, Piromante pela tecla F e F10 para sair.
- O protótipo visual **não confirma** que rede multiplayer, inventário, persistência, IA de monstros ou loot já estejam implementados.

### 1.3 Pilares ✅

1. **Mundo compartilhado:** exploração contínua, territórios, regiões e eventos públicos.
2. **Combate action + RPG:** habilidade do jogador, build e equipamento importam.
3. **Ascensão como conquista:** derrotar Guardiões para liberar novas faixas de nível.
4. **Ecossistemas memoráveis:** cada família tem variantes pequenas, médias, altas, elites, ancestrais e Guardiões.
5. **Descoberta social:** pergaminhos revelam masmorras exclusivas para uma party.
6. **PvP livre com regras regionais:** zonas protegidas, opcionais e de confronto aberto.

---

## 2. Mundo e estrutura dos mapas

### 2.1 Mundo principal ✅

- Um **mundo aberto contínuo** com regiões fisicamente conectadas: bosques, vilas, pântanos, montanhas, desertos, cavernas e assim por diante.
- Os jogadores compartilham espaços, criaturas, acontecimentos e recursos.
- Divisão técnica interna por regiões/chunks é compatível com a impressão visual de um mundo contínuo.
- Instâncias são exceções deliberadas: **provações** e **masmorras secretas**.

### 2.2 Tipos de conteúdo

| Tipo | Presença | Acesso | PvP sugerido |
|---|---|---|---|
| Vila / refúgio | Mundo aberto | Todos | Protegido |
| Região opcional | Mundo aberto | Todos | Só participantes com PvP habilitado |
| Território contestado | Mundo aberto | Todos | Livre, com regras próprias |
| Terras sem lei | Mundo aberto | Todos | Livre, alto risco |
| Arena de ascensão | Instância | Solo/party | Desativado durante a prova |
| Masmorra por pergaminho | Instância privada | Party autorizada | PvE, salvo variantes PvP explicitamente anunciadas |

> 🧪 Não confundir **PvP livre por região** com obrigação de PvP em todo o mundo. As fronteiras e as condições precisam ser transparentes.

### 2.3 Mundo vivo 🧪

- Rastros que anunciam monstros perigosos: pegadas gigantes, árvores arranhadas, carcaças, uivos e fuga de animais menores.
- Patrulhas, ninhos, territórios e confrontos entre criaturas.
- Invasões regionais reversíveis: caso os jogadores falhem, surgem patrulhas extras ou rotas perigosas temporárias.
- Indicadores visuais e sonoros para mudanças de perigo.

---

## 3. Progressão de níveis e ascensões

### 3.1 Regra central ✅

- A cada faixa de aproximadamente **dez níveis**, o personagem atinge um limite temporário (10, 20, 30, 40 etc.).
- Para **desbloquear a faixa seguinte**, é preciso vencer a provação associada ao **Guardião da região** e conquistar sua **Pedra de Ascensão**.
- A pedra **não aumenta automaticamente dez níveis**; ela libera a possibilidade de evoluir até o novo limite.
- Os Guardiões mudam conforme o bioma, a família de monstros e o estágio da jornada.
- Os bosses também oferecem loot útil para a evolução de personagem.

### 3.2 Ritmo pretendido ✅ / 🧪

**Decisão:** começo rápido; a progressão fica mais exigente nas faixas avançadas, com algumas faixas moderadas. O intervalo de 8–15 horas é uma referência, **não uma regra fixa para todas as ascensões**.

| Faixa | Tempo-alvo inicial de jogo ativo | Estado |
|---|---:|---|
| 1–10 | 1–2 h | 🧪 |
| 11–20 | 3–5 h | 🧪 |
| 21–30 | 5–8 h | 🧪 |
| 31–40 | 8–12 h | 🧪 |
| 41–50 | 10–15 h | 🧪 |
| 51–60 | 12–18 h | 🧪 |

Esses são **alvos para playtest**, não promessas nem temporizadores. Considerar tempo médio de jogadores novos, experientes, solos e em grupos.

### 3.3 Regras contra frustração 🧪

- Primeira Pedra de Ascensão garantida na primeira vitória **válida** do Guardião correspondente.
- Loot raro adicional continua sujeito a chance de drop e tabela de recompensas.
- Uma fração limitada do XP pode ser reservada quando o personagem está no cap, para não invalidar toda a atividade enquanto procura vencer a prova.
- Jogadores travados na provação podem aprimorar equipamentos, investigar fraquezas, conseguir consumíveis ou fazer conteúdo paralelo.
- Provações solo e cooperativas possíveis, com dificuldades balanceadas; não exigir obrigatoriamente uma party para subir.
- **Evitar carregamento trivial:** normalização ou limitação de poder de integrantes muito acima da faixa da provação.

### 3.4 Pedras e fantasia narrativa 🧪

| Ascensão | Pedra | Tema | Guardião de exemplo |
|---|---|---|---|
| 10 → 20 | Pedra do Instinto | Predação e sobrevivência | Fenrath, Devorador de Raízes |
| 20 → 30 | Pedra da Fúria | Poder ofensivo e controle | Guardião Vulcânico |
| 30 → 40 | Pedra da Resistência | Sobrevivência sob pressão | Guardião Glacial |
| 40 → 50 | Pedra do Abismo | Conhecimento proibido | Entidade Ancestral |

Nomes, lore e recompensas são **provisórios**. A pedra pode ser apresentada em um ritual curto e marcante, com registro da conquista no personagem.

---

## 4. Famílias de criaturas e hierarquia de ameaça

### 4.1 Conceito ✅

Cada área tem várias famílias de criaturas, com variações de tamanho, anatomia, funções, comportamento e poder. Criaturas muito avançadas podem ocasionalmente surgir em locais mais comuns como minibosses ou pequenas hordas, sinalizadas para evitar mortes injustas.

Uma família de quadrúpedes, por exemplo, pode evoluir de lobos comuns para lobos maiores, criaturas multicéfalas, Alfas e um Guardião colossal com identidade visual de lobo.

### 4.2 Categorias de ameaça 🧪

| Categoria | Papel | Frequência sugerida |
|---|---|---|
| Comum | XP, materiais, aprendizado | Alta |
| Veterano | Introduz ataques e resistências | Moderada |
| Elite | Desafio local, loot melhor | Incomum |
| Alfa | Miniboss territorial e comandante | Rara |
| Ancestral | Evento/ameaça excepcional | Muito rara |
| Guardião | Chefe maior da área e ascensão | Encontro próprio |

### 4.3 Exemplo de linhagem: lobos 🧪

1. **Lobo Silvestre:** fraco, caça em grupos pequenos, pode recuar quando ferido.
2. **Lobo Sangrento:** corpo maior, investida, sangramento e uivo de convocação.
3. **Lobo Bicípite:** duas cabeças, ataques em ângulos diferentes e pressão sobre posicionamento.
4. **Cérbero da Matilha:** três cabeças, miniboss, comandando lobos e ataques coordenados.
5. **Fenrath, o Devorador de Raízes:** Guardião colossal associado à primeira ascensão, com múltiplas fases.

A família pode ter **ramificações** (caçador furtivo, defensor blindado, invocador/comandante), não apenas uma linha linear de monstros maiores.

### 4.4 Arquétipos de IA 🧪

- Caçador: perseguir, flanquear, aproveitar distância.
- Defensor: proteger aliados, controlar passagens.
- Predador: atacar e recuar, esperar brechas.
- Invocador: chamar reforços de forma sinalizada.
- Berserker: mudar padrão quando ferido.
- Comandante: coordenar a matilha e fortalecer aliados.

Comportamentos podem ser combinados e variam por fase de boss. Definir **alcance de perseguição**, condições de retorno e limites para invasões de regiões iniciais.

### 4.5 Identidade audiovisual 🧪

- Silhuetas reconhecíveis em escala top-down.
- Variações de corpo/cabeças/membros e acessórios orgânicos, não só recolor.
- Passadas mais pesadas, tremores sutis, uivos e efeitos de ambiente para criaturas superiores.
- Animações claras de antecipação, execução e recuperação de ataques.
- Tamanho visual impressionante **sem sacrificar legibilidade de hitbox e colisão**.

---

## 5. Guardiões, prova de bravura e encounters

### 5.1 Princípio ✅

O Guardião não é somente um inimigo com muito HP. Cada provação deve testar o conjunto de técnicas aprendidas na faixa: movimentação, mira, esquiva, posicionamento, controle de recursos, habilidades e leitura de padrões.

### 5.2 Exemplo: Fenrath 🧪

| Fase | Gatilho proposto | Padrões | O que testa |
|---|---|---|---|
| O Predador | 100–66% HP | Mordida, avanço frontal, garras | Esquiva e reconhecimento de telegráficos |
| O Chamado | 65–26% HP | Uivo, matilha, salto, cerco | Prioridade de alvo e posicionamento |
| A Fúria Ancestral | 25–0% HP | Raízes, rugido, golpes amplos | Controle da arena e janelas de punição |

Valores de HP e timings dependem de playtest. Evitar golpes inevitáveis ou ataques visualmente ambíguos. Recompensas da primeira vitória: Pedra do Instinto garantida, XP/recursos apropriados e chance de equipamentos temáticos.

### 5.3 Provações cooperativas 🧪

- Solo ou party pequena (quantidade final a definir).
- Escalonar mecânicas, não apenas HP bruto.
- Evitar carregar personagens novos por força bruta de níveis altos.
- Boss e recompensas devem ser contabilizados pelo **servidor**, inclusive em desconexões.

---

## 6. Pergaminhos e masmorras instanciadas

### 6.1 Fantasia central ✅

Alguns **pergaminhos especiais revelam masmorras invisíveis para o mundo normal**, com acesso exclusivo à party que os ativou. A entrada pode surgir em locais ocultos do mapa principal; outros jogadores não veem a entrada nem entram naquela instância.

Essas masmorras coexistem com o mundo aberto, sem substituí-lo.

### 6.2 Fluxo sugerido 🧪

1. Um jogador encontra ou obtém um pergaminho.
2. O item descreve pistas, região, dificuldade e requisitos.
3. O jogador reúne sua party e se desloca até a área indicada.
4. O líder ativa o pergaminho no local correto.
5. O **servidor** valida o item, a party, o acesso e a capacidade de criar a instância.
6. Depois da confirmação, o item é consumido e uma entrada visível apenas à party aparece.
7. Jogadores autorizados atravessam o portal e enfrentam a masmorra.
8. Ao concluir, recebem recompensas e retornam ao mundo aberto.

**Tratamento de falha:** não consumir o pergaminho se a instância não for criada; reservar estado da instância durante reconexões por um intervalo a definir.

### 6.3 Raridades / tipos 🧪

| Tipo | Experiência |
|---|---|
| Esquecida | Curta, exploração e recursos |
| Amaldiçoada | Modificadores e inimigos difíceis |
| Ancestral | Minibosses e mecânicas especiais |
| Lendária | Encontro marcante, boss e recompensas especiais |

Construir salas, encontros e modificadores reutilizáveis para viabilizar conteúdo sem produzir mapas totalmente novos para cada pergaminho.

### 6.4 Exemplo de item 🧪

**Pergaminho: Sepulcro da Matilha Esquecida**  
Raridade: épico · Party sugerida: 1–4 · Faixa: 20–30  
Efeito: revela entrada oculta em uma floresta e cria sessão exclusiva da party.

### 6.5 Economia e trocas 🧪

- Pergaminhos podem ser **negociáveis**, **vinculados** ou **instáveis** (modificadores adicionais).
- Alguns podem ser encontrados dentro de outras masmorras.
- Evitar distribuir pergaminhos lendários sem controle de frequência.
- Evitar prazo de validade na maioria dos pergaminhos para não forçar agenda social.
- A entrada e a recompensa pertencem à sessão autorizada, mesmo se uma região de acesso tiver PvP livre.

---

## 7. PvP livre com restrições regionais

### 7.1 Decisão de direção ✅

**O PvP é livre como fundamento do mundo, mas varia conforme o território.** Algumas áreas são protegidas; outras são **PvP opcional**, nas quais **só pode receber ataques PvP quem habilitou essa participação**; e há áreas de confronto **totalmente livre**, inclusive de alto risco.

A regra deve ser perceptível ao jogador antes de entrar em uma região perigosa.

### 7.2 Modelo de zonas proposto 🧪

| Zona | Pode iniciar PvP? | Quem pode ser atingido? | Uso de design |
|---|---|---|---|
| **Santuário** | Não | Ninguém por PvP | Cidades, respawns, comércio, tutorial |
| **Opt-in (opcional)** | Sim, entre opt-ins | Apenas quem está com PvP ativo **e** participa legalmente | Florestas e rotas de exploração de baixo/médio risco |
| **Conflito aberto** | Sim | Qualquer jogador elegível, independentemente do opt-in | Territórios disputados, recursos raros, rotas de guildas |
| **Terras sem lei** | Sim | Qualquer jogador elegível, independentemente do opt-in | Alto risco, chefes, itens especiais, eventos de guerra |

**Nota:** “elegível” exige regras futuras de proteção de contas novas, faixa de nível, grupos e anti-abuso. Não significa automaticamente matar iniciantes sem limites.

### 7.3 Regras recomendadas para o opt-in 🧪

- Flag de PvP ativável/desativável apenas fora de combate e com cooldown.
- Flag **não desliga** enquanto houver combate PvP ativo, perseguição registrada ou debuff de agressão.
- Jogador com PvP **desativado** não recebe dano de ataques de jogadores em zona opt-in; tampouco pode causar dano, aplicar controle ou beneficiar um ataque PvP por brechas indiretas.
- Suporte, cura, buffs e dano em área precisam seguir a mesma lógica de elegibilidade para evitar exploração do sistema (por exemplo, healer invulnerável dando suporte a combatentes habilitados).
- Destacar no HUD: estado PvP pessoal e regra da região atual.

### 7.4 Regras recomendadas para transições 🧪

- Aviso antecipado ao se aproximar de fronteira de zona aberta.
- Pequeno período de preparação ao sair de área segura, **sem** permitir imunidade ofensiva abusiva.
- Não permitir cruzar uma fronteira para zerar instantaneamente dano, perseguição ou penalidades de agressão.
- Teleporte, desconexão, respawn e entrada em instância devem ter regras explícitas em combate.
- Zonas devem ser verificadas pelo servidor com coordenadas/volumes de colisão; HUD é somente exibição.

### 7.5 Morte, reputação e risco — pendente ❓

Questões centrais:

- PvP aberto causa perda de XP, durabilidade, moedas, equipamentos ou apenas tempo de retorno?
- Existe **PK / criminalidade / caçadores de recompensa** ou o risco é totalmente livre sem punição?
- O que acontece ao matar alguém muito abaixo do próprio nível?
- Como funcionam abates em party e guilda, cura de PK, combate em grupos e loot do cadáver?
- Jogadores podem ativar ou abrir pergaminho estando sob ataque?
- Como proteger rotas de iniciantes sem eliminar a tensão do mundo?
- Haverá arenas ranqueadas com atributos normalizados, separadas do PvP aberto?

**Diretriz inicial:** evitar *full loot* e perda pesada de XP nas primeiras faixas até que o combate, a rede e o anticheat estejam confiáveis. Diferenciar risco entre zonas abertas normais e terras sem lei.

### 7.6 Regra especial: portais exclusivos em região PvP 🧪

- A jornada até a localização do pergaminho pode ter risco de emboscada se estiver em zona livre.
- A instância ativada continua **exclusiva da party**, sem invasões inesperadas de jogadores externos.
- Definir se o pergaminho pode cair, ser roubado, ser cancelado ou permanecer seguro na morte — **não decidido**.

---

## 8. Combate action e construção de personagem

### 8.1 Filosofia ✅

**Equilíbrio entre habilidade mecânica, build e equipamentos.** O jogador deve sentir que sua mira, esquiva, reflexos e posicionamento importam, sem tornar inútil investir em evolução e itens.

### 8.2 Fundamentos 🧪

- Movimentação responsiva, esquiva direcional e recuperações previsíveis.
- Habilidades direcionadas pelo mouse, projéteis reais, telegráficos e indicadores de área.
- Defesa ativa: esquivar, bloquear, interromper e usar obstáculos.
- Atributos, equipamentos e especializações abrem estilos de jogo, em vez de apenas multiplicar números.
- Combos e condições (queimadura, lentidão, sangramento), com limites de controle para PvP.
- Evitar combos de *stun* infinito; testar respostas defensivas.

### 8.3 Exemplo: Piromante 🧪

1. **Bola de Fogo** aplica queimadura.
2. **Passo Ígneo** reposiciona e pode criar trilha de fogo.
3. **Detonação** consome queimaduras para causar dano em área.

Valores, alcance, cooldown e custo de recursos são assunto de balanceamento, não decisões fechadas.

### 8.4 Especializações 🧪

A ascensão pode liberar caminhos dentro da classe, por exemplo guerreiros ofensivos, defensivos ou móveis, e piromantes orientados a explosão, controle de área ou dano contínuo. Evitar que uma única build seja obrigatória em todas as modalidades.

### 8.5 PvP e disparidade de níveis 🧪

- **Mundo aberto:** progressão real e equipamentos importam.
- **Arena competitiva (opcional):** normalização parcial de atributos, preservando escolhas de habilidade/build.
- **Guerras territoriais (futuras):** objetivos variados para que diferentes classes e papéis contribuam.

---

## 9. Loot, economia e incentivos

### 9.1 Fontes de recompensa 🧪

| Origem | Recompensas sugeridas |
|---|---|
| Criatura comum | XP, recursos, materiais de craft |
| Elite / Alfa | Material raro, itens de nicho, pistas |
| Ancestral | Equipamentos especiais, cosméticos, pergaminhos |
| Guardião | Pedra garantida na 1ª vitória válida + tabela de loot |
| Masmorra | Itens temáticos, receitas, materiais, pergaminhos |
| Eventos regionais | Recursos e reconhecimento pela participação |

### 9.2 Princípios 🧪

- Loot de progressão obrigatório não depende exclusivamente de RNG injusto.
- Itens raros alteram opções e estratégias, não apenas números.
- Definir regras de vínculo, comércio, destruição de itens e inflação econômica.
- Evitar que chefes obrigatórios sejam permanentemente monopolizados por guildas dominantes.

---

## 10. Implementação técnica: princípios, não prompts

> **Ainda não escrever prompts de implementação para Codex/Claude nesta etapa.** Primeiro consolidar regras, casos-limite e protótipo de gameplay.

### 10.1 Separação de responsabilidades 🧪

**Servidor autoritativo** para: dano, HP, posição validada, estado PvP, elegibilidade de alvo, inventário, drops, experiência, ascensão, geração de instâncias, autorização de party, transições e persistência.

**Cliente** para: entrada, renderização, animações, áudio, UI e predição visual/movimentação onde apropriado. Validar contra teleporte, speed hack, duplicação de pergaminhos, falsificação de dano e abuso de fronteiras PvP.

### 10.2 Subsistemas

- Progression/Ascension: regras de limite de nível, provas, pedras e recompensas.
- CreatureFamily/Spawner/AI: famílias, variantes, spawn, aggro, telegráficos e fases de boss.
- PvPZone/CombatEligibility: volumes de zona, flags, cooldowns, legalidade de ataques, cura e AoE.
- Party/InstanceManager: grupos, sessão, entrada, autorização, logout/reconnect e encerramento.
- Scroll/Inventory/ItemTransaction: consumo atômico, propriedades do item, negociação e recompensa.
- Combat/Skills/StatusEffects: colisão, alcance, cooldown, condições e combate PvE/PvP.
- Analytics: registro de morte, abandono de boss, duração de combate, progressão e economia.

### 10.3 Casos-limite a testar

- Jogador se desconecta após consumir o pergaminho.
- Party muda integrantes durante a instância.
- O líder do grupo sai ou morre.
- Jogador tenta curar aliado PvP ativo enquanto o próprio PvP está desativado.
- Projétil atravessa uma fronteira PvP.
- Jogador tenta desligar PvP imediatamente após atacar.
- Jogador tenta obter pedra duplicada ou repetir a primeira recompensa.
- Dois grupos ativam pergaminhos iguais no mesmo local.
- Guardião morre enquanto um integrante está desconectado.

---

## 11. Vertical slice recomendada

**Meta:** provar que os sistemas são divertidos e funcionam juntos, antes de multiplicar conteúdo.

- [ ] Floresta com **Santuário**, **zona Opt-in** e **Conflito aberto**, todos visíveis no HUD.
- [ ] PvP ativo/inativo na zona opcional; teste de ataques, suporte e fronteiras.
- [ ] Três variantes de lobo com IA distinta e telegráficos.
- [ ] Um Alfa que patrulha território e pode chamar uma matilha.
- [ ] Fenrath em arena com 2–3 fases e recompensa de primeira vitória.
- [ ] Níveis 1–10, limite e desbloqueio até 20 com Pedra do Instinto.
- [ ] Um pergaminho com entrada oculta e instância privada de 1–4 integrantes.
- [ ] Uma recompensa que mude uma habilidade/build perceptivelmente.
- [ ] Registro de métricas: tempo até ascensão, tentativas no boss e causa de mortes.

**Critérios de aprovação:** combate legível e responsivo, ascensão recompensadora, progressão inicial ágil, nenhuma violação grave de regras PvP e nenhum caminho óbvio de duplicação/roubo de acesso a instâncias.

---

## 12. Backlog de ideias (sem compromisso)

- [ ] Sinais ambientais de monstros ancestrais antes do spawn.
- [ ] Ramos evolutivos dentro de uma mesma família de criaturas.
- [ ] Eventos de hordas e invasões com consequências temporárias.
- [ ] Reputação regional com famílias de monstros.
- [ ] Pergaminhos instáveis com afixos únicos.
- [ ] Masmorras que podem dropar pistas de outras masmorras.
- [ ] Relíquias cosméticas pela primeira ascensão.
- [ ] Coleção de registros de criaturas e descoberta de fraquezas.
- [ ] Guerras de guildas e domínio territorial.
- [ ] Caçadores de recompensa / sistema de PK.
- [ ] Arenas competitivas com normalização parcial.
- [ ] NPCs e economia influenciados por eventos regionais.

---

## 13. Questões abertas para próximas sessões

### PvP e morte (prioridade alta)

1. Qual a penalidade de morte por PvP em **Conflito aberto** e em **Terras sem lei**?
2. Teremos criminalidade/PK, reputação negativa e caçadores de recompensa?
3. Haverá proteção para novatos ou diferenças excessivas de nível?
4. A flag PvP ativa exclusivamente em zonas opt-in ou também altera outras interações?
5. Como impedir exploração de fronteiras, cura, AoE e desligamento de PvP?

### Progressão

6. Nível máximo previsto na primeira versão?
7. Quantas classes? Quais especializações e recursos?
8. Pode tentar Guardião antecipadamente? Precisa estar exatamente no cap?
9. Pedra é item utilizável, vinculada à conta ou convertida imediatamente em registro permanente?

### Masmorras

10. Tamanho das parties (solo, 2–4, 2–6 etc.)?
11. Masmorras têm tempo máximo, checkpoints, ressurreição e tentativa única?
12. Pergaminhos podem ser perdidos no PvP?
13. Haverá masmorras competitivas ou todas as privadas serão PvE?

### Economia e mundo

14. Comércio direto, leilão, crafting e destruição de equipamentos?
15. Bosses públicos podem ser disputados? Como atribuir loot e participação?
16. Quais biomas/famílias entram no lançamento inicial?

---

## 14. Registro de decisões

| Data | Tema | Decisão |
|---|---|---|
| 03/11/2026 | Estrutura do mundo | Mundo aberto contínuo com regiões conectadas |
| 03/11/2026 | Instâncias | Masmorras exclusivas abertas/reveladas por pergaminhos para uma party |
| 03/11/2026 | Progressão | Ascensão a cada faixa de ~10 níveis por Guardião + pedra |
| 03/11/2026 | Ritmo | Começo rápido; progressão mais moderada/lenta em faixas avançadas |
| 03/11/2026 | Combate | Equilíbrio entre habilidade, build e equipamento |
| 03/11/2026 | PvP | Livre com restrições regionais, incluindo zonas opt-in e zonas totalmente livres |

---

## 15. Registro de novas ideias

> Use este formato ao longo da criação. Toda nova ideia deve ser avaliada por **diversão**, **impacto no PvP/PvE**, **custo de implementação**, **risco de abuso** e **prioridade**.

### Modelo para copiar

```md
### Ideia: [nome]
- **Data:** AAAA-MM-DD
- **Problema/oportunidade:**
- **Como o jogador vivencia isso:**
- **Regras:**
- **Interação com PvE/PvP:**
- **Risco/abuso possível:**
- **Custo aproximado:** baixo / médio / alto
- **Prioridade:** agora / depois / futuro
- **Status:** proposta / validando / decidida / descartada
```

### Próxima discussão sugerida

**Morte no PvP, PK, loot e risco por tipo de zona.** Essas regras afetam diretamente a economia, o valor dos pergaminhos e a sensação de perigo do mundo.

---

*Este GDD representa decisões e propostas discutidas até 03/11/2026. Valores, nomes, percentuais e tempos ainda precisam de protótipos e playtests.*
