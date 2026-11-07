# Echos of Aethra — Backlog de execução

**Versão:** 0.3 · 2026-11-06  
**Referência de design:** `ECHOS_OF_AETHRA_GAME_DESIGN_MASTER.md`  
**Escopo:** protótipo 3D multiplayer existente. Não é uma autorização para reconstruir sistemas.

## Como usar
- Hierarquia: **Épico → História → Tarefas verificáveis**. ID estável para cada item.
- Estados: `BACKLOG`, `REFINEMENT`, `READY`, `IN_PROGRESS`, `REVIEW`, `DONE`, `BLOCKED`.
- `READY` significa que um executor pode implementar **apenas aquele item**, respeitando o escopo e as restrições.
- `SPIKE` significa investigação/experimento, **não aprovação de mecânica final**.
- Um executor por tarefa que altere os mesmos arquivos. Não executar histórias dependentes em paralelo.
- Atribuições são **neutras quanto à IA**: qualquer agente pode assumir uma história pelo ID, desde que respeite dependências, estado e escopo. Não atribuir uma história permanentemente a um produto específico.
- Antes de editar, registrar quem está executando e quais arquivos pretende tocar no acompanhamento compartilhado, para evitar colisões entre agentes.
- Antes de editar, confirmar existência dos caminhos e comportamento atual do Git; não presumir que a limpeza recente do repositório preservou os mesmos arquivos.
- Só marcar `DONE` com testes executados e evidências; testes não executados devem ser informados como pendentes.

## Decisões que regem este backlog
- **[APROVADO]** Jogo exclusivamente online. Teste local roda cliente e servidor, não um segundo jogo offline.
- **[APROVADO]** Servidor autoritativo. Preservar predição, reconciliação e interpolação existentes.
- **[APROVADO]** WASD; orientação acompanha deslocamento; parado conserva última orientação; mouse orienta ações ofensivas, não locomoção comum; dash segue direção de movimento quando há input; parado, segue orientação atual do personagem.
- **[APROVADO]** Visual 3D low-poly pixelado, câmera atual como referência; não alterar visual/câmera sem tarefa própria.
- **[APROVADO]** Combate equilibra habilidade, build e equipamento; zonas PvP seguras, opcionais e livres.
- **[A VALIDAR]** Parâmetros de movimento, tempos de ataque, parry, cancelamentos (inclusive dash durante ações bloqueantes), imunidades, feedback de hit, regras PvP detalhadas.

## Sprint 00 — Baseline operacional (curta, sem auditoria global)

### EOA-001 — Reproduzir execução multiplayer local
- **Tipo:** história técnica · **Estado:** READY · **Prioridade:** P0
- **Objetivo:** estabelecer caminho confiável para iniciar servidor e dois clientes usando as regras online reais.
- **Tarefas:** localizar comandos/cenas vigentes; iniciar servidor e clientes; registrar portas/configuração relevante sem segredos; registrar erros preexistentes; descrever execução mínima em `docs/development/local-multiplayer.md` **somente se ainda não houver guia canônico equivalente**.
- **Aceite:** passos reproduzíveis; cliente conecta ao servidor; dois personagens são visíveis ou a limitação fica comprovada e reportada; erros preexistentes separados de regressões.
- **Limites:** não alterar gameplay, arquivos `.import` preexistentes ou dependências sem necessidade; não fazer commit/push.

### EOA-002 — Smoke test e referência de comportamento
- **Tipo:** história técnica · **Estado:** READY · **Prioridade:** P0 · **Depende:** EOA-001
- **Objetivo:** registrar uma referência curta antes de editar movimento.
- **Tarefas:** validar Guerreiro/Mago/Arqueiro quando disponíveis; testar WASD, diagonal, inversão, parada, dash, colisões e ataque; marcar `PASS`, `FAIL` ou `NOT TESTED` com observações; registrar logs relevantes.
- **Aceite:** checklist reproduzível e lista objetiva de divergências; sem novas mudanças de gameplay.

## Sprint 01 — Movimento multiplayer (primeira implementação)

### MOV-001 — Orientação e controle de locomoção
- **Tipo:** história · **Estado:** READY · **Prioridade:** P0 · **Depende:** EOA-002
- **Como jogador**, quero movimentação precisa e orientação previsível para me posicionar no PvP.
- **Tarefas:** localizar caminho ativo entre input, predição e servidor; corrigir orientação por deslocamento; manter última orientação ao parar; impedir que mouse gire o corpo na caminhada normal; garantir diagonais normalizadas e inversões rápidas; ajustar aceleração/frenagem apenas no necessário, sem inventar valores definitivos.
- **Aceite:** WASD e diagonais sem ganho indevido de velocidade; personagem olha para movimento e não para cursor; parado preserva orientação; mudanças de direção sem deslizamento excessivo; resultado conferido em cliente + servidor; ações ofensivas não têm sua orientação sobrescrita.
- **Não inclui:** animações novas, câmera, hitbox, parry ou dano.

