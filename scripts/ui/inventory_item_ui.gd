extends TextureButton
class_name InventoryItemUI

signal selection_toggled(item_ui: InventoryItemUI, is_selected: bool)
signal item_clicked(item_ui: InventoryItemUI, button_index: int)

var item_id: String = ""
var item_name: String = ""
var item_type: String = ""
var item_icon: String = ""
var item_level: int = 1
var item_rarity: String = "コモン"
var item_equip_skill: Array = []
var item_forge_count: int = 0
var is_grayed_out: bool = false
var is_selected: bool = false
static var drag_select_mode: int = -1 # -1: 未開始, 0: 選択解除モード, 1: 選択モード

@onready var equipment_icon: EquipmentIcon = %EquipmentIcon
@onready var selected_border: Panel = %SelectedBorder
@onready var check_mark: Control = %CheckMark
var _custom_tooltip: EquipmentTooltip = null

func setup(item_data: Dictionary) -> void:
	item_id = item_data.get("id", "")
	item_name = item_data.get("name", "")
	item_type = item_data.get("type", "")
	item_icon = item_data.get("icon", "")
	item_level = item_data.get("level", 1)
	item_rarity = item_data.get("rarity", "コモン")
	item_equip_skill = item_data.get("equip_skill", [])
	item_forge_count = item_data.get("forge_count", 0)
	
	if is_node_ready():
		update_ui_display()


func set_grayed_out(grayed: bool) -> void:
	is_grayed_out = grayed
	_update_grayed_out_visual()


func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_selection_visual()


func _update_selection_visual() -> void:
	if selected_border:
		selected_border.visible = is_selected
	if check_mark:
		check_mark.visible = is_selected
		if is_selected:
			check_mark.queue_redraw()


func _on_check_mark_draw() -> void:
	if not check_mark:
		return
	var pts := PackedVector2Array([
		Vector2(4.0, 12.0),
		Vector2(9.0, 17.0),
		Vector2(19.0, 5.0)
	])
	# 外枠の黒縁取り
	check_mark.draw_polyline(pts, Color(0.0, 0.0, 0.0, 1.0), 5.0, true)
	# 鮮やかな純黄色
	check_mark.draw_polyline(pts, Color(1.0, 0.90, 0.05, 1.0), 3.0, true)


func _update_grayed_out_visual() -> void:
	if not equipment_icon:
		return
	if is_grayed_out:
		equipment_icon.modulate = Color(0.38, 0.38, 0.44, 0.55)
	else:
		equipment_icon.modulate = Color.WHITE


func _ready() -> void:
	clip_contents = false
	
	if check_mark and not check_mark.draw.is_connected(_on_check_mark_draw):
		check_mark.draw.connect(_on_check_mark_draw)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	visibility_changed.connect(_on_mouse_exited)
	tree_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
	if not Engine.is_editor_hint():
		set_process(false)
	
	update_ui_display()


func update_ui_display() -> void:
	if not equipment_icon:
		return
		
	var item_data := {
		"icon": item_icon,
		"level": item_level,
		"rarity": item_rarity,
		"forge_count": item_forge_count
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
	_update_grayed_out_visual()
	_update_selection_visual()


func _update_bg_color(color: Color) -> void:
	if equipment_icon and equipment_icon.bg_texture_rect:
		equipment_icon.bg_texture_rect.self_modulate = color


func _on_mouse_entered() -> void:
	if is_grayed_out:
		_update_bg_color(Color(1.15, 1.15, 1.15))
		if equipment_icon:
			equipment_icon.modulate = Color(0.52, 0.52, 0.58, 0.75)
	else:
		_update_bg_color(Color(1.18, 1.18, 1.18))
	
	if Engine.is_editor_hint():
		return
	if not is_visible_in_tree():
		return

	# 右クリックホールド中のなぞり選択（開始時の状態で揃える）
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_remove_tooltip()
		if drag_select_mode != -1 and GameData.is_item_equipped(item_id) == "":
			var target_state := (drag_select_mode == 1)
			if is_selected != target_state:
				set_selected(target_state)
				selection_toggled.emit(self, is_selected)
		return
	else:
		drag_select_mode = -1

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
	
	_custom_tooltip.z_index = 50
	_custom_tooltip.z_as_relative = false
	
	var item_data := {
		"id": item_id,
		"name": item_name,
		"type": item_type,
		"icon": item_icon,
		"level": item_level,
		"rarity": item_rarity,
		"equip_skill": item_equip_skill,
		"forge_count": item_forge_count
	}
	_custom_tooltip.setup(item_data)
	_update_tooltip_position()
	set_process(true)


func _on_mouse_exited() -> void:
	_update_bg_color(Color.WHITE)
	_update_grayed_out_visual()
	_remove_tooltip()


func _on_button_down() -> void:
	_update_bg_color(Color(0.8, 0.8, 0.8))


func _on_button_up() -> void:
	if is_hovered():
		if is_grayed_out:
			_update_bg_color(Color(1.15, 1.15, 1.15))
			if equipment_icon:
				equipment_icon.modulate = Color(0.52, 0.52, 0.58, 0.75)
		else:
			_update_bg_color(Color(1.18, 1.18, 1.18))
	else:
		_update_bg_color(Color.WHITE)
		_update_grayed_out_visual()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_update_grayed_out_visual()


func get_slot_index() -> int:
	var parent = get_parent()
	if parent and "slot_index" in parent:
		return parent.slot_index
	return get_index()


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
		"item_index": get_slot_index(),
		"forge_count": item_forge_count
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
		"rarity": item_rarity,
		"forge_count": item_forge_count
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
			var to_index: int = get_slot_index()
			GameData.swap_inventory_items(item_type, from_index, to_index)
		elif data.has("from_slot"):
			var from_slot_key: String = data.get("slot_key", "")
			GameData.unequip_item_to_index(from_slot_key, get_slot_index())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_remove_tooltip()
				if GameData.is_item_equipped(item_id) == "":
					var target_state := not is_selected
					drag_select_mode = 1 if target_state else 0
					set_selected(target_state)
					selection_toggled.emit(self, is_selected)
				accept_event()
			else:
				drag_select_mode = -1
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if event.double_click:
				_auto_equip()
			else:
				item_clicked.emit(self, event.button_index)


func _discard_self() -> void:
	if GameData.is_item_equipped(item_id) != "":
		return
	_remove_tooltip()
	GameData.discard_inventory_item(item_type, get_slot_index())


func _auto_equip() -> void:
	if item_type == "main":
		if GameData.is_slot_unlocked("main"):
			GameData.equip_item_by_id(item_id, "main")
	elif item_type == "sub":
		if GameData.is_slot_unlocked("sub"):
			GameData.equip_item_by_id(item_id, "sub")
	elif item_type == "accessory":
		var target_slot := ""
		for i in range(1, 5):
			var slot_key := "accessory_%d" % i
			if GameData.is_slot_unlocked(slot_key) and GameData.equipped_items.get(slot_key) == null:
				target_slot = slot_key
				break
		if target_slot == "" and GameData.is_slot_unlocked("accessory_1"):
			target_slot = "accessory_1"
		if target_slot != "":
			GameData.equip_item_by_id(item_id, target_slot)


func _remove_tooltip() -> void:
	if is_instance_valid(_custom_tooltip):
		_custom_tooltip.queue_free()
	_custom_tooltip = null
	if not Engine.is_editor_hint():
		set_process(false)


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
