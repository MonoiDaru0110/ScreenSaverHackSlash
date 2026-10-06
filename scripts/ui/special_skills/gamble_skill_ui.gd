extends Control

const ROULETTE_RADIUS := 96.0 # 80.0 * 1.2
const CENTER_CIRCLE_RADIUS := 33.6 # 28.0 * 1.2
const CENTER := Vector2(120.0, 120.0) # 1.2倍サイズに対応した中央位置
const SECTORS_COUNT := 5 # 5分割 (1, n, n^2, n^3, n^4)

# 倍率・タイマー用フォントサイズ (1.2倍 * 1.5倍 = 1.8倍)
const FONT_SIZE_MULT_NORMAL := 22 # 通常時倍率フォントサイズ (12 * 1.8)
const FONT_SIZE_MULT_SELECTED := 32 # 抽選完了・当選スロット固定拡大フォントサイズ
const FONT_SIZE_TIMER := 24 # タイマーフォントサイズ (13 * 1.8)

# 1倍からn^4倍の順に「緑、青、紫、黄色、赤」
const SECTOR_COLORS: Array[Color] = [
	Color(0.18, 0.58, 0.28, 0.95), # 緑 (1倍)
	Color(0.16, 0.38, 0.82, 0.95), # 青 (n倍)
	Color(0.52, 0.18, 0.76, 0.95), # 紫 (n^2倍)
	Color(0.85, 0.70, 0.12, 0.95), # 黄色 (n^3倍)
	Color(0.85, 0.18, 0.22, 0.95)  # 赤 (n^4倍)
]

var skill_level: int = 1
var wheel_rotation: float = 0.0:
	set(val):
		wheel_rotation = val
		queue_redraw()
var is_spinning: bool = false
var highlight_intensity: float = 0.0

var _spin_tween: Tween = null
var _flash_tween: Tween = null


func _ready() -> void:
	GameData.gamble_changed.connect(_on_gamble_changed)
	GameData.gamble_timer_updated.connect(_on_gamble_timer_updated)
	GameData.equipment_changed.connect(_on_equipment_changed)

	skill_level = GameData.get_special_skill_total_level("spec_gamble")

	var target_slot := GameData.gamble_current_slot
	if GameData.gamble_should_spin_on_ui_ready:
		# スキルレベルが0の状態から正の値になったときのみリール回転演出を実行！
		GameData.gamble_should_spin_on_ui_ready = false
		var target_base := -TAU / 4.0 - (float(target_slot) + 0.5) * (TAU / float(SECTORS_COUNT))
		var turns := 4 + (randi() % 2) # 4〜5回転手前からスタート
		wheel_rotation = target_base - float(turns) * TAU
		call_deferred("_start_spin_animation", target_slot)
	else:
		# それ以外 (HUD更新、トリニティ操作、トークン注入など) は現在位置に静止
		_align_wheel_instant(target_slot)


func _process(_delta: float) -> void:
	# 回転中や発光中は滑らかに再描画
	if is_spinning or highlight_intensity > 0.01:
		queue_redraw()


func set_skill_data(sk_data: Dictionary) -> void:
	skill_level = int(sk_data.get("level", 1))
	queue_redraw()


func _on_equipment_changed() -> void:
	skill_level = GameData.get_special_skill_total_level("spec_gamble")
	queue_redraw()


func _on_gamble_timer_updated(_remaining_seconds: float) -> void:
	queue_redraw()


func _on_gamble_changed(_new_mult: float, target_slot: int, animated: bool) -> void:
	if animated:
		_start_spin_animation(target_slot)
	else:
		_align_wheel_instant(target_slot)


func _align_wheel_instant(slot: int) -> void:
	if is_instance_valid(_spin_tween) and _spin_tween.is_running():
		_spin_tween.kill()
	is_spinning = false
	var target_angle := -TAU / 4.0 - (float(slot) + 0.5) * (TAU / float(SECTORS_COUNT))
	wheel_rotation = fposmod(target_angle, TAU)
	queue_redraw()


