extends Button
class_name SlotButton

@export var slot_key: String = ""
@export var allowed_type: String = ""

func _ready() -> void:
	gui_input.connect(_on_gui_input)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var item_type = data.get("type", "")
	return item_type == allowed_type


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		var item_id = data.get("item_id", "")
		GameData.equip_item_by_id(item_id, slot_key)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			GameData.unequip_item(slot_key)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# If clicked and equipped, unequip it
			if GameData.equipped_items.get(slot_key) != null:
				GameData.unequip_item(slot_key)
