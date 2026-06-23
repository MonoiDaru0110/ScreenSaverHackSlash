@tool
extends Button
class_name SkillNode

@export var skill_id: String = ""
@export var skill_name: String = ""
@export var icon_char: String = "❓"
@export_multiline var description: String = ""
@export var max_level: int = 5
@export var base_cost: int = 1
@export var cost_multiplier: float = 1.5
@export var prerequisites: Array[String] = []
var _lines: Array[Line2D] = []

func _ready() -> void:
	# item_rect_changedシグナルに接続して、ドラッグ時に接続線を更新する
	if Engine.is_editor_hint():
		item_rect_changed.connect(_update_connections)
	
	# 無効状態 (disabled) のときに半透明になるのを防ぐため、不透過のStyleBoxをオーバーライド設定する
	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.12, 0.12, 0.2, 1.0)
	style_disabled.border_width_left = 2
	style_disabled.border_width_top = 2
	style_disabled.border_width_right = 2
	style_disabled.border_width_bottom = 2
	style_disabled.border_color = Color(0.2, 0.2, 0.35, 1.0)
	style_disabled.corner_radius_top_left = 3
	style_disabled.corner_radius_top_right = 3
	style_disabled.corner_radius_bottom_right = 3
	style_disabled.corner_radius_bottom_left = 3
	add_theme_stylebox_override("disabled", style_disabled)
	
	_update_connections()
	_update_ui()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		# Preview icons on editor
		_update_ui_editor()


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
	text = icon_char
	tooltip_text = "%s\n%s\nMax Lvl: %d\nBase Cost: 💎 %d" % [
		skill_name if not skill_name.is_empty() else (skill_id if not skill_id.is_empty() else name),
		description,
		max_level,
		base_cost
	]


func _update_ui() -> void:
	if Engine.is_editor_hint():
		return
	
	text = icon_char
	
	# ゲーム実行時のUI更新
	var current_level = GameData.skill_levels.get(skill_id, 0)
	var cost = get_upgrade_cost(current_level)
	
	var lvl_str = "MAX" if current_level >= max_level else "Lvl %d/%d" % [current_level, max_level]
	var cost_str = "最大レベルに達しました" if current_level >= max_level else "コスト: 💎 %d" % cost
	
	tooltip_text = "%s\n[%s]\n%s\n%s" % [
		skill_name,
		lvl_str,
		description,
		cost_str
	]
	
	# 解放可能状態（前提スキルがすべてレベル1以上）かつトークンが足りるか判定
	var is_playable = true
	for prereq_id in prerequisites:
		var req_lvl = GameData.skill_levels.get(prereq_id, 0)
		if req_lvl == 0:
			is_playable = false
			break
	
	if current_level >= max_level:
		disabled = false
		self_modulate = Color(0.5, 1.0, 0.5) # MAXレベルは緑っぽく
	elif not is_playable:
		disabled = true
		self_modulate = Color(0.3, 0.3, 0.3, 1.0) # ロック中は暗い完全不透過に変更
	else:
		disabled = false
		# トークンが足りるかどうかで見た目を変える
		var player_tokens = GameData.tokens
		if player_tokens >= cost:
			self_modulate = Color(1.0, 1.0, 1.0) # 解放可能
		else:
			self_modulate = Color(1.0, 0.7, 0.7) # 解放可能だがトークン不足（少し赤っぽく）


func get_upgrade_cost(level: int) -> int:
	return int(base_cost * pow(cost_multiplier, level))


# 外部（HUDなど）からレベル変更通知を受け取って再描画するための関数
func refresh() -> void:
	_update_ui()
	_update_connections()