### MOV-002 — Dash autoritativo e previsível
- **Tipo:** história · **Estado:** READY · **Prioridade:** P0 · **Depende:** MOV-001
- **Como jogador**, quero que meu dash use a direção do movimento e se mantenha confiável online.
- **Tarefas:** fazer dash usar input de deslocamento e não cursor; preservar validação do servidor, cooldown e reconciliação existentes; investigar discrepâncias com latência; implementar dash parado na orientação atual do personagem (que pode ter sido alterada por um ataque anterior); garantir que o cursor não altere a orientação passivamente.
- **Aceite:** dash na direção do input em todos os quadrantes; sem input, dash na orientação atual (inclusive após ataque que a mudou); cursor não altera direção passivamente; cooldown não pode ser burlado no cliente; colisões e estado após dash consistentes; teste com dois clientes e latência simulada **se houver ferramenta disponível**.
- **Não inclui:** inventar i-frames, definir cancelamentos de ataques ou mudar habilidades ofensivas.

### MOV-003 — Regressão de classes e estados
- **Tipo:** teste de integração · **Estado:** BACKLOG · **Prioridade:** P0 · **Depende:** MOV-002
- **Tarefas:** repetir checklist em Guerreiro, Mago e Arqueiro; registrar divergências por classe; testar movimento simultâneo entre dois jogadores; conferir que ataques mantêm sua orientação própria.
- **Aceite:** sem regressões conhecidas não justificadas; resultados e limitações documentados.

## Sprint 02 — Combate e animação sincronizados (após Sprint 01)

### CMB-001 — Contrato de execução de ataques
- **Tipo:** SPIKE técnico + proposta · **Estado:** BACKLOG · **Prioridade:** P0 · **Depende:** MOV-003
- **Problema observado anteriormente:** indício de dano online aplicado antes do momento visual do golpe; **reconfirmar no código atual**.
- **Tarefas:** mapear estados atuais, eventos de animação, instante de hit, validação do servidor, cooldowns e projeção no cliente; propor contrato de timeline comum que preserve autoridade.
- **Aceite:** fluxograma curto de evento/tempo, arquivos envolvidos, riscos e casos de teste; sem reescrever o combate nesta história.

### CMB-002 — Alinhar aplicação de hit à janela do golpe
- **Tipo:** história · **Estado:** BLOCKED · **Prioridade:** P0 · **Depende:** CMB-001 e aprovação do contrato
- **Objetivo:** alvos só recebem dano quando o evento autoritativo do ataque permitir, sem depender da confiança na animação local.
- **Aceite:** ataques não causam dano antecipado; servidor determina hit válido; client feedback é responsivo; teste com dois jogadores, latência e casos de interrupção.
- **Não inclui:** parry definitivo, rebalanceamento geral de dano.

### ANI-001 — Pipeline mínimo de animação por classe
- **Tipo:** SPIKE · **Estado:** BACKLOG · **Prioridade:** P1
- **Tarefas:** identificar rig, AnimationTree/Player e assets atuais; avaliar transições idle/walk/dash/attack/hit para Guerreiro, Mago, Arqueiro; propor convenção de nomes/eventos e fluxo de exportação; prototipar isoladamente sem substituir assets em massa.
- **Aceite:** matriz de animações existentes, ausentes e defeituosas; recomendação de pipeline; um protótipo testável quando viável.

### PVP-001 — Prototipar parry e esquiva sob latência
- **Tipo:** SPIKE de design/técnico · **Estado:** BACKLOG · **Prioridade:** P1 · **Depende:** CMB-002
- **Tarefas:** propor 2 ou 3 modelos de janela de defesa; avaliar legibilidade e abuso por latência; fazer teste restrito, não lançar regra final.
- **Aceite:** evidência comparativa e decisão pendente explícita sobre timings, cancelamentos e i-frames.

## Frente de refinamento — Estrutura das habilidades e especializações

> Esta frente pode ser **refinada em paralelo** à Sprint 01, mas não deve alterar controladores de movimento ou código de rede sem coordenação e história `READY`.

