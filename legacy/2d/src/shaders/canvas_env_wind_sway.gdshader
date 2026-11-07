// Autor: Claude Code (meu-mmorpg) · Propósito: vento em árvores, arbustos e samambaias.
// A base do sprite fica presa e o topo balança. Na copa (acima de canopy_v) as folhas
// tremem 1 px em blocos de 3 px. A fase vem da posição no mundo, então um material
// compartilhado serve para todas as instâncias.
// Pipeline: Forward+ (2D canvas). Custo: 1 leitura de textura por fragmento, sem laços.
shader_type canvas_item;

group_uniforms sway;
uniform float sway_px : hint_range(0.0, 6.0) = 1.5;
uniform float sway_speed : hint_range(0.0, 4.0) = 1.1;
group_uniforms leaves;
uniform float canopy_v : hint_range(0.0, 1.0) = 0.6;
uniform float rustle : hint_range(0.0, 2.0) = 1.0;
group_uniforms;

const float LEAF_CELL_PX = 3.0;       // tamanho do bloco de folhas que treme junto
const float RUSTLE_THRESHOLD = 0.55;  // fração de blocos que se mexem por vez
const float SHIMMER = 0.05;           // brilho da copa ao vento (±5 %)

varying vec2 world_pos;
varying vec4 tint;

void vertex() {
	vec2 origin = MODEL_MATRIX[3].xy;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float weight = 1.0 - UV.y; // 0 na base, 1 no topo
	float phase = origin.x * 0.013 + origin.y * 0.009;
	// duas senoides com razão irracional para o balanço não parecer um metrônomo
	float s = sin(TIME * sway_speed + phase) * 0.7 + sin(TIME * sway_speed * 2.37 + phase * 1.9) * 0.3;
	VERTEX.x += s * sway_px * weight;
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV;
	float leaf = step(UV.y, canopy_v);
	vec2 cell = floor(world_pos / LEAF_CELL_PX);
	float n = sin(cell.x * 1.7 + TIME * 2.9) * sin(cell.y * 2.3 - TIME * 2.1);
	uv.x += leaf * rustle * step(RUSTLE_THRESHOLD, n) * TEXTURE_PIXEL_SIZE.x;
	vec4 c = texture(TEXTURE, uv);
	c.rgb *= 1.0 + leaf * SHIMMER * sin(TIME * 1.3 + world_pos.x * 0.04 + world_pos.y * 0.03);
	COLOR = c * tint;
}
