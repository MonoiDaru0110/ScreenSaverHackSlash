extends Control

# 各頂点の定義
const CIRCLE_RADIUS := 36.0

# 正三角形の各頂点中心 (上: boost, 左下: size, 右下: speed)
const POS_BOOST := Vector2(130.0, 42.0)
const POS_SIZE := Vector2(65.0, 154.0)
const POS_SPEED := Vector2(195.0, 154.0)

const STAT_ITEMS := [
	{ "id": "boost", "pos": POS_BOOST, "name": "ゴールド・\nトークン" },
	{ "id": "size", "pos": POS_SIZE, "name": "ロゴサイズ" },
	{ "id": "speed", "pos": POS_SPEED, "name": "速度" }
]

var skill_level: int = 1


func _ready() -> void:
	GameData.trinity_changed.connect(queue_redraw)
	GameData.upgrades_changed.connect(queue_redraw)
	GameData.equipment_changed.connect(_on_equipment_changed)
	queue_redraw()


func _process(_delta: float) -> void:
	# 強化フチの発光パルスがあるため、トリニティ発動中は継続して再描画
	if GameData.is_trinity_active() and is_inside_tree() and is_visible_in_tree():
		queue_redraw()


func set_skill_data(sk_data: Dictionary) -> void:
	skill_level = int(sk_data.get("level", 1))
	queue_redraw()


func _on_equipment_changed() -> void:
	skill_level = GameData.get_special_skill_total_level("spec_trinity")
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = event.position
		for item in STAT_ITEMS:
			var center: Vector2 = item["pos"]
			if mouse_pos.distance_to(center) <= CIRCLE_RADIUS + 4.0:
				var stat_id: String = item["id"]
				GameData.set_trinity_sacrificed_stat(stat_id)
				accept_event()
				return


func _draw() -> void:
	var active_stat: String = GameData.trinity_sacrificed_stat
	var is_active := GameData.is_trinity_active()
	var mult_val := GameData.get_trinity_multiplier()
	# 倍率を float (小数第1位) でしっかり表記
	var mult_str := "x%.1f" % mult_val

	# --- 1. 三角形の内部を不透明な領域として描画 ---
	var tri_poly := PackedVector2Array([POS_BOOST, POS_SPEED, POS_SIZE])
	var tri_bg_color := Color(0.12, 0.08, 0.18, 1.0) # 不透明ダークパープル
	draw_colored_polygon(tri_poly, tri_bg_color)

	# --- 2. 三角形のコネクションライン ---
	var line_color := Color(0.45, 0.25, 0.65, 0.75)
	if is_active:
		line_color = Color(0.60, 0.32, 0.85, 0.95)
	draw_line(POS_BOOST, POS_SIZE, line_color, 2.0)
	draw_line(POS_SIZE, POS_SPEED, line_color, 2.0)
	draw_line(POS_SPEED, POS_BOOST, line_color, 2.0)

	# --- 3. 各頂点円の描画 ---
	var time := Time.get_ticks_msec() * 0.001
	var pulse := 0.75 + 0.25 * sin(time * 3.5)

	var font := ThemeDB.fallback_font
	var font_size_title := 12
	var font_size_sub := 13

	for item in STAT_ITEMS:
		var stat_id: String = item["id"]
		var center: Vector2 = item["pos"]
		var is_sacrificed := (is_active and active_stat == stat_id)
		var is_buffed := (is_active and active_stat != stat_id)

		# カラーは通常の紫色をそのまま維持（不透明）
		var bg_color := Color(0.18, 0.11, 0.28, 1.0)
		var border_color := Color(0.55, 0.30, 0.80, 0.85)
		var border_width := 2.0

		if is_sacrificed:
			# 無効化時: フチを赤色で強調
			border_color = Color(0.95, 0.25, 0.30, 0.95)
			border_width = 2.5
			# 赤のグロー
			draw_arc(center, CIRCLE_RADIUS + 3.0, 0, TAU, 32, Color(0.95, 0.25, 0.30, 0.35), 2.0)
		elif is_buffed:
			# 強化時: カラーはそのままで、フチを黄金の発光で強調表示
			border_color = Color(1.0, 0.90, 0.35, 1.0)
			border_width = 2.8
			# 外側グローリング（多重パルス発光）
			draw_arc(center, CIRCLE_RADIUS + 2.0, 0, TAU, 32, Color(1.0, 0.85, 0.25, 0.65 * pulse), 2.5)
			draw_arc(center, CIRCLE_RADIUS + 5.0, 0, TAU, 32, Color(1.0, 0.85, 0.25, 0.38 * pulse), 3.0)
			draw_arc(center, CIRCLE_RADIUS + 8.0, 0, TAU, 32, Color(1.0, 0.85, 0.25, 0.16 * pulse), 3.5)

		# 円背景と枠線
		draw_circle(center, CIRCLE_RADIUS, bg_color)
		draw_arc(center, CIRCLE_RADIUS, 0, TAU, 36, border_color, border_width)

		# --- テキスト描画 ---
		var name_text: String = item["name"]
		var lines := name_text.split("\n")

		if is_buffed:
			# 強化中: 項目名(上寄り) ＋ 倍率表記(下寄り、黄色)
			var y_offset := -10.0 if lines.size() == 1 else -16.0
			for l in lines:
				var str_size := font.get_string_size(l, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_title)
				var text_pos := center + Vector2(-str_size.x / 2.0, y_offset + str_size.y * 0.4)
				draw_string_outline(font, text_pos, l, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_title, 2, Color.BLACK)
				draw_string(font, text_pos, l, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_title, Color(1, 1, 1, 0.95))
				y_offset += 12.0

			# 倍率表記 (例: x2.0, x2.2) - 黄色
			var mult_size := font.get_string_size(mult_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_sub)
			var mult_pos := center + Vector2(-mult_size.x / 2.0, 16.0)
			draw_string_outline(font, mult_pos, mult_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_sub, 3, Color(0.08, 0.04, 0.12, 0.95))
			draw_string(font, mult_pos, mult_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_sub, Color(1.0, 0.93, 0.35, 1.0))
		elif is_sacrificed:
			# 無効化中: 項目名(上寄り) ＋ 「無効」(下寄り、赤色)
			var y_offset := -10.0 if lines.size() == 1 else -16.0
			for l in lines:
				var str_size := font.get_string_size(l, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_title)
				var text_pos := center + Vector2(-str_size.x / 2.0, y_offset + str_size.y * 0.4)
				draw_string_outline(font, text_pos, l, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_title, 2, Color.BLACK)
				draw_string(font, text_pos, l, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_title, Color(0.85, 0.85, 0.85, 0.85))
				y_offset += 12.0

			# 「無効」表記 - 赤色
			var disabled_str := "無効"
			var dis_size := font.get_string_size(disabled_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_sub)
			var dis_pos := center + Vector2(-dis_size.x / 2.0, 16.0)
			draw_string_outline(font, dis_pos, disabled_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_sub, 3, Color(0.08, 0.02, 0.02, 0.95))
			draw_string(font, dis_pos, disabled_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_sub, Color(1.0, 0.35, 0.35, 1.0))
		else:
			# 未選択(通常): 中央揃えでテキスト描画
			var y_offset := -4.0 if lines.size() == 1 else -10.0
			for l in lines:
				var str_size := font.get_string_size(l, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_title)
				var text_pos := center + Vector2(-str_size.x / 2.0, y_offset + str_size.y * 0.4)
				draw_string_outline(font, text_pos, l, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_title, 2, Color.BLACK)
				draw_string(font, text_pos, l, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_title, Color.WHITE)
				y_offset += 13.0
