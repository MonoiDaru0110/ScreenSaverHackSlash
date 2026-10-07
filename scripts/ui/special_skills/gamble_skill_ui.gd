extends Control

const ROULETTE_RADIUS := 96.0 # 80.0 * 1.2
const BORDER_WIDTH := 21.0 # ルーレット本体の半径の1/4〜1/5 (太いフチ)
const CENTER_CIRCLE_RADIUS := 33.6 # 28.0 * 1.2
const CENTER := Vector2(130.0, 135.0) # 太いフチ・大型ピンに対応した中央位置
const SECTORS_COUNT := 5 # 5分割 (1, n, n^2, n^3, n^4)

# 倍率・タイマー用フォントサイズ (1.2倍 * 1.5倍 = 1.8倍)
const FONT_SIZE_MULT_NORMAL := 22 # 通常時倍率フォントサイズ (12 * 1.8)
const FONT_SIZE_MULT_SELECTED := 32 # 抽選完了・当選スロット固定拡大フォントサイズ
const FONT_SIZE_TIMER := 24 # タイマーフォントサイズ (13 * 1.8)

# 「多様性」UIのカラー (アンコモン以上の部分のカラー: アンコモン, レア, エピック, レジェンド, ミシック)
const RARITY_KEYS: Array[String] = [
	"アンコモン", # 1倍 (緑)
	"レア",       # n倍 (青)
	"エピック",   # n^2倍 (紫)
	"レジェンド", # n^3倍 (オレンジ)
	"ミシック"    # n^4倍 (赤)
]

var skill_level: int = 1
var wheel_rotation: float = 0.0:
	set(val):
		wheel_rotation = val
		queue_redraw()
var is_spinning: bool = false
var highlight_intensity: float = 0.0
var selected_text_scale: float = 1.0

var _spin_tween: Tween = null
var _flash_tween: Tween = null
var _bounce_tween: Tween = null


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
	# 回転中や当選エリアのゆっくり発光のため、アクティブ時は毎フレーム滑らかに再描画
	if is_inside_tree() and is_visible_in_tree():
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
	if is_instance_valid(_bounce_tween) and _bounce_tween.is_running():
		_bounce_tween.kill()
	is_spinning = false
	selected_text_scale = 1.0
	var target_angle := -TAU / 4.0 - (float(slot) + 0.5) * (TAU / float(SECTORS_COUNT))
	wheel_rotation = fposmod(target_angle, TAU)
	queue_redraw()


