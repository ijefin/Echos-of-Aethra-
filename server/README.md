# Ecos de Aethra — servidor dedicado (protótipo 3D)

> **Hospedagem: PENDENTE DE APROVAÇÃO DO USUÁRIO.** Duas decisões são dele: hospedar código
> de protótipo (`.claude/rules/prototype-code.md` diz que protótipos "não são publicados") e
> subir um container separado na VPS de produção, abrindo UDP 7777. Até agora nada foi
> instalado em servidor nenhum. Tudo foi testado só em 127.0.0.1.

O código fica em `prototypes/pixel3d/net/`. Esta pasta guarda só os arquivos de hospedagem
(Dockerfile, compose, unidade systemd).

## O que é

- **Servidor autoritativo:** Godot 4.7.2 headless com ENet UDP cru (sem RPC). O cliente manda
  só comandos: direção, esquiva e ações com alvo. Posição, dano, XP, nível, poções e recargas
  são calculados no servidor.
- **Colisão do mundo:** vem do mapa gerado (árvores, rochas, serra, casas, rio), exportada para
  `net/data/collision_surface.json`.
  - Superfície: 1897 círculos, 246 caixas e 1 polígono.
  - Gruta (andar −1): 477 obstáculos; o servidor troca de andar pelas escadas e pelo portal.
  - Água bloqueia o andar, mas não o tiro.
  - O mesmo arquivo é usado pela predição do cliente.
- **Monstros:** a IA é a mesma do jogo (`ai/enemy_director.gd`). Roda num World3D headless
  montado com essa colisão: perseguição, telegraph, salto, investida, teia com lento. Isso dá
  42 monstros: os `field_enemies` com o `level` das caçadas (vida, dano e XP escalados por
  `enemy_level`), os lobos e a Garra-Velha.
- **Vocações:** lidas de `data/classes.json`. O servidor valida alcance, arco, recarga, mana e
  dano.

  | Vocação | Ataque | Q | R |
  |---|---|---|---|
  | Mago | bola de fogo, alcance 10,4 m | Eco | Anel de Brasa |
  | Guerreiro | espada 2,0 m em arco de 130° | Investida (para no 1º monstro e na parede) | Redemoinho de 360°, raio 2,6 m |
  | Arqueiro | flecha 24 m/s, alcance 18 m | Salto Evasivo (5 m para trás) | Flecha Perfurante (atravessa) |

  Velocidade, vida, mana, armadura e multiplicadores também vêm de `classes.json`.
- **Luz ("utevo vis lux"):** mana, duração e recarga vêm de `data/core_skills.json`.
  - Os outros jogadores veem a Luz pelo bit `light` no snapshot e pelo evento `light`.
  - Quem chega depois recebe o tempo restante em `entity_info.light_left`.
- **Taxas e predição:**
  - Simulação, snapshots e comandos a 20 Hz. Os comandos vão com redundância 3.
  - Interpolação de 110 ms para as outras entidades.
  - A predição do próprio jogador corrige acima de 0,15 m e salta acima de 2,5 m.
- **Área de interesse e banda:**
  - Entidades entram a 40 m e saem a 48 m, no máximo 48 por snapshot.
  - Prioridade: jogadores, depois monstros, depois projéteis.
  - Snapshot: 61 B + 19 B por entidade. Com 20 entidades dá cerca de 9 KB/s por jogador na
    descida e cerca de 0,6 KB/s na subida.
- **Contas:** nome + senha (SHA-256 iterado 20 000×, sal por conta). A vocação é escolhida
  ao criar a conta; uma vocação já salva não pode ser trocada.
  - A sessão usa um token. Depois de uma queda, o jogador volta pelo token (RESUME) em até
    120 s, no mesmo personagem e na mesma posição.
- **Amigos:** pedir, aceitar e remover, com presença (online/offline e região) em tempo real.
- **Limites:** pacote acima de 512 B derruba o peer. Há rate limit por tipo e placar de abuso.
  5 senhas erradas bloqueiam o IP por 60 s. Chat e nomes são sanitizados.

