shader_type canvas_item;

float temple(vec2 p, float columns, float baseline, float seed) {
	float cell = floor(p.x * columns);
	float x = abs(fract(p.x * columns) - 0.5);
	float h = 0.039 + 0.074 * fract(sin(cell * 7.13 + seed) * 132.37);
	float roof = baseline - h + pow(x * 2.0, 1.8) * h * 0.67;
	return step(x, 0.43) * step(roof, p.y) * step(p.y, baseline);
}

void fragment() {
	vec2 p = UV;
	vec3 sky = mix(vec3(0.91, 0.70, 0.48), vec3(1.0, 0.94, 0.79), smoothstep(0.0, 0.43, p.y));
	vec2 sun = (p - vec2(0.70, 0.245)) * vec2(1.0, 1.9);
	float radius = length(sun);
	sky += vec3(0.12, 0.09, 0.032) * (1.0 - smoothstep(0.043, 0.18, radius));
	float halo = 1.0 - smoothstep(0.001, 0.004, abs(radius - 0.075));
	sky = mix(sky, vec3(1.0, 0.98, 0.85), 0.27 * halo * (0.7 + 0.3 * sin(atan(sun.y, sun.x) - TIME * 0.08)));
	sky = mix(sky, vec3(1.0, 0.96, 0.77), 1.0 - smoothstep(0.034, 0.036, radius));
	sky = mix(sky, vec3(0.63, 0.42, 0.29), temple(p, 13.0, 0.39, 4.0) * 0.26);
	sky = mix(sky, vec3(0.49, 0.31, 0.24), temple(p + vec2(0.04, 0.0), 8.0, 0.414, 1.0) * 0.33);
	float waves = pow(max(0.0, sin(p.y * 360.0 + sin(p.x * 24.0 - TIME * 0.75) * 1.8 - TIME * 0.55)), 6.0);
	vec3 river = mix(vec3(0.76, 0.81, 0.68), vec3(0.58, 0.72, 0.66), smoothstep(0.41, 0.73, p.y));
	river += waves * vec3(0.12, 0.11, 0.07) * exp(-abs(p.x - 0.70) * 4.0);
	vec3 stone = mix(vec3(0.88, 0.78, 0.60), vec3(0.74, 0.62, 0.45), smoothstep(0.59, 1.0, p.y));
	float steps = step(0.96, fract(p.y * 38.0));
	stone += steps * 0.09;
	vec3 scene = mix(sky, river, smoothstep(0.413, 0.419, p.y));
	scene = mix(scene, stone, smoothstep(0.627, 0.631, p.y));
	float edge = smoothstep(0.25, 0.59, abs(p.x - 0.5));
	COLOR = vec4(scene * (1.0 - 0.18 * edge), 1.0);
}
