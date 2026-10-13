shader_type canvas_item;

uniform vec4 bg_top_color : source_color = vec4(0.038, 0.016, 0.078, 1.0);
uniform vec4 bg_bottom_color : source_color = vec4(0.088, 0.035, 0.155, 1.0);
uniform vec4 nebula_color_1 : source_color = vec4(0.32, 0.10, 0.48, 0.22);
uniform vec4 nebula_color_2 : source_color = vec4(0.18, 0.06, 0.35, 0.18);

// 2D Hash function
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 2D value noise for nebula clouds & veil waves
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i + vec2(0.0, 0.0)), hash1(i + vec2(1.0, 0.0)), u.x),
			   mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	vec2 shift = vec2(100.0);
	mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.5)));
	for (int i = 0; i < 3; ++i) {
		v += a * noise(p);
		p = rot * p * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

// Ethereal Aurora Veil curtain simulation (Purple celestial veil)
vec3 aurora_veil(vec2 uv, float time) {
	vec3 total_aurora = vec3(0.0);
	
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float speed = 0.10 + fi * 0.04;
		float t = time * speed;
		
		float wave1 = sin(uv.x * (2.0 + fi * 0.8) + t + fi * 1.8) * 0.10;
		float wave2 = cos(uv.x * (3.5 - fi * 0.4) - t * 0.8 + fi * 2.5) * 0.06;
		float n_disp = noise(vec2(uv.x * 2.5 + t * 0.3, fi * 8.0)) * 0.08;
		
		float base_y = 0.22 + fi * 0.18 + wave1 + wave2 + n_disp;
		float dist_y = uv.y - base_y;
		
		float ray_noise = noise(vec2(uv.x * (14.0 + fi * 5.0) + t * 0.5, uv.y * 2.5));
		float rays = mix(0.75, 1.25, ray_noise);
		
		float veil_height = 0.35;
		if (dist_y > -0.05 && dist_y < veil_height) {
			float norm_y = clamp((dist_y + 0.05) / (veil_height + 0.05), 0.0, 1.0);
			float intensity = sin(norm_y * 3.14159) * pow(1.0 - norm_y, 0.45) * rays;
			
			vec3 ribbon_color;
			if (i == 0) {
				ribbon_color = vec3(0.52, 0.20, 0.68); // Soft Purple Veil
			} else if (i == 1) {
				ribbon_color = vec3(0.32, 0.14, 0.52); // Deep Royal Violet
			} else {
				ribbon_color = vec3(0.22, 0.30, 0.52); // Night Indigo
			}
			
			total_aurora += ribbon_color * (intensity * (0.28 - fi * 0.05));
		}
	}
	
	return total_aurora;
}

// Render sparse star field with controlled density
float star_layer(vec2 uv, float grid_size, float time_speed, float min_twinkle, float max_size, float spawn_threshold, float time) {
	vec2 grid_uv = uv * grid_size;
	vec2 id = floor(grid_uv);
	vec2 gv = fract(grid_uv) - 0.5;
	
	float stars = 0.0;
	
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 neighbor_id = id + offset;
			vec2 h = hash2(neighbor_id);
			
			if (h.x < spawn_threshold) {
				continue;
			}
			
			vec2 star_pos = offset + (h - 0.5) * 0.75;
			float dist = length(gv - star_pos);
			
			float twinkle_phase = h.x * 6.28318 + time * (time_speed * (0.6 + h.y * 1.4));
			float twinkle = mix(min_twinkle, 1.0, 0.5 + 0.5 * sin(twinkle_phase));
			
			float star_radius = (0.014 + h.y * 0.030) * max_size;
			float core = smoothstep(star_radius, 0.0, dist);
			float glow = (star_radius * 0.40) / (dist + 0.007);
			
			vec2 delta = abs(gv - star_pos);
			float spike = max(0.0, 1.0 - (delta.x + delta.y * 4.0) * 14.0) +
						  max(0.0, 1.0 - (delta.x * 4.0 + delta.y) * 14.0);
			spike *= step(0.75, h.x) * 0.4;
			
			stars += (core + glow * 0.45 + spike) * twinkle;
		}
	}
	return stars;
}

