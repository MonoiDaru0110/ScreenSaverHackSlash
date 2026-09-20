@tool
extends Button
class_name ReincarnationSkillNode

@export var skill_id: String = ""
@export var skill_name: String = ""
@export var icon_char: String = "⚛️"
@export_multiline var description: String = ""
@export var base_cost: int = 1
@export var prerequisites: Array[String] = []

var _lines: Array[Line2D] = []
var _icon_texture: Texture2D = null
var _icon_loaded: bool = false
var _last_loaded_icon_char: String = ""
var _is_dirty: bool = true
var _deferred_pending: bool = false

var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_pressed: StyleBoxFlat
var _style_disabled: StyleBoxFlat

var is_selected: bool = false:
	set(val):
		if is_selected != val:
			is_selected = val
			queue_update_ui()


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


func _ready() -> void:
	if Engine.is_editor_hint():
		item_rect_changed.connect(_update_connections)
	
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.15, 0.1, 0.22, 1.0)
	_style_normal.border_width_left = 9
	_style_normal.border_width_top = 9
	_style_normal.border_width_right = 9
	_style_normal.border_width_bottom = 9
	_style_normal.expand_margin_left = 9
	_style_normal.expand_margin_top = 9
	_style_normal.expand_margin_right = 9
	_style_normal.expand_margin_bottom = 9
	_style_normal.corner_radius_top_left = 3
	_style_normal.corner_radius_top_right = 3
	_style_normal.corner_radius_bottom_right = 3
	_style_normal.corner_radius_bottom_left = 3
	
	_style_hover = _style_normal.duplicate()
	_style_hover.bg_color = Color(0.22, 0.14, 0.32, 1.0)
	
	_style_pressed = _style_normal.duplicate()
	_style_pressed.bg_color = Color(0.1, 0.06, 0.16, 1.0)
	
	_style_disabled = _style_normal.duplicate()
	_style_disabled.bg_color = Color(0.12, 0.08, 0.18, 1.0)
	
	add_theme_stylebox_override("normal", _style_normal)
	add_theme_stylebox_override("hover", _style_hover)
	add_theme_stylebox_override("pressed", _style_pressed)
	add_theme_stylebox_override("disabled", _style_disabled)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	focus_mode = Control.FOCUS_NONE
	
	if not Engine.is_editor_hint():
		GameData.stars_changed.connect(_on_stars_changed)
		GameData.upgrades_changed.connect(_on_upgrades_changed)
		visibility_changed.connect(_on_visibility_changed)
	
	_update_connections()
	queue_update_ui()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_ui_editor()


func _update_connections() -> void:
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
			
		var target: ReincarnationSkillNode = null
		for child in parent.get_children():
			if child is ReincarnationSkillNode and child.skill_id == prereq_id:
				target = child
				break
				
		if target:
			var line = Line2D.new()
			line.width = 4.0
			line.default_color = Color(1.0, 1.0, 1.0, 1.0)
			
			var points = _get_connection_points(self, target)
			line.add_point(points[0])
			line.add_point(points[1])
			
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
	const EPSILON = 1.0
	
	if abs(dx) < EPSILON:
		if dy > 0:
			return [a_pos + Vector2(a_size.x / 2, a_size.y), b_pos + Vector2(b_size.x / 2, 0)]
		else:
			return [a_pos + Vector2(a_size.x / 2, 0), b_pos + Vector2(b_size.x / 2, b_size.y)]
	elif abs(dy) < EPSILON:
		if dx > 0:
			return [a_pos + Vector2(a_size.x, a_size.y / 2), b_pos + Vector2(0, b_size.y / 2)]
		else:
			return [a_pos + Vector2(0, a_size.y / 2), b_pos + Vector2(b_size.x, b_size.y / 2)]
	else:
		if dx > 0 and dy > 0:
			return [a_pos + Vector2(a_size.x, a_size.y), b_pos + Vector2(0, 0)]
		elif dx < 0 and dy > 0:
			return [a_pos + Vector2(0, a_size.y), b_pos + Vector2(b_size.x, 0)]
		elif dx > 0 and dy < 0:
			return [a_pos + Vector2(a_size.x, 0), b_pos + Vector2(0, b_size.y)]
		else:
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
		
	var border_color = Color(0.5, 0.35, 0.65)
	if _style_normal:
		_style_normal.border_color = border_color
	if _style_hover:
		_style_hover.border_color = border_color
	if _style_pressed:
		_style_pressed.border_color = border_color
	if _style_disabled:
		_style_disabled.border_color = border_color


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
	
	var acquired = is_acquired()
	var playable = is_playable()
	var cost = base_cost
	
	tooltip_text = ""
	var is_affordable = (GameData.stars >= cost)
	
	var border_color = Color(0.9, 0.2, 0.2)
	if is_selected:
		border_color = Color(0.3, 0.95, 1.0) # 選択中ハイライト (シアン)
	elif acquired:
		border_color = Color(1.0, 0.82, 0.0) # 習得済み (ゴールド)
	elif playable:
		if is_affordable:
			border_color = Color(0.2, 0.9, 0.2) # 習得可能 (緑)
		else:
			border_color = Color(0.9, 0.2, 0.2) # スター不足
	else:
		border_color = Color(0.5, 0.2, 0.2) # ロック中
		
	if _style_normal:
		_style_normal.border_color = border_color
	if _style_hover:
		_style_hover.border_color = border_color
	if _style_pressed:
		_style_pressed.border_color = border_color
	if _style_disabled:
		_style_disabled.border_color = border_color
		
	self_modulate = Color(1.0, 1.0, 1.0)
	if acquired:
		modulate = Color(1.0, 1.0, 1.0)
	elif playable:
		modulate = Color(0.9, 0.9, 0.9)
	else:
		modulate = Color(0.5, 0.5, 0.5, 0.9)


func is_acquired() -> bool:
	return GameData.is_reincarnation_skill_unlocked(skill_id)


func is_playable() -> bool:
	if is_acquired():
		return false
	for prereq_id in prerequisites:
		if prereq_id.is_empty():
			continue
		if not GameData.is_reincarnation_skill_unlocked(prereq_id):
			return false
	return true


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
	if is_visible_in_tree() and _is_dirty:
		_update_ui_actual()


func _on_stars_changed(_new_stars: int) -> void:
	if is_inside_tree() and is_visible_in_tree():
		queue_update_ui()
	else:
		_is_dirty = true


func _on_upgrades_changed() -> void:
	if is_inside_tree() and is_visible_in_tree():
		queue_update_ui()
	else:
		_is_dirty = true
