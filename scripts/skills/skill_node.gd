@tool
extends Button
class_name SkillNode

@export var skill_id: String = ""
@export var skill_name: String = ""
@export var icon_char: String = "❓"
@export_multiline var description: String = ""
@export var is_unlimited: bool = false
@export var base_cost: float = 1.0
@export var cost_multiplier: float = 1.5
@export var prerequisites: Array[String] = []
var _lines: Array[Line2D] = []

var _icon_texture: Texture2D = null
var _icon_loaded: bool = false
var _last_loaded_icon_char: String = ""
var _is_dirty: bool = true
var _deferred_pending: bool = false
var _custom_tooltip: SkillTooltip = null

func _load_icon_if_needed() -> void:
	if _icon_loaded and _last_loaded_icon_char == icon_char:
		return
	
	_icon_loaded = true
	_last_loaded_icon_char = icon_char
	_icon_texture = null
	
	if icon_char.begins_with("res://") and ResourceLoader.exists(icon_char):
		var tex = load(icon_char)
		if tex is Texture2D:
			_icon_texture = tex

var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_pressed: StyleBoxFlat
var _style_disabled: StyleBoxFlat

func _ready() -> void:
	# item_rect_changedシグナルに接続して、ドラッグ時に接続線を更新する
	if Engine.is_editor_hint():
		item_rect_changed.connect(_update_connections)
	
	# スタイルボックスを動的に初期化して外側の枠（フチ）を構成する（太さ：11px）
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.12, 0.12, 0.2, 1.0)
	_style_normal.border_width_left = 11
	_style_normal.border_width_top = 11
	_style_normal.border_width_right = 11
	_style_normal.border_width_bottom = 11
	_style_normal.expand_margin_left = 9
	_style_normal.expand_margin_top = 9
	_style_normal.expand_margin_right = 9
	_style_normal.expand_margin_bottom = 9
	_style_normal.content_margin_left = 2
	_style_normal.content_margin_top = 2
	_style_normal.content_margin_right = 2
	_style_normal.content_margin_bottom = 2
	_style_normal.corner_radius_top_left = 3
	_style_normal.corner_radius_top_right = 3
	_style_normal.corner_radius_bottom_right = 3
	_style_normal.corner_radius_bottom_left = 3
	
	_style_hover = _style_normal.duplicate()
	_style_hover.bg_color = Color(0.18, 0.18, 0.28, 1.0)
	
	_style_pressed = _style_normal.duplicate()
	_style_pressed.bg_color = Color(0.08, 0.08, 0.15, 1.0)
	
	_style_disabled = _style_normal.duplicate()
	_style_disabled.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	
	add_theme_stylebox_override("normal", _style_normal)
	add_theme_stylebox_override("hover", _style_hover)
	add_theme_stylebox_override("pressed", _style_pressed)
	add_theme_stylebox_override("disabled", _style_disabled)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	focus_mode = Control.FOCUS_NONE
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	expand_icon = true
	
	# トークン変化やスキル解放状況の変化による購入可能状態の変化をリアルタイムに更新反映する
	# (永続シングルトンのシグナルに接続するため、リークやフリーズを防ぐようメンバー関数に直接接続する)
	if not Engine.is_editor_hint():
		GameData.tokens_changed.connect(_on_tokens_changed)
		GameData.skill_upgraded.connect(_on_skill_upgraded)
		visibility_changed.connect(_on_visibility_changed)
		
		# マニュアルツールチップのホバー接続
		mouse_entered.connect(_on_mouse_entered_tooltip)
		mouse_exited.connect(_on_mouse_exited_tooltip)
		visibility_changed.connect(_on_mouse_exited_tooltip)
		tree_exited.connect(_on_mouse_exited_tooltip)
		set_process(false)
	
	_update_connections()
	queue_update_ui()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		# Preview icons on editor
		_update_ui_editor()
	else:
		# ゲーム実行時はツールチップの位置をマウス位置に追従させる
		_update_tooltip_position()


func _update_connections() -> void:
	# 既存の線をクリア
	for line in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()
	
	var parent = get_parent()
	if not parent:
		return
		
	for prereq_id in prerequisites:
		if prereq_id.is_empty():
			continue
			
		# 親ノードの子から、スキルIDが一致するものを探す
		var target: SkillNode = null
		for child in parent.get_children():
			if child is SkillNode and child.skill_id == prereq_id:
				target = child
				break
				
		if target:
			var line = Line2D.new()
			line.width = 4.0
			# スキル間の辺の色は完全な白に変更
			line.default_color = Color(1.0, 1.0, 1.0, 1.0)
			line.set_meta("prereq_id", prereq_id)
			
			# 上下左右に並んでいる場合は辺の中央同士、ななめに並んでいる場合は角同士を結ぶ
			var points = _get_connection_points(self, target)
			line.add_point(points[0])
			line.add_point(points[1])
			
			# 親ノードに線を追加し、最背面に描画するためにインデックス0へ移動
			parent.add_child(line)
			parent.move_child(line, 0)
			_lines.append(line)


