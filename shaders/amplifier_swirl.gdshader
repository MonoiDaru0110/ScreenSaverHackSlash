shader_type canvas_item;

// Balatro-inspired vibrant dynamic swirling background shader (Gold Yellow & Cyan Light Blue)
uniform vec4 color_gold : source_color = vec4(0.90, 0.65, 0.09, 1.0);
uniform vec4 color_cyan : source_color = vec4(0.05, 0.65, 0.88, 1.0);
uniform vec4 color_mid : source_color = vec4(0.10, 0.20, 0.44, 1.0);
uniform float spin_speed : hint_range(0.0, 5.0) = 0.65;
uniform float swirl_scale : hint_range(1.0, 20.0) = 4.5;
uniform float contrast : hint_range(0.5, 5.0) = 2.5;
uniform float brightness : hint_range(0.2, 1.5) = 0.84;
uniform float pixel_filter : hint_range(100.0, 2000.0) = 650.0;

void fragment() {
	// Subtle pixelation like Balatro's retro paint effect
	vec2 res = vec2(1200.0, 811.0);
	vec2 pix_uv = floor(UV * pixel_filter) / pixel_filter;

	// Normalize coordinates to [-1, 1] with aspect ratio correction
	vec2 uv = (pix_uv - 0.5) * 2.0;
	uv.x *= res.x / res.y;

	float uv_len = length(uv);

	// Polar vortex twist around the center
	float speed = TIME * spin_speed * 0.35 + 302.2;
	float new_pixel_angle = atan(uv.y, uv.x) + speed - 1.8 * (0.75 * uv_len + 0.25);
	vec2 mid = vec2(0.0);
	uv = vec2(uv_len * cos(new_pixel_angle) + mid.x, uv_len * sin(new_pixel_angle) + mid.y);

	// Iterative domain warping (Balatro paint swirl algorithm)
	uv *= swirl_scale;
	float t = TIME * spin_speed;
	vec2 uv2 = vec2(uv.x + uv.y);

	for (int i = 0; i < 5; i++) {
		uv2 += sin(max(uv.x, uv.y)) + uv;
		uv += 0.5 * vec2(
			cos(5.1123314 + 0.353 * uv2.y + t * 0.45),
			sin(uv2.x - 0.183 * t)
		);
		uv -= 1.0 * cos(uv.x + uv.y) - 1.0 * sin(uv.x * 0.711 - uv.y);
	}

	// Calculate paint bands & contrast modulation
	float contrast_mod = (0.25 * contrast + 0.5 * 4.0 + 1.2);
	float paint_res = min(2.0, max(0.0, length(uv) * (0.38 / max(swirl_scale, 1.0)) * contrast_mod));
	float c1p = max(0.0, 1.0 - contrast_mod * abs(1.0 - paint_res));
	float c2p = max(0.0, 1.0 - contrast_mod * abs(paint_res));
	float c3p = 1.0 - min(1.0, c1p + c2p);

	// Blend Amber-Gold, Luminous Cyan, and Deep Twilight Indigo mid-tone
	vec4 ret_col = (0.15 / contrast) * color_gold + (1.0 - 0.15 / contrast) * (
		color_gold * c1p + color_cyan * c2p + color_mid * c3p
	);

	// Subtle edge vignette to ground the window frame
	float vignette = clamp(1.0 - smoothstep(0.65, 1.65, uv_len) * 0.25, 0.0, 1.0);
	COLOR = vec4(ret_col.rgb * vignette * brightness, 1.0);
}
