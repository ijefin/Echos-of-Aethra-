// PROTOTYPE - NOT FOR PRODUCTION
// Água estilizada (lago, rio, fonte): cor rasa→funda pela profundidade da cena atrás da
// superfície (4 faixas), fundo visto com leve refração, espuma recortada na margem,
// brilhos de onda. Rio: `use_uv` faz a correnteza seguir a fita (UV.y = distância).
// Profundidade linear com reversed-Z (4.3+): INV_PROJECTION_MATRIX * (uv*2-1, d, 1).
// Forward+. Transparente (lê a tela depois dos opacos).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 shallow : source_color = vec4(0.32, 0.72, 0.72, 1.0);
uniform vec4 deep : source_color = vec4(0.16, 0.42, 0.52, 1.0);
uniform vec4 foam : source_color = vec4(0.72, 0.88, 0.9, 1.0);
uniform float depth_scale = 0.6;    // quanto escurece por unidade de profundidade
uniform float foam_width = 0.07;    // espessura da espuma na margem (unidades)
uniform bool use_uv = false;
uniform float flow_speed = 0.0;     // rio: velocidade da correnteza (UV/s)

varying vec3 w;

void vertex() {
	w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float diff = (-v.z / v.w) - (-VERTEX.z);  // água entre a superfície e o fundo
	vec2 uv = use_uv ? vec2(UV.x * 0.6, UV.y - TIME * flow_speed) : w.xz * 0.25 + TIME * vec2(0.02, 0.013);
	float n = texture(noise_tex, uv * 0.5).r;
	float n2 = texture(noise_tex, uv * 1.3 + vec2(0.4, TIME * 0.03)).r;
	float t = floor(clamp(diff * depth_scale, 0.0, 1.0) * 4.0) / 4.0;
	vec3 col = mix(shallow.rgb, deep.rgb, t);
	vec3 under = texture(screen_tex, SCREEN_UV + (n - 0.5) * 0.008).rgb;
	col = mix(under * shallow.rgb * 1.3, col, clamp(t * 1.6 + 0.35, 0.0, 1.0));
	float glint = step(0.8, n2) * 0.3;
	col += glint;
	if (use_uv) {
		float streak = step(0.72, texture(noise_tex, vec2(UV.x * 0.35, UV.y * 0.12 - TIME * flow_speed * 0.12)).r);
		col = mix(col, foam.rgb * 0.85, streak * 0.45);
	}
	float edge = 1.0 - step(foam_width + n * 0.09, diff);
	ALBEDO = mix(col, foam.rgb, edge);
	ALPHA = 1.0;
}
