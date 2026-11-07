# Game Brief: Ecos de Aethra

**One-sentence pitch:** Naufrague em Aethra, uma ilha mágica e viva, seja escolhido por uma força divina que lhe concede uma classe, e desperte santuários antigos que dão novos poderes e armaduras, enfrentando o que acordou junto com eles.

## Core loop
- **Explorar** a ilha: floresta, lagos, ruínas e a fauna viva
- **Combater** criaturas e guardiões com as skills da classe
- **Evoluir**: ganhar XP, níveis e armaduras que mudam os atributos
- **Despertar um santuário**: ganhar um poder novo, um fragmento da história e acesso a uma região nova, e recomeçar o ciclo

## Player goal & fail state — what "working" looks like
- **Objetivo:** despertar os santuários e descobrir por que Aethra chama heróis. A sessão está completa quando um santuário é despertado ou um guardião é vencido.
- **Falha:** o HP chega a zero e o jogador renasce na última **fogueira** acesa. As fogueiras funcionam como checkpoints e perde-se parte do XP do nível.

## MVP — what must exist to be the game
1. **Praia do naufrágio e floresta da clareira** montadas no editor da Godot, com lago, fonte e fogueiras
2. **O Chamado:** o santuário inicial onde a força divina concede a primeira classe (Mago de Fogo)
3. **Combate do Mago de Fogo** com HUD de skills: 4 skills, Ignição e o game feel de `design/quick-specs/class-combat-fire-mage-mvp-2026-10-30.md`
4. **Criaturas da ilha:** 2 tipos com IA simples e 1 guardião de santuário (chefe)
5. **Progressão:** XP e níveis de 1 a 10 que liberam skills e o uso de armaduras melhores
6. **Armaduras:** 3 conjuntos, como modificadores do esquema de atributos modular
7. **Segundo santuário:** concede um poder novo e revela um fragmento da história

## Out of scope — not building this
- **PvP e servidor dedicado de MMO**: já existe co-op online para testes (listen server ENet, host autoritativo, 2026-10-30, a pedido do usuário); PvP, contas, persistência e servidor dedicado continuam fora do MVP
- Paladino e Arqueiro jogáveis (ficam só os perfis em dados); o Guerreiro tanque já é jogável para o teste online
- Crafting, comércio e economia
- Editor de mapas próprio (usamos o da Godot)
- Missões secundárias, diálogos ramificados e áudio final

## Build order
1. Combate do Mago na Godot contra 1 inimigo (o núcleo da diversão e o maior risco)
2. HUD de skills
3. Mapa no editor: água, fonte e fogueiras (fogueira = checkpoint)
4. Progressão: XP, níveis e armaduras
5. Santuário 2 e o guardião
6. Abertura: o naufrágio e O Chamado
7. Arte final de IA no lugar dos placeholders

---
**Who it's for / what they feel:** Jogadores de RPG de ação que amam explorar; deslumbramento com uma ilha encantada, mistério e a sensação de se tornar digno de um poder divino.

**Art & audio direction:** Pixel art detalhada em vista 3/4 top-down, personagens de 48 px em 8 direções com animações por frames (gerados em IA de pixel art), floresta viva com luz quente e manchada, magia que brilha e ilumina o cenário; trilha mística orquestral leve e ambiente natural rico. *(2026-10-31: a troca para HD com rig foi testada e descartada.)*

**Reference game:** Secret of Mana: a exploração de um mundo encantado com combate de ação e magias. Ficam de fora o multiplayer local e o menu em anel.
