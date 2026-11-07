// PROTOTYPE - NOT FOR PRODUCTION
// Flores do chão (MultiMesh com cor por instância): sombreiam como o chão (normal para
// cima), balançam com o vento na pétala, miolo claro. Forward+.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://src/game/shaders/toon_light.gdshaderinc"

varying vec3 base_w;
varying vec3 petal;
varying float h;

void vertex() {
	base_w = MODEL_MATRIX[3].xyz;
	h = clamp(VERTEX.y / 0.22, 0.0, 1.0);
	VERTEX.x += sin(TIME * 2.2 + base_w.x * 0.9 + base_w.z * 0.6) * 0.03 * h;
	petal = COLOR.rgb;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	toon_w = base_w;
	// haste verde embaixo, pétala colorida em cima, miolo amarelo no centro do UV
	vec3 stem = vec3(0.24, 0.42, 0.18);
	float core = 1.0 - step(0.18, length(UV - vec2(0.5)));
	vec3 col = mix(stem, petal, step(0.55, h));
	col = mix(col, vec3(1.0, 0.86, 0.35), core * step(0.55, h));
	ALBEDO = col;
}
