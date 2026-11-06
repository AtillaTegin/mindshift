shader_type canvas_item;

uniform float density : hint_range(0.0, 1.0) = 0.0;

uniform bool feather_edges = false;
uniform vec4 tint : source_color = vec4(0.42, 0.56, 0.78, 1.0);

float mist(vec2 uv) {
	return sin(uv.x * 8.0 + sin(uv.y * 8.0) + TIME * 0.34)
		+ 0.5 * sin(uv.x * 17.0 - uv.y * 13.0 - TIME * 0.49)
		+ 0.25 * sin(uv.x * 37.0 + uv.y * 24.0 + TIME * 0.57);
}

void fragment() {
	float banks = smoothstep(-0.9, 1.4, mist(UV));
	float edge = smoothstep(0.26, 0.50, abs(UV.y - 0.5));
	vec3 cloud = mix(tint.rgb, mix(tint.rgb, vec3(1.0, 0.92, 1.0), 0.66), banks);
	float fade = feather_edges ? smoothstep(0.0, 0.23, min(UV.y, 1.0 - UV.y)) : 1.0;
	COLOR = vec4(cloud, fade * density * (0.18 + 0.67 * banks + 0.15 * edge));
}
