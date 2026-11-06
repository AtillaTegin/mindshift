shader_type canvas_item;
uniform vec4 upper : source_color;
uniform vec4 lower : source_color;
uniform bool waterway = false;

void fragment() {
	float t = UV.y;
	vec3 sky = mix(upper.rgb, lower.rgb, smoothstep(0.0, 1.0, t));
	float shape = sin(UV.x * 8.0 - TIME * 0.3) + 0.4 * sin(UV.x * 19.0 + TIME * 0.21);
	float center = 0.46 + shape * 0.13;
	float bank = 1.0 - smoothstep(0.06, 0.37, abs(t - center));
	float envelope = sin(PI * t);
	vec3 cloud = mix(sky, vec3(0.88, 0.91, 1.0), bank * 0.55 * envelope);
	if (waterway) {
		float flow = 1.0 - smoothstep(0.01, 0.07, abs(t - center - 0.15));
		cloud = mix(cloud, vec3(0.35, 0.91, 0.93), flow * envelope * 0.33);
	}
	COLOR = vec4(cloud, 1.0);
}
