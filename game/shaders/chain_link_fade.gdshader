shader_type spatial;
// The camera-side fence (D281): the same chain link as chain_link.gdshader, see-through and faded in
// only where a fighter is against it, so the cage stays open to the camera the rest of the time.
render_mode cull_disabled, depth_draw_never, shadows_disabled;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
// The fence bowing where a man is held on it (D287, LocalVenue.bow_fence): bow_depth metres out of the cage
// at bow_at (on the panel, from its middle), fading over bow_size, held flat at the posts and rails.
uniform vec2 bow_at = vec2(0.0);
uniform float bow_depth = 0.0;
uniform vec2 bow_size = vec2(0.5, 0.65);
uniform vec2 panel_half = vec2(1.0, 0.95);
void vertex() {
	vec2 d = (VERTEX.xy - bow_at) / bow_size;
	vec2 edge = clamp((panel_half - abs(VERTEX.xy)) / 0.3, 0.0, 1.0);
	VERTEX.z += bow_depth * exp(-dot(d, d) * 2.0) * edge.x * edge.y;
}
void fragment() {
	vec2 p = UV * vec2(26.0, 13.0);
	float diagonal_a = abs(fract(p.x + p.y) - 0.5);
	float diagonal_b = abs(fract(p.x - p.y) - 0.5);
	float wire = min(diagonal_a, diagonal_b);
	ALBEDO = vec3(0.13, 0.16, 0.19);
	ROUGHNESS = 0.55;
	METALLIC = 0.35;
	ALPHA = (1.0 - smoothstep(0.025, 0.055, wire)) * fade;
}
