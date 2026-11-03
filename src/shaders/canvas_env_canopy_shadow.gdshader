// Autor: Claude Code (meu-mmorpg) · Propósito: sombra da copa no chão com luz
// manchada — buracos de sol que derivam devagar, como luz entre folhas ao vento.
// O alfa é quantizado em poucos níveis para combinar com a pixel art.
// Pipeline: Forward+ (2D canvas). Custo: 1 leitura de textura + 2 value noise por fragmento.
shader_type canvas_item;

group_uniforms shadow;
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform vec4 shadow_color : source_color = vec4(0.04, 0.08, 0.14, 1.0);
group_uniforms dapple;
uniform float drift : hint_range(0.0, 1.0) = 0.12;
group_uniforms;

const float NOISE_SCALE = 0.07;    // tamanho das manchas de sol (~14 px)
const float HOLE_LO = 0.6;         // limiar onde começa o buraco de luz
const float HOLE_HI = 0.66;
const float HOLE_LIGHT = 0.85;     // quanto da sombra o buraco remove
const float ALPHA_STEPS = 5.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	vec2 p = floor(world_pos) * NOISE_SCALE;
	// duas oitavas que derivam em direções diferentes: as manchas mudam de forma
	float n = vnoise(p + vec2(TIME * drift, TIME * drift * 0.6)) * 0.65
		+ vnoise(p * 2.1 - vec2(TIME * drift * 1.4, 0.0)) * 0.35;
	float holes = smoothstep(HOLE_LO, HOLE_HI, n);
	float a = mask * strength * (1.0 - holes * HOLE_LIGHT);
	a = floor(a * ALPHA_STEPS + 0.5) / ALPHA_STEPS;
	COLOR = vec4(shadow_color.rgb, a);
}