func _start_spin_animation(target_slot: int) -> void:
	if not is_inside_tree():
		return

	if is_instance_valid(_spin_tween) and _spin_tween.is_running():
		_spin_tween.kill()
	if is_instance_valid(_bounce_tween) and _bounce_tween.is_running():
		_bounce_tween.kill()

	is_spinning = true
	selected_text_scale = 1.0
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

	# 当選文字のバウンスアニメーション (滑らかにポップしてバウンス拡大し固定)
	if is_instance_valid(_bounce_tween) and _bounce_tween.is_running():
		_bounce_tween.kill()
	selected_text_scale = 0.65
	_bounce_tween = create_tween()
	_bounce_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(self, "selected_text_scale", 1.0, 0.55)

	# 当選停止時の初期フラッシュ発光
	if is_instance_valid(_flash_tween) and _flash_tween.is_running():
		_flash_tween.kill()
	highlight_intensity = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "highlight_intensity", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _draw() -> void:
	var n := GameData.get_gamble_base_multiplier()
	var current_slot := GameData.gamble_current_slot
	var font := ThemeDB.fallback_font
	var time := Time.get_ticks_msec() * 0.001
	var glow_pulse := 0.5 + 0.5 * sin(time * 2.5) # 0.0 ~ 1.0 ゆっくり発光用パルス

	var outer_ring_radius := ROULETTE_RADIUS + BORDER_WIDTH
	var border_mid_radius := ROULETTE_RADIUS + BORDER_WIDTH * 0.5

	# --- 1. ルーレット外周シャドウ ---
	draw_circle(CENTER, outer_ring_radius + 4.0, Color(0.03, 0.02, 0.06, 0.85))

	# --- 2. 5つの扇形セクターの描画 (「多様性」UIのアンコモン〜ミシックカラー) ---
	var sector_step := TAU / float(SECTORS_COUNT)

	for i in range(SECTORS_COUNT):
		var start_angle := wheel_rotation + float(i) * sector_step
		var end_angle := start_angle + sector_step

		# 「多様性」UIのレア度別カラー (アンコモン, レア, エピック, レジェンド, ミシック)
		var rarity_name: String = RARITY_KEYS[i % RARITY_KEYS.size()]
		var base_color: Color = GameData.get_rarity_color(rarity_name)
		base_color.a = 0.92

		var is_selected := (i == current_slot)

		# 有効エリアのゆっくり発光 (回転完了しビジュアル決定されたタイミングで実行)
		if is_selected and not is_spinning:
			var flash_add := highlight_intensity * 0.35
			var pulse_val := (0.25 + 0.25 * glow_pulse) + flash_add
			base_color = base_color.lerp(Color(1.0, 1.0, 0.88, 1.0), clampf(pulse_val, 0.0, 1.0))

		# 扇形ポリゴンの頂点構築
		var poly_pts := PackedVector2Array()
		poly_pts.append(CENTER)
		var segments := 16
		for s in range(segments + 1):
			var a := lerpf(start_angle, end_angle, float(s) / float(segments))
			poly_pts.append(CENTER + Vector2.from_angle(a) * ROULETTE_RADIUS)

		draw_colored_polygon(poly_pts, base_color)

		# セクター境界ライン (落ち着いた黒系ライン)
		draw_line(CENTER, CENTER + Vector2.from_angle(start_angle) * ROULETTE_RADIUS, Color(0.06, 0.04, 0.10, 0.85), 2.0)

		# 有効エリアの境界・外枠パルス発光 (停止時)
		if is_selected and not is_spinning:
			var arc_pts := PackedVector2Array()
			for s in range(segments + 1):
				var a := lerpf(start_angle, end_angle, float(s) / float(segments))
				arc_pts.append(CENTER + Vector2.from_angle(a) * (ROULETTE_RADIUS - 1.0))
			var arc_glow := Color(1.0, 0.95, 0.55, 0.70 + 0.30 * glow_pulse)
			draw_polyline(arc_pts, arc_glow, 3.5)
			# 両脇の境界線も明るく発光
			draw_line(CENTER, CENTER + Vector2.from_angle(start_angle) * ROULETTE_RADIUS, Color(1.0, 0.95, 0.6, 0.55 * glow_pulse), 2.2)
			draw_line(CENTER, CENTER + Vector2.from_angle(end_angle) * ROULETTE_RADIUS, Color(1.0, 0.95, 0.6, 0.55 * glow_pulse), 2.2)

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

		# 抽選完了時に選ばれた倍率の文字サイズを大きくサイズアップし固定 (32)
		var current_font_size: int = FONT_SIZE_MULT_NORMAL
		var text_scale := 1.0
		if is_selected and not is_spinning:
			current_font_size = FONT_SIZE_MULT_SELECTED
			text_scale = selected_text_scale # バウンスアニメーションスケール

		var str_size := font.get_string_size(mult_str, HORIZONTAL_ALIGNMENT_CENTER, -1, current_font_size)
		var local_text_pos := Vector2(-str_size.x * 0.5, str_size.y * 0.35)

		var text_color := Color.WHITE
		if is_selected and not is_spinning:
			# 当選時はゴールド＋ゆっくり脈動
			text_color = Color(1.0, 0.95, 0.45, 1.0).lerp(Color(1.0, 1.0, 0.85, 1.0), glow_pulse * 0.4)

		# 円の直径方向に垂直に配置 (円に対して固定された向き、接線方向)
		var text_rotation := mid_angle + PI / 2.0

		draw_set_transform(text_center, text_rotation, Vector2(text_scale, text_scale))
		draw_string_outline(font, local_text_pos, mult_str, HORIZONTAL_ALIGNMENT_CENTER, -1, current_font_size, 3, Color(0.05, 0.04, 0.08, 0.95))
		draw_string(font, local_text_pos, mult_str, HORIZONTAL_ALIGNMENT_CENTER, -1, current_font_size, text_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- 3. ルーレット外周の太いフチ (太さ約21px、金色をイメージしたオレンジ色) ---
	var gold_orange := Color(0.96, 0.62, 0.14, 1.0)
	var gold_bright := Color(1.0, 0.84, 0.38, 1.0)
	var bronze_dark := Color(0.65, 0.36, 0.05, 0.95)

	# 太いフチ本体
	draw_arc(CENTER, border_mid_radius, 0, TAU, 72, gold_orange, BORDER_WIDTH)

	# 外縁・内縁の境界ライン (立体感を出すブロンズ＆ハイライトゴールド)
	draw_arc(CENTER, outer_ring_radius, 0, TAU, 72, bronze_dark, 2.5)
	draw_arc(CENTER, ROULETTE_RADIUS, 0, TAU, 72, gold_bright, 2.0)
	# リング中央の光彩アクセントライン
	draw_arc(CENTER, border_mid_radius, 0, TAU, 72, Color(1.0, 0.88, 0.45, 0.40), 2.0)

	# フチ上のゴールドリベット装飾 (10箇所)
	for r in range(10):
		var riv_angle := float(r) * (TAU / 10.0)
		var riv_pos := CENTER + Vector2.from_angle(riv_angle) * border_mid_radius
		draw_circle(riv_pos, 2.5, Color(0.50, 0.28, 0.04, 0.9))
		draw_circle(riv_pos, 1.8, gold_bright)

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

	# 白背景のため通常時は濃い黒色。残り10秒以下は赤点滅
	var timer_color := Color(0.12, 0.10, 0.18, 1.0)
	if timer_val <= 10.0 and timer_val > 0.0:
		var pulse := 0.5 + 0.5 * sin(time * 10.0)
		timer_color = Color(0.90, 0.15, 0.20, 1.0).lerp(Color(0.2, 0.05, 0.05, 1.0), pulse * 0.4)

	draw_string(font, timer_pos, timer_str, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE_TIMER, timer_color)

	# --- 5. 上部ピン (ポインター ▽: 太いフチに合わせた大型ゴールドピン) ---
	var pin_tip := CENTER + Vector2(0.0, -ROULETTE_RADIUS + 8.0) # フチを跨いでルーレット内側を指す先端
	var pin_top_left := CENTER + Vector2(-11.0, -(outer_ring_radius + 4.0))
	var pin_top_right := CENTER + Vector2(11.0, -(outer_ring_radius + 4.0))

	var pin_poly := PackedVector2Array([pin_tip, pin_top_left, pin_top_right])
	var pin_color := Color(1.0, 0.94, 0.60, 1.0) # 明るいホワイトゴールド
	var pin_border := Color(0.20, 0.10, 0.02, 1.0)

	# ピンシャドウ
	draw_colored_polygon(PackedVector2Array([pin_tip + Vector2(0, 2.0), pin_top_left + Vector2(0, 2.0), pin_top_right + Vector2(0, 2.0)]), Color(0, 0, 0, 0.55))
	# ピン本体
	draw_colored_polygon(pin_poly, pin_color)
	draw_polyline(PackedVector2Array([pin_tip, pin_top_left, pin_top_right, pin_tip]), pin_border, 1.8)

	# ピン上部固定鋲 (ゴールドスタッド)
	var pin_stud_pos := CENTER + Vector2(0.0, -border_mid_radius)
	draw_circle(pin_stud_pos, 4.0, Color(0.50, 0.25, 0.03, 1.0))
	draw_circle(pin_stud_pos, 3.0, Color(1.0, 0.85, 0.4, 1.0))
	draw_circle(pin_stud_pos, 1.5, Color(1.0, 1.0, 0.9, 1.0))