// Shooting star / meteor trail
float shooting_star(vec2 uv, float time) {
	float t = time * 0.30;
	float cycle = floor(t);
	float progress = fract(t);
	
	vec2 seed = vec2(cycle, 73.0);
	vec2 start = vec2(hash1(seed) * 0.7 + 0.15, hash1(seed + 1.0) * 0.35);
	vec2 dir = normalize(vec2(-0.85 - hash1(seed + 2.0) * 0.3, 0.5 + hash1(seed + 3.0) * 0.35));
	
	float meteor_active = step(0.1, progress) * step(progress, 0.35);
	float p = (progress - 0.1) / 0.25;
	
	vec2 current_pos = start + dir * p * 0.95;
	vec2 to_star = uv - current_pos;
	
	float along = dot(to_star, -dir);
	float perp = length(to_star - along * (-dir));
	
	float trail_len = 0.16;
	float trail = smoothstep(trail_len, 0.0, along) * step(0.0, along);
	float width = smoothstep(0.003, 0.0, perp);
	
	return trail * width * meteor_active * 1.5;
}

void fragment() {
	vec2 uv = UV;
	float time = TIME;
	
	// Cosmic Purple Night Sky Base Gradient
	vec4 base_color = mix(bg_top_color, bg_bottom_color, uv.y);
	
	// Subtle purple cosmic nebula flow
	vec2 nebula_uv1 = uv * 2.0 + vec2(time * 0.010, time * 0.006);
	vec2 nebula_uv2 = uv * 2.5 - vec2(time * 0.012, -time * 0.008);
	float neb1 = fbm(nebula_uv1);
	float neb2 = fbm(nebula_uv2);
	vec4 neb_glow = nebula_color_1 * (neb1 * 1.1) + nebula_color_2 * (neb2 * 0.9);
	
	// Soft Drifting Purple Aurora Veil
	vec3 aurora = aurora_veil(uv, time);
	
	// Multi-layer Starfield with independent swaying directions
	// Layer 1 (Far background): Slow horizontal/slight vertical sway
	vec2 sway1 = vec2(sin(time * 0.22) * 0.014, cos(time * 0.18) * 0.008);
	vec2 uv_layer1 = uv + sway1;
	float s1 = star_layer(uv_layer1, 32.0, 1.1, 0.2, 0.65, 0.65, time);
	
	// Layer 2 (Mid-ground): Diagonal sway in a different direction and speed
	vec2 sway2 = vec2(cos(time * 0.32 + 1.4) * 0.022, sin(time * 0.28 + 0.7) * 0.016);
	vec2 uv_layer2 = uv + sway2;
	float s2 = star_layer(uv_layer2, 18.0, 1.5, 0.3, 1.05, 0.70, time + 14.0);
	
	// Layer 3 (Foreground): Elliptical floating sway in the opposite direction
	vec2 sway3 = vec2(-sin(time * 0.38 + 2.5) * 0.028, cos(time * 0.34 + 1.8) * 0.022);
	vec2 uv_layer3 = uv + sway3;
	float s3 = star_layer(uv_layer3, 9.0, 1.8, 0.35, 1.40, 0.75, time + 29.0);
	
	vec3 star_color_1 = vec3(0.88, 0.86, 0.96) * s1 * 0.30;
	vec3 star_color_2 = vec3(0.92, 0.90, 1.0) * s2 * 0.45;
	vec3 star_color_3 = vec3(0.96, 0.94, 1.0) * s3 * 0.58;
	
	// Shooting stars
	float meteor = shooting_star(uv, time);
	vec3 meteor_color = vec3(0.92, 0.90, 0.98) * meteor * 0.60;
	
	vec3 final_rgb = base_color.rgb + neb_glow.rgb * neb_glow.a + aurora + star_color_1 + star_color_2 + star_color_3 + meteor_color;
	
	COLOR = vec4(final_rgb, 1.0);
}
