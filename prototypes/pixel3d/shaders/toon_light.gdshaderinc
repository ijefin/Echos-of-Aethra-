// PROTOTYPE - NOT FOR PRODUCTION
// Luz em degraus (toon): a sombra fica com a cor do ambiente (roxo frio), a luz em
// faixas duras — dá o recorte de pixel art quando renderizado em baixa resolução.
// Sombras de nuvem: ruído global rolando no chão, só na luz direcional (o sol).
// Quem inclui precisa preencher `toon_w` (posição de mundo) no fragment():
//   toon_w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
uniform float toon_bands = 3.0;
uniform float toon_bias = 0.35;
uniform float local_light_softness = 0.0;
global uniform sampler2D cloud_noise;

varying vec3 toon_w;

float cloud_light(vec3 w) {
	// fract no lugar de repeat (o ruído é seamless). textureLod 0: na emenda do fract a
	// derivada explode e o mipmap automático desenhava linhas em grade ("+" piscando)
	vec2 uv = fract(w.xz * 0.012 + TIME * vec2(0.0014, 0.0008));
	return mix(0.93, 1.0, smoothstep(0.30, 0.65, textureLod(cloud_noise, uv, 0.0).r));
}

void light() {
	float facing = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = facing * ATTENUATION;
		float q = floor(lit * toon_bands + toon_bias) / toon_bands;
		// Cloud opacity follows quantization so a faint cloud cannot flip an
		// entire toon band and cause a large brightness jump.
		DIFFUSE_LIGHT += q * cloud_light(toon_w) * LIGHT_COLOR;
	} else {
		// Quantize the surface shading, not the distance falloff. Quantizing
		// attenuation made hard discs that vanished as the animated staff rose.
		float surface = floor(facing * toon_bands + toon_bias) / toon_bands;
		surface = mix(surface, facing, local_light_softness);
		DIFFUSE_LIGHT += surface * ATTENUATION * LIGHT_COLOR;
	}
}