- **Missões, segredos e recompensas (autoritativos):** `net/server_content.gd` roda a regra
  pura `quests.gd` e o inventário `src/core/inventory.gd` por jogador, no servidor.
  - O cliente só pede `{"act": "interact", "target": "npc:<id>" | "pickup" | "secret:<id>" |
    "nessa" | "chest"}` (tecla E). O servidor confere o andar e a distância na posição dele
    (raio do jogo + 1,2 m de folga, `combat.interact_tolerance_m`). Recusas: `range`, `floor`,
    `target`, `claimed`, `locked`.
  - Abates (só os do servidor, da caçada certa) e passos "chegue a" (posição do servidor, a
    cada 5 ticks) avançam as missões. A Nessa (As Três Brasas) e o baú da gruta também.
  - Recompensas aplicadas uma vez: XP, poções, item da vocação (vestido na hora), bônus
    permanentes. O XP de missão/segredo agora fica no snapshot (antes era sobrescrito).
  - O evento `content` (só para o jogador) leva o resultado e o estado para o cliente mostrar
    (diário J, objetivo, falas, bolsa); o `welcome` leva o mesmo estado.
- **Equipamento (autoritativo):** `{"act": "equip", "item": id}` — o inventário confere bolsa,
  slot e vocação. O servidor calcula o bônus acima do equipamento inicial com a mesma conta do
  cliente: dano (`attack_power` + `spell_power`), armadura (2 % por ponto, teto 80 %), vida e
  mana máximas (com as relíquias). `{"act": "unequip", "slot": s}` devolve à bolsa (recusas
  `slot`, `full`). A bolsa (`content.bag`) e o ouro (`content.gold`) são salvos; saves antigos
  sem bolsa são refeitos pelas recompensas.
- **Ouro e loja (autoritativos, `data/shop.json` + `economy.gd`):** cada abate do servidor soma
  moedas pelo tipo e pelo nível da caçada (evento `kill` leva `gold` e `gold_total`); missões e
  segredos com `reward.gold` também. A Nessa abre a troca (`shop: true` no evento `nessa` fora
  do aceite/entrega). `{"act": "buy", "kind": "hp"|"mana"}` e `{"act": "sell", "item": id}`
  conferem andar e distância da Nessa (raio + folga), ouro e se o item está na bolsa (vestido não
  vende). Recusas: `kind`, `range`, `floor`, `gold`, `item`.
- **Itens no chão e troca entre jogadores (`net/server_trade.gd`):**
  - `{"act": "drop", "item": id}` tira da bolsa e deixa o item um passo à frente do corpo por
    `ground_item_s` (60 s); todos recebem `ground` (`op: add/del`) e o `welcome` traz a lista.
    `{"act": "take", "gid": n}` pega (mesmo andar, `ground_take_m` + folga, bolsa com espaço).
    Recusas: `item`, `trade`, `gone`, `floor`, `range`, `full`.
  - Troca: `trade_ask` (target = eid, perto: `trade_radius_m` + folga) abre para os dois;
    `trade_add`/`trade_remove` (item da bolsa, até 6) desfazem as confirmações; com os dois
    `trade_ok` o servidor confere tudo de novo (itens ainda na bolsa, espaço) e troca no mesmo
    passo. Afastar além de `trade_break_m` (6 m), mudar de andar, morrer, sair ou
    `trade_cancel` fecham para os dois. Eventos `trade` com `op: open/state/done/close`.
- **Investida e salto remotos:** o servidor resolve o deslocamento no tick do pedido; o cliente
  desenha o corpo deslizando de `from` até o destino no tempo da habilidade (ease-out,
  `net/dash_motion.gd`), tanto para o próprio jogador quanto para os outros. O Eco do mago
  continua teleporte.

Parâmetros de rede: `prototypes/pixel3d/net/data/net_config.json`.
Regras de jogo: `prototypes/pixel3d/data/first_adventure.json`, `classes.json` e `core_skills.json`.

