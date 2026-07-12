extends Button
class_name InventoryItemUI

var item_id: String = ""
var item_name: String = ""
var item_type: String = ""

func setup(item_data: Dictionary) -> void:
	item_id = item_data.get("id", "")
	item_name = item_data.get("name", "")
	item_type = item_data.get("type", "")
	
	var type_icon := "⚔️"
	if item_type == "sub":
		type_icon = "🛡️"
	elif item_type == "accessory":
		type_icon = "💍"
		
	var type_label := ""
	if item_type == "main":
		type_label = " (Main)"
	elif item_type == "sub":
		type_label = " (Sub)"
	else:
		type_label = " (Acc)"
		
	text = "%s %s%s" % [type_icon, item_name, type_label]
	_update_style()


func _update_style() -> void:
	var equipped_slot := GameData.is_item_equipped(item_id)
	if equipped_slot != "":
		# Clean the text and prepend equipped prefix
		var base_text = text
		if base_text.begins_with("📌 [E] "):
			base_text = base_text.substr(6)
		text = "📌 [E] %s" % base_text
		modulate = Color(0.6, 1.0, 0.6) # Light green
	else:
		if text.begins_with("📌 [E] "):
			text = text.substr(6)
		modulate = Color.WHITE


func _get_drag_data(_at_position: Vector2) -> Variant:
	# Create preview label
	var preview := Label.new()
	preview.text = text
	preview.modulate = modulate
	preview.add_theme_font_size_override("font_size", 16)
	
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.18, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.6)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(preview)
	
	set_drag_preview(panel)
	
	# Return data dictionary for drop target
	return {
		"item_id": item_id,
		"type": item_type,
		"name": item_name
	}


# Double-click to auto equip
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			_auto_equip()


func _auto_equip() -> void:
	if item_type == "main":
		GameData.equip_item_by_id(item_id, "main")
	elif item_type == "sub":
		GameData.equip_item_by_id(item_id, "sub")
	elif item_type == "accessory":
		# Find the first empty accessory slot, or overwrite accessory_1
		var target_slot := "accessory_1"
		for i in range(1, 5):
			var slot_key := "accessory_%d" % i
			if GameData.equipped_items.get(slot_key) == null:
				target_slot = slot_key
				break
		GameData.equip_item_by_id(item_id, target_slot)
