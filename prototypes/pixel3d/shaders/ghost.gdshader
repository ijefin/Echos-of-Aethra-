// PROTOTYPE - NOT FOR PRODUCTION
// Fantasma de rastro (blink/esquiva) e onda de choque: cor sólida aditiva com borda mais
// forte. Em 3D não existe `modulate`: o sumiço é pelo uniform `alpha` (Tween).
// Forward+.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform float alpha = 1.0;
uniform float energy = 2.0;      // HDR: acima de 1 acende o bloom
uniform float rim_cut = 0.4;     // a partir de onde a borda fica cheia

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float a = alpha * (0.35 + 0.65 * step(rim_cut, rim));
	ALBEDO = color.rgb * energy * a;
}
