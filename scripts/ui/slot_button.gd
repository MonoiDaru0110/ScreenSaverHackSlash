extends Button
class_name SlotButton

@export var slot_key: String = ""
@export var allowed_type: String = ""

@onready var slot_base: Panel = $SlotBase
@onready var equipment_icon: EquipmentIcon = %EquipmentIcon
@onready var empty_label: Label = $EmptyLabel
@onready var equip_skill_labels: Control = $EquipSkillGrid/EquipSkillLabels
var _custom_tooltip: EquipmentTooltip = null


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
	visibility_changed.connect(_on_mouse_exited)
	tree_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _ensure_nodes() -> void:
	if not slot_base:
		slot_base = get_node_or_null("SlotBase") as Panel
	if not equipment_icon:
		equipment_icon = get_node_or_null("EquipmentIcon") as EquipmentIcon
	if not empty_label:
		empty_label = get_node_or_null("EmptyLabel") as Label
	if not equip_skill_labels:
		equip_skill_labels = get_node_or_null("EquipSkillGrid/EquipSkillLabels") as Control


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
		
		tooltip_text = ""
		if empty_label:
			empty_label.visible = false
		if equip_skill_labels:
			equip_skill_labels.visible = true
			var item_equip_skills = eq.get("equip_skill", [])
			for i in range(1, 7):
				var name_node = equip_skill_labels.get_node_or_null("EquipSkillName%d" % i) as Label
				var val_node = equip_skill_labels.get_node_or_null("EquipSkillVal%d" % i) as Label
				
				if i <= item_equip_skills.size():
					var skill = item_equip_skills[i - 1]
					if name_node:
						name_node.tooltip_text = ""
						name_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
						name_node.text = skill.get("name", "")
						name_node.visible = true
					if val_node:
						val_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
						val_node.text = "+%d" % skill.get("level", 1)
						val_node.visible = true
				else:
					if name_node:
						name_node.tooltip_text = ""
						name_node.visible = false
					if val_node:
						val_node.visible = false
						
		if equipment_icon:
			equipment_icon.set_show_icon_base(false)
			equipment_icon.update_item(eq)
			
		modulate = Color.WHITE
	else:
		base_style.border_color = Color(0.32, 0.24, 0.48, 0.9) # デフォルトの薄紫色
		if slot_base:
			slot_base.add_theme_stylebox_override("panel", base_style)
			
		tooltip_text = "" # 空にしてツールチップを無効化
		if empty_label:
			empty_label.visible = true
		if equip_skill_labels:
			equip_skill_labels.visible = false
		if equipment_icon:
			equipment_icon.update_item(null)
			equipment_icon.set_show_icon_base(false)
			
		modulate = Color.WHITE


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if equipment_icon:
			equipment_icon.modulate = Color.WHITE


func _get_drag_data(_at_position: Vector2) -> Variant:
	_remove_tooltip()
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
		_remove_tooltip()
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
	
	if Engine.is_editor_hint():
		return
	if not is_visible_in_tree():
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
		
	_remove_tooltip()
	
	var eq = GameData.equipped_items.get(slot_key)
	if eq == null or eq.is_empty():
		return
		
	var tooltip_scene := preload("res://scenes/ui/equipment_tooltip.tscn")
	_custom_tooltip = tooltip_scene.instantiate() as EquipmentTooltip
	
	# 親方向へ最寄りの CanvasLayer を探し、そこに追加することでインベントリ等の前面に確実に描画する
	var parent_node = get_parent()
	var canvas_layer: CanvasLayer = null
	while parent_node:
		if parent_node is CanvasLayer:
			canvas_layer = parent_node as CanvasLayer
			break
		parent_node = parent_node.get_parent()
		
	if canvas_layer:
		canvas_layer.add_child(_custom_tooltip)
	else:
		_custom_tooltip.top_level = true
		add_child(_custom_tooltip)
	
	_custom_tooltip.setup(eq)
	_update_tooltip_position()


func _on_mouse_exited() -> void:
	_update_bg_color(Color.WHITE)
	_remove_tooltip()


func _on_button_down() -> void:
	_update_bg_color(Color(0.8, 0.8, 0.8))


func _on_button_up() -> void:
	if is_hovered():
		_update_bg_color(Color(1.18, 1.18, 1.18))
	else:
		_update_bg_color(Color.WHITE)


func _remove_tooltip() -> void:
	if is_instance_valid(_custom_tooltip):
		_custom_tooltip.queue_free()
	_custom_tooltip = null


func _update_tooltip_position() -> void:
	if not is_instance_valid(_custom_tooltip):
		return
		
	var mouse_pos = get_global_mouse_position()
	var offset = Vector2(15, 15)
	var target_pos = mouse_pos + offset
	
	# 画面端での見切れ防止処理
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_size = _custom_tooltip.get_combined_minimum_size()
	
	if target_pos.x + tooltip_size.x > viewport_size.x:
		target_pos.x = mouse_pos.x - tooltip_size.x - 15
	if target_pos.y + tooltip_size.y > viewport_size.y:
		target_pos.y = mouse_pos.y - tooltip_size.y - 15
		
	_custom_tooltip.global_position = target_pos


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_remove_tooltip()
		else:
			_update_tooltip_position()