## Passo a passo local (Windows, Git Bash)

```bash
G="C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"

# 0) só numa cópia nova do repositório: importar os assets uma vez
"$G" --headless --path . --import

# 1) (só se o mapa mudou) exportar a colisão do mundo para o servidor
"$G" --headless --path . -s res://prototypes/pixel3d/net/tools/export_collision.gd -- --no_save --mute
#    → "EXPORT_COLLISION: OK -> res://prototypes/pixel3d/net/data/collision_surface.json"
#    Faça o commit do JSON: o servidor e a predição do cliente usam o mesmo arquivo.

# 2) servidor (UDP 7777; deixe este terminal aberto)
"$G" --headless --path . -s res://prototypes/pixel3d/net/server_main.gd -- --port=7777
#    → "AETHRA_SERVER_READY 7777" e "IA real dos monstros ligada (42 monstros, enemy_director)"

# 3) dois clientes do jogo (cada um num terminal). Na 1ª vez use --register; --class só vale
#    para personagem novo (mage | warrior | archer)
"$G" --path . res://prototypes/pixel3d/pixel3d_demo.tscn -- --connect=127.0.0.1:7777 --user=Ana  --pass=senha123 --register --class=archer
"$G" --path . res://prototypes/pixel3d/pixel3d_demo.tscn -- --connect=127.0.0.1:7777 --user=Davi --pass=senha123 --register --class=warrior
#    das próximas vezes: sem --register (e sem --class)
```

Sem `--connect`, o jogo roda offline como sempre: nada da rede é criado.

**No jogo (online):**

| Tecla | Ação |
|---|---|
| WASD | andar (predição local, servidor confirma) |
| Clique | ataque da vocação |
| Q / botão direito | Q |
| R | R |
| Espaço | esquiva |
| 1 / 2 | poções |
| 3 | Luz |
| Enter | chat |
| O | painel de amigos |

**Chat:** a aba **Local** vai para quem está a até 30 m e aparece sobre a cabeça. A aba
**Servidor** vai para todos. Grupo e PvP ainda não têm canal próprio e saem como Servidor.

**Painel de amigos (O):**
- **Enter** abre o campo de nome. Digite o nome e aperte **Enter** de novo para pedir amizade.
- **1–9** aceitam os pedidos recebidos.
- **↑ / ↓** escolhem um amigo e **Del** remove o escolhido.
- A bolinha verde indica que o amigo está online; a região dele aparece à direita.

## Testes

```bash
"$G" --headless --path . -s res://tests/unit/net/net_rules_test.gd          # NET_RULES: OK (77)
"$G" --headless --path . -s res://tests/unit/net/collision_export_test.gd   # COLLISION_EXPORT: OK (39)
"$G" --headless --path . -s res://tests/unit/net/server_ai_test.gd          # SERVER_AI: OK (16)
"$G" --headless --path . -s res://tests/unit/net/vocation_rules_test.gd     # VOCATION_RULES: OK (44)
"$G" --headless --path . -s res://tests/unit/net/server_content_test.gd     # SERVER_CONTENT: OK (43)
"$G" --headless --path . -s res://tests/unit/net/dash_motion_test.gd        # DASH_MOTION: OK (9)
"$G" --headless --path . -s res://tests/unit/net/server_economy_test.gd     # SERVER_ECONOMY: OK (58)
bash tools/net_unit_tests.sh          # todos os tests/unit/net/*_test.gd de uma vez
bash tools/net_session_test.sh        # 1 servidor + 7 bots (~6 min)
bash tools/net_trade_test.sh          # só Tara + Teo: loja, troca concluída, chão, troca cancelada: 28 PASS
bash tools/net_game_client_test.sh    # servidor + bot + CLIENTE REAL do jogo (--connect): 34 PASS
bash tools/net_drop_shot.sh           # 2 clientes em janela; item largado pela Ana visto pelo Davi
bash tools/net_two_clients_shot.sh    # 2 clientes em janela; prints em production/qa/evidence/pixel3d-net-client-*.png
bash prototypes/pixel3d/tools/run_world_tests.sh test_quests test_world_reach test_vocations test_mage_combat test_floors test_day_night test_core_light test_enemy_ai
```

