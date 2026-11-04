# Ecos de Aethra — servidor dedicado (protótipo 3D)

> **Situação da hospedagem: PENDENTE.** Falta o usuário aprovar o uso da VPS e a abertura
> da porta UDP 7777. Nada foi instalado nem alterado em servidor nenhum. O servidor só foi
> testado em 127.0.0.1.
>
> **Aviso de regra do projeto:** `.claude/rules/prototype-code.md` diz que protótipos "não
> são publicados". Hospedar este servidor para jogar com amigos é uma exceção que só o
> usuário pode decidir. Todo o código fica em `prototypes/pixel3d/net/`. Esta pasta guarda
> apenas os arquivos de hospedagem.

## O que é

- Servidor autoritativo **Godot 4.7.2 headless** com **ENet UDP** cru (sem RPC).
- O cliente envia só **comandos** (direção, esquiva, ações com alvo). Posição, dano, XP e
  itens são calculados apenas no servidor.
- Taxas: simulação a **20 Hz**, snapshots a **20 Hz**, comandos a **20 Hz** com redundância 3.
- Cliente: interpolação de **110 ms** para as outras entidades; predição do próprio jogador
  com reconciliação (corrige acima de 0,15 m, salta acima de 2,5 m).
- Área de interesse: entidades entram a **40 m** e saem a **48 m**, no máximo 48 por
  snapshot. Prioridade: jogadores, depois monstros, depois projéteis.
- Tamanho do snapshot: 61 B + 19 B por entidade. Com 20 entidades dá cerca de
  **9 KB/s por jogador de descida** e cerca de 0,6 KB/s de subida (sem contar o overhead do
  ENet). Para 16 jogadores, a saída total fica em torno de 150 KB/s.
- Contas: nome + senha (SHA-256 iterado 20 000×, sal por conta). A sessão usa um token;
  depois de uma queda, o jogador volta pelo token (RESUME) em até 120 s, no mesmo personagem
  e na mesma posição.
- Persistência: `accounts.json` atômico (`.tmp`, `.bak` e rename) em `AETHRA_DATA_DIR`.
  Salva a cada 30 s, no logout/queda e ao encerrar.
- Amigos: pedir, aceitar, recusar e remover, com presença (online/offline e região)
  avisada em tempo real.
- Limites: pacote recebido com mais de 512 B derruba o peer; rate limit por peer e por tipo;
  placar de abuso; 5 senhas erradas bloqueiam o IP por 60 s; chat e nomes sanitizados.

Parâmetros de rede: `prototypes/pixel3d/net/data/net_config.json`.
Regras de jogo: `prototypes/pixel3d/data/first_adventure.json`.

## Configuração (variáveis de ambiente)

| Variável | Padrão | O quê |
|---|---|---|
| `AETHRA_PORT` | 7777 | porta UDP |
| `AETHRA_MAX_PLAYERS` | 16 | conexões simultâneas |
| `AETHRA_DATA_DIR` | `user://aethra-server` | onde fica `accounts.json` (no Docker: `/data`) |
| `AETHRA_LOG_LEVEL` | info | debug, info, warn, error |
| `AETHRA_ADMIN_TOKEN` | vazio | habilita `/admin <token> save\|who\|kick <nome>` no chat |
| `AETHRA_RECONNECT_GRACE_S` | 120 | validade do token depois de uma queda |
| `AETHRA_AUTOSAVE_S` | 30 | intervalo de gravação |
| `AETHRA_PASSWORD_ITERATIONS` | 20000 | custo do hash de senha para contas novas |

**`.env` (não versionar).** O arquivo `server/.env.example` foi bloqueado pela regra de
permissão do projeto. Crie `server/.env` com:

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

## Rodar e testar localmente (Windows)

```
godot --headless --path . -s res://prototypes/pixel3d/net/server_main.gd -- --port=7777
godot --headless --path . -s res://tests/unit/net/net_rules_test.gd     # regras puras
bash tools/net_session_test.sh                                          # 1 servidor + 2 clientes + reinício
```

`tools/net_session_test.ps1` faz o mesmo roteiro pelo PowerShell.

## Deploy (PENDENTE: aprovação do usuário para usar a VPS e abrir UDP 7777)

O que se sabe da VPS que hoje roda o site do Lumbra:

- Debian 13, 2 vCPU, 8 GB de RAM, Docker 29 e Compose v5.
- Sites atuais em 80 e 443 (Caddy).
- UDP 7777 livre. A política INPUT do host está em ACCEPT.
- **Falta confirmar** se o painel do provedor tem firewall próprio que bloqueia UDP.

