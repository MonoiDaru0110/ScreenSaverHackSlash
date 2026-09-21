extends Control

@onready var rank_label: Label = %RankLabel
@onready var mult_label: Label = %MultLabel
@onready var progress_bar_control: Control = %ProgressBarControl
@onready var count_label: Label = %CountLabel

var skill_level: int = 1
var _rankup_tween: Tween = null
var _flash_alpha: float = 0.0


func _ready() -> void:
	GameData.accumulation_changed.connect(_on_accumulation_changed)
	GameData.upgrades_changed.connect(update_ui)
	GameData.equipment_changed.connect(update_ui)

	if progress_bar_control:
		progress_bar_control.draw.connect(_on_bar_draw)

	update_ui()


func _draw() -> void:
	# --- 境界線のないソフトフェード・ダークアストラル座布団 ---
	# 黒枠の野暮ったさを完全に排除しつつ、上下左右に自然に溶け込むグラデーションで視認性を確保
	var w := 268.0
	var h := 78.0
	var pad_x := 6.0
	var pad_y := 6.0

	var c_core := Color(0.03, 0.015, 0.07, 0.58) # 文字のコントラストを保つ深みのあるアストラルダーク
	var c_edge := Color(0.03, 0.015, 0.07, 0.0)  # 外周に向かって完全に透明に溶ける

	# 上部フェード (y: -pad_y ~ 0)
	var top_pts := PackedVector2Array([
		Vector2(-pad_x, -pad_y), Vector2(w, -pad_y),
		Vector2(w, 0.0), Vector2(-pad_x, 0.0)
	])
	var top_cols := PackedColorArray([c_edge, c_edge, c_core, c_core])
	draw_polygon(top_pts, top_cols)

	# 中央コア (y: 0 ~ h)
	draw_rect(Rect2(-pad_x, 0.0, w + pad_x, h), c_core)

	# 下部フェード (y: h ~ h + pad_y + 4)
	var bot_pts := PackedVector2Array([
		Vector2(-pad_x, h), Vector2(w, h),
		Vector2(w, h + pad_y + 4.0), Vector2(-pad_x, h + pad_y + 4.0)
	])
	var bot_cols := PackedColorArray([c_core, c_core, c_edge, c_edge])
	draw_polygon(bot_pts, bot_cols)

	# 左右ソフトフェード
	var left_pts := PackedVector2Array([
		Vector2(-pad_x - 10.0, 0.0), Vector2(-pad_x, 0.0),
		Vector2(-pad_x, h), Vector2(-pad_x - 10.0, h)
	])
	var left_cols := PackedColorArray([c_edge, c_core, c_core, c_edge])
	draw_polygon(left_pts, left_cols)

	var right_pts := PackedVector2Array([
		Vector2(w, 0.0), Vector2(w + 12.0, 0.0),
		Vector2(w + 12.0, h), Vector2(w, h)
	])
	var right_cols := PackedColorArray([c_core, c_edge, c_edge, c_core])
	draw_polygon(right_pts, right_cols)

	# --- 左端のサイバーHUDアクセントライン ---
	# 黒枠の代わりに「近未来HUD」感を演出する上下フェードの極細光彩ライン
	var line_top := Vector2(-pad_x, 2.0)
	var line_mid := Vector2(-pad_x, 22.0)
	var line_bot := Vector2(-pad_x, 46.0)
	var accent_bright := Color(0.85, 0.45, 1.0, 0.7)
	var accent_fade := Color(0.85, 0.45, 1.0, 0.0)
	draw_line(line_top, line_mid, accent_bright, 1.5)
	draw_line(line_mid, line_bot, accent_fade, 1.5)


func set_skill_data(sk_data: Dictionary) -> void:
	skill_level = int(sk_data.get("level", 1))
	update_ui()


func _on_accumulation_changed(ranked_up: bool) -> void:
	update_ui()
	if ranked_up:
		_play_rankup_effect()


func update_ui() -> void:
	if not is_inside_tree():
		return

	var rank: int = GameData.accumulation_rank
	var req: int = GameData.get_accumulation_req_bounces(rank)
	var cur: int = GameData.accumulation_bounces_in_rank
	var mult: float = GameData.get_accumulation_multiplier()

	if rank_label:
		rank_label.text = "Rank %d" % rank

	if mult_label:
		mult_label.text = "x" + GameData.format_num(mult)

	if count_label:
		count_label.text = "[ %s / %s ]" % [GameData.format_num(float(cur)), GameData.format_num(float(req))]

	if progress_bar_control:
		progress_bar_control.queue_redraw()


func _on_bar_draw() -> void:
	if not progress_bar_control:
		return

	var size := progress_bar_control.size
	var rank: int = GameData.accumulation_rank
	var req: int = GameData.get_accumulation_req_bounces(rank)
	var cur: int = GameData.accumulation_bounces_in_rank
	var ratio := clampf(float(cur) / float(maxi(1, req)), 0.0, 1.0)

	# 1. 背景バー（透過ダークパープル ＋ 繊細な外枠）
	var bg_rect := Rect2(Vector2.ZERO, size)
	progress_bar_control.draw_rect(bg_rect, Color(0.04, 0.02, 0.08, 0.75))
	progress_bar_control.draw_rect(bg_rect, Color(0.3, 0.22, 0.45, 0.65), false, 1.0)

	# 2. フィル部分（バーの長さに寄らず、右端の色は常に一定の最高輝度ネオンパープル）
	var fill_w := size.x * ratio
	if fill_w > 0.5:
		# 左端: 深みのあるアストラルパープル、右端: 常に一定の鮮やかな高輝度ネオン色
		var c_left := Color(0.48, 0.15, 0.82, 0.9)
		var c_right := Color(1.0, 0.7, 1.0, 1.0)

		var points := PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(fill_w, 0.0),
			Vector2(fill_w, size.y),
			Vector2(0.0, size.y)
		])
		var colors := PackedColorArray([
			c_left,
			c_right,
			c_right,
			c_left
		])
		progress_bar_control.draw_polygon(points, colors)

		# 右端（先端）の光彩ライン
		progress_bar_control.draw_line(Vector2(fill_w, 0.0), Vector2(fill_w, size.y), Color(1.0, 1.0, 1.0, 0.95), 1.5)

	# 3. ランクアップ時のホワイトフラッシュ
	if _flash_alpha > 0.0:
		progress_bar_control.draw_rect(bg_rect, Color(1.0, 1.0, 1.0, _flash_alpha * 0.85))


func _play_rankup_effect() -> void:
	if is_instance_valid(_rankup_tween) and _rankup_tween.is_running():
		_rankup_tween.kill()

	_rankup_tween = create_tween().set_parallel(true)

	if mult_label:
		mult_label.scale = Vector2(1.35, 1.35)
		mult_label.modulate = Color(1.5, 1.5, 1.5, 1.0)
		_rankup_tween.tween_property(mult_label, "scale", Vector2.ONE, 0.35)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_rankup_tween.tween_property(mult_label, "modulate", Color.WHITE, 0.35)\
			.set_ease(Tween.EASE_OUT)

	if rank_label:
		rank_label.scale = Vector2(1.25, 1.25)
		_rankup_tween.tween_property(rank_label, "scale", Vector2.ONE, 0.3)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# バーのフラッシュアニメーション
	_flash_alpha = 1.0
	var flash_tween := create_tween()
	flash_tween.tween_method(func(v: float):
		_flash_alpha = v
		if progress_bar_control:
			progress_bar_control.queue_redraw()
	, 1.0, 0.0, 0.45).set_ease(Tween.EASE_OUT)
