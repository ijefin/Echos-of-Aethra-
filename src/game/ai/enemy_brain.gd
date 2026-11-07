extends RefCounted
## Estado de decisão de UM monstro (dados puros; a lógica fica em enemy_director.gd).
## A apresentação (modelo, anel, lane) lê `state`, `phase()`, `tele_*` e `hop`.

const IDLE := 0
const PATROL := 1
const CHASE := 2
const WINDUP := 3
const ATTACK := 4
const RECOVER := 5
const RETURN := 6
const NAMES := ["IDLE", "PATROL", "CHASE", "WINDUP", "ATTACK", "RECOVER", "RETURN"]

var state := IDLE
var state_t := 0.0
var think_t := 0.0
var idle_for := 2.0
var frozen := false
## quantas vezes entrou em cada estado (testes / depuração)
var entered := {}

# percepção / alvo
var target_id := ""
var last_seen := Vector3.ZERO
var memory_until := -1.0
var calm_until := -1.0
var seen := false
var target_dist := INF

# combate
var attack := ""  # "bite", "leap", "charge", "spit"
var attack_from := Vector3.ZERO
var attack_to := Vector3.ZERO
var attack_dir := Vector3.FORWARD
var attack_dur := 0.0
var attack_hit: Array[String] = []
var special_cd := 1.0
var flash_t := 0.0
var hop := 0.0
var hits_landed := 0

# telegraph (área de dano mostrada antes do impacto)
var tele_kind := ""  # "", "circle", "lane"
var tele_center := Vector3.ZERO
var tele_radius := 1.0
var tele_len := 0.0
var tele_width := 0.9

# navegação
var path := PackedVector3Array()
var path_i := 0
var path_goal := Vector3.INF
var path_partial := false
var need_repath := false
var move_goal := Vector3.INF
var wants_move := false
var speed_mul := 1.0
var moving := false
var face := Vector3.ZERO
var face_target := false
var retreating := false
var slot := -1
var slot_target := ""

# travamento
var stuck_clock := 0.0
var stuck_ref := Vector3.ZERO
var stuck_count := 0
var stuck_events := 0

var rng := RandomNumberGenerator.new()


## 0..1 dentro do estado temporizado atual (preparação, ataque, recuperação).
func phase() -> float:
	return clampf(state_t / maxf(attack_dur, 0.001), 0.0, 1.0)


func state_name() -> String:
	return NAMES[state]
