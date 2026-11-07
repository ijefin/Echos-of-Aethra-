# Echos of Aethra — Game Design Master

**Versão:** 0.1 — consolidação das conversas de design até 06/11/2026  
**Status:** Documento de alinhamento, **não** especificação final de todas as mecânicas.  
**Escopo:** visão de jogo, decisões registradas, propostas em análise, conflitos documentais e próximos passos.  
**Regra de leitura:** a marcação **[APROVADO]** representa decisão expressamente adotada na conversa; **[PROPOSTO]** representa sugestão ainda sujeita a teste/aprovação; **[A VALIDAR]** representa informação que depende de inspeção do repositório ou playtest.

> Este documento foi criado com base nas conversas disponíveis, não por inspeção direta do repositório. Arquivos, versões e valores técnicos mencionados em discussões anteriores devem ser confirmados no código antes de qualquer implementação.

---

## 1. Visão geral

**[APROVADO]** Echos of Aethra é um MMORPG action RPG com mundo aberto contínuo, regiões conectadas e foco em PvE, PvP, exploração, progressão de personagem, economia e interação social. O combate deve equilibrar **habilidade mecânica**, **build** e **equipamento**, evitando tanto um modelo puramente baseado em atributos quanto um jogo em que progressão RPG não importe.

**Objetivo de experiência:** explorar um mundo com identidade própria, sentir o perigo de regiões avançadas, perceber a evolução do personagem e continuar encontrando objetivos sociais, econômicos e competitivos após atingir o limite de progressão disponibilizado.

### Princípios norteadores

1. **Preservar e evoluir o protótipo existente**, não reconstruí-lo sem diagnóstico.
2. **Legibilidade de PvP** é critério funcional do visual: personagens, ataques, projéteis e zonas de perigo precisam ser reconhecíveis.
3. **O mundo deve permanecer relevante** ao longo da progressão; evitar que todo o conteúdo antigo se torne descartável.
4. **Progressão persistente**; evitar resets obrigatórios de personagens.
5. **Definir → implementar → jogar → avaliar → ajustar**, com tarefas curtas e verificáveis.
6. **Separar decisões de design de execução técnica**: decisões aqui; tarefas delimitadas para Codex/agentes.

---

## 2. Direção visual, cena e câmera

### 2.1 Visual

- **[APROVADO]** 3D low-poly com renderização pixelada; não retornar automaticamente a conceitos antigos de sprites/personagens 2D.
- **[APROVADO]** Preservar a identidade já alcançada na floresta, água, caminhos, iluminação e ambientação; fazer melhorias incrementais.
- **[APROVADO]** Evitar estética de personagem *anime*.
- **[PROPOSTO]** Melhorar silhuetas, leitura de armas, materiais, animações e equipamentos de guerreiro, mago e arqueiro.
- **[PROPOSTO]** Refinar as árvores, unificar princípios de modelagem/material e reduzir ruído onde ele prejudicar a leitura.
- **[PROPOSTO]** Tornar vegetação e obstáculos que ocultam personagens parcialmente transparentes durante situações relevantes de combate.
- **[PROPOSTO]** Revisar a resolução interna/pixelização da renderização se detalhes essenciais dos personagens estiverem sendo perdidos; não mudar globalmente sem teste A/B.

### 2.2 Câmera

- **[APROVADO, para o estágio atual]** Câmera top-down inclinada, centrada no personagem e acompanhando sua movimentação. O enquadramento atual é referência visual; **não alterar automaticamente** na primeira rodada de implementação.
- **[A VALIDAR]** Confirmar no projeto se a projeção é ortográfica e se a inclinação efetiva é de 50°; esses valores foram citados nas discussões, mas devem ser verificados no código.
- **[PROPOSTO]** Comparar em ambiente isolado o enquadramento atual com uma inclinação mais vertical (por exemplo, 60°–65°) para medir leitura de distância, alvos, projéteis e oclusão.
- **[PROPOSTO]** Testar um deslocamento *sutil* de câmera na direção da mira, apenas se não comprometer orientação/controle; não implementar sem playtest.
- **[PROPOSTO]** Evitar rotação automática de câmera durante PvP.

**Nota terminológica:** projeção ortográfica não significa, por si só, câmera em diagonal. O ângulo de visão top-down inclinado e a rotação horizontal (*yaw*) são propriedades distintas.

---

## 3. Movimento, orientação e combate

### 3.1 Comportamento de locomoção

