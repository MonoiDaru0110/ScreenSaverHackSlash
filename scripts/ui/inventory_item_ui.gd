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
		
	text = type_icon
	tooltip_text = "%s %s" % [type_icon, item_name]
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.25, 1.0)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.3, 0.3, 0.45, 1.0)
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_right = 4
	style_normal.corner_radius_bottom_left = 4
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.22, 0.22, 0.35, 1.0)
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(0.4, 0.4, 0.6, 1.0)
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_right = 4
	style_hover.corner_radius_bottom_left = 4

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.1, 0.1, 0.18, 1.0)
	style_pressed.border_width_left = 1
	style_pressed.border_width_top = 1
	style_pressed.border_width_right = 1
	style_pressed.border_width_bottom = 1
	style_pressed.border_color = Color(0.2, 0.2, 0.3, 1.0)
	style_pressed.corner_radius_top_left = 4
	style_pressed.corner_radius_top_right = 4
	style_pressed.corner_radius_bottom_right = 4
	style_pressed.corner_radius_bottom_left = 4

	add_theme_stylebox_override("normal", style_normal)
	add_theme_stylebox_override("hover", style_hover)
	add_theme_stylebox_override("pressed", style_pressed)
	
	add_theme_font_size_override("font_size", 24)
	
	_update_style()


func _update_style() -> void:
	var equipped_slot := GameData.is_item_equipped(item_id)
	
	var border_color = Color(0.3, 0.3, 0.45, 1.0)
	var border_width = 1
	
	if equipped_slot != "":
		border_color = Color(0.2, 0.8, 0.2, 1.0)
		border_width = 2
		tooltip_text = "[装備中 - %s] %s" % [equipped_slot.capitalize(), "%s %s" % [text, item_name]]
	else:
		tooltip_text = "%s %s" % [text, item_name]
		
	var normal_style = get_theme_stylebox("normal").duplicate()
	if normal_style is StyleBoxFlat:
		normal_style.border_color = border_color
		normal_style.border_width_left = border_width
		normal_style.border_width_top = border_width
		normal_style.border_width_right = border_width
		normal_style.border_width_bottom = border_width
		add_theme_stylebox_override("normal", normal_style)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = "%s %s" % [text, item_name]
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
	
	return {
		"item_id": item_id,
		"type": item_type,
		"name": item_name
	}


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
		var target_slot := "accessory_1"
		for i in range(1, 5):
			var slot_key := "accessory_%d" % i
			if GameData.equipped_items.get(slot_key) == null:
				target_slot = slot_key
				break
		GameData.equip_item_by_id(item_id, target_slot)