func _get_connection_points(node_a: Control, node_b: Control) -> Array[Vector2]:
	var a_pos = node_a.position
	var a_size = node_a.size
	var b_pos = node_b.position
	var b_size = node_b.size
	
	var dx = b_pos.x - a_pos.x
	var dy = b_pos.y - a_pos.y
	
	# 浮動小数点の誤差を考慮する許容値
	const EPSILON = 1.0
	
	# 1. 垂直に並んでいる場合 (左右のズレがない)
	if abs(dx) < EPSILON:
		if dy > 0:
			# BがAの下にある場合：Aの下中央 ⇄ Bの上中央
			return [a_pos + Vector2(a_size.x / 2, a_size.y), b_pos + Vector2(b_size.x / 2, 0)]
		else:
			# BがAの上にある場合：Aの上中央 ⇄ Bの下中央
			return [a_pos + Vector2(a_size.x / 2, 0), b_pos + Vector2(b_size.x / 2, b_size.y)]
			
	# 2. 水平に並んでいる場合 (上下のズレがない)
	elif abs(dy) < EPSILON:
		if dx > 0:
			# BがAの右にある場合：Aの右中央 ⇄ Bの左中央
			return [a_pos + Vector2(a_size.x, a_size.y / 2), b_pos + Vector2(0, b_size.y / 2)]
		else:
			# BがAの左にある場合：Aの左中央 ⇄ Bの右中央
			return [a_pos + Vector2(0, a_size.y / 2), b_pos + Vector2(b_size.x, b_size.y / 2)]
			
	# 3. ななめに並んでいる場合 (角同士を結ぶ)
	else:
		if dx > 0 and dy > 0:
			# BがAの右下にある場合：Aの右下角 ⇄ Bの左上角
			return [a_pos + Vector2(a_size.x, a_size.y), b_pos + Vector2(0, 0)]
		elif dx < 0 and dy > 0:
			# BがAの左下にある場合：Aの左下角 ⇄ Bの右上角
			return [a_pos + Vector2(0, a_size.y), b_pos + Vector2(b_size.x, 0)]
		elif dx > 0 and dy < 0:
			# BがAの右上にある場合：Aの右上角 ⇄ Bの左下角
			return [a_pos + Vector2(a_size.x, 0), b_pos + Vector2(0, b_size.y)]
		else:
			# BがAの左上にある場合：Aの左上角 ⇄ Bの右下角
			return [a_pos + Vector2(0, 0), b_pos + Vector2(b_size.x, b_size.y)]


func _update_ui_editor() -> void:
	_load_icon_if_needed()
	
	if _icon_texture:
		icon = _icon_texture
		text = ""
		expand_icon = true
	else:
		icon = null
		text = icon_char
		
	# エディタ上でのデフォルト枠色を設定 (青/グレー)
	var border_color = Color(0.35, 0.4, 0.55)
	if _style_normal:
		_style_normal.border_color = border_color
	if _style_hover:
		_style_hover.border_color = border_color
	if _style_pressed:
		_style_pressed.border_color = border_color
	if _style_disabled:
		_style_disabled.border_color = border_color
		
	var type_str := "無制限強化" if is_unlimited else "1回のみ解放"
	tooltip_text = "%s\n%s\nタイプ: %s\nBase Cost: 💎 %d" % [
		skill_name if not skill_name.is_empty() else (skill_id if not skill_id.is_empty() else name),
		description,
		type_str,
		base_cost
	]


