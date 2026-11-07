// PROTOTYPE - NOT FOR PRODUCTION
shader_type spatial;
render_mode cull_back, specular_disabled;
// Chão: grama em 3 tons por ruído, trilhas de terra, margem lamacenta afundando na água
// (bacia no vertex com normal por diferença finita) e praça de pedra no cruzamento.
// Forward+.

#include "res://src/game/shaders/toon_light.gdshaderinc"
#include "res://src/game/shaders/terrain.gdshaderinc"

const float NORMAL_EPS = 0.25;

varying vec3 wpos;

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += terrain_h(p);
	float hx = terrain_h(p + vec2(NORMAL_EPS, 0.0)) - terrain_h(p - vec2(NORMAL_EPS, 0.0));
	float hz = terrain_h(p + vec2(0.0, NORMAL_EPS)) - terrain_h(p - vec2(0.0, NORMAL_EPS));
	NORMAL = normalize(vec3(-hx, 2.0 * NORMAL_EPS, -hz));
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	toon_w = wpos;
	float n2 = texture(noise_tex, wpos.xz * 0.11).r;
	float pd = path_dist(wpos.xz) + (n2 - 0.5) * 1.2;
	vec3 col = grass_color(wpos.xz);
	if (pd < 1.25) {
		col = mix(dirt_a.rgb, dirt_b.rgb, step(0.62, n2));
	} else if (pd < 1.55) {
		col = mix(col, dirt_a.rgb, 0.55);
	}
	// Estrada Velha: lajes antigas, quebradas, com grama brotando nas falhas
	float rd = old_road_dist(wpos.xz) + (n2 - 0.5) * 0.8;
	if (rd < 1.7) {
		vec2 g = wpos.xz * 1.6;
		g.x += step(1.0, mod(floor(g.y), 2.0)) * 0.5;
		vec2 f = fract(g);
		float var = texture(noise_tex, floor(g) * 0.211).r;
		float joint = step(0.86, max(f.x, f.y));
		bool missing = var < 0.3 || (rd > 1.1 && var < 0.55);
		if (!missing) {
			col = mix(mix(stone_a.rgb * 0.92, stone_b.rgb * 0.85, step(0.6, var)), stone_a.rgb * 0.55, joint);
		} else if (rd < 1.3) {
			col = mix(col, dirt_a.rgb, 0.5);
		}
	}
	// serra: cascalho pelo chão do vale e do desfiladeiro
	vec4 rw = region_weights(wpos.xz);
	if (rw.x > 0.5 && pd > 1.55 && n2 > 0.66) {
		col = mix(col, stone_a.rgb * 0.8, 0.7);
	}
	// praça: pedras em grade com juntas escuras e variação por pedra
	float pr = length(wpos.xz - PLAZA_C);
	if (pr < PLAZA_R + (n2 - 0.5) * 0.4) {
		vec2 g = wpos.xz * 2.6;
		g.x += step(1.0, mod(floor(g.y), 2.0)) * 0.5;  // fiadas desencontradas
		vec2 f = fract(g);
		float joint = step(0.9, max(f.x, f.y));
		float var = texture(noise_tex, floor(g) * 0.173).r;
		col = mix(mix(stone_a.rgb, stone_b.rgb, step(0.5, var)), stone_a.rgb * 0.6, joint);
	}
	// margem e fundo d'água
	float wd = water_dist(wpos.xz);
	if (wd < 0.7) {
		col = mix(mud.rgb, col, smoothstep(0.0, 0.7, wd));
	}
	ALBEDO = col;
}
