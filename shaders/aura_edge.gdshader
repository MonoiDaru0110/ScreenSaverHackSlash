shader_type canvas_item;
render_mode blend_add;

// オーラ: 画面のフチを「物質的」に覆うエフェクト (テスト用)。
// aura_type: 0=炎 / 1=氷 / 2=雷 / 3=光
uniform vec2 rect_size = vec2(1662.0, 1080.0);
uniform int aura_type : hint_range(0, 3) = 0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width = 170.0;
uniform float pulse_speed = 1.2;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(11.7, 5.3);
		a *= 0.5;
	}
	return v;
}

// e: 最寄りのフチまでの距離(px) / along: そのフチに沿った座標(辺ごとにオフセット)
void edge_info(vec2 px, out float e, out float along) {
	float l = px.x;
	float r = rect_size.x - px.x;
	float t = px.y;
	float b = rect_size.y - px.y;
	e = l; along = px.y;
	if (r < e) { e = r; along = px.y + 500.0; }
	if (t < e) { e = t; along = px.x + 1000.0; }
	if (b < e) { e = b; along = px.x + 1500.0; }
}

vec3 fire(float e, float along, float t) {
	float n = fbm(vec2(along * 0.011, e * 0.018 - t * 1.6));
	float n2 = fbm(vec2(along * 0.03 + 7.0, e * 0.04 - t * 3.2));
	float h = edge_width * (0.25 + 1.15 * n);
	float f = clamp(1.0 - e / h, 0.0, 1.0);
	f = pow(f, 0.8) * (0.75 + 0.5 * n2);
	vec3 c = vec3(1.0, 0.22, 0.02) * f * 1.5;
	c += vec3(1.0, 0.65, 0.08) * pow(f, 2.5) * 1.3;
	c += vec3(1.0, 0.95, 0.7) * pow(f, 6.0);
	return c;
}

vec3 ice(vec2 px, float e, float along, float t) {
	float cell = along * 0.032;
	float tri = abs(fract(cell) - 0.5) * 2.0;
	float h = edge_width * (0.4 + 0.8 * hash21(vec2(floor(cell), 3.0))) * (1.0 - tri);
	float body = smoothstep(0.0, 14.0, h - e);
	float rim = exp(-abs(h - e) * 0.22) * step(2.0, h);
	float glow = exp(-e / (edge_width * 0.7)) * 0.45;
	vec3 c = vec3(0.25, 0.75, 1.0) * (body * 0.55 + glow);
	c += vec3(0.85, 0.97, 1.0) * rim * 0.9;
	// きらめき
	vec2 sc = floor(px / 18.0);
	float tw = pow(max(0.0, sin(t * 3.0 + hash21(sc) * 60.0)), 12.0);
	c += vec3(1.0) * tw * step(0.93, hash21(sc + 5.0)) * (body + glow);
	return c;
}

vec3 lightning(float e, float along, float t) {
	float seg = floor(t * 14.0);
	float strike = step(0.3, hash21(vec2(seg, 1.0)));
	float path = (fbm(vec2(along * 0.02, seg * 3.1)) - 0.5) * edge_width * 1.3 + edge_width * 0.5;
	float d = abs(e - path);
	float path2 = (fbm(vec2(along * 0.035 + 20.0, seg * 1.7)) - 0.5) * edge_width * 1.0 + edge_width * 0.25;
	float d2 = abs(e - path2);
	float bolt = exp(-d * 0.3) * strike + exp(-d2 * 0.5) * strike * 0.6;
	float core = (exp(-d * 1.3) + exp(-d2 * 1.6) * 0.6) * strike;
	float glow = exp(-e / (edge_width * 0.7)) * 0.4 * (0.6 + 0.4 * hash21(vec2(seg, 2.0)));
	return vec3(0.4, 0.45, 1.0) * (bolt * 1.1 + glow) + vec3(1.0) * core * 1.4;
}

// 注意: light() は canvas_item の予約関数名なので使えない
vec3 holy_glow(float e) {
	float core = exp(-e / (edge_width * 0.35));
	float halo = exp(-e / (edge_width * 1.2)) * 0.35;
	return vec3(1.0, 0.82, 0.35) * (core + halo) * 0.8;
}

void fragment() {
	vec2 px = UV * rect_size;
	float t = TIME;
	float e;
	float along;
	edge_info(px, e, along);

	vec3 c;
	if (aura_type == 0) {
		c = fire(e, along, t);
	} else if (aura_type == 1) {
		c = ice(px, e, along, t);
	} else if (aura_type == 2) {
		c = lightning(e, along, t);
	} else {
		c = holy_glow(e);
	}
	// 加算合成で白飛びしないようにトーンマップ
	c = vec3(1.0) - exp(-c * 1.1);
	float pulse = 0.85 + 0.15 * sin(t * pulse_speed);
	COLOR = vec4(c * pulse * strength, 1.0);
}