func _start_spin_animation(target_slot: int) -> void:
	if not is_inside_tree():
		return

	if is_instance_valid(_spin_tween) and _spin_tween.is_running():
		_spin_tween.kill()

	is_spinning = true
	var target_base := -TAU / 4.0 - (float(target_slot) + 0.5) * (TAU / float(SECTORS_COUNT))
	var turns := 4 + (randi() % 3) # 4〜6回転
	var diff := fposmod(target_base - wheel_rotation, TAU)
	var final_rotation := wheel_rotation + float(turns) * TAU + diff

	_spin_tween = create_tween()
	_spin_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_spin_tween.tween_property(self, "wheel_rotation", final_rotation, 3.2)
	_spin_tween.finished.connect(_on_spin_finished)


func _on_spin_finished() -> void:
	is_spinning = false
	wheel_rotation = fposmod(wheel_rotation, TAU)

	# 当選停止時のフラッシュ発光演出
	if is_instance_valid(_flash_tween) and _flash_tween.is_running():
		_flash_tween.kill()
	highlight_intensity = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "highlight_intensity", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.finished.connect(func(): queue_redraw())
	queue_redraw()


func _draw() -> void:
	var n := GameData.get_gamble_base_multiplier()
	var current_slot := GameData.gamble_current_slot
	var font := ThemeDB.fallback_font

	# --- 1. ルーレット外周シャドウ ---
	draw_circle(CENTER, ROULETTE_RADIUS + 3.0, Color(0.04, 0.02, 0.08, 0.85))

	# --- 2. 5つの扇形セクターの描画 (緑, 青, 紫, 黄色, 赤) ---
	var sector_step := TAU / float(SECTORS_COUNT)

	for i in range(SECTORS_COUNT):
		var start_angle := wheel_rotation + float(i) * sector_step
		var end_angle := start_angle + sector_step

		# 指定された配色
		var base_color: Color = SECTOR_COLORS[i % SECTOR_COLORS.size()]

		# 当選スロットのハイライト (停止時)
		var is_selected := (i == current_slot)
		if is_selected and not is_spinning:
			var flash_tint := base_color.lerp(Color(1.0, 1.0, 0.7, 1.0), highlight_intensity * 0.5)
			base_color = flash_tint

		# 扇形ポリゴンの頂点構築
		var poly_pts := PackedVector2Array()
		poly_pts.append(CENTER)
		var segments := 16
		for s in range(segments + 1):
			var a := lerpf(start_angle, end_angle, float(s) / float(segments))
			poly_pts.append(CENTER + Vector2.from_angle(a) * ROULETTE_RADIUS)

		draw_colored_polygon(poly_pts, base_color)

		# セクター境界ライン (黒系アウトラインで引き締め)
		draw_line(CENTER, CENTER + Vector2.from_angle(start_angle) * ROULETTE_RADIUS, Color(0.08, 0.05, 0.12, 0.85), 2.0)

		# 当選セクターの外枠強調 (停止時)
		if is_selected and not is_spinning:
			var arc_pts := PackedVector2Array()
			for s in range(segments + 1):
				var a := lerpf(start_angle, end_angle, float(s) / float(segments))
				arc_pts.append(CENTER + Vector2.from_angle(a) * (ROULETTE_RADIUS - 1.0))
			draw_polyline(arc_pts, Color(1.0, 0.95, 0.4, 0.9), 3.5)

		# --- 倍率テキストの描画 (1倍, n倍, n^2倍, n^3倍, n^4倍) ---
		var mid_angle := start_angle + sector_step * 0.5
		var text_r := (ROULETTE_RADIUS + CENTER_CIRCLE_RADIUS) * 0.52
		var text_center := CENTER + Vector2.from_angle(mid_angle) * text_r

		var mult_val := pow(float(n), float(i))
		var mult_str: String
		if mult_val < 1000.0:
			mult_str = "x%d" % int(mult_val)
		else:
			mult_str = "x%s" % GameData.format_num(mult_val)

		# 抽選完了時に選ばれた倍率の文字サイズを大きくサイズアップし固定
		var current_font_size: int = FONT_SIZE_MULT_NORMAL
		if is_selected and not is_spinning:
			current_font_size = FONT_SIZE_MULT_SELECTED

		var str_size := font.get_string_size(mult_str, HORIZONTAL_ALIGNMENT_CENTER, -1, current_font_size)
		var local_text_pos := Vector2(-str_size.x * 0.5, str_size.y * 0.35)

		var text_color := Color.WHITE
		if is_selected and not is_spinning:
			text_color = Color(1.0, 1.0, 0.6, 1.0) # 当選時は明るいゴールドの輝き

		# 全て円の直径方向に垂直に配置 (円に対して固定された向き、接線方向)
		var text_rotation := mid_angle + PI / 2.0

		draw_set_transform(text_center, text_rotation, Vector2.ONE)
		draw_string_outline(font, local_text_pos, mult_str, HORIZONTAL_ALIGNMENT_CENTER, -1, current_font_size, 3, Color(0.05, 0.04, 0.08, 0.95))
		draw_string(font, local_text_pos, mult_str, HORIZONTAL_ALIGNMENT_CENTER, -1, current_font_size, text_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- 3. ルーレット外周リング ---
	var border_color := Color(0.40, 0.25, 0.65, 0.9)
	if highlight_intensity > 0.01:
		border_color = border_color.lerp(Color(1.0, 0.90, 0.35, 1.0), highlight_intensity)
	draw_arc(CENTER, ROULETTE_RADIUS, 0, TAU, 64, border_color, 2.5)

	# --- 4. 中心円 (白背景) & タイマー ---
	var center_bg := Color(0.97, 0.97, 0.98, 1.0) # 白
	var center_border := Color(0.28, 0.20, 0.38, 0.85)

	draw_circle(CENTER, CENTER_CIRCLE_RADIUS, center_bg)
	draw_arc(CENTER, CENTER_CIRCLE_RADIUS, 0, TAU, 48, center_border, 2.0)

	# タイマー文字列 (分:秒)
	var timer_val := GameData.gamble_timer
	var minutes := int(timer_val) / 60
	var seconds := int(timer_val) % 60
	var timer_str := "%02d:%02d" % [minutes, seconds]

	var timer_size := font.get_string_size(timer_str, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE_TIMER)
	var timer_pos := CENTER + Vector2(-timer_size.x * 0.5, timer_size.y * 0.35)

	# 白背景のため、通常時は濃い黒色。残り10秒以下は赤点滅
	var timer_color := Color(0.12, 0.10, 0.18, 1.0)
	if timer_val <= 10.0 and timer_val > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
		timer_color = Color(0.90, 0.15, 0.20, 1.0).lerp(Color(0.2, 0.05, 0.05, 1.0), pulse * 0.4)

	draw_string(font, timer_pos, timer_str, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE_TIMER, timer_color)

	# --- 5. 上部指針 (ポインター ▽) ---
	var pointer_tip := CENTER + Vector2(0.0, -ROULETTE_RADIUS + 10.0) # 内側を指す先端
	var pointer_left := CENTER + Vector2(-8.5, -ROULETTE_RADIUS - 10.0)
	var pointer_right := CENTER + Vector2(8.5, -ROULETTE_RADIUS - 10.0)

	var pointer_poly := PackedVector2Array([pointer_tip, pointer_left, pointer_right])
	var pointer_color := Color(1.0, 0.85, 0.25, 1.0) # ゴールド
	var pointer_border := Color(0.15, 0.08, 0.02, 1.0)

	# ポインターシャドウ
	draw_colored_polygon(PackedVector2Array([pointer_tip + Vector2(0, 1.5), pointer_left + Vector2(0, 1.5), pointer_right + Vector2(0, 1.5)]), Color(0, 0, 0, 0.6))
	# ポインター本体
	draw_colored_polygon(pointer_poly, pointer_color)
	draw_polyline(PackedVector2Array([pointer_tip, pointer_left, pointer_right, pointer_tip]), pointer_border, 1.5)
