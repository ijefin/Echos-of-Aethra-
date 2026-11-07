# Tarefas do jogo

Registre aqui trabalho com etapas ou troca de agente. Mantenha poucas tarefas
ativas. Não crie um documento por ajuste. Estado: `pendente`, `em andamento`,
`bloqueado`, `concluído`. Uma etapa só recebe `[x]` com evidência registrada.

## CTX-001 — adotar o 3D e organizar o contexto

Estado: concluído · autorização: usuário, 2026-11-06.
Objetivo: trabalhar no jogo 3D com qualquer agente, sem redescobrir o legado ou
carregar o framework de estúdio em cada tarefa.

- [x] Definir orientação comum, mapa seletivo e contrato leve de tarefas.
- [x] Promover o 3D para `src/game/` e isolar 2D/experimentos sem apagar arquivos.
- [x] Arquivar o framework e remover seus carregamentos automáticos do projeto.
- [x] Validar referências, independência dos módulos e suítes existentes.
- [x] Executar o jogo 3D e inspecionar captura após a migração.

Aceite: cena padrão 3D; nenhum caminho antigo no código ativo; testes relacionados
aprovados; captura inspecionada; alterações locais anteriores preservadas.
Evidência/resultados (2026-11-06):
- Importação Godot concluída; `python tools/check_structure.py`: 249 arquivos, zero erros.
- `tools/test.ps1 -Suite unit`: 16 scripts aprovados.
- `tools/test.ps1 -Suite offline`: 11 scripts aprovados.
- `tools/test.ps1 -Suite world`: 6 scripts aprovados (5 também pertencem a unit).
- Integração `tools/net_session_test.ps1` executada pelo runner: 38 PASS, 0 FAIL,
  3/3 bots concluíram, zero erros de script; inclui reconexão e persistência.
- `tests/unit/items/icon_baker_test.gd` gráfico: OK.
- Build Windows em `.scratch/context-reorg/windows/`: exportação concluída;
  jogo de fonte e executável exportado abertos, capturas inspecionadas.
  Evidência preservada: `production/qa/evidence/reorg-3d-windows.png`.
- As 520 alterações locais anteriores foram conferidas por hash e preservadas.
- Runner corrigido durante validação: captura de ExitCode no Windows e distinção
  entre falha e resumo com `0 FAIL`; suítes revalidadas separadamente.

Pendências: nenhuma desta reorganização. Docker/VPS não foram executados;
sem commit, push ou deploy. Integração do cenário procedural com o módulo de
regiões é desenvolvimento futuro, fora do escopo desta tarefa.

## Formato para a próxima tarefa

Copie somente quando necessário:

```text
ID — resultado esperado
Estado:
Objetivo/escopo:
Etapas: [ ] implementação; [ ] verificação pertinente
Aceite: comportamento observável que demonstra conclusão
Resultado/evidência: comando + resultado ou captura inspecionada
Pendências/bloqueios:
```
