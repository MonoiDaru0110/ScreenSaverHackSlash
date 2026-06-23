@tool
extends Control

@export var snap_step: Vector2 = Vector2(80, 80)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	
	# Scan and snap all child SkillNodes to the grid in the editor
	for child in get_children():
		if child is SkillNode:
			if snap_step.x > 0 and snap_step.y > 0:
				var snapped_pos = (child.position / snap_step).round() * snap_step
				if child.position != snapped_pos:
					child.position = snapped_pos
