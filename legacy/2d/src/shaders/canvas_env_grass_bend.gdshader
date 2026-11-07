// Autor: Claude Code (meu-mmorpg) · Propósito: grama alta com vento que se abre
// quando o jogador passa. player_pos é escrito uma vez por frame no material
// compartilhado por todos os tufos.
// Pipeline: Forward+ (2D canvas). Custo: 1 leitura de textura por fragmento.
shader_type canvas_item;

group_uniforms interaction;
uniform vec2 player_pos;
uniform float bend_radius : hint_range(4.0, 64.0) = 20.0;
uniform float bend_px : hint_range(0.0, 12.0) = 5.0;
group_uniforms wind;
uniform float sway_px : hint_range(0.0, 4.0) = 1.2;
uniform float sway_speed : hint_range(0.0, 4.0) = 1.6;
group_uniforms;

const float Y_SQUASH = 1.6;    // distância vertical pesa mais (vista 3/4)
const float PRESS_DOWN_PX = 3.0; // quanto a grama abaixa ao ser pisada

varying vec4 tint;

void vertex() {
	vec2 origin = MODEL_MATRIX[3].xy;
	float weight = 1.0 - UV.y;
	vec2 d = origin - player_pos;
	float near = 1.0 - smoothstep(4.0, bend_radius, length(d * vec2(1.0, Y_SQUASH)));
	float side = d.x >= 0.0 ? 1.0 : -1.0;
	float phase = origin.x * 0.05 + origin.y * 0.03;
	float s = sin(TIME * sway_speed + phase) * 0.6 + sin(TIME * sway_speed * 2.1 + phase * 1.3) * 0.4;
	VERTEX.x += (s * sway_px + side * near * bend_px) * weight;
	VERTEX.y += near * PRESS_DOWN_PX * weight;
	tint = COLOR;
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * tint;
}
