# Echos of Aethra

Jogo oficial: **3D com visual de pixel art**, Godot 4.7.2, GDScript, Forward+.
Entrada: `src/game/pixel3d_demo.tscn`. Trabalhe no jogo atual.

## Contexto por tarefa

- Use a tabela em `docs/context/index.md` para localizar apenas o sistema afetado.
- Execução e verificação: `docs/context/testing.md`.
- Estado geral e limites conhecidos: `docs/context/current-state.md`, quando necessário.
- Especializações: consulte somente o perfil pertinente em `docs/context/agents.md`.
- Retomada: leia a tarefa indicada em `production/tasks.md`; o checkpoint local
  `production/session-state/active.md` serve apenas para continuar uma sessão interrompida.
- `legacy/`, `docs/history/` e `tools/studio/` são arquivo histórico/opcional.
  Não entram na contextualização habitual. Não investigue o 2D para trabalhar no 3D.
- Se uma memória ou conversa antiga apontar outros caminhos, use o mapa atual;
  não retome handoffs históricos apenas por hábito.

## Trabalho e conclusão

1. Entenda o resultado pedido, localize código/dados/testes e defina como verificar.
2. Para trabalho com etapas ou troca de agente, use uma entrada curta em
   `production/tasks.md`: objetivo, etapas, aceite, resultado e pendências.
   Correções pequenas podem ser descritas na própria conversa.
3. Execute dentro do escopo autorizado. Não peça nova aprovação para cada arquivo
   ou decisão técnica rotineira. Consulte o usuário se o escopo mudar materialmente.
4. Marque uma etapa concluída somente com evidência: comando e resultado, inspeção
   visual ou artefato verificável. Use `bloqueado` ou `pendente` quando couber.
5. Ao terminar, informe o que mudou, como foi verificado e o que falta.
   Atualize apenas os documentos afetados; não gere relatórios de estúdio por padrão.

## Arquitetura e qualidade

- `src/game/`: jogo 3D e rede. `src/core/`: lógica compartilhada.
- `src/world/`: módulo reutilizável de mundo; não deve depender de `src/game/`
  ou `legacy/`. Preserve o ADR-0001 e seus testes de independência.
- `src/items/`: catálogo e pipeline de itens. `assets/data/items.json` é compartilhado
  pelo cliente e servidor; confira consumidores antes de mudar seu formato.
- Servidor autoritativo para posição, combate, inventário, trocas e persistência online.
- Preserve UIDs ao mover recursos. Não altere saves, IDs ou protocolo como efeito
  colateral de outra tarefa.
- Mantenha tuning em dados quando o sistema já usa configuração. Evite reescritas
  e novas abstrações sem necessidade demonstrada.
- O código descreve o implementado; decisões aprovadas descrevem a intenção.
  Registre divergências relevantes em vez de escolher silenciosamente uma versão.
- Direção visual: `design/art/pixel3d-style-guide.md`. Mudanças visuais exigem
  execução gráfica e inspeção da captura. Parse/headless não comprovam aparência.
- Consulte referência Godot do domínio quando uma API ou comportamento for incerto.
  Não carregue toda a documentação de engine para uma alteração localizada.

## Busca e delegação

- Comece por caminhos e símbolos: `rg --files <diretório>` e `rg -n <símbolo> <diretório>`.
  Leia por seção; aprofunde quando dependências, contradições ou riscos exigirem.
- `.ignore` filtra descoberta rotineira, não autorização de acesso ou versionamento.
  Consulte arquivos filtrados explicitamente quando a tarefa precisar deles.
- Não releia documentação já verificada sem motivo. Não imponha limites de leitura
  que prejudiquem a análise.
- Use subagentes somente com ganho técnico claro. Envie objetivo, fatos verificados,
  arquivos, limites e resultado esperado; evite herdar histórico irrelevante.
  Peça conclusões e evidências novas, sem repetir toda a contextualização.
- Perfis e workflows arquivados do estúdio são referências opcionais; seus protocolos
  históricos não substituem estas instruções nem a autorização atual do usuário.

## Limites

Preserve alterações locais alheias à tarefa. Não faça commit, push, publicação,
deploy ou mudanças de hospedagem sem autorização explícita para essas ações.
Responda em português, com foco no progresso verificável do jogo.

## Fonte de verdade — Echos of Aethra

O documento `ECHOS_OF_AETHRA_GAME_DESIGN_MASTER.md`,
localizado na raiz, é a referência principal para decisões
de Game Design.

Consulte somente as seções relevantes para a tarefa atual.

Respeite os estados:
- [APROVADO]: decisão definida.
- [PROPOSTO]: ideia ainda não aprovada.
- [A VALIDAR]: depende de análise ou testes.

Não carregue recursivamente toda a documentação para
se contextualizar.

Não restaure agentes ou configurações removidos
durante a otimização do repositório.