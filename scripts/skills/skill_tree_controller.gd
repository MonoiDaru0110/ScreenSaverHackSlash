extends Control
class_name SkillTreeController

@export var min_zoom := 0.5
@export var max_zoom := 2.0
@export var zoom_speed := 0.1

@onready var viewport: Control = %SkillTreeViewport

var _zoom := 1.0
var _is_dragging := false
var _last_mouse_pos := Vector2.ZERO

func _ready() -> void:
	clip_contents = true
	
	# Wait a frame to ensure the instanced skill tree data is loaded
	await get_tree().process_frame
	if viewport:
		# Set mouse filter to PASS so background clicks propagate to this controller.
		viewport.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Also make sure the instanced SkillTreeData itself passes mouse events.
		var child_size = Vector2(400, 400)
		for child in viewport.get_children():
			if not child is SkillNode and child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_PASS
				child_size = child.size
				
		# Set pivot offset to ZERO so scaling calculation from top-left is accurate
		viewport.pivot_offset = Vector2.ZERO
		
		# Center the viewport initially
		var parent_size = size
		viewport.position = (parent_size - child_size) / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			# Mouse Wheel Zoom
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_mouse(zoom_speed)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_mouse(-zoom_speed)
				accept_event()
		
		# Dragging / Panning initiation
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
			# Directly shift the viewport coordinate system for panning
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
		
	# Get mouse local position on the viewport control before scaling
	var mouse_local = viewport.get_local_mouse_position()
	
	# Apply scale
	viewport.scale = Vector2(_zoom, _zoom)
	
	# Adjust position to keep the mouse point stable
	var shift = mouse_local * (_zoom - old_zoom)
	viewport.position -= shift