**Bot Quinn (arqueira) no `net_session_test.sh`:** sobe ao nível 2, anda (BFS na colisão, longe
das bocas de escada) até a Sálvia, faz a missão 1 inteira online (5 sapos do Charco abatidos
pelo servidor, entrega, +25 XP e +3 poções no snapshot), revela o segredo da Ilhota dos Juncos
(+15 de mana; a 2ª vez é recusada, inclusive depois de cair e voltar por RESUME), faz a missão
2 (Rook, Estrada Velha, 4 aranhas, insígnia) e recebe o Arco de Teixo. **Equipar muda o dano
autoritativo** é provado com a arma ganha na própria missão (caminho real, sem conta semeada):
os golpes no monstro saem com o dano do Arco de Teixo e, depois de `equip hunting_bow`, com o
do arco inicial (14 > 11 na execução de referência); espada de guerreiro é recusada. Depois do
reinício do servidor, `quester2` confere missão, segredo e arma no save.

## Configuração

**Porta:** UDP **7777** (só UDP; não há TCP). Em casa, para jogar pela internet, o host libera
UDP 7777 no roteador.

| Variável | Padrão | O quê |
|---|---|---|
| `AETHRA_PORT` | 7777 | porta UDP |
| `AETHRA_MAX_PLAYERS` | 16 | conexões simultâneas |
| `AETHRA_DATA_DIR` | `user://aethra-server` | onde fica `accounts.json` (no Docker: `/data`) |
| `AETHRA_LOG_LEVEL` | info | debug, info, warn, error |
| `AETHRA_ADMIN_TOKEN` | vazio | habilita `/admin <token> save\|who\|kick <nome>` no chat |
| `AETHRA_RECONNECT_GRACE_S` | 120 | validade do token depois de uma queda |
| `AETHRA_AUTOSAVE_S` | 30 | intervalo de gravação |
| `AETHRA_PASSWORD_ITERATIONS` | 20000 | custo do hash para contas novas |

Os argumentos `--port=`, `--data_dir=`, `--log_level=` e `--quit_after=s` sobrescrevem as
variáveis. Para desligar a IA real (só para depurar), use `"server_ai": false` no
`net_config.json`.

**`.env` (não versionar).** Crie `server/.env`:

```
AETHRA_PORT=7777
AETHRA_MAX_PLAYERS=16
AETHRA_LOG_LEVEL=info
AETHRA_DATA_DIR=/data
AETHRA_HOST_DATA=/var/lib/aethra
AETHRA_ADMIN_TOKEN=            # gere com: openssl rand -hex 24
AETHRA_RECONNECT_GRACE_S=120
AETHRA_AUTOSAVE_S=30
```

## Persistência, logs e backup

- **Persistência:** `accounts.json` em `AETHRA_DATA_DIR`, gravado de forma atômica (`.tmp`,
  `.bak` e rename). Guarda contas, amigos e o personagem: vocação, nível, XP, posição, vida,
  mana, poções e o conteúdo (`progress.content`: missões, segredos, itens de missão, bônus
  permanentes, equipamento ganho e vestido — mesmo formato do save offline).
  - Grava a cada 30 s, no logout ou queda e ao encerrar.
  - No pior caso (kill brusco) perdem-se até 30 s.
  - No modo online, o cliente não grava o save local.
- **Logs:** saem no stdout/stderr (`docker compose logs -f aethra` ou
  `journalctl -u aethra-server -f`).
  - Linhas esperadas: `AETHRA_SERVER_READY`, `IA real dos monstros ligada`, `X entrou` e
    `X saiu`.
  - Anomalias de rede têm limite de frequência.
  - Uma linha de estatística por minuto mostra pacotes, bytes e kicks.