**[APROVADO — regras comportamentais]**

- WASD move o personagem.
- Na movimentação comum, o personagem **olha para a direção em que se desloca**, não acompanha o mouse.
- Quando parado, conserva a última orientação.
- **Durante ataques**, o cursor define a direção/alvo da ação; fora de ações ofensivas, o personagem não fica girando para acompanhar o cursor.
- O dash respeita **a direção do deslocamento**, não a direção do mouse.
- Movimentação deve parecer responsiva e precisa, sem deslizamento excessivo.

**[PROPOSTO — precisa de testes e parâmetros]**

- Aceleração muito curta e desaceleração previsível.
- Golpes pesados têm limitações de correção de orientação depois de iniciados, para permitir leitura e contra-jogo no PvP.
- Estados de combate incluem possíveis antecipação, execução e recuperação; valores exatos não definidos.
- Dash, parry, esquiva e ataques devem ser concebidos em conjunto, não como sistemas isolados.
- Feedback imediato no cliente e validação/autoridade do servidor para decisões competitivas, se compatível com a arquitetura existente.

### 3.2 Filosofia de combate

- **[APROVADO]** Equilíbrio entre habilidade mecânica, build e equipamento.
- **[PROPOSTO]** Tomar como referências funcionais a precisão e direção de ataques de action RPGs competitivos, preservando a profundidade RPG de equipamentos, atributos e escolhas de build.
- **[A VALIDAR]** Definir quantitativo final de habilidades, recursos de defesa, janelas de parry, cancelamentos, *crowd control*, imunidades e tempos de recuperação.
- **[A VALIDAR]** Testar PvP com duas pessoas, obstáculos e latência simulada antes de consolidar o controlador.

### 3.3 Critérios de legibilidade

Um jogador precisa identificar rapidamente sua própria posição, alvos, direção de ataques, zonas perigosas, projéteis e elementos meramente decorativos. Avaliar cenas com múltiplos jogadores, diferentes classes e muitos efeitos, não apenas com um único personagem na floresta.

---

## 4. PvP e zonas do mundo

- **[APROVADO]** PvP livre faz parte da identidade do mundo, com regras dependentes da região.
- **[APROVADO]** Haverá zonas seguras, zonas de PvP opcional (só participa quem estiver habilitado sob as regras do local) e zonas de PvP amplamente livre.
- **[A VALIDAR]** Definir em detalhe: sinalização de zonas, ativação/desativação do PvP opcional, proteção ao entrar/sair, prevenção de abuso, consequências de mortes, *spawn camping*, grupos e diferença excessiva entre níveis/tiers.
- **[A VALIDAR]** Balancear diferença de poder entre veteranos e iniciantes sem eliminar a sensação de progressão vertical.

---

## 5. Progressão: níveis, tiers, ascensões e ciclos

### 5.1 Estrutura

- **[APROVADO COMO DIREÇÃO]** O ritmo desejado é **moderado: aproximadamente 8–15 horas por faixa de ascensão**, valor a validar em testes de progressão.
- **[APROVADO COMO DIREÇÃO]** Trabalhar com **aproximadamente 20 níveis por tier**, em vez de especificações anteriores de 10 níveis por ascensão.
- **[PROPOSTO, não fixado]** Agrupar **5 tiers por ciclo**, com uma grande provação/conquista ao final do ciclo. Um primeiro ciclo representaria, ilustrativamente, níveis 1–100.
- **[PROPOSTO, não compromisso de produção]** Escala futura de 100+ tiers, mas **não** criar 100 tiers exclusivos para o lançamento. O número é uma possibilidade de expansão, não uma obrigação de conteúdo.
- **[PROPOSTO]** Construir inicialmente um ciclo completo de até 5 tiers para validar curva de experiência, recompensas, dificuldade e sensação de ascensão.

### 5.2 Significado da ascensão

**[PROPOSTO]** Cada ascensão deve ser mais do que um contador numérico. O ciclo pode incluir aprendizado, domínio de vocação, identidade da build, desafios mais complexos e uma grande provação. Recompensas possíveis: título, aparência, variação de habilidade, acesso a conteúdo ou opções de personalização. Evitar desbloqueios que obriguem a criar uma nova mecânica para cada tier.

### 5.3 Bloqueio e evolução paralela

