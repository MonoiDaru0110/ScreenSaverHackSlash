extends Control

# 2時の位置から時計回り順
const RARITY_ORDER := ["コモン", "アンコモン", "レア", "エピック", "レジェンド", "ミシック"]

# 各角度 (2時=-30°, 4時=30°, 6時=90°, 8時=150°, 10時=-150°, 12時=-90°)
const ANGLES_DEG := [-30.0, 30.0, 90.0, 150.0, -150.0, -90.0]

@onready var hex_draw_control: Control = %HexDrawControl
@onready var multiplier_label: Label = %MultiplierLabel

var skill_level: int = 1
var is_mult_active: bool = false


func _ready() -> void:
	GameData.upgrades_changed.connect(update_ui)
	GameData.equipment_changed.connect(update_ui)
	if hex_draw_control:
		hex_draw_control.draw.connect(_on_hex_draw)
	update_ui()


func _process(_delta: float) -> void:
	# 倍率発動中はコロナおよび倍率文字のパルスアニメーションのために毎フレーム更新
	if is_mult_active and is_inside_tree() and is_visible_in_tree():
		if hex_draw_control:
			hex_draw_control.queue_redraw()
		_update_text_glow_effect()


func set_skill_data(sk_data: Dictionary) -> void:
	skill_level = int(sk_data.get("level", 1))
	update_ui()


func update_ui() -> void:
	if not is_inside_tree():
		return

	var mult := GameData.get_diversity_multiplier()
	is_mult_active = (mult > 1.0)

	if multiplier_label:
		if is_mult_active:
			multiplier_label.text = "x" + GameData.format_num(mult)
		else:
			multiplier_label.text = "x1"
			# 未発動時のシックなフォントスタイル
			multiplier_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75, 0.9))
			multiplier_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
			multiplier_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
			multiplier_label.add_theme_constant_override("outline_size", 3)
			multiplier_label.add_theme_constant_override("shadow_outline_size", 0)

	if is_mult_active:
		_update_text_glow_effect()

	if hex_draw_control:
		hex_draw_control.queue_redraw()


func _update_text_glow_effect() -> void:
	if not multiplier_label or not is_mult_active:
		return

	var time := Time.get_ticks_msec() * 0.001
	var glow_pulse := 0.5 + 0.5 * sin(time * 2.2) # 0.0 ~ 1.0

	# 文字が潰れないクッキリ白金ゴールド色 ＋ シャープな黒フチ
	var core_color := Color(1.0, 0.93, 0.35, 1.0)
	var sharp_outline := Color(0.08, 0.04, 0.12, 0.95)

	# 優しく透過する裏側ネオングロー
	var glow_shadow_color := Color(1.0, 0.65, 0.1, 0.4 + 0.3 * glow_pulse)

	multiplier_label.add_theme_color_override("font_color", core_color)
	multiplier_label.add_theme_color_override("font_outline_color", sharp_outline)
	multiplier_label.add_theme_color_override("font_shadow_color", glow_shadow_color)
	
	multiplier_label.add_theme_constant_override("outline_size", 3)
	multiplier_label.add_theme_constant_override("shadow_offset_x", 0)
	multiplier_label.add_theme_constant_override("shadow_offset_y", 0)
	# 2倍サイズに合わせてグローシャドウ幅調整 (5px ~ 9px)
	multiplier_label.add_theme_constant_override("shadow_outline_size", int(5 + 4 * glow_pulse))


func _on_hex_draw() -> void:
	if not hex_draw_control:
		return

	var center := hex_draw_control.size / 2.0
	var hex_radius := 80.0       # 2倍の六角形配置半径 (旧40.0)
	var ball_radius := 22.0      # 2倍の玉のサイズ (旧11.0)
	var bg_radius := 116.0       # 2倍の円形背景半径 (旧58.0)

	var time := Time.get_ticks_msec() * 0.001

	# --- 1. 倍率発動時の太陽コロナ（Corona）アニメーション描画 ---
	if is_mult_active:
		var pulse := 0.5 + 0.5 * sin(time * 2.2)
		var num_rays := 36
		var corona_points := PackedVector2Array()

		for i in range(num_rays + 1):
			var angle := (float(i) / float(num_rays)) * TAU + (time * 0.15)
			var ray_wave := sin(angle * 7.0 + time * 3.5) * 8.0 * (0.6 + 0.4 * pulse)
			var r := bg_radius + 3.0 + ray_wave
			corona_points.append(center + Vector2(cos(angle), sin(angle)) * r)

		# コロナの外輪光彩描画 (透過を高めた上品な光)
		var corona_alpha := 0.2 + 0.25 * pulse
		var corona_color := Color(1.0, 0.75, 0.2, corona_alpha)
		hex_draw_control.draw_polyline(corona_points, corona_color, 6.0)

		# 内側のサブアストラル光彩
		var inner_corona_color := Color(0.85, 0.35, 1.0, corona_alpha * 0.7)
		hex_draw_control.draw_polyline(corona_points, inner_corona_color, 3.0)

	# --- 2. 円形背景の描画 (透過を大幅に強化: alpha 0.35) ---
	var bg_color := Color(0.05, 0.03, 0.10, 0.35) # 高透過背景
	var border_color := Color(0.85, 0.45, 1.0, 0.55) # 半透明アストラル外枠
	if is_mult_active:
		var pulse_b := 0.5 + 0.3 * sin(time * 2.2)
		border_color = Color(1.0, 0.8, 0.3, pulse_b)

	hex_draw_control.draw_circle(center, bg_radius, bg_color)
	hex_draw_control.draw_arc(center, bg_radius, 0, TAU, 64, border_color, 3.0)

	# --- 3. レア度別ベースカラーによる玉（宝石アイコン）の描画 ---
	var active_rarities := GameData.get_equipped_unique_rarities()

	for i in range(RARITY_ORDER.size()):
		var rarity: String = RARITY_ORDER[i]
		var deg: float = ANGLES_DEG[i]
		var rad := deg_to_rad(deg)
		var pos := center + Vector2(cos(rad), sin(rad)) * hex_radius

		var is_active := active_rarities.has(rarity)
		var std_color := GameData.get_rarity_color(rarity)

		if is_active:
			# 発光状態（鮮やかな標準色 ＋ 輝く光輝線）
			hex_draw_control.draw_circle(pos, ball_radius + 5.0, std_color.lightened(0.4) * Color(1, 1, 1, 0.45))
			hex_draw_circle_safe(pos, ball_radius, std_color)
			hex_draw_control.draw_arc(pos, ball_radius + 2.0, 0, TAU, 32, Color.WHITE, 2.0)
		else:
			# 各レアリティ独自の標準色をベースにしたグレーアウト表示（透過を強めた暗色）
			var dimmed_bg := Color(std_color.r * 0.2 + 0.03, std_color.g * 0.2 + 0.03, std_color.b * 0.2 + 0.03, 0.45)
			var dimmed_border := Color(std_color.r * 0.4 + 0.06, std_color.g * 0.4 + 0.06, std_color.b * 0.4 + 0.06, 0.55)
			
			hex_draw_control.draw_circle(pos, ball_radius, dimmed_bg)
			hex_draw_control.draw_arc(pos, ball_radius, 0, TAU, 32, dimmed_border, 1.5)


func hex_draw_circle_safe(pos: Vector2, r: float, c: Color) -> void:
	if hex_draw_control:
		hex_draw_control.draw_circle(pos, r, c)
