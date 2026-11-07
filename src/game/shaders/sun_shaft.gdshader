// PROTOTYPE - NOT FOR PRODUCTION
// Air illuminated between the canopy opening and its real spotlight footprint.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 source = vec3(0.0, 4.0, 0.0);
uniform vec3 target = vec3(2.0, 0.0, 0.0);
uniform vec4 color : source_color = vec4(1.0, 0.88, 0.65, 1.0);
uniform float intensity = 0.0;
uniform float width = 0.65;
uniform float seed = 0.0;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
void vertex() {
    vec3 axis = normalize(target - source);
    vec3 side = normalize(cross(axis, INV_VIEW_MATRIX[2].xyz));
    vec3 w = mix(source, target, UV.y) + side * (UV.x - 0.5) * width * mix(0.45, 1.5, UV.y);
    VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}
void fragment() {
    float side = 1.0 - smoothstep(0.06, 0.5, abs(UV.x - 0.5));
    float ends = smoothstep(0.0, 0.18, UV.y) * (1.0 - smoothstep(0.78, 1.0, UV.y));
    float dust = 0.85 + 0.15 * sin(UV.y * 15.0 - TIME * 0.45 + seed);
    float depth = textureLod(scene_depth, SCREEN_UV, 0.0).r;
    vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
    float gap = -behind.z / behind.w + VERTEX.z;
    ALBEDO = color.rgb;
    ALPHA = side * ends * dust * intensity * smoothstep(0.0, 0.4, gap);
}