- **[PROPOSTO]** O nível pode ficar temporariamente limitado até vencer uma prova de ascensão.
- **[PROPOSTO]** Enquanto o nível estiver bloqueado, ainda permitir progresso significativo em domínio de habilidades, crafting, equipamentos e especializações.
- **[A VALIDAR]** Definir se XP excedente é armazenado, convertido, limitado ou perdido ao atingir o teto atual; **não há decisão final**.

### 5.4 Longevidade do mundo

- **[PROPOSTO]** Manter recursos de regiões iniciais úteis em algumas receitas avançadas, evitando pressão excessiva de veteranos sobre novatos.
- **[PROPOSTO]** Progressão horizontal com equipamentos de estilos diferentes, sem um único melhor item em todas as circunstâncias.
- **[PROPOSTO]** Eventos e desafios selecionados podem escalar dificuldade; **não** escalar automaticamente todos os monstros ao nível de cada jogador.

---

## 6. Endgame após o conteúdo principal

**[APROVADO COMO PRINCÍPIO]** Atingir o maior nível disponível não deve significar esgotar as atividades interessantes. O endgame deverá oferecer caminhos de **poder aperfeiçoado (sem crescimento infinito)**, **conquistas** e **influência no mundo**.

**[PROPOSTO]** Pilares possíveis:

1. **Masmorras de dificuldade variável** com modificadores, desafios de equipe/solo, materiais, cosméticos e troféus.
2. **Bosses mundiais e eventos dinâmicos**, com consequências para regiões e recompensas relevantes.
3. **Crafting, profissões e comércio** como atividades persistentes.
4. **Disputas territoriais, fortalezas e relíquias**, com consequências sociais e benefícios limitados/temporários.
5. **Desafios de classe, domínio e prestígio**, com reconhecimento visual e opções de build equilibradas.

**[PROPOSTO]** Sistema complementar de **Legado de Ascensão**: após atingir o teto disponível, atividades relevantes concederiam progresso de prestígio/personalização e opções horizontais limitadas, **sem acumular atributos infinitamente**.

**[PROPOSTO]** Não usar redefinição periódica de personagens como mecanismo principal de temporada; temporadas podem renovar desafios, eventos e rankings preservando os personagens.

**Riscos a evitar:** dailies obrigatórias, PvP inalcançável para recém-chegados, mapas antigos vazios e endgame inteiramente instanciado que retire jogadores do mundo aberto.

---

## 7. HUD, interface e experiência de usuário

- **[APROVADO COMO OBJETIVO]** Reformular o HUD atual, considerado visualmente insatisfatório, sem perder as funções existentes.
- **[A VALIDAR]** Inventariar no código barras de HP/mana, experiência, hotbar, consumíveis, chat, estados de combate e suas dependências.
- **[PROPOSTO]** Reduzir a competição visual do HUD com o cenário; melhorar hierarquia e leitura durante PvE/PvP.
- **[A VALIDAR]** Definir layout, estilo, atalhos, escalonamento e comportamento em diferentes resoluções antes de substituir a interface.

---

## 8. Diretrizes de personagens e vegetação

### Personagens

- **[PROPOSTO]** Começar com refinamento controlado do guerreiro e do mago, verificando silhueta, proporção em gameplay, equipamento reconhecível, direção de ataques, animações e sistema de equipamentos modulares. Arqueiro deve ser contemplado na arquitetura.
- **[A VALIDAR]** Separar problemas de modelagem dos problemas causados por pixelização, câmera, iluminação e escala; não aumentar o personagem sem medir impacto ambiental.
- **[PROPOSTO]** Antes de construir todos os sets, aprovar um padrão visual e animações de referência que funcionem em escala real de combate.

### Vegetação

- **[PROPOSTO]** Refinar um pequeno conjunto de árvores representativas, padronizar linguagem de copas/materiais/sombreamento e avaliar variantes.
- **[PROPOSTO]** Distinguir áreas de exploração (ricas em detalhes) de situações de combate (personagens e ameaças em primeiro plano visual), sem criar dois estilos gráficos distintos.
- **[A VALIDAR]** Medir custo de transparência dinâmica e efeitos visuais em áreas populadas.

---

## 9. Implementação incremental e trabalho paralelo

**[APROVADO COMO PROCESSO]** Planejar e executar tarefas curtas; evitar refatoração ampla antes de verificar código real. Quatro frentes de evolução:

