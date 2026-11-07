# Echos of Aethra — Protocolo de execução de histórias

Este protocolo é independente da ferramenta ou agente escolhido. Identifique trabalho por ID da história, não pelo nome da IA.

Este documento **não substitui** `AGENTS.md` ou `CLAUDE.md` existentes. Eles devem apontar apenas para os arquivos necessários.

## Contexto mínimo
1. Leia o `COMECE_POR_AQUI.md` e as instruções vigentes aplicáveis ao ambiente (`AGENTS.md`, `CLAUDE.md` ou equivalentes).
2. Leia somente a história solicitada em `ECHOS_BACKLOG.md` e os trechos relevantes de `ECHOS_OF_AETHRA_GAME_DESIGN_MASTER.md`.
3. Inspecione o Git e pesquise os scripts do subsistema por caminho/símbolo. Não faça nova auditoria global e não carregue recursivamente docs/agentes.
4. Se um arquivo citado não existir, localize o equivalente atual em vez de recriar um legado.
5. Preserve o trabalho recente de limpeza, sem restaurar agentes/arquivos removidos.

## Prompt neutro para iniciar

> Execute a história **EOA-001** do `ECHOS_BACKLOG.md`.
> Siga `COMECE_POR_AQUI.md` e as regras vigentes de instrução do repositório e apenas as seções pertinentes do documento-mestre.
> O jogo é exclusivamente online, com servidor autoritativo; teste local precisa preservar a lógica online.
> Trabalhe somente no escopo e nos critérios de aceite dessa história. Não faça auditoria integral do repositório, não convoque subagentes sem ganho real, não restaure componentes removidos e não faça commit/push.
> Antes de alterar arquivos, verifique o estado do Git e preserve modificações locais preexistentes.
> Execute testes viáveis e informe o que foi de fato testado, evidências, arquivos alterados e impedimentos.
> Ao concluir, proponha a atualização do status da tarefa; não inicie automaticamente a próxima.

## Controle de trabalho
- Se for necessário decidir uma regra marcada `[A VALIDAR]`, apresente alternativas e impacto antes de consolidar a mecânica.
- Se o código mostrar que a história já está implementada corretamente, demonstre isso com evidências; não altere por alterar.
- Uma história por executor para itens com arquivos compartilhados.
- Depois de `EOA-001` e `EOA-002`, executar `MOV-001`, `MOV-002` e `MOV-003`, nessa ordem; só então abordar `CMB-001`.

## Trecho opcional a INSERIR (sem sobrescrever) nas instruções vigentes

```md
## Execução das histórias de desenvolvimento
- `COMECE_POR_AQUI.md`: ponto de entrada e mapa seletivo de fontes.
- `ECHOS_OF_AETHRA_GAME_DESIGN_MASTER.md`: regras de design; leia apenas as seções relevantes.
- `ECHOS_BACKLOG.md`: épicos/histórias, dependências, status e critérios de aceite; leia somente o item solicitado.
- `PROTOCOLO_EXECUCAO.md`: protocolo de execução; consulte quando iniciando uma história.
- Não executar histórias bloqueadas, presumir decisões em aberto, nem repetir uma auditoria integral sem justificativa.
```
