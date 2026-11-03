// PROTOTYPE - NOT FOR PRODUCTION
shader_type spatial;
render_mode cull_back, specular_disabled;
// Material base de tudo que é sólido: cor chapada + luz em degraus + emissão opcional.
// `sway` balança a malha ao vento (copas). `dissolve` (0..1) desfaz a peça em pixels com
// borda acesa — usado no teleporte. Forward+.

#include "res://prototypes/pixel3d/shaders/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform sampler2D albedo_tex : source_color, filter_nearest;  // paleta dos modelos KayKit
uniform bool use_tex = false;
uniform vec4 tint : source_color = vec4(1.0);                  // Piromante escurece o manto
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float sway = 0.0;
// Subtle cool edge for character readability; does not cast light on the floor.
uniform float readability = 0.0;
// copa vaza em pontilhado quando o jogador está embaixo (não some o personagem)
uniform bool see_through = false;
global uniform vec3 player_world;
const float SEE_RADIUS = 2.4;
group_uniforms dissolver;
uniform float dissolve = 0.0;
uniform vec4 dissolve_edge : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float dissolve_edge_width = 0.08;

varying vec3 obj;

void vertex() {
	obj = VERTEX;
	if (sway > 0.0) {
		vec3 w = MODEL_MATRIX[3].xyz;
		// rajada: onda de vento que atravessa a floresta de oeste para leste
		float gust = sin(TIME * 0.55 - w.x * 0.07 - w.z * 0.03);
		gust = 1.0 + 2.2 * gust * gust * gust * step(0.0, gust);
		VERTEX.x += sin(TIME * 1.3 + w.x * 0.7 + w.z * 0.5 + VERTEX.y * 1.5) * sway * gust;
		VERTEX.z += cos(TIME * 1.1 + w.z * 0.6 + VERTEX.y) * sway * 0.5 * gust;
	}
}

void fragment() {
	toon_w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (see_through && toon_w.y > player_world.y + 1.6) {
		float d = length(toon_w.xz - player_world.xz - vec2(0.0, 0.6));
		// xadrez de pixel: metade some perto do jogador, tudo some bem em cima dele
		float checker = mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0);
		if (d < SEE_RADIUS * 0.55 || (d < SEE_RADIUS && checker > 0.5)) {
			discard;
		}
	}
	ALBEDO = (use_tex ? texture(albedo_tex, UV).rgb : albedo.rgb) * tint.rgb;
	EMISSION = emission.rgb * emission_energy;
	float edge = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.0);
	EMISSION += ALBEDO * vec3(0.40, 0.48, 0.75) * readability * (0.25 + 0.75 * edge);
	if (dissolve > 0.0) {
		// ruído em espaço do objeto: o padrão não escorrega quando o personagem anda
		float n = textureLod(cloud_noise, fract(obj.xy * 9.0 + obj.z * 7.0), 0.0).r;
		n = mix(n, 1.0 - fract(obj.y * 0.9), 0.35);  // de baixo para cima
		if (n < dissolve) {
			discard;
		}
		EMISSION += dissolve_edge.rgb * 5.0 * (1.0 - step(dissolve + dissolve_edge_width, n));
	}
}
