// Autor: Claude Code (meu-mmorpg) · Propósito: feixe de luz diagonal entre as copas.
// Aditivo, bordas suaves, "respira" devagar e é quantizado em faixas (pixel art).
// Pipeline: Forward+ (2D canvas). Custo: sem leitura de textura.
shader_type canvas_item;
render_mode blend_add;

group_uniforms ray;
uniform vec4 ray_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.14;
uniform float phase = 0.0;
group_uniforms;

const float BANDS = 40.0;       // degraus de alfa
const float BREATHE_SPEED = 0.6;

void fragment() {
	float across = smoothstep(0.0, 0.4, UV.x) * smoothstep(1.0, 0.6, UV.x);
	float along = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.5, UV.y);
	float breathe = 0.7 + 0.3 * sin(TIME * BREATHE_SPEED + phase);
	float a = floor(across * along * breathe * intensity * BANDS) / BANDS;
	COLOR = vec4(ray_color.rgb, a);
}