### CMB-003 — Mobilidade e compromisso durante habilidades
- **Tipo:** história de design / SPIKE · **Estado:** REFINEMENT · **Prioridade:** P1 · **Relacionado:** CMB-001
- **Direção acordada:** mobilidade e restrições durante ataques/conjurações **dependem da habilidade**, não de uma regra única para todas as classes.
- **A explorar:** preparação, execução e recuperação; quais habilidades exigem imobilidade, quais permitem movimento reduzido e quais admitem movimento normal; se podem mudar orientação; como interrupções, cancelamentos e dash interagem com cada fase.
- **Tarefas de refinamento:** inventariar habilidades atuais de Guerreiro/Mago/Arqueiro; propor classes de mobilidade e um contrato de estados configurável; desenhar matriz de exceções e efeitos sobre PvP, animações e servidor.
- **Aceite do refinamento:** proposta comparativa, riscos e casos de teste; **nenhuma regra numérica nem implementação autorizada** por esta história.

### BUILD-001 — Passivas e modificadores de habilidades
- **Tipo:** história de design / SPIKE · **Estado:** REFINEMENT · **Prioridade:** P1 · **Relacionado:** CMB-003 e sistema de ascensões
- **Hipótese de design em discussão:** permitir escolhas de build que modifiquem habilidades, por exemplo conjurar andando, melhorar velocidade durante conjuração, aumentar dano ou ampliar área. Ascensões **podem** ampliar escolhas, mas o método de desbloqueio não está aprovado.
- **Tarefas de refinamento:** comparar passivas gerais, modificadores por habilidade e modelo híbrido; estudar trade-offs e incompatibilidades; examinar risco de acúmulo de mobilidade + dano + área em PvP; propor limites e formas de reespecialização para decisão futura.
- **Aceite do refinamento:** alternativas, exemplos por classe, dependências e decisões ainda pendentes; **não criar árvore completa nem bônus numéricos**.

## Sprint 03 — Leitura visual do combate (não iniciar junto aos controladores)

### VIS-001 — Silhuetas e animações legíveis
- **Tipo:** SPIKE visual · **Estado:** BACKLOG · **Prioridade:** P1
- **Tarefas:** capturar as três classes na câmera real; comparar identificação de armas, direção, ataques e hit feedback; definir ajustes pequenos antes de trocar modelos.
- **Aceite:** comparativo de cenas e lista priorizada; manter identidade 3D pixelada, sem anime.

### WORLD-001 — Oclusão por árvores
- **Tipo:** SPIKE técnico · **Estado:** BACKLOG · **Prioridade:** P2
- **Tarefas:** confirmar sistema de transparência/recorte existente; reproduzir obstruções; propor correção mínima separada de remodelagem.
- **Aceite:** teste antes/depois sem regressão óbvia de desempenho ou legibilidade.

### UI-001 — Bloqueio de input ao usar interface
- **Tipo:** história · **Estado:** BACKLOG · **Prioridade:** P1
- **Tarefas:** impedir movimento/ataque indevido durante chat e campos com foco conforme as regras vigentes; preservar atalhos intencionais.
- **Aceite:** digitar no chat não dispara ação de combate; volta ao jogo recupera controle corretamente.

## Perguntas abertas — NÃO transformar em implementação automática
1. **RESOLVIDO — dash parado:** avança na orientação atual do personagem, inclusive após ataque que a tenha alterado. Dash durante estados bloqueantes permanece pendente de definição de cancelamentos.
2. Qual a tolerância aceitável de resposta e correção visual sob 80–150 ms de latência simulada?
3. Quais ataques podem girar durante wind-up e quais travam orientação?
4. Parry terá janela por classe/equipamento ou regra básica comum?
5. Quais são as condições concretas para habilitar/desabilitar PvP opcional e impedir abusos nas bordas de zonas?
6. Mobilidade durante cada habilidade: parado, reduzida ou livre? Quais fases permitem cancelamento/dash?
7. Modificadores por habilidade, passivas gerais ou ambos? Quantos podem coexistir e como funcionará a troca de build?
8. O que cada ascensão desbloqueia em especializações, sem forçar vantagens competitivas excessivas?

## Definition of Done de qualquer história
- Comportamento atual verificado; alterações limitadas ao escopo.
- Arquivos modificados explicitados e diferenças relevantes descritas.
- Testes reais com comandos, resultado e limitações.
- Nenhum commit/push sem autorização; nenhuma alteração local preexistente sobrescrita.
- Pendências de design registradas como pendências, não resolvidas por suposição.
