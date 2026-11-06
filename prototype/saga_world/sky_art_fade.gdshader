shader_type canvas_item;
uniform vec4 upper : source_color;
uniform vec4 lower : source_color;
uniform float aspect_scale = 1.0;

void fragment() {
	float correction = clamp(aspect_scale - 1.0, -0.65, 0.65);
	float y = UV.y + correction * sin((UV.y - 0.5) * TAU) / TAU;
	vec4 art = texture(TEXTURE, vec2(UV.x, y));
	float top = 1.0 - smoothstep(0.0, 0.068, UV.y);
	float bottom = smoothstep(0.932, 1.0, UV.y);
	COLOR = mix(mix(art, upper, top), lower, bottom);
}