O servidor do jogo é um **projeto compose separado**. Ele não toca na stack do Lumbra.

### Opção A — Docker (recomendada)

```
# no servidor, com o repositório clonado em /opt/aethra/src
cd /opt/aethra/src/server
#   crie o .env conforme acima
sudo mkdir -p /var/lib/aethra && sudo chown 10001:10001 /var/lib/aethra
docker compose up -d --build
docker compose logs -f aethra          # deve aparecer "AETHRA_SERVER_READY 7777"
```

- Antes de publicar, preencha `GODOT_SHA512` no Dockerfile com o valor de `SHA512-SUMS.txt`
  da release 4.7.2.
- Firewall: se houver ufw/nftables ativo, libere só `7777/udp`. No painel do provedor,
  libere `7777/udp` de entrada.

### Opção B — systemd (sem Docker)

```
sudo useradd --system --home /var/lib/aethra aethra
sudo mkdir -p /opt/aethra/app /var/lib/aethra /etc/aethra && sudo chown aethra: /var/lib/aethra
# copie o binário Godot_v4.7.2-stable_linux.x86_64 para /opt/aethra/godot (chmod +x)
# copie para /opt/aethra/app: project.godot, prototypes/pixel3d/first_adventure_state.gd,
#   prototypes/pixel3d/data/first_adventure.json e prototypes/pixel3d/net/
# /etc/aethra/aethra.env com as variáveis acima (AETHRA_DATA_DIR=/var/lib/aethra), chmod 600
sudo cp server/aethra-server.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now aethra-server
journalctl -u aethra-server -f
```

### Logs, backup e atualização

- **Logs.** Saem no stdout/stderr (`docker compose logs`, `journalctl`). Anomalias de rede
  têm limite de frequência. Uma linha de estatística por minuto mostra pacotes, bytes e kicks.
- **Backup.** Copie `/var/lib/aethra/accounts.json` (e o `.bak`). Exemplo de cron diário:
  `cp /var/lib/aethra/accounts.json /root/backups/aethra-$(date +%F).json`.
  O arquivo contém hashes de senha: proteja como segredo.
- **Atualizar.** Rode `git pull`, depois `docker compose up -d --build`. Os jogadores
  conectados caem e voltam pelo RESUME, porque o token vive em memória. Depois de um
  reinício, o login é feito com senha.
- **Parar.** `docker compose stop` salva o que já foi gravado. A gravação também acontece em
  cada logout ou queda e a cada 30 s. Não está provado que o Godot trata SIGTERM com
  gravação final, então no pior caso perdem-se até 30 s de progresso.

## Como os amigos conectam

Isto só funciona depois de aplicar o patch de integração descrito abaixo:

```
Ecos-de-Aethra.exe -- --connect=HOST:7777 --user=Nome --pass=senha --register   # 1ª vez
Ecos-de-Aethra.exe -- --connect=HOST:7777 --user=Nome --pass=senha
```

## Preset de exportação (opcional)

O Docker e o systemd rodam o projeto direto do código-fonte, então nenhum export é
necessário. Se quiser um binário exportado, acrescente ao `export_presets.cfg` (arquivo
compartilhado; não foi editado):

```
[preset.1]
name="Linux Server"
platform="Linux"
runnable=false
dedicated_server=true
export_filter="resources"
export_files=PackedStringArray("res://prototypes/pixel3d/net/server_main.gd")
include_filter="prototypes/pixel3d/net/*,prototypes/pixel3d/data/first_adventure.json,prototypes/pixel3d/first_adventure_state.gd"
exclude_filter="prototypes/pixel3d/net/tests/*"
export_path="builds/server/aethra-server.x86_64"

[preset.1.options]
binary_format/embed_pck=true
binary_format/architecture="x86_64"
```

Para isso também é preciso instalar o export template Linux da 4.7.2.

## Patch de integração no cliente (pendente; aplicar em `main`)

Em `prototypes/pixel3d/pixel3d_demo.gd`:

