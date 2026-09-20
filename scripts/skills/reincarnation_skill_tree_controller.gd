extends Control
class_name ReincarnationSkillTreeController

@export var scroll_speed: float = 45.0

@onready var viewport: Control = %ReincTreeViewport

var _is_dragging := false
var _last_mouse_pos := Vector2.ZERO

var _cached_min_y: float = -400.0
var _cached_max_y: float = 0.0


func _ready() -> void:
	clip_contents = true
	resized.connect(_on_resized)

	await get_tree().process_frame
	if viewport:
		viewport.mouse_filter = Control.MOUSE_FILTER_PASS
		viewport.scale = Vector2.ONE
		viewport.pivot_offset = Vector2.ZERO

		for child in viewport.get_children():
			if not child is ReincarnationSkillNode and child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_PASS

		_calculate_tree_bounds()
		center_on_root()


func _on_resized() -> void:
	_update_x_position()
	_clamp_y_position()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			# ホイールによる上下スクロール
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll_vertical(scroll_speed)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll_vertical(-scroll_speed)
				accept_event()

		# ドラッグによる上下スクロール
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.is_pressed():
				_is_dragging = true
				_last_mouse_pos = event.global_position
				mouse_default_cursor_shape = Control.CURSOR_DRAG
				accept_event()
			else:
				_is_dragging = false
				mouse_default_cursor_shape = Control.CURSOR_ARROW
				accept_event()

	elif event is InputEventMouseMotion:
		if _is_dragging:
			var diff = event.global_position - _last_mouse_pos
			scroll_vertical(diff.y)
			_last_mouse_pos = event.global_position
			accept_event()


func scroll_vertical(amount: float) -> void:
	if not viewport:
		return
	viewport.position.y += amount
	_clamp_y_position()


func _update_x_position() -> void:
	if not viewport:
		return
	viewport.position.x = (size.x / 2.0) - 30.0


func _calculate_tree_bounds() -> void:
	if not viewport:
		return
	var min_y := 0.0
	var max_y := 0.0
	var found := false
	for child in viewport.get_children():
		if child is ReincarnationSkillNode:
			var pos_y: float = child.position.y
			if not found:
				min_y = pos_y
				max_y = pos_y
				found = true
			else:
				min_y = minf(min_y, pos_y)
				max_y = maxf(max_y, pos_y)
	if found:
		_cached_min_y = min_y
		_cached_max_y = max_y


func _clamp_y_position() -> void:
	if not viewport:
		return
	var parent_h = size.y if size.y > 0 else 500.0
	var min_allowed_pos_y = -_cached_max_y + 80.0
	var max_allowed_pos_y = -_cached_min_y + parent_h - 140.0

	if min_allowed_pos_y > max_allowed_pos_y:
		var mid = (min_allowed_pos_y + max_allowed_pos_y) / 2.0
		min_allowed_pos_y = mid - 50.0
		max_allowed_pos_y = mid + 50.0

	viewport.position.y = clampf(viewport.position.y, min_allowed_pos_y, max_allowed_pos_y)


func center_on_root(_target_window: Control = null) -> void:
	if not viewport:
		return
	viewport.scale = Vector2.ONE
	_calculate_tree_bounds()
	_update_x_position()

	var parent_h = size.y if size.y > 0 else 500.0
	viewport.position.y = parent_h * 0.72 - _cached_max_y
	_clamp_y_position()