- **Backup:** copie `accounts.json` e `accounts.json.bak`. Exemplo de cron diário:
  `cp /var/lib/aethra/accounts.json /root/backups/aethra-$(date +%F).json`. O arquivo tem
  hashes de senha: trate como segredo.

## Deploy (PENDENTE: aprovação do usuário)

O que se sabe da VPS do Lumbra (levantado só por leitura):
- Debian 13, 2 vCPU, 8 GB, Docker 29 e Compose v5.
- Caddy em 80/443.
- UDP 7777 livre.
- **Falta confirmar** se o painel do provedor tem firewall que bloqueia UDP.

O jogo seria um projeto compose **separado**, sem tocar na stack do Lumbra.

### Opção A — Docker (recomendada)

```
cd /opt/aethra/src/server              # repositório clonado em /opt/aethra/src
#   crie o .env conforme acima
sudo mkdir -p /var/lib/aethra && sudo chown 10001:10001 /var/lib/aethra
docker compose up -d --build
docker compose logs -f aethra          # "AETHRA_SERVER_READY 7777"
```

- A imagem leva só o necessário:
  - `project.godot`, `first_adventure_state.gd`;
  - `data/first_adventure.json`, `data/classes.json` e `data/core_skills.json`;
  - as pastas `ai/` e `net/` (com `collision_surface.json`);
  - o conteúdo: `quests.gd`, `data/quests.json`, `data/world_regions.json`,
    `assets/data/items.json`, `src/core/inventory.gd` e `src/core/json_data.gd`.
- Antes de publicar, preencha `GODOT_SHA512` no Dockerfile com o valor da release 4.7.2.
- Firewall: libere só `7777/udp` (ufw/nftables e painel do provedor).

### Opção B — systemd (sem Docker)

```
sudo useradd --system --home /var/lib/aethra aethra
sudo mkdir -p /opt/aethra/app /var/lib/aethra /etc/aethra && sudo chown aethra: /var/lib/aethra
# binário Godot_v4.7.2-stable_linux.x86_64 → /opt/aethra/godot (chmod +x)
# copie para /opt/aethra/app: project.godot, prototypes/pixel3d/first_adventure_state.gd,
#   prototypes/pixel3d/data/{first_adventure,classes,core_skills}.json,
#   prototypes/pixel3d/ai/ e prototypes/pixel3d/net/, prototypes/pixel3d/quests.gd,
#   prototypes/pixel3d/data/{quests,world_regions}.json, assets/data/items.json,
#   src/core/{inventory,json_data}.gd
# /etc/aethra/aethra.env com as variáveis (AETHRA_DATA_DIR=/var/lib/aethra), chmod 600
sudo cp server/aethra-server.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now aethra-server
```

**Atualizar:** `git pull` e depois `docker compose up -d --build`. Quem está conectado cai.
Depois de um reinício, a volta é com senha, porque o token vive em memória.

**Amigos pela internet:**
`Ecos-de-Aethra.exe res://prototypes/pixel3d/pixel3d_demo.tscn -- --connect=HOST:7777 --user=Nome --pass=senha [--register --class=archer]`.

## O que ainda falta

- **Itens no chão:** somem só por tempo (não há limite por área) e todos os jogadores recebem os
  eventos, sem área de interesse; para muitos jogadores, filtrar por distância.
- **Troca:** só itens de equipamento (ouro, poções e itens de missão ainda não entram na troca).
- **Q de guerreiro e arqueiro:** o deslizamento é só visual (o servidor resolve tudo no tick do
  pedido, inclusive o dano). Um dash simulado tick a tick no servidor (com predição) daria
  colisão com monstros no meio do caminho mais fiel.
- **Monstros da missão compartilhados:** cada abate conta só para quem deu o golpe final; não
  há grupo dividindo progresso.
- **Chat:** abas Grupo e PvP sem canal próprio; não há painel para mensagem privada.
- **Hash de senha:** SHA-256 iterado, porque o Godot não expõe PBKDF2/scrypt. Para
  produção, trocar por argon2/scrypt (GDExtension) ou por um serviço de contas.