| Frente | Objetivo | Primeira entrega sugerida | Atenção |
|---|---|---|---|
| A — Movimento e combate | Responsividade e regras de orientação | Auditoria, pequena arena de teste, teste de controle | Controlador, estados, animação e netcode podem estar acoplados |
| B — Personagens | Silhueta, equipamentos, animações | Prova visual de guerreiro/mago em escala real | Não refazer todos os modelos antes de validar padrão |
| C — Ambiente | Refinar árvores e legibilidade | 1–3 variantes de árvore e teste de oclusão | Preservar floresta, sombras e performance |
| D — HUD | Reestruturar visualmente sem perdas | Inventário de funções e protótipo de layout | Evitar perda de integração com gameplay |

**[APROVADO COMO RESTRIÇÃO INICIAL]** Primeira rodada do Codex: **auditoria e plano, sem editar arquivos, gerar assets, instalar dependências, fazer commits ou push**.

**[PROPOSTO]** Depois da auditoria, separar trabalho por arquivos/áreas sem conflito; usar branches ou worktrees se houver agentes simultâneos. Integrar de forma controlada e testar a cena jogável.

---

## 10. Documentos existentes e conflitos a reconciliar

Em conversas anteriores, foram citados os seguintes caminhos no projeto. **A existência e o estado atual devem ser confirmados pelo Codex antes de confiar neles:**

- `CLAUDE.md` — possíveis regras atuais de colaboração.
- `AGENTS.md` — instruções para Codex, se existir.
- `design/art/pixel3d-style-guide.md` — possível guia atual de estilo 3D pixelado.
- `design/art/art-bible.md` — pode conter referências desatualizadas a personagens 2D.
- `MMORPG_Game_Design_Document_v0.1.md` — pode conter ascensões a cada 10 níveis, em conflito com a direção de 20 níveis/tier.
- `prototypes/pixel3d/` — local do protótipo mencionado anteriormente.
- `src/world/` — arquitetura mencionada; situação de integração não verificada aqui.
- `.claude/agents/`, `.claude/skills/`, `.claude/settings.json` — possíveis definições e recursos de agentes Claude.

**Ordem de interpretação para uma tarefa específica:**

1. Requisitos expressos no prompt da tarefa aprovada.
2. Decisões **[APROVADO]** neste documento, quando não houver conflito com comportamento já aprovado mais recente.
3. Código real e regras técnicas obrigatórias do repositório.
4. Guias de estilo atualizados verificados no repositório.
5. Documentos legados, tratados como referências e não como autoridade automática.

Se houver conflito de produto, **relatar e pedir decisão**, não escolher silenciosamente. Documentos de segurança, restrições técnicas críticas e instruções de execução do ambiente não devem ser ignorados por esta ordem conceitual.

---

## 11. Uso de Codex e agentes Claude

**[APROVADO COMO FLUXO]** Design e prioridades são discutidos fora da implementação; Codex recebe tarefa fechada com objetivo, restrições, arquivos prováveis, testes e critérios de aceite; resultados e trade-offs voltam para revisão.

**[A VALIDAR]** Codex **não** deve assumir que executa automaticamente agentes configurados para Claude Code. Primeiro detectar quais especialistas existem e se há integração de execução realmente disponível. Se não houver, consultar suas instruções como referências, sem instalar ferramentas no escuro.

**Modelo mínimo de tarefa:**

```text
TIPO: AUDITAR | IMPLEMENTAR | CORRIGIR | VALIDAR
OBJETIVO: ...
DECISÕES DE DESIGN RELEVANTES: ...
ARQUIVOS/ÁREAS PERMITIDOS: ...
FORA DE ESCOPO: ...
CRITÉRIOS DE ACEITE: ...
TESTES: ...
RESTRIÇÕES: sem alteração de câmera/arte etc., conforme o caso
ENTREGA: resumo de mudanças, riscos e evidências de teste
```

---

## 12. Backlog inicial e critérios de aceite

### Etapa zero — Auditoria (primeira execução)

**Saída esperada:** localização do protótipo jogável, documentação conflitante, controlador de movimento, scripts de câmera, personagens, assets de árvores, HUD, multiplayer, agentes disponíveis, dependências cruzadas e plano de tarefas paralelizáveis.

**Aceite:** relatório conciso apontando arquivos reais, prioridades P0–P3 e justificativas; repositório não alterado.

### Etapa um — Vertical slice de combate

**[PROPOSTO]** Arena ou cenário isolado com dois personagens e obstáculos, reutilizando o que já existe. Comparar movimentação, mira no ataque, dash, orientação e leitura dos efeitos, sem mexer na floresta principal.

