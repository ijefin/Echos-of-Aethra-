# Especializações sob demanda

Qualquer agente segue `AGENTS.md`. Use as lentes abaixo para a tarefa relevante;
não há exigência de criar subagentes, equipes, documentos ou aprovações em cadeia.

| Domínio | O que conferir |
|---|---|
| Gameplay/GDScript | estados, input, tempos, configuração existente, bordas e testes do comportamento |
| Rede/segurança | autoridade, validação de comandos, taxas, persistência, reconciliação e dois clientes |
| Mundo | coordenadas XZ/andares, colisão, regiões, IDs, independência do módulo e custo de carga |
| Arte/shaders | silhueta, legibilidade, grade de pixels, luz/sombra, custo gráfico e captura inspecionada |
| Interface | fluxo jogável, feedback visual, texto legível, evitar texto tutorial genérico; NPCs contam história |
| QA/performance | reprodução, regressão pertinente, evidência observada; distinguir parse, headless e gráfico |

Para uma questão especializada que esta tabela não resolve, os perfis completos
originais estão em `tools/studio/.claude/agents/`: `godot-gdscript-specialist.md`,
`network-programmer.md`, `level-designer.md`, `godot-shader-specialist.md`,
`technical-artist.md`, `ui-programmer.md`, `qa-tester.md`, `performance-analyst.md`.
Leia apenas a seção técnica necessária. Os demais perfis também foram preservados.
Protocolos de hierarquia e aprovação desse snapshot não são políticas atuais.

Brief para delegação: pergunta independente, fatos já verificados, arquivos,
restrições, critério de aceite e retorno com novas evidências e pendências.
Não peça ao agente para redescobrir todo o projeto nem reproduzir documentos.
