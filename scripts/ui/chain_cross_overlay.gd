extends Control
class_name ChainCrossOverlay

## 装備欄（6スロット全体）を無効化する鎖のバツ印オーバーレイ

@export var link_length: float = 24.0 # リンク1個あたりの間隔
@export var link_width: float = 16.0  # 正面向きリングの幅
@export var ring_thickness: float = 4.5 # リングの太さ

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x < 20.0 or size.y < 20.0:
		return

	var p_top_left := Vector2(0.0, 0.0)
	var p_bottom_right := Vector2(size.x, size.y)
	var p_top_right := Vector2(size.x, 0.0)
	var p_bottom_left := Vector2(0.0, size.y)

	var center := size * 0.5
	var shadow_offset := Vector2(5.0, 8.0)

	# 1. 落ち影（2本の鎖全体）
	_draw_chain(p_top_left + shadow_offset, p_bottom_right + shadow_offset, true)
	_draw_chain(p_top_right + shadow_offset, p_bottom_left + shadow_offset, true)
	_draw_center_lock(center + shadow_offset, true)

	# 2. 1本目の鎖（左上 -> 右下）
	_draw_chain(p_top_left, p_bottom_right, false)

	# 3. 2本目の鎖（右上 -> 左下）
	_draw_chain(p_top_right, p_bottom_left, false)

	# 4. 中央の南京錠・封印金具
	_draw_center_lock(center, false)


func _draw_chain(from_pos: Vector2, to_pos: Vector2, is_shadow: bool) -> void:
	var delta := to_pos - from_pos
	var total_len := delta.length()
	if total_len <= 1.0:
		return

	var dir := delta / total_len
	var angle := dir.angle()
	var step := link_length
	var count := int(ceil(total_len / step)) + 1

	for i in range(count):
		var pos := from_pos + dir * (float(i) * step)
		var is_flat := (i % 2 == 0)

		# トランスフォームを行列で設定
		draw_set_transform(pos, angle, Vector2.ONE)

		if is_shadow:
			_draw_link_shadow(is_flat)
		else:
			_draw_link(is_flat)

	# トランスフォームを元に戻す
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_link_shadow(is_flat: bool) -> void:
	var shadow_col := Color(0.0, 0.0, 0.0, 0.40)
	if is_flat:
		var rx := link_length * 0.65
		var ry := link_width * 0.5
		# 楕円のポリライン
		_draw_capsule_ring(rx, ry, ring_thickness + 2.0, shadow_col)
	else:
		# 横向きリング（長方形カプセル）
		var half_w := link_length * 0.55
		var half_h := ring_thickness * 0.75
		draw_rect(Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0), shadow_col, true)


func _draw_link(is_flat: bool) -> void:
	var c_dark := Color(0.12, 0.13, 0.16, 1.0)
	var c_body := Color(0.62, 0.65, 0.72, 1.0)
	var c_light := Color(0.88, 0.92, 0.98, 1.0)
	var c_rim := Color(0.35, 0.38, 0.45, 1.0)

	if is_flat:
		var rx := link_length * 0.65
		var ry := link_width * 0.5

		# 1. 外側と内側の境界線（ダークアウトライン）
		_draw_capsule_ring(rx, ry, ring_thickness + 2.0, c_dark)
		# 2. メタリックボディ
		_draw_capsule_ring(rx, ry, ring_thickness, c_body)
		# 3. ハイライト（上側と光沢）
		_draw_capsule_highlight(rx, ry, ring_thickness * 0.5, c_light)
	else:
		# 横向きリング: 縦に走る金属棒
		var half_w := link_length * 0.55
		var half_h := ring_thickness * 0.85

		# 外枠
		draw_rect(Rect2(-half_w, -half_h - 1.0, half_w * 2.0, half_h * 2.0 + 2.0), c_dark, true)
		# ボディ
		draw_rect(Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0), c_body, true)
		# 中央ハイライトライン
		draw_line(Vector2(-half_w + 2.0, 0.0), Vector2(half_w - 2.0, 0.0), c_light, 1.5)
		# 端のシャドウ
		draw_rect(Rect2(-half_w, -half_h, 3.0, half_h * 2.0), c_rim, true)
		draw_rect(Rect2(half_w - 3.0, -half_h, 3.0, half_h * 2.0), c_rim, true)


