extends Button
class_name SlotButton

@export var slot_key: String = ""
@export var allowed_type: String = ""

@onready var slot_base: Panel = $SlotBase
@onready var equipment_icon: EquipmentIcon = %EquipmentIcon
@onready var empty_label: Label = $EmptyLabel
@onready var skill_labels: Control = $SkillGrid/SkillLabels


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
	if not equipment_icon:
		equipment_icon = get_node_or_null("EquipmentIcon") as EquipmentIcon
	if not empty_label:
		empty_label = get_node_or_null("EmptyLabel") as Label
	if not skill_labels:
		skill_labels = get_node_or_null("SkillGrid/SkillLabels") as Control


func update_slot_ui(_slot_name: String, eq: Variant) -> void:
	_ensure_nodes()
	
	# スロット全体の枠線スタイルボックスを作成
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.05, 0.05, 0.08, 0.8)
	base_style.border_width_left = 2
	base_style.border_width_top = 2
	base_style.border_width_right = 2
	base_style.border_width_bottom = 2
	base_style.corner_radius_top_left = 6
	base_style.corner_radius_top_right = 6
	base_style.corner_radius_bottom_right = 6
	base_style.corner_radius_bottom_left = 6

	if eq != null and not eq.is_empty():
		var item_rarity: String = eq.get("rarity", "コモン")
		
		var rarity_color := GameData.get_rarity_color(item_rarity)
		base_style.border_color = rarity_color
		if slot_base:
			slot_base.add_theme_stylebox_override("panel", base_style)
		
		if empty_label:
			empty_label.visible = false
		if skill_labels:
			skill_labels.visible = true
		if equipment_icon:
			equipment_icon.set_show_icon_base(false)
			equipment_icon.update_item(eq)
			
		modulate = Color.WHITE
	else:
		base_style.border_color = Color(0.32, 0.24, 0.48, 0.9) # デフォルトの薄紫色
		if slot_base:
			slot_base.add_theme_stylebox_override("panel", base_style)
			
		if empty_label:
			empty_label.visible = true
		if skill_labels:
			skill_labels.visible = false
		if equipment_icon:
			equipment_icon.update_item(null)
			equipment_icon.set_show_icon_base(false)
			
		modulate = Color.WHITE


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if equipment_icon:
			equipment_icon.modulate = Color.WHITE


func _get_drag_data(_at_position: Vector2) -> Variant:
	var eq = GameData.equipped_items.get(slot_key)
	if eq == null or eq.is_empty():
		return null
		
	if equipment_icon:
		equipment_icon.modulate = Color(0.35, 0.35, 0.35, 0.5)
	
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
	
	var preview_icon_scene := preload("res://scenes/ui/equipment_icon.tscn")
	var preview_icon := preview_icon_scene.instantiate() as EquipmentIcon
	preview_icon.position = -Vector2(32, 32)
	preview_root.add_child(preview_icon)
	
	preview_icon.set_show_icon_base(true)
	preview_icon.update_item(eq)
	
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
			if GameData.equipped_items.get(slot_key) != null:
				GameData.unequip_item(slot_key)


func _update_bg_color(color: Color) -> void:
	if equipment_icon and equipment_icon.bg_texture_rect:
		equipment_icon.bg_texture_rect.self_modulate = color


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
