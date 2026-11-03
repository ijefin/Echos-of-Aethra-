// PROTOTYPE - NOT FOR PRODUCTION
// Chama de partícula: quad virado para a câmera com forma de lágrima (larga embaixo,
// ponta em cima) torcida por ruído, núcleo claro e 3 faixas de brilho. A cor vem do
// degradê da partícula (COLOR). Aditivo, HDR. Forward+.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float intensity = 3.0;
uniform vec4 core_color : source_color = vec4(1.0, 0.92, 0.6, 1.0);

void vertex() {
	// billboard mantendo a escala da partícula
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float y = -uv.y;                       // -1 base, +1 ponta
	float up = clamp((y + 1.0) * 0.5, 0.0, 1.0);
	float n = texture(noise_tex, vec2(UV.x * 0.5 + COLOR.b * 3.0, UV.y * 0.5 + TIME * 1.6)).r;
	float x = uv.x + (n - 0.5) * 0.7 * up;  // a ponta tremula mais que a base
	float w = mix(0.8, 0.06, up);           // largura: lágrima
	float shape = 1.0 - smoothstep(w * 0.55, w, abs(x));
	shape *= smoothstep(-1.0, -0.65, y) * (1.0 - smoothstep(0.55, 1.0, y + (n - 0.5) * 0.6));
	float core = shape * (1.0 - smoothstep(0.0, w * 0.6, abs(x))) * (1.0 - up * 0.8);
	shape = floor(shape * 3.0) / 3.0;
	vec3 col = mix(COLOR.rgb, core_color.rgb, step(0.45, core));
	ALBEDO = col * shape * COLOR.a * intensity;
}
