extends TextureButton
class_name InventoryItemUI

var item_id: String = ""
var item_name: String = ""
var item_type: String = ""
var item_icon: String = ""
var item_level: int = 1
var item_rarity: String = "コモン"

@onready var icon_rect: TextureRect = %IconRect
@onready var gloss_panel: Panel = %GlossPanel
@onready var lvl_label: Label = %LevelLabel
@onready var equip_border: Panel = %EquipBorder
@onready var bg_texture_rect: TextureRect = %BgTextureRect
@onready var slot_base: Panel = %SlotBase

func setup(item_data: Dictionary) -> void:
	item_id = item_data.get("id", "")
	item_name = item_data.get("name", "")
	item_type = item_data.get("type", "")
	item_icon = item_data.get("icon", "")
	item_level = item_data.get("level", 1)
	item_rarity = item_data.get("rarity", "コモン")
	
	# If the node is already ready (in the tree), update the display immediately
	if is_node_ready():
		update_ui_display()


func _ready() -> void:
	# Ensure the button doesn't clip children so the level label can overflow
	clip_contents = false
	
	# Configure the slot base StyleBox (identical to empty slots style)
	if slot_base:
		var base_style := StyleBoxFlat.new()
		base_style.bg_color = Color(0.08, 0.08, 0.12, 0.6) # Dark transparent slot BG
		base_style.border_width_left = 1
		base_style.border_width_top = 1
		base_style.border_width_right = 1
		base_style.border_width_bottom = 1
		base_style.border_color = Color(0.18, 0.18, 0.25, 0.8) # Grid border color
		base_style.corner_radius_top_left = 4
		base_style.corner_radius_top_right = 4
		base_style.corner_radius_bottom_right = 4
		base_style.corner_radius_bottom_left = 4
		slot_base.add_theme_stylebox_override("panel", base_style)
	
	# Configure the white border for equipped items (full 64x64 border)
	if equip_border:
		var border_style := StyleBoxFlat.new()
		border_style.draw_center = false # Transparent center
		border_style.border_width_left = 2
		border_style.border_width_top = 2
		border_style.border_width_right = 2
		border_style.border_width_bottom = 2
		border_style.border_color = Color(1.0, 1.0, 1.0, 0.6) # Translucent white border
		border_style.corner_radius_top_left = 4
		border_style.corner_radius_top_right = 4
		border_style.corner_radius_bottom_right = 4
		border_style.corner_radius_bottom_left = 4
		equip_border.add_theme_stylebox_override("panel", border_style)
		
	# Connect hover and press signals to modulate background brightness dynamically
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
	# Update the display when entering the tree
	update_ui_display()


func update_ui_display() -> void:
	# Set up texture icon
	if item_icon != "" and icon_rect:
		var tex := load(item_icon)
		if tex:
			icon_rect.texture = tex
		else:
			icon_rect.texture = null
	elif icon_rect:
		icon_rect.texture = null
			
	# Set up level label
	if lvl_label:
		lvl_label.text = "Lv%d" % item_level
	
	# Tooltip setting
	tooltip_text = "[%s] %s (Lv.%d)" % [item_rarity, item_name, item_level]
	
	# Apply rarity background texture directly to BgTextureRect (which is 56x56, centered inside 64x64 base)
	if bg_texture_rect:
		var bg_path := GameData.get_rarity_bg_path(item_rarity)
		var bg_tex := load(bg_path)
		if bg_tex:
			bg_texture_rect.texture = bg_tex
		else:
			bg_texture_rect.texture = null
		bg_texture_rect.self_modulate = Color.WHITE
	
	# Configure gloss panel StyleBox (layered on top of BgTextureRect)
	if gloss_panel:
		var gloss_style := StyleBoxFlat.new()
		gloss_style.bg_color = Color(1.0, 1.0, 1.0, 0.12) # 12% opacity white
		gloss_style.corner_radius_top_left = 4
		gloss_style.corner_radius_top_right = 4
		gloss_style.corner_radius_bottom_left = 0
		gloss_style.corner_radius_bottom_right = 0
		gloss_panel.add_theme_stylebox_override("panel", gloss_style)
		
	# Ensure the level label stays on top of the gloss panel
	if lvl_label:
		move_child(lvl_label, get_child_count() - 1)
	
	_update_style()


func _update_style() -> void:
	var equipped_slot := GameData.is_item_equipped(item_id)
	
	if equipped_slot != "":
		if equip_border:
			equip_border.visible = true
		tooltip_text = "[装備中 - %s] [%s] %s (Lv.%d)" % [equipped_slot.capitalize(), item_rarity, item_name, item_level]
	else:
		if equip_border:
			equip_border.visible = false
		tooltip_text = "[%s] %s (Lv.%d)" % [item_rarity, item_name, item_level]


func _update_bg_color(color: Color) -> void:
	if bg_texture_rect:
		bg_texture_rect.self_modulate = color


# Modulation effects for hover / press states applied to the BgTextureRect
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE


func _get_drag_data(_at_position: Vector2) -> Variant:
	# Entire root node grayed out during drag
	modulate = Color(0.35, 0.35, 0.35, 0.5)
	
	set_drag_preview(_create_drag_preview())
	
	return {
		"from_inventory": true,
		"item_id": item_id,
		"type": item_type,
		"name": item_name,
		"level": item_level,
		"rarity": item_rarity,
		"icon": item_icon,
		"item_index": get_index()
	}


func _create_drag_preview() -> Control:
	var preview_root := Control.new()
	preview_root.z_index = 100
	preview_root.z_as_relative = false
	
	var preview_box := TextureRect.new()
	preview_box.custom_minimum_size = Vector2(64, 64)
	preview_box.size = Vector2(64, 64)
	preview_box.position = -Vector2(32, 32) # Centered under mouse cursor
	preview_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if bg_texture_rect and bg_texture_rect.texture:
		preview_box.texture = bg_texture_rect.texture
		
	if icon_rect and icon_rect.texture:
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
		preview_icon.texture = icon_rect.texture
		preview_box.add_child(preview_icon)
		
	if lvl_label and lvl_label.text != "":
		var preview_lbl := Label.new()
		preview_lbl.text = lvl_label.text
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
	var incoming_type: String = data.get("type", "")
	return incoming_type == item_type


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		if data.has("item_index"):
			var from_index: int = data.get("item_index", -1)
			var to_index: int = get_index()
			GameData.swap_inventory_items(item_type, from_index, to_index)
		elif data.has("from_slot"):
			var from_slot_key: String = data.get("slot_key", "")
			GameData.unequip_item_to_index(from_slot_key, get_index())


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
