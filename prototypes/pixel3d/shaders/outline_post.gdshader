// PROTOTYPE - NOT FOR PRODUCTION
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
// Pós-processo de contorno (quadrado em tela cheia preso à câmera): borda escura onde a
// profundidade salta (silhueta) e borda clara onde a normal quebra (quinas). Lê a tela
// antes dos transparentes — por isso render_priority baixo: fogo e partículas desenham depois.

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float depth_threshold = 0.9;   // em unidades de mundo: grama (~0.3) não ganha contorno
uniform float normal_threshold = 0.45;
uniform float darken = 0.42;
uniform float highlight = 1.35;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	float d = lin_depth(uv, INV_PROJECTION_MATRIX);
	vec3 n = texture(normal_tex, uv).xyz * 2.0 - 1.0;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	float depth_edge = 0.0;
	float normal_edge = 0.0;
	for (int i = 0; i < 4; i++) {
		float dn = lin_depth(uv + offs[i], INV_PROJECTION_MATRIX);
		depth_edge += clamp(dn - d, 0.0, 1.0);
		vec3 nn = texture(normal_tex, uv + offs[i]).xyz * 2.0 - 1.0;
		// só quinas "para fora" (vizinho mais fundo ou no mesmo plano) acendem
		float behind = step(-0.02, dn - d);
		normal_edge += (1.0 - dot(n, nn)) * behind;
	}
	if (depth_edge > depth_threshold) {
		col *= darken;
	} else if (normal_edge > normal_threshold) {
		col *= highlight;
	}
	ALBEDO = col;
	ALPHA = 1.0;
}
