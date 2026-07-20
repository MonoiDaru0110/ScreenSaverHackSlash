extends TextureButton
class_name InventoryItemUI

var item_id: String = ""
var item_name: String = ""
var item_type: String = ""
var item_icon: String = ""
var item_level: int = 1
var item_rarity: String = "コモン"
var item_equip_skill: Array = []

@onready var equipment_icon: EquipmentIcon = %EquipmentIcon
var _custom_tooltip: EquipmentTooltip = null

func setup(item_data: Dictionary) -> void:
	item_id = item_data.get("id", "")
	item_name = item_data.get("name", "")
	item_type = item_data.get("type", "")
	item_icon = item_data.get("icon", "")
	item_level = item_data.get("level", 1)
	item_rarity = item_data.get("rarity", "コモン")
	item_equip_skill = item_data.get("equip_skill", [])
	
	if is_node_ready():
		update_ui_display()


func _ready() -> void:
	clip_contents = false
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	visibility_changed.connect(_on_mouse_exited)
	tree_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
	update_ui_display()


func update_ui_display() -> void:
	if not equipment_icon:
		return
		
	var item_data := {
		"icon": item_icon,
		"level": item_level,
		"rarity": item_rarity
	}
	equipment_icon.update_item(item_data)
	
	tooltip_text = ""
	_update_style()


func _update_style() -> void:
	if not equipment_icon:
		return
		
	var equipped_slot := GameData.is_item_equipped(item_id)
	if equipped_slot != "":
		equipment_icon.set_equipped_border(true)
	else:
		equipment_icon.set_equipped_border(false)
	tooltip_text = ""


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
	
	var tooltip_scene := preload("res://scenes/ui/equipment_tooltip.tscn")
	_custom_tooltip = tooltip_scene.instantiate() as EquipmentTooltip
	
	# 親方向へ最寄りの CanvasLayer を探し、そこに追加することで最前面に描画する
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
	
	var item_data := {
		"id": item_id,
		"name": item_name,
		"type": item_type,
		"icon": item_icon,
		"level": item_level,
		"rarity": item_rarity,
		"equip_skill": item_equip_skill
	}
	_custom_tooltip.setup(item_data)
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if equipment_icon:
			equipment_icon.modulate = Color.WHITE


func _get_drag_data(_at_position: Vector2) -> Variant:
	_remove_tooltip()
	if equipment_icon:
		equipment_icon.modulate = Color(0.35, 0.35, 0.35, 0.5)
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
	
	var preview_icon_scene := preload("res://scenes/ui/equipment_icon.tscn")
	var preview_icon := preview_icon_scene.instantiate() as EquipmentIcon
	preview_icon.position = -Vector2(32, 32)
	preview_root.add_child(preview_icon)
	
	var item_data := {
		"icon": item_icon,
		"level": item_level,
		"rarity": item_rarity
	}
	preview_icon.update_item(item_data)
	
	var equipped_slot := GameData.is_item_equipped(item_id)
	preview_icon.set_equipped_border(equipped_slot != "")
	
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