func _update_ui_actual() -> void:
	_deferred_pending = false
	if not is_inside_tree() or not is_visible_in_tree():
		return
	
	_is_dirty = false
	
	_load_icon_if_needed()
	
	if _icon_texture:
		icon = _icon_texture
		text = ""
		expand_icon = true
	else:
		icon = null
		text = icon_char
	
	# ゲーム実行時のUI更新
	var current_count = GameData.get_skill_level(skill_id)
	var is_unlocked = current_count > 0
	var is_max = not is_unlimited and is_unlocked
	
	var cost = get_upgrade_cost(current_count)
	
	# マニュアル管理ツールチップを使用するため、Godot標準のポップアップは完全に無効化します
	tooltip_text = ""
	
	# 解放可能状態（前提スキルがすべて1回以上解放されているか）
	var playable = is_playable()
			
	# トークンが足りるかどうかの判定
	var player_tokens = GameData.tokens
	var is_affordable = player_tokens >= cost
	
	# 枠線の色決定:
	# 購入済み：黄色枠
	# コスト的に購入可能：緑枠
	# コスト的に購入不可能：赤枠
	var border_color = Color(0.82, 0.30, 0.30) # 赤
	if is_max:
		border_color = Color(0.92, 0.78, 0.28) # 黄色/ゴールド
	elif is_affordable:
		border_color = Color(0.28, 0.80, 0.35) # 緑
	else:
		border_color = Color(0.82, 0.30, 0.30) # 赤
		
	# 枠線の適用
	if _style_normal:
		_style_normal.border_color = border_color
	if _style_hover:
		_style_hover.border_color = border_color
	if _style_pressed:
		_style_pressed.border_color = border_color
	if _style_disabled:
		_style_disabled.border_color = border_color
		
	# グレーアウト判定:
	# 前提ノードが解放されている：グレーアウト無し(現状のまま)
	# 前提ノードが解放されていない：グレーアウトアリ
	# 購入済み：黄色枠(グレーアウト無し)
	var should_gray_out = false
	if not is_max and not playable:
		should_gray_out = true
	
	if should_gray_out:
		modulate = Color(0.45, 0.45, 0.45, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0)


func is_maxed() -> bool:
	if is_unlimited:
		return false
	return GameData.get_skill_level(skill_id) > 0


func get_upgrade_cost(level: int) -> float:
	var raw_cost := float(base_cost) * pow(cost_multiplier, float(level))
	var discount := GameData.get_equipped_token_saving_cost_multiplier()
	return maxf(1.0, raw_cost * discount)


func is_playable() -> bool:
	for prereq_id in prerequisites:
		if prereq_id.is_empty():
			continue
		var req_lvl = GameData.skill_levels.get(prereq_id, 0)
		if req_lvl == 0:
			return false
	return true


# 外部（HUDなど）からレベル変更通知を受け取って再描画するための関数
func refresh() -> void:
	queue_update_ui()
	_update_connections()


func queue_update_ui() -> void:
	_is_dirty = true
	if _deferred_pending:
		return
	if is_inside_tree() and is_visible_in_tree():
		if not is_queued_for_deletion():
			_deferred_pending = true
			call_deferred(&"_update_ui_actual")


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		queue_update_ui()


func _on_tokens_changed(_new_tokens: float) -> void:
	if is_inside_tree() and is_visible_in_tree():
		queue_update_ui()
	else:
		_is_dirty = true


func _on_skill_upgraded(_skill_id: String, _new_level: int) -> void:
	if is_inside_tree() and is_visible_in_tree():
		queue_update_ui()
	else:
		_is_dirty = true


func _update_ui() -> void:
	queue_update_ui()


func _on_mouse_entered_tooltip() -> void:
	if Engine.is_editor_hint():
		return
	if not is_visible_in_tree():
		return
		
	_remove_tooltip()
	
	var tooltip_scene = preload("res://scenes/ui/skill_tooltip.tscn")
	_custom_tooltip = tooltip_scene.instantiate() as SkillTooltip
	
	# 親方向へ最寄りの CanvasLayer を探し、そこに追加することでインベントリ等の前面に確実に描画する
	var parent_node = get_parent()
	var canvas_layer: CanvasLayer = null
	while parent_node:
		if parent_node is CanvasLayer:
			canvas_layer = parent_node as CanvasLayer
			break
		parent_node = parent_node.get_parent()
		
	if canvas_layer:
		canvas_layer.add_child(_custom_tooltip)
	else:
		_custom_tooltip.top_level = true
		add_child(_custom_tooltip)
	
	_custom_tooltip.setup_from_node(self)
	_update_tooltip_position()
	set_process(true)


func _on_mouse_exited_tooltip() -> void:
	_remove_tooltip()


func _remove_tooltip() -> void:
	if is_instance_valid(_custom_tooltip):
		_custom_tooltip.queue_free()
	_custom_tooltip = null
	if not Engine.is_editor_hint():
		set_process(false)


func _update_tooltip_position() -> void:
	if not is_instance_valid(_custom_tooltip):
		return
		
	var mouse_pos = get_global_mouse_position()
	var offset = Vector2(15, 15)
	var target_pos = mouse_pos + offset
	
	# 画面端での見切れ防止処理
	# まだレイアウト前で size が (0,0) の場合があるため、get_combined_minimum_size() を使う
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_size = _custom_tooltip.get_combined_minimum_size()
	
	if target_pos.x + tooltip_size.x > viewport_size.x:
		target_pos.x = mouse_pos.x - tooltip_size.x - 15
	if target_pos.y + tooltip_size.y > viewport_size.y:
		target_pos.y = mouse_pos.y - tooltip_size.y - 15
		
	_custom_tooltip.global_position = target_pos
