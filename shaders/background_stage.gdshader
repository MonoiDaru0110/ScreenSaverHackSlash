shader_type canvas_item;
render_mode blend_add;

// 背景の段階変化 (テスト用)。段階が上がるごとにレイヤーが累積して派手になる。
// 既存の背景色(Background)の上に加算合成するので、角ヒット時のフラッシュも見える。
// 1:オーロラ / 2:きらめく星 / 3:浮かぶ泡 / 4:斜めレインボーストライプ
// 5:レインボー渦 / 6:回転する光線 (小数は各レイヤーのフェードイン量)
uniform float stage : hint_range(0.0, 6.0) = 0.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform vec2 rect_size = vec2(1662.0, 1080.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

vec3 aurora(vec2 uv, float t) {
	float a = sin(uv.x * 6.0 + t * 0.6 + sin(uv.y * 3.0 + t * 0.3) * 1.5);
	float b = sin(uv.x * 9.0 - t * 0.45 + uv.y * 2.0);
	float band = smoothstep(0.1, 1.0, a) * (1.0 - uv.y * 0.75);
	float band2 = smoothstep(0.3, 1.0, b) * (0.8 - uv.y * 0.6);
	vec3 c1 = mix(vec3(0.1, 0.95, 0.5), vec3(0.45, 0.2, 1.0), clamp(uv.x + sin(t * 0.2) * 0.3, 0.0, 1.0));
	vec3 c2 = vec3(0.1, 0.5, 1.0);
	return c1 * band * 0.55 + c2 * max(band2, 0.0) * 0.35;
}

vec3 stars(vec2 px, float t) {
	float cs = 56.0;
	vec2 g = floor(px / cs);
	vec2 f = fract(px / cs) - 0.5;
	float h = hash21(g);
	vec2 off = (vec2(hash21(g + 3.1), hash21(g + 7.7)) - 0.5) * 0.6;
	vec2 p = f - off;
	float tw = 0.5 + 0.5 * sin(t * (1.0 + h * 3.0) + h * 40.0);
	float size = 0.4 + 0.6 * hash21(g + 1.9);
	float core = exp(-length(p) * 28.0 / size);
	float cr = exp(-abs(p.x) * 70.0) * exp(-abs(p.y) * 7.0 / size)
		+ exp(-abs(p.y) * 70.0) * exp(-abs(p.x) * 7.0 / size);
	vec3 c = hsv2rgb(vec3(fract(h * 3.0 + 0.1), 0.35, 1.0));
	return c * (core + cr * 0.8) * tw * step(0.45, h);
}

vec3 bubbles(vec2 px, float t) {
	vec2 q = px + vec2(0.0, t * 40.0);
	float cs = 110.0;
	vec2 g = floor(q / cs);
	vec2 f = fract(q / cs) - 0.5;
	float h = hash21(g + 11.0);
	vec2 off = (vec2(hash21(g + 2.3), hash21(g + 9.1)) - 0.5) * 0.4;
	float r = 0.15 + 0.2 * hash21(g + 4.4);
	float d = length(f - off);
	float ring = exp(-abs(d - r) * 45.0);
	float fill = smoothstep(r, 0.0, d) * 0.12;
	vec3 c = hsv2rgb(vec3(fract(h + t * 0.03), 0.6, 1.0));
	return c * (ring * 0.7 + fill) * step(0.35, h);
}

vec3 stripes(vec2 uv, float t) {
	float s = fract((uv.x * 1.6 + uv.y) * 2.2 - t * 0.12);
	return hsv2rgb(vec3(s, 0.85, 1.0)) * 0.22;
}

vec3 swirl(vec2 uv, float t) {
	vec2 p = (uv - 0.5) * vec2(rect_size.x / rect_size.y, 1.0);
	float ang = atan(p.y, p.x) / 6.28318;
	float hue = fract(ang + length(p) * 0.8 - t * 0.06);
	return hsv2rgb(vec3(hue, 0.8, 1.0)) * 0.2;
}

vec3 rays(vec2 uv, float t) {
	vec2 p = (uv - 0.5) * vec2(rect_size.x / rect_size.y, 1.0);
	float ang = atan(p.y, p.x);
	float r = pow(0.5 + 0.5 * sin(ang * 14.0 + t * 0.6), 3.0);
	float fade = clamp(1.15 - length(p) * 1.1, 0.0, 1.0);
	vec3 c = hsv2rgb(vec3(fract(t * 0.05), 0.5, 1.0));
	return c * r * fade * 0.3;
}

void fragment() {
	vec2 px = UV * rect_size;
	float s = clamp(stage, 0.0, 6.0);
	float t = TIME;
	vec3 col = vec3(0.0);

	col += aurora(UV, t) * clamp(s, 0.0, 1.0);
	col += stars(px, t) * 0.9 * clamp(s - 1.0, 0.0, 1.0);
	col += bubbles(px, t) * 0.7 * clamp(s - 2.0, 0.0, 1.0);
	col += stripes(UV, t) * clamp(s - 3.0, 0.0, 1.0);
	col += swirl(UV, t) * clamp(s - 4.0, 0.0, 1.0);
	col += rays(UV, t) * clamp(s - 5.0, 0.0, 1.0);

	COLOR = vec4(col * brightness, 1.0);
}
