# Baseline multiplayer local

Referência da história `EOA-002`, executada em 2026-11-07 no Linux com Godot
4.7.2. Este documento registra o comportamento anterior às mudanças de movimento;
não define tuning novo.

## Como reproduzir

```bash
godot --headless --path . -s res://tests/unit/net/net_rules_test.gd
godot --headless --path . -s res://tests/unit/net/collision_export_test.gd
godot --headless --path . -s res://tests/unit/net/vocation_rules_test.gd
godot --headless --path . -s res://tests/unit/net/dash_motion_test.gd
GODOT=godot bash tools/net_game_client_test.sh 17790
```

Os testes usam servidor e cliente online reais onde indicado. As regras puras de
movimento são compartilhadas pela predição do cliente e pela autoridade do servidor.

## Checklist observado

| Comportamento | Estado | Evidência |
|---|---|---|
| Cliente abre exclusivamente conectado | PASS | cliente real entrou com `--connect`; nenhum monstro local foi criado |
| WASD em um eixo | PASS | tecla D moveu 4,06 m em aproximadamente 1 s; posição visual terminou com erro de 0,000 m contra o servidor |
| Diagonal | PASS | entrada diagonal normalizada: 4,20 m, igual ao eixo, sem ganho de velocidade |
| Inversão de direção | PASS | inversão respondeu no tick seguinte e retornou ao ponto inicial no teste simétrico |
| Parada | PASS | entrada zero manteve posição e última orientação |
| Dash/esquiva com input | PASS | direção do dash igual à direção do deslocamento |
| Dash/esquiva parado | PASS | usou a última orientação conservada |
| Apresentação e reconciliação do dash | PASS | 18 quadros para 0,3 s, movimento monotônico e término exato no destino autoritativo |
| Colisão ao andar | PASS | jogador não atravessou tronco, rocha, água, serra ou limite do mapa |
| Colisão durante esquiva | PASS | esquiva não atravessou tronco no mapa exportado |
| Ataque do Mago | PASS | bola de fogo/alcance, Anel de Brasa e Eco validados; cliente real abateu monstro pelo servidor |
| Ataque do Guerreiro | PASS | espada, arco de 130°, Investida e Redemoinho validados pelo servidor |
| Ataque do Arqueiro | PASS | flecha, Salto Evasivo e Flecha Perfurante validados pelo servidor |
| Guerreiro e Arqueiro visíveis online | PASS | capturas da `EOA-001`: Ana arqueira e Davi guerreiro renderizados mutuamente |
| Sensação subjetiva sob latência real | NOT TESTED | exige sessão humana e latência simulada; não faz parte deste smoke local |

## Resumo das execuções

- `NET_RULES`: 82 PASS, 0 falhas.
- `COLLISION_EXPORT`: 39 PASS, 0 falhas.
- `VOCATION_RULES`: 44 PASS, 0 falhas.
- `DASH_MOTION`: 9 PASS, 0 falhas.
- `NET_GAME_CLIENT_TEST`: 39 PASS, 0 FAIL, 2/2 processos concluídos,
  zero erros de script.

## Divergências e mensagens preexistentes

- `net_rules_test.gd` provoca de propósito erros de decodificação de payload e JSON
  inválidos para comprovar fallback; o processo concluiu com código 0.
- Alguns testes puros encerram com avisos de objetos/recursos ainda em uso; código 0,
  sem falha funcional observada neste baseline.
- A suíte ampla da `EOA-001` mantém quatro falhas no roteiro de ofertas de
  moedas/poções. Elas pertencem ao sistema de troca e não foram tratadas aqui.

Nenhuma regra de gameplay ou valor de tuning foi alterado pela `EOA-002`.
