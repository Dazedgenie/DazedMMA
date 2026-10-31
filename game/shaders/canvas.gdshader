shader_type spatial;
render_mode diffuse_burley;
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
}
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec2 p = local_position.xz;
	float grain = hash(floor(p * 310.0));
	float wear = hash(floor(p * 7.0));
	float weave = sin(p.x * 940.0) * sin(p.y * 940.0);
	float scuff = smoothstep(0.94, 0.99, hash(floor(p * vec2(25.0, 120.0))));
	vec3 canvas = mix(vec3(0.28, 0.30, 0.30), vec3(0.38, 0.39, 0.36), grain * 0.25 + wear * 0.18);
	ALBEDO = canvas - scuff * 0.04 + weave * 0.008;
	ROUGHNESS = 0.96;
}
