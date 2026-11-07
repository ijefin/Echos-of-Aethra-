// Autor: Claude Code (meu-mmorpg) · Propósito: vinheta de tela, escurece as bordas
// com um tom frio para focar o centro.
// Pipeline: Forward+ (2D canvas, CanvasLayer). Custo: sem leitura de textura.
shader_type canvas_item;

group_uniforms vignette;
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform vec4 tint : source_color = vec4(0.06, 0.04, 0.1, 1.0);
group_uniforms;

const float ASPECT = 1.78;   // 16:9, para a vinheta ficar circular
const float INNER = 0.5;
const float OUTER = 1.05;

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= ASPECT;
	float v = smoothstep(INNER, OUTER, length(uv));
	COLOR = vec4(tint.rgb, v * strength);
}
