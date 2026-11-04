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
// Mundo maior (world/world_layout.gd): trilhas novas, Estrada Velha e poças do charco.
uniform vec4 world_trails[32];
uniform int world_trail_count = 0;
uniform vec4 old_road[16];
uniform int old_road_count = 0;
uniform vec3 pools[10];
uniform int pool_count = 0;

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
	for (int i = 0; i < world_trail_count; i++) {
		d = min(d, trail_segment(p, world_trails[i].xy, world_trails[i].zw) + 0.3);
	}
	return d;
}

float old_road_dist(vec2 p) {
	float d = 1e6;
	for (int i = 0; i < old_road_count; i++) {
		d = min(d, trail_segment(p, old_road[i].xy, old_road[i].zw));
	}
	return d;
}

float pool_dist(vec2 p) {
	float d = 1e6;
	for (int i = 0; i < pool_count; i++) {
		vec2 v = p - pools[i].xy;
		float a = atan(v.y, v.x);
		d = min(d, length(v) - pools[i].z * (1.0 + 0.12 * sin(3.0 * a + pools[i].x) + 0.07 * sin(5.0 * a + pools[i].y)));
	}
	return d;
}

// Peso de cada região (0..1) com borda quebrada por ruído: serra, bosque, charco, ruínas.
vec4 region_weights(vec2 p) {
	float n = (texture(noise_tex, p * 0.031).r - 0.5) * 9.0;
	float serra = 1.0 - smoothstep(-66.0, -56.0, p.y + n);
	float charco = smoothstep(56.0, 66.0, p.y + n);
	float bosque = smoothstep(56.0, 66.0, p.x + n) * (1.0 - serra) * (1.0 - charco);
	float ruinas = (1.0 - smoothstep(-66.0, -56.0, p.x + n)) * (1.0 - serra) * (1.0 - charco);
	return vec4(serra, bosque, charco, ruinas);
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
	float d = min(lake, river);
	if (p.y > 60.0) {
		d = min(d, pool_dist(p));
	}
	return d;
}

// altura do chão: bacia funda dentro d'água, margem suave
float terrain_h(vec2 p) {
	return -(1.0 - smoothstep(-1.6, 0.6, water_dist(p))) * WATER_DEPTH;
}

vec3 grass_color(vec2 p) {
	float n = texture(noise_tex, p * 0.08).r;
	vec3 col = n < 0.42 ? grass_a.rgb : (n < 0.58 ? grass_b.rgb : grass_c.rgb);
	// tom de cada região, em degraus (sem degradê liso): serra fria e pedregosa, bosque
	// fundo, charco oliva-escuro, ruínas seca e amarelada
	vec4 w = step(vec4(0.5), region_weights(p));
	col = mix(col, col * vec3(0.86, 0.9, 1.02) + vec3(0.05, 0.04, 0.06), w.x);
	col = mix(col, col * vec3(0.78, 0.86, 0.9), w.y);
	col = mix(col, col * vec3(0.92, 0.82, 0.62) + vec3(0.03, 0.02, 0.0), w.z);
	col = mix(col, col * vec3(1.1, 0.98, 0.7) + vec3(0.04, 0.02, 0.0), w.w);
	return col;
}
