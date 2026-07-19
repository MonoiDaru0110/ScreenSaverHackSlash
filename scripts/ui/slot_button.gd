extends Button
class_name SlotButton

@export var slot_key: String = ""
@export var allowed_type: String = ""

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE


func _get_drag_data(_at_position: Vector2) -> Variant:
	var eq = GameData.equipped_items.get(slot_key)
	if eq == null or eq.is_empty():
		return null
		
	# Entire slot button grayed out during drag
	modulate = Color(0.35, 0.35, 0.35, 0.5)
	
	set_drag_preview(_create_drag_preview(eq))
	
	return {
		"from_slot": true,
		"slot_key": slot_key,
		"item_id": eq.get("id", ""),
		"type": allowed_type,
		"name": eq.get("name", ""),
		"level": eq.get("level", 1),
		"rarity": eq.get("rarity", "コモン"),
		"icon": eq.get("icon", "")
	}


func _create_drag_preview(eq: Dictionary) -> Control:
	var preview_root := Control.new()
	preview_root.z_index = 100
	preview_root.z_as_relative = false
	
	var item_rarity: String = eq.get("rarity", "コモン")
	var item_icon: String = eq.get("icon", "")
	var item_level: int = eq.get("level", 1)
	
	var preview_box := TextureRect.new()
	preview_box.custom_minimum_size = Vector2(64, 64)
	preview_box.size = Vector2(64, 64)
	preview_box.position = -Vector2(32, 32) # Centered under mouse cursor
	preview_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var bg_path := GameData.get_rarity_bg_path(item_rarity)
	var bg_tex := load(bg_path)
	if bg_tex:
		preview_box.texture = bg_tex
		
	if item_icon != "":
		var tex := load(item_icon)
		if tex:
			var preview_icon := TextureRect.new()
			preview_icon.anchor_left = 0.15
			preview_icon.anchor_top = 0.15
			preview_icon.anchor_right = 0.85
			preview_icon.anchor_bottom = 0.85
			preview_icon.offset_left = 0
			preview_icon.offset_top = 0
			preview_icon.offset_right = 0
			preview_icon.offset_bottom = 0
			preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview_icon.texture = tex
			preview_box.add_child(preview_icon)
			
	var preview_lbl := Label.new()
	preview_lbl.text = "Lv%d" % item_level
	preview_lbl.anchor_left = 1.0
	preview_lbl.anchor_top = 1.0
	preview_lbl.anchor_right = 1.0
	preview_lbl.anchor_bottom = 1.0
	preview_lbl.offset_left = -55
	preview_lbl.offset_top = -30
	preview_lbl.offset_right = -3
	preview_lbl.offset_bottom = -2
	preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preview_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	preview_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	preview_lbl.add_theme_constant_override("outline_size", 3)
	preview_lbl.add_theme_font_size_override("font_size", 20)
	preview_box.add_child(preview_lbl)
		
	preview_root.add_child(preview_box)
	return preview_root


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


func _update_bg_color(color: Color) -> void:
	var bg_tex := find_child("BgTextureRect") as TextureRect
	if bg_tex:
		bg_tex.self_modulate = color


func _on_mouse_entered() -> void:
	_update_bg_color(Color(1.18, 1.18, 1.18))


func _on_mouse_exited() -> void:
	_update_bg_color(Color.WHITE)


func _on_button_down() -> void:
	_update_bg_color(Color(0.8, 0.8, 0.8))


func _on_button_up() -> void:
	if is_hovered():
		_update_bg_color(Color(1.18, 1.18, 1.18))
	else:
		_update_bg_color(Color.WHITE)
