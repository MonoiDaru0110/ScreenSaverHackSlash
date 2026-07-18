extends TextureButton
class_name InventoryItemUI

var item_id: String = ""
var item_name: String = ""
var item_type: String = ""
var item_icon: String = ""
var item_level: int = 1
var item_rarity: String = "ノーマル"

@onready var icon_rect: TextureRect = %IconRect
@onready var gloss_panel: Panel = %GlossPanel
@onready var lvl_label: Label = %LevelLabel
@onready var equip_border: Panel = %EquipBorder
@onready var bg_color_rect: ColorRect = %BgColorRect
@onready var slot_base: Panel = %SlotBase

var base_bg_color: Color = Color.WHITE

func setup(item_data: Dictionary) -> void:
	item_id = item_data.get("id", "")
	item_name = item_data.get("name", "")
	item_type = item_data.get("type", "")
	item_icon = item_data.get("icon", "")
	item_level = item_data.get("level", 1)
	item_rarity = item_data.get("rarity", "ノーマル")
	
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
	
	# Configure the green/white border for equipped items (full 60x60 border)
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
		
	# Connect hover and press signals to modulate background color tint dynamically
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
	
	# Calculate modulated rarity color background (lerp with Color(0.1, 0.1, 0.25) at 12%)
	var rarity_color := GameData.get_rarity_color(item_rarity)
	base_bg_color = rarity_color.lerp(Color(0.1, 0.1, 0.25), 0.12)
	base_bg_color.a = 0.95
	
	# Apply rarity color directly to BgColorRect (which is 52x52, centered inside the 60x60 base)
	if bg_color_rect:
		bg_color_rect.color = base_bg_color
	
	# Configure gloss panel StyleBox (layered on top of BgColorRect)
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
	if bg_color_rect:
		bg_color_rect.color = color


# Modulation effects for hover / press states applied directly to the ColorRect
func _on_mouse_entered() -> void:
	_update_bg_color(base_bg_color.lightened(0.15))


func _on_mouse_exited() -> void:
	_update_bg_color(base_bg_color)


func _on_button_down() -> void:
	_update_bg_color(base_bg_color.darkened(0.15))


func _on_button_up() -> void:
	if is_hovered():
		_update_bg_color(base_bg_color.lightened(0.15))
	else:
		_update_bg_color(base_bg_color)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = "[%s] %s (Lv.%d)" % [item_rarity, item_name, item_level]
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
		"name": item_name,
		"level": item_level,
		"rarity": item_rarity,
		"icon": item_icon
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
