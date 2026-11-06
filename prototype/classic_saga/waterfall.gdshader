shader_type canvas_item;

uniform bool pale_water = false;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	// Restrict movement to the painted turquoise water on the cliff faces.
	float left_upper = step(0.045, UV.x) * step(UV.x, 0.151) * step(0.174, UV.y) * step(UV.y, 0.416);
	float left_lower = step(UV.x, 0.12) * step(0.354, UV.y) * step(UV.y, 0.722);
	float right_upper = step(0.846, UV.x) * step(0.232, UV.y) * step(UV.y, 0.365);
	float right_lower = step(0.88, UV.x) * step(0.55, UV.y) * step(UV.y, 0.736);
	float cliff = max(max(left_upper, left_lower), max(right_upper, right_lower));
	float water = smoothstep(0.06, 0.32, min(base.g, base.b) - base.r) * cliff;
	if (pale_water) {
		float edge = (1.0 - smoothstep(0.10, 0.16, UV.x)) + smoothstep(0.87, 0.92, UV.x);
		float height_mask = smoothstep(0.29, 0.36, UV.y) * (1.0 - smoothstep(0.77, 0.84, UV.y));
		water = smoothstep(0.07, 0.22, base.b - base.r) * min(edge, 1.0) * height_mask;
	}
	float streams = sin(UV.x * 850.0 + sin(UV.y * 24.0) * 1.7);
	float flow = sin(UV.y * 175.0 - TIME * 9.0 + streams * 2.0);
	float spray = pow(max(0.0, flow), 3.0) * (streams * 0.25 + 0.75);
	COLOR = vec4(base.rgb + vec3(0.25, 0.51, 0.48) * water * (spray * 0.48 - 0.09), base.a);
}