```gdscript
const NetGame := preload("res://prototypes/pixel3d/net/net_game.gd")
var _net = null

# _ready(), logo depois de `_adventure.build(self, args)`:
	_net = NetGame.new()
	add_child(_net)
	var lf := func(p: Node, t: String, a: Vector3, c: Color) -> Label3D: return _adventure.world.label(p, t, a, c)
	if not _net.start_from_args(args, _world_root, lf if _adventure != null else Callable()):
		_net.queue_free()
		_net = null

# _physics_process(): logo depois de calcular `input` (antes do bloco de blink/dodge):
	if _net != null and _net.is_online():
		_net.send_move(input, Input.is_physical_key_pressed(KEY_SPACE))
		var np: Vector3 = _net.local_position()
		_player.velocity = (np - _player.global_position) / maxf(delta, 0.001)
		_player.global_position = np
		_model.rotation.y = _net.local_yaw()
		_animate(delta, input)
		_update_projectiles(delta)
		_update_camera(delta)
		# (o restante do quadro — céu, vida, fauna — continua igual; retirar só o move_and_slide)

# _attack_at(): no modo online, não gasta mana local nem cria a bola de fogo local:
	if _net != null and _net.is_online():
		_net.fire_at(_net.entity_id_of(node), tgt)
		_attack_t = 0.0      # só a animação; o projétil vem do servidor
		_fired = true
		return

# _begin_blink(destination): online → _net.blink_to(destination) e não move o jogador
# (o servidor teleporta e a reconciliação salta acima de 2,5 m).
# KEY_1/KEY_2: online → _net.drink("hp"/"mana"); KEY_R: _net.ring(); KEY_3: _net.cast_light().
# _mouse_ground(): os monstros remotos têm StaticBody3D na camada 8 com meta "kind"="enemy" e
# "net_id"; o raio atual (camada 1|8) já os encontra.
```

Em `prototypes/pixel3d/pixel3d_adventure.gd` (só no modo online):

- Não chamar `enemies.build(self)` nem `enemies.update(...)`. Os monstros passam a ser os
  do servidor, desenhados por `NetWorldView`.
- Ligar os sinais:
  - `stats_changed(me)`: copiar `hp`, `mana`, `level`, `xp` e as poções para o HUD.
    Não chamar `state.add_xp` localmente.
  - `combat_event`:
    - `kill`: XP branco subindo e mensagem no chat;
    - `level`: `world_labels.announce`;
    - `damage` cujo `target == net.client.eid`: número vermelho;
    - `refused`: feedback visual (barra de mana piscando com `reason == "mana"`, recarga no HUD);
    - `death`: fala da Nessa.
  - `chat_received`: `chat.post` na aba Servidor (`global`) ou Local.
  - `friend_event` / `friends_updated`: painel de amigos (ainda não existe no HUD).
- A aba Grupo/PvP do chat pode usar `net.say("private", texto, nome)`.

## O que ainda falta

- **Colisão do servidor.** Hoje o servidor colide só com as bordas do mapa (sem obstáculos).
  É preciso exportar troncos, pedras, rio e casas do mundo gerado para
  `prototypes/pixel3d/net/data/collision_surface.json`
  (formato `{"half":60, "circles":[[x,z,r]], "boxes":[[cx,cz,hx,hz,yaw]]}`). Isso pede uma
  ferramenta que rode o mundo headless e leia os `StaticBody3D` da superfície. Até lá, o
  cliente local colide com árvores e o servidor não: a reconciliação corrige, mas o jogador
  pode "atravessar" árvores do ponto de vista dos outros.
- **IA nova dos monstros.** A IA do `main` (`ai/enemy_director.gd`, com `targets_provider` /
  `damage_sink` / `slow_sink`) depende de `CharacterBody3D` e `PhysicsDirectSpaceState3D`.
  O `server_world.gd` simula em 2D puro e mantém uma IA mínima isolada em `_monster_ai()`.
  Para usar a IA nova no servidor é preciso:
  1. criar no servidor headless um `World3D` com os obstáculos acima como `StaticBody3D` e
     um `CharacterBody3D` por monstro;
  2. `targets_provider` = jogadores do `ServerWorld` (`{id: str(eid), pos, safe}`);
  3. `damage_sink` = `ServerWorld.damage_player`;
  4. `slow_sink` = efeito `slow` (o bit já existe no protocolo), aplicado também no
     `PlayerMotion` para a predição continuar igual ao servidor.
- **Andares e gruta.** O servidor só conhece a superfície (y = 0).
- **Itens, bolsas, baú e tochas** ainda não passam pelo servidor.
- **Hash de senha.** SHA-256 iterado, porque o Godot não expõe PBKDF2/scrypt. Para
  produção, trocar por argon2/scrypt via GDExtension ou por um serviço de contas.
