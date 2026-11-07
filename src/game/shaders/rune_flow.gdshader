// PROTOTYPE - NOT FOR PRODUCTION
// Runas e canais de fogo na roupa: segunda passada (next_pass) aditiva. Em espaço LOCAL
// da peça (não escorrega quando o personagem anda): canais verticais em volta do eixo,
// anéis horizontais, quebras tipo glifo e pulsos de brasa subindo pelos canais.
// Forward+, HDR > 1 para acender o bloom.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
group_uniforms padrao;
uniform float channels = 6.0;       // canais verticais em volta da peça
uniform float channel_width = 0.26; // largura (fração do espaço entre canais; ~2 px de arte)
uniform float ring_spacing = 0.55;  // distância entre anéis (unidades locais)
uniform float ring_width = 0.022;
group_uniforms fluxo;
uniform float flow_speed = 0.9;     // pulsos subindo (ciclos por segundo)
uniform float flow_density = 2.2;   // pulsos por unidade de altura
uniform float base_glow = 0.35;     // brilho mínimo do canal fora do pulso
uniform float intensity = 3.0;
uniform float pulse = 1.0;          // respiração geral vinda do script
uniform vec4 ember : source_color = vec4(1.0, 0.28, 0.05, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.82, 0.4, 1.0);

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
	VERTEX += NORMAL * 0.004; // evita brigar com a superfície da roupa
}

void fragment() {
	float ang = atan(lpos.x, lpos.z) / TAU + 0.5;           // 0..1 em volta do eixo
	float cell = ang * channels;
	float dc = abs(fract(cell) - 0.5) * 2.0;                 // 0 no centro do canal
	float chan = 1.0 - step(channel_width, 1.0 - dc);        // linha vertical fina
	float ring = 1.0 - step(ring_width, abs(fract(lpos.y / ring_spacing + 0.5) - 0.5) * ring_spacing);
	// quebras tipo glifo: cada trecho de canal liga/desliga por ruído fixo
	float glyph = step(0.38, texture(noise_tex, vec2(floor(cell) * 0.137, floor(lpos.y * 6.0) * 0.091)).r);
	float lines = max(chan * glyph, ring * 0.45);
	// pulso de brasa correndo para cima pelos canais (desencontrado por canal)
	float phase = fract(lpos.y * flow_density - TIME * flow_speed + floor(cell) * 0.37);
	float flow = pow(phase, 6.0);
	float e = lines * (base_glow + flow * 1.6) * pulse;
	vec3 col = mix(ember.rgb, hot.rgb, clamp(flow * 1.3, 0.0, 1.0));
	ALBEDO = col * e * intensity;
}
