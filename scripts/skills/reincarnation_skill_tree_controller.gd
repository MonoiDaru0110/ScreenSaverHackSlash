extends Control
class_name ReincarnationSkillTreeController

@export var min_zoom := 0.3
@export var max_zoom := 2.0
@export var zoom_speed := 0.1

@onready var viewport: Control = %ReincTreeViewport

var _zoom := 1.0
var _is_dragging := false
var _last_mouse_pos := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	
	await get_tree().process_frame
	if viewport:
		viewport.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var child_size = Vector2(400, 400)
		for child in viewport.get_children():
			if not child is ReincarnationSkillNode and child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_PASS
				child_size = child.size
				
		viewport.pivot_offset = Vector2.ZERO
		viewport.position = (size - child_size) / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_mouse(zoom_speed)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_mouse(-zoom_speed)
				accept_event()
		
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
			if viewport:
				viewport.position += diff
			_last_mouse_pos = event.global_position
			accept_event()


func _zoom_at_mouse(factor: float) -> void:
	if not viewport:
		return
		
	var old_zoom = _zoom
	_zoom = clamp(_zoom + factor, min_zoom, max_zoom)
	if old_zoom == _zoom:
		return
		
	var mouse_local = viewport.get_local_mouse_position()
	viewport.scale = Vector2(_zoom, _zoom)
	var shift = mouse_local * (_zoom - old_zoom)
	viewport.position -= shift


func center_on_root(target_window: Control = null) -> void:
	_zoom = 1.0
	if viewport:
		viewport.scale = Vector2.ONE
		
	var root_node: ReincarnationSkillNode = null
	if viewport:
		for child in viewport.get_children():
			if child is ReincarnationSkillNode:
				if child.prerequisites.is_empty():
					root_node = child
					break
			else:
				for sub_child in child.get_children():
					if sub_child is ReincarnationSkillNode and sub_child.prerequisites.is_empty():
						root_node = sub_child
						break
			if root_node:
				break
			
	if root_node:
		var target_global_center: Vector2 = Vector2.ZERO
		if target_window:
			var w_size = target_window.size
			if w_size.x <= 100 or w_size.y <= 100:
				w_size = target_window.custom_minimum_size
			target_global_center = target_window.global_position + w_size / 2.0
		else:
			var parent_size = size
			if parent_size.x <= 0 or parent_size.y <= 0:
				parent_size = Vector2(600, 600)
			target_global_center = global_position + parent_size / 2.0
			
		var node_size = root_node.size
		if node_size.x <= 0 or node_size.y <= 0:
			node_size = root_node.custom_minimum_size
		if node_size.x <= 0 or node_size.y <= 0:
			node_size = Vector2(60, 60)
			
		var node_global_center = root_node.global_position + node_size / 2.0
		var diff = target_global_center - node_global_center
		viewport.position += diff
	elif viewport:
		viewport.position = size / 2.0
