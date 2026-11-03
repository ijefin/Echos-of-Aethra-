// PROTOTYPE - NOT FOR PRODUCTION
// Cachoeirinha da gruta: faixa vertical com listras descendo (3 tons quantizados), borda
// irregular que balança, espuma clara no pé. Transparente, sem luz (a água "brilha" de
// leve no escuro). Forward+.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 water : source_color = vec4(0.36, 0.66, 0.74, 1.0);
uniform vec4 light_streak : source_color = vec4(0.70, 0.90, 0.95, 1.0);
uniform vec4 foam : source_color = vec4(0.86, 0.96, 1.0, 1.0);
uniform float speed = 1.6;   // descida das listras (UV/s)
uniform float seed = 0.0;

void fragment() {
	// UV.y = 0 no topo, 1 no pé
	float wobble = (texture(noise_tex, vec2(UV.y * 0.6 + seed, TIME * 0.4)).r - 0.5) * 0.25;
	float edge = 1.0 - smoothstep(0.32, 0.5, abs(UV.x - 0.5 + wobble));
	float streak = texture(noise_tex, vec2(UV.x * 0.9 + seed, UV.y * 0.35 - TIME * speed)).r;
	vec3 col = water.rgb;
	col = mix(col, light_streak.rgb, step(0.62, streak));
	float base_foam = smoothstep(0.78, 0.95, UV.y + (streak - 0.5) * 0.15);
	col = mix(col, foam.rgb, step(0.5, base_foam));
	float top_fade = smoothstep(0.0, 0.08, UV.y);
	ALBEDO = col * 1.1;
	ALPHA = floor(edge * top_fade * 0.85 * 3.0) / 3.0;
}
