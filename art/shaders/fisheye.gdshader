shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 2.0) = 0.85;

void fragment() {
	vec2 uv = SCREEN_UV * 2.0 - 1.0;
	float r = length(uv);
	float distortion = 1.0 + strength * r * r;
	vec2 distorted = uv / distortion;
	vec2 remapped = distorted * 0.5 + 0.5;
	COLOR = texture(SCREEN_TEXTURE, remapped);
}
