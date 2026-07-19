extends Button
class_name SlotButton

@export var slot_key: String = ""
@export var allowed_type: String = ""

@onready var slot_base: Panel = $SlotBase
@onready var detail_container: VBoxContainer = $DetailContainer
@onready var name_label: Label = $DetailContainer/NameLabel
@onready var detail_label: Label = $DetailContainer/DetailLabel
@onready var icon_container: Control = $IconContainer
@onready var icon_base: Panel = $IconContainer/IconBase
@onready var bg_texture_rect: TextureRect = $IconContainer/BgTextureRect
@onready var icon_rect: TextureRect = $IconContainer/BgTextureRect/IconRect


func _ready() -> void:
	if slot_key == "" or allowed_type == "":
		match name:
			"Slot1":
				slot_key = "main"
				allowed_type = "main"
			"Slot2":
				slot_key = "sub"
				allowed_type = "sub"
			"Slot3":
				slot_key = "accessory_1"
				allowed_type = "accessory"
			"Slot4":
				slot_key = "accessory_2"
				allowed_type = "accessory"
			"Slot5":
				slot_key = "accessory_3"
				allowed_type = "accessory"
			"Slot6":
				slot_key = "accessory_4"
				allowed_type = "accessory"

	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _ensure_nodes() -> void:
	if not slot_base:
		slot_base = get_node_or_null("SlotBase") as Panel
	if not detail_container:
		detail_container = get_node_or_null("DetailContainer") as VBoxContainer
	if not name_label:
		name_label = get_node_or_null("DetailContainer/NameLabel") as Label
	if not detail_label:
		detail_label = get_node_or_null("DetailContainer/DetailLabel") as Label
	if not icon_container:
		icon_container = get_node_or_null("IconContainer") as Control
	if not icon_base:
		icon_base = get_node_or_null("IconContainer/IconBase") as Panel
	if not bg_texture_rect:
		bg_texture_rect = get_node_or_null("IconContainer/BgTextureRect") as TextureRect
	if not icon_rect:
		icon_rect = get_node_or_null("IconContainer/BgTextureRect/IconRect") as TextureRect


func update_slot_ui(slot_name: String, eq: Variant) -> void:
	_ensure_nodes()
	if eq != null and not eq.is_empty():
		if icon_base:
			icon_base.visible = false
		var item_name: String = eq.get("name", "")
		var item_icon: String = eq.get("icon", "")
		var item_level: int = eq.get("level", 1)
		var item_rarity: String = eq.get("rarity", "コモン")
		
		if icon_container:
			icon_container.visible = true
			icon_container.modulate = Color.WHITE
		if bg_texture_rect:
			bg_texture_rect.visible = true
			bg_texture_rect.modulate = Color.WHITE
			bg_texture_rect.self_modulate = Color.WHITE
			var bg_path := GameData.get_rarity_bg_path(item_rarity)
			var bg_tex := load(bg_path)
			if bg_tex:
				bg_texture_rect.texture = bg_tex
			else:
				bg_texture_rect.texture = null
			
		if icon_rect:
			icon_rect.visible = true
			icon_rect.modulate = Color.WHITE
			icon_rect.self_modulate = Color.WHITE
			if item_icon != "":
				var tex := load(item_icon)
				if tex:
					icon_rect.texture = tex
				else:
					icon_rect.texture = null
			else:
				icon_rect.texture = null
			
		if name_label:
			name_label.text = "%s: %s" % [slot_name, item_name]
			var rarity_color := GameData.get_rarity_color(item_rarity)
			name_label.add_theme_color_override("font_color", rarity_color)
		if detail_label:
			detail_label.text = "Lv.%d  [詳細スペース]" % item_level
		
		modulate = Color.WHITE
	else:
		if icon_container:
			icon_container.visible = false
		if bg_texture_rect:
			bg_texture_rect.texture = null
		if icon_rect:
			icon_rect.texture = null
		
		if name_label:
			name_label.text = "%s: (Empty)" % slot_name
			name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		if detail_label:
			detail_label.text = ""
			
		modulate = Color.WHITE


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
	
	var preview_base := Panel.new()
	preview_base.custom_minimum_size = Vector2(64, 64)
	preview_base.size = Vector2(64, 64)
	preview_base.position = -Vector2(32, 32) # Centered under mouse cursor
	
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0.05, 0.05, 0.08, 0.8)
	border_style.border_width_left = 3
	border_style.border_width_top = 3
	border_style.border_width_right = 3
	border_style.border_width_bottom = 3
	border_style.border_color = Color(0.0, 0.0, 0.0, 1.0)
	border_style.corner_radius_top_left = 6
	border_style.corner_radius_top_right = 6
	border_style.corner_radius_bottom_right = 6
	border_style.corner_radius_bottom_left = 6
	preview_base.add_theme_stylebox_override("panel", border_style)
	preview_root.add_child(preview_base)
	
	var preview_box := TextureRect.new()
	preview_box.anchor_left = 0.5
	preview_box.anchor_top = 0.5
	preview_box.anchor_right = 0.5
	preview_box.anchor_bottom = 0.5
	preview_box.offset_left = -28
	preview_box.offset_top = -28
	preview_box.offset_right = 28
	preview_box.offset_bottom = 28
	preview_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var bg_path := GameData.get_rarity_bg_path(item_rarity)
	var bg_tex := load(bg_path)
	if bg_tex:
		preview_box.texture = bg_tex
	preview_base.add_child(preview_box)
		
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
	preview_base.add_child(preview_lbl)
		
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
