// PROTOTYPE - NOT FOR PRODUCTION
// Labaredas na silhueta: segunda passada (next_pass) sobre as roupas. Infla a malha um
// pouco, estica para cima onde o ruído é alto (línguas de fogo) e acende mais nas bordas
// (fresnel). Aditivo, HDR > 1 para o bloom. Forward+.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float grow = 0.035;        // quanto a casca sai da roupa (unidades)
uniform float lick = 0.22;         // altura extra das línguas de fogo
uniform float speed = 1.4;         // velocidade de subida do ruído
uniform float intensity = 3.2;     // brilho HDR
uniform float pulse = 1.0;         // pulso vindo do script
uniform vec4 hot : source_color = vec4(1.0, 0.8, 0.35, 1.0);
uniform vec4 deep : source_color = vec4(1.0, 0.2, 0.03, 1.0);

varying vec3 wpos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = texture(noise_tex, vec2(w.x * 0.9 + w.z * 0.9, w.y * 0.8 - TIME * speed)).r;
	VERTEX += NORMAL * grow * (1.0 + n);
	// lados e topo esticam para cima; a base quase não mexe
	VERTEX.y += max(n - 0.45, 0.0) * lick * (1.0 - abs(NORMAL.y) * 0.5);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec2 nuv = vec2(wpos.x * 1.7 + wpos.z * 1.7, wpos.y * 1.3 - TIME * speed);
	float n = texture(noise_tex, nuv).r * 0.6 + texture(noise_tex, nuv * 2.3 + vec2(0.37, -TIME * speed * 0.6)).r * 0.4;
	float f = smoothstep(0.45, 0.75, n * 0.75 + rim * 0.8 - 0.32);
	f = floor(f * 3.0) / 3.0;  // 3 faixas: casa com a luz em degraus
	ALBEDO = mix(deep.rgb, hot.rgb, f) * f * intensity * pulse;
}
