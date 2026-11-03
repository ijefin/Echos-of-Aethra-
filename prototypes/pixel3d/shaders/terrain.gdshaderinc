// PROTOTYPE - NOT FOR PRODUCTION
// Cores, trilhas, água e praça do chão, compartilhadas por chão e grama (a grama pega a
// cor do chão embaixo dela, como no visual do t3ssel8r). As fórmulas de trilha/água/praça
// são as mesmas de prototypes/pixel3d/pixel3d_demo.gd (espalhamento e colisão).
uniform vec4 grass_a : source_color = vec4(0.22, 0.38, 0.19, 1.0);
uniform vec4 grass_b : source_color = vec4(0.27, 0.44, 0.20, 1.0);
uniform vec4 grass_c : source_color = vec4(0.33, 0.50, 0.21, 1.0);
uniform vec4 dirt_a : source_color = vec4(0.36, 0.24, 0.16, 1.0);
uniform vec4 dirt_b : source_color = vec4(0.46, 0.32, 0.20, 1.0);
uniform vec4 mud : source_color = vec4(0.26, 0.2, 0.14, 1.0);
uniform vec4 stone_a : source_color = vec4(0.5, 0.48, 0.5, 1.0);
uniform vec4 stone_b : source_color = vec4(0.56, 0.54, 0.55, 1.0);
uniform sampler2D noise_tex : repeat_enable, filter_linear;
// Uploaded from pixel3d_camps.gd; also used to reserve CPU vegetation placement.
uniform vec2 camp_centers[3];
uniform vec2 woodland_trails[20];

const vec2 LAKE_C = vec2(-15.0, 13.0);
const float LAKE_R = 6.5;
const vec2 PLAZA_C = vec2(2.2, 4.7);
const float PLAZA_R = 3.4;
const float RIVER_HALF = 1.8;
const float WATER_DEPTH = 1.1;

float trail_segment(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0));
}

float path_dist(vec2 p) {
	float a = abs(p.x - sin(p.y * 0.18) * 3.0);
	float b = abs(p.y - (sin(p.x * 0.15) * 2.0 + 4.0));
	float d = min(a, b);
	for (int camp = 0; camp < 3; camp++) {
		d = min(d, length(p - camp_centers[camp]) - 2.4);
	}
	for (int camp = 0; camp < 4; camp++) {
		for (int i = 0; i < 4; i++) {
			d = min(d, trail_segment(p, woodland_trails[camp * 5 + i], woodland_trails[camp * 5 + i + 1]) + 0.6);
		}
	}
	return d;
}

float river_center(float x) {
	return sin(x * 0.11) * 4.0 - 15.0;
}

// Lago orgânico: raio varia com o ângulo (3 harmônicos) e a forma é alongada.
float lake_dist(vec2 p) {
	vec2 d = (p - LAKE_C) * vec2(0.78, 1.12);
	float a = atan(d.y, d.x);
	float r = LAKE_R * (1.0 + 0.22 * sin(2.0 * a + 0.6) + 0.14 * sin(3.0 * a + 2.1) + 0.08 * sin(5.0 * a + 0.4));
	return length(d) - r;
}

// < 0 dentro d'água (lago ou rio), em unidades de mundo até a margem
float water_dist(vec2 p) {
	float lake = lake_dist(p);
	float river = abs(p.y - river_center(p.x)) - RIVER_HALF;
	return min(lake, river);
}

// altura do chão: bacia funda dentro d'água, margem suave
float terrain_h(vec2 p) {
	return -(1.0 - smoothstep(-1.6, 0.6, water_dist(p))) * WATER_DEPTH;
}

vec3 grass_color(vec2 p) {
	float n = texture(noise_tex, p * 0.08).r;
	return n < 0.42 ? grass_a.rgb : (n < 0.58 ? grass_b.rgb : grass_c.rgb);
}
