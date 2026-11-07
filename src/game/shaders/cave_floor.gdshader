// PROTOTYPE - NOT FOR PRODUCTION
// Chão da Gruta das Raízes: rocha em 2 tons, terra, manchas de musgo, pedriscos e, na
// área das ruínas, lajotas antigas desencontradas — faltando nas bordas e rachadas.
// Nada de grade regular fora das ruínas: a gruta é natural. Luz toon do projeto.
// Forward+.
shader_type spatial;
render_mode cull_back, specular_disabled;

#include "res://src/game/shaders/toon_light.gdshaderinc"

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec3 room_origin = vec3(0.0);
group_uniforms ruinas;
uniform vec2 ruin_center = vec2(0.0);   // centro das lajotas (coordenada local da gruta)
uniform float ruin_radius = 7.0;
group_uniforms cores;
uniform vec4 rock_a : source_color = vec4(0.30, 0.28, 0.31, 1.0);
uniform vec4 rock_b : source_color = vec4(0.36, 0.33, 0.35, 1.0);
uniform vec4 dirt : source_color = vec4(0.33, 0.26, 0.21, 1.0);
uniform vec4 moss : source_color = vec4(0.27, 0.38, 0.20, 1.0);
uniform vec4 tile_a : source_color = vec4(0.47, 0.44, 0.41, 1.0);
uniform vec4 tile_b : source_color = vec4(0.52, 0.49, 0.44, 1.0);

varying vec3 w;

void vertex() {
	w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	toon_w = w;
	vec2 p = w.xz - room_origin.xz;
	float n = texture(noise_tex, p * 0.09).r;
	float n2 = texture(noise_tex, p * 0.31 + vec2(3.1, 1.7)).r;
	float n3 = texture(noise_tex, p * 0.63 + vec2(9.2, 4.4)).r;
	vec3 col = mix(rock_a.rgb, rock_b.rgb, step(0.5, n2));
	col = mix(col, dirt.rgb, step(0.6, n));
	col = mix(col, moss.rgb, step(0.66, texture(noise_tex, p * 0.14 + vec2(7.3, 2.2)).r));
	// ruínas: fiadas desencontradas; lajotas somem nas bordas e algumas rachadas
	float rd = length(p - ruin_center);
	if (rd < ruin_radius) {
		vec2 g = p * 1.7;
		g.x += step(1.0, mod(floor(g.y), 2.0)) * 0.5;
		vec2 f = fract(g);
		float joint = step(0.9, max(f.x, f.y));
		float stone = texture(noise_tex, floor(g) * 0.137).r;
		// muitas lajotas faltando (mais nas bordas), o resto do chão natural aparece
		float present = step(0.42 + rd / ruin_radius * 0.25, stone) * step(rd, ruin_radius - n3 * 3.0);
		vec3 tile = mix(tile_a.rgb, tile_b.rgb, step(0.62, stone)) * mix(0.82, 1.0, fract(stone * 7.13));
		tile = mix(tile, moss.rgb, step(0.78, n2) * 0.7);           // musgo entre as pedras
		tile = mix(tile, tile * 0.55, joint);
		tile = mix(tile, tile * 0.45, step(0.965, texture(noise_tex, p * 0.85).r));  // rachaduras
		col = mix(col, tile, present);
	}
	col = mix(col, col * 1.22, step(0.86, n3));   // pedriscos claros
	ALBEDO = col;
}
