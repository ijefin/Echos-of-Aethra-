// PROTOTYPE - NOT FOR PRODUCTION
shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Tufos de grama (MultiMesh): normal "para cima" para sombrear igual ao chão, cor do chão
// embaixo, ponta mais clara, vento e empurrão do jogador.

#include "res://prototypes/pixel3d/shaders/toon_light.gdshaderinc"
#include "res://prototypes/pixel3d/shaders/terrain.gdshaderinc"

uniform vec3 player_pos = vec3(0.0);
uniform float push_radius = 0.9;

varying vec3 base_w;
varying float tip;

void vertex() {
	base_w = MODEL_MATRIX[3].xyz;
	tip = clamp(VERTEX.y / 0.4, 0.0, 1.0);
	float h = tip * tip;
	vec3 wind = vec3(sin(TIME * 2.0 + base_w.x * 0.6 + base_w.z * 0.4) * 0.09 + sin(TIME * 3.7 + base_w.x * 1.7) * 0.03, 0.0, 0.0);
	vec2 d = base_w.xz - player_pos.xz;
	float f = 1.0 - smoothstep(0.0, push_radius, length(d));
	vec3 push = vec3(normalize(d + vec2(0.0001)).x, -0.6, normalize(d + vec2(0.0001)).y) * f * 0.3;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * (wind + push) * h;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	// normal do chão em espaço de vista: frente e costas da folha sombreiam igual
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	toon_w = base_w;
	vec3 col = grass_color(base_w.xz);
	ALBEDO = mix(col * 0.85, col * 1.25, step(0.6, tip));
}
