# COMECE POR AQUI — Echos of Aethra

> **Arquivo de entrada para qualquer pessoa ou agente que trabalhe neste repositório.**
> Este documento é um mapa de leitura, não uma ordem para carregar todo o repositório.

## 1. O que estamos construindo

**Echos of Aethra** é um MMORPG de ação **exclusivamente online**, com servidor autoritativo, mundo aberto contínuo, combate que equilibra habilidade, build e equipamento, e PvP com regiões seguras, opcionais e livres. O jogo atual usa visual **3D low-poly pixelado**; preserve o protótipo 3D e sua câmera como ponto de partida.

**Teste local não é outro jogo offline:** sempre que possível, inicie cliente e servidor localmente usando a arquitetura online real. Preserve predição, reconciliação e interpolação existentes.

## 2. Fonte de verdade — qual arquivo consultar?

| Necessidade | Fonte | Leitura recomendada |
|---|---|---|
| Visão e decisões aprovadas do jogo | `ECHOS_OF_AETHRA_GAME_DESIGN_MASTER.md` | Somente a seção relevante |
| O que implementar e como validar | `ECHOS_BACKLOG.md` | Somente a história solicitada e suas dependências |
| Como executar histórias com segurança | `PROTOCOLO_EXECUCAO.md` | Antes de assumir uma história |
| Instruções técnicas do ambiente/agentes | `AGENTS.md`, `CLAUDE.md`, outros arquivos já existentes | Respeitar os vigentes; não sobrescrever |
| Comportamento real e estrutura ativa | Código + testes do repositório | Sempre prevalecem para descrever **o que existe hoje** |

Se uma referência estiver ausente no checkout, **não invente seu conteúdo** nem recrie uma cópia legada: registre a lacuna e use as fontes disponíveis. Documentação descreve a intenção; código e testes revelam o estado atual. Divergências exigem registro, não decisão arbitrária.

## 3. Prioridade de execução

1. `EOA-001`: reproduzir servidor + dois clientes locais.
2. `EOA-002`: registrar baseline de comportamento atual.
3. `MOV-001`: orientação e locomoção responsiva.
4. `MOV-002`: dash direcional autoritativo.
5. `MOV-003`: regressão de movimento entre classes e multiplayer.
6. `CMB-001`: investigar contrato temporal de ataques, antes de mudar dano.

Os demais itens permanecem no `ECHOS_BACKLOG.md` para refinamento e execução quando estiverem elegíveis. **A prioridade não autoriza executar itens sucessivos automaticamente.**

## 4. Decisões de gameplay relevantes já aprovadas

- WASD movimenta; andando, personagem olha para o movimento; parado, mantém a orientação atual.
- Cursor direciona ações ofensivas, mas **não** faz o personagem girar passivamente.
- Dash com input usa a direção do deslocamento; **dash parado usa a orientação atual do personagem**, inclusive quando um ataque anterior a alterou.
- Não decidir por conta própria se o dash cancela ataques ou pode ser usado em estados bloqueantes.
- Mobilidade durante habilidades **depende da habilidade**. A ideia de passivas/modificadores para conjurar andando, mudar velocidade, dano ou área está em **refinamento**, sem números, combinações nem desbloqueios aprovados.

## 5. Como trabalhar sem desperdiçar contexto

1. Identifique o ID solicitado e consulte **apenas** sua história, dependências diretas, regras de design pertinentes e arquivos de código envolvidos.
2. Localize scripts com busca por nomes/símbolos; não leia recursivamente todos os documentos, agentes ou arquivos gerados.
3. Confirme `git status` e respeite alterações locais, inclusive os artefatos `.import` existentes; nunca faça limpeza ou reversão automática.
4. Não repita auditorias gerais do projeto quando for suficiente investigar um subsistema.
5. Agentes são **intercambiáveis**: nenhuma história depende de um nome ou produto de IA. Coordene trabalho por ID e arquivos alterados.
6. Não faça commit ou push de alterações de implementação sem solicitação explícita.

## 6. Status e responsabilidades

Estados de história: `BACKLOG` (ideia), `REFINEMENT` (precisa de definição), `READY` (escopo/aceite prontos), `IN_PROGRESS` (em andamento), `REVIEW` (aguardando validação), `DONE` (validada), `BLOCKED` (impedimento).

Antes de alterar arquivos, verifique se outro executor já trabalha no mesmo subsistema. Use branch/worktree independente quando necessário e não integre mudanças concorrentes sem revisão. Teste realizado e teste pendente devem ser relatados separadamente.

## 7. Primeira solicitação recomendada

> Consulte `COMECE_POR_AQUI.md`, o protocolo de execução e a história `EOA-001` no backlog. Execute **somente `EOA-001`**, respeitando as instruções vigentes do repositório. Verifique estado do Git, preserve trabalho existente e valide a execução multiplayer local. Registre evidências, arquivos envolvidos e bloqueios. Não faça commit/push nem avance automaticamente para outra história.

## 8. Mantendo documentação viva

- **Design aprovado**: atualizar o documento-mestre, sem misturar proposta com decisão.
- **Trabalho definido ou executado**: atualizar status/evidências do backlog.
- **Mudança do processo**: atualizar o protocolo.
- **Nova pessoa ou agente**: apontar primeiro para **este arquivo**; nunca copiar todo o contexto para múltiplas instruções.

**Nota:** este pacote contém documentação; não executa nem modifica o jogo. Confirmar integração com instruções já existentes no checkout antes de commitar.