func _draw_capsule_ring(rx: float, ry: float, thickness: float, color: Color) -> void:
	# 楕円近似のポリラインでリングを描画
	var segments := 16
	var pts := PackedVector2Array()
	pts.resize(segments + 1)
	for i in range(segments + 1):
		var rad := float(i) * TAU / float(segments)
		pts[i] = Vector2(cos(rad) * rx, sin(rad) * ry)
	draw_polyline(pts, color, thickness, true)


func _draw_capsule_highlight(rx: float, ry: float, thickness: float, color: Color) -> void:
	# 上半分のみにハイライト円弧を描画
	var segments := 10
	var pts := PackedVector2Array()
	pts.resize(segments)
	for i in range(segments):
		var rad := PI + float(i) * PI / float(segments - 1) # π〜2π (上側)
		pts[i] = Vector2(cos(rad) * (rx - 0.5), sin(rad) * (ry - 0.5))
	draw_polyline(pts, color, thickness, false)


func _draw_center_lock(center: Vector2, is_shadow: bool) -> void:
	# 交差点中央の重厚なロック金具
	draw_set_transform(center, 0.0, Vector2.ONE)

	if is_shadow:
		var shadow_col := Color(0.0, 0.0, 0.0, 0.50)
		# アーチ（U字シャックル）の影
		draw_arc(Vector2(0, -14), 16.0, PI, TAU, 16, shadow_col, 7.0)
		# ボディ（錠前本体）の影
		draw_rect(Rect2(-24, -10, 48, 42), shadow_col, true)
	else:
		var c_steel_dark := Color(0.15, 0.16, 0.20, 1.0)
		var c_steel_mid := Color(0.55, 0.60, 0.68, 1.0)
		var c_steel_light := Color(0.85, 0.90, 0.98, 1.0)
		var c_gold_dark := Color(0.35, 0.25, 0.05, 1.0)
		var c_gold_mid := Color(0.85, 0.70, 0.20, 1.0)
		var c_gold_light := Color(1.0, 0.92, 0.55, 1.0)

		# 1. U字シャックル（金属の太い掛け金）
		# 外枠
		draw_arc(Vector2(0, -14), 16.0, PI, TAU, 16, c_steel_dark, 8.0)
		# 本体
		draw_arc(Vector2(0, -14), 16.0, PI, TAU, 16, c_steel_mid, 6.0)
		# ハイライト
		draw_arc(Vector2(0, -14), 16.0, PI * 1.1, PI * 1.6, 8, c_steel_light, 2.5)

		# 2. 錠前本体（ゴールド/真鍮調の重厚なボディ）
		var body_rect := Rect2(-24, -10, 48, 42)
		# 外枠
		draw_rect(Rect2(-26, -12, 52, 46), c_steel_dark, true)
		# ベース
		draw_rect(body_rect, c_gold_mid, true)
		# 上部ハイライト
		draw_line(Vector2(-23, -8), Vector2(23, -8), c_gold_light, 2.5)
		# 下部シャドウ
		draw_line(Vector2(-23, 30), Vector2(23, 30), c_gold_dark, 3.0)

		# 3. 鍵穴（Keyhole）
		var keyhole_col := Color(0.08, 0.08, 0.12, 1.0)
		draw_circle(Vector2(0, 6), 5.0, keyhole_col)
		var keyhole_stem := PackedVector2Array([
			Vector2(-3.0, 6.0),
			Vector2(3.0, 6.0),
			Vector2(4.5, 18.0),
			Vector2(-4.5, 18.0)
		])
		draw_colored_polygon(keyhole_stem, keyhole_col)

		# リベット（四隅の飾り鋲）
		var rivet_col := Color(0.95, 0.88, 0.5, 0.9)
		draw_circle(Vector2(-18, -4), 2.0, rivet_col)
		draw_circle(Vector2(18, -4), 2.0, rivet_col)
		draw_circle(Vector2(-18, 26), 2.0, rivet_col)
		draw_circle(Vector2(18, 26), 2.0, rivet_col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