**Aceite proposto:** locomoção olha para a direção de movimento; parado mantém direção; mouse só afeta orientação na ação ofensiva; dash segue movimento; controles respondem consistentemente e não quebram animações existentes.

### Etapa dois — Prova visual de personagem/vegetação

**[PROPOSTO]** Variante refinada de personagem e 1–3 árvores, com comparação no mesmo cenário/câmera/luz e sob condições de combate.

**Aceite proposto:** maior legibilidade em escala real, compatibilidade de estilo, sem degradação significativa de performance.

### Etapa três — HUD

**[PROPOSTO]** Prototipar interface revisada, mapear controles e sinais antes de remover a anterior.

**Aceite proposto:** manter todas as funcionalidades atuais, reduzir ruído visual e permitir testes em resoluções-alvo.

### Etapa quatro — Integração e teste multiplayer

**[PROPOSTO]** Testar duas pessoas e latência simulada, colisões, transições, efeitos, oclusão e desempenho. Só depois consolidar decisões mais arriscadas de câmera e rede.

---

## 13. Decisões em aberto (não autorizar implementação definitiva ainda)

1. Tamanho exato da janela de ataques, parry, esquiva e *recovery*.
2. Valores de velocidade, aceleração, duração/distância do dash e prioridade de animações.
3. Regras completas para PvP opcional, livre e seguro, inclusive punições e diferenças de tier.
4. Qual inclinação de câmera vence nos testes comparativos (atual vs. mais vertical).
5. Resolução de renderização, escala de personagem e tratamento de contornos/efeitos.
6. Estrutura final de 5 tiers/ciclo e quantidade de tiers no lançamento.
7. XP quando se atinge um teto provisório ou a ascensão ainda está bloqueada.
8. Escopo exato do Legado de Ascensão e recompensas do endgame.
9. Regras de crafting, mercado, recursos, boss mundial e guerra territorial.
10. Layout final de HUD e requisitos de acessibilidade.
11. Arquitetura multiplayer/servidor e possibilidade de execução real dos agentes Claude pelo Codex.

---

## 14. Histórico de decisões (resumo)

| Tema | Resultado registrado | Situação |
|---|---|---|
| Estrutura do mundo | Mundo aberto contínuo e conectado | Aprovado |
| Progressão | Ritmo moderado, ~8–15 horas por faixa | Direção aprovada, números a testar |
| Combate | Habilidade + build + equipamentos | Aprovado |
| PvP | Zonas livres, opcionais e seguras | Aprovado, regras detalhadas pendentes |
| Estilo | 3D low-poly pixelado, sem anime | Aprovado |
| Câmera | Manter atual no primeiro ciclo de trabalho | Aprovado provisoriamente; A/B futuro |
| Movimento | WASD; olha para deslocamento; parado mantém direção | Aprovado |
| Mouse | Orienta ataques, não caminhada passiva | Aprovado |
| Dash | Direção do movimento | Aprovado |
| Progressão vertical | ~20 níveis por tier | Direção aprovada |
| Ciclos | 5 tiers por ciclo | Proposto |
| Escala | 100+ tiers como expansão possível | Hipótese, não escopo de lançamento |
| Endgame | Bosses, dungeons, economia, conquistas, territórios | Direção de design; sistemas propostos |
| HUD | Reformular sem perder funcionalidades | Objetivo aprovado |
| Execução | Codex audita antes de alterar; frentes separadas | Aprovado |

---

## 15. Como manter o documento vivo

- Guardar na raiz do repositório como `ECHOS_OF_AETHRA_GAME_DESIGN_MASTER.md`.
- Pedir ao Codex para **inspecionar o repositório antes de integrar** este documento. Evitar duplicar versões divergentes de GDD.
- Atualizar a marcação `[APROVADO]`, `[PROPOSTO]` ou `[A VALIDAR]` após cada decisão/experimento.
- Registrar no changelog toda mudança que afete combate, câmera, progressão, PvP ou estilo.
- Em tarefas do Codex, referenciar apenas as seções pertinentes para economizar leitura desnecessária.

**Próxima ação recomendada:** concluir a auditoria em modo somente leitura. Com o relatório em mãos, identificar quais documentos são legados, eleger o caminho canônico e iniciar as tarefas independentes em fatias pequenas, sem permitir que agentes alterem simultaneamente uma mesma cena.
