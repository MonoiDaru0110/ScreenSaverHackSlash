extends Control

@onready var graph_edit: GraphEdit = $VBoxContainer/HBoxContainer2/GraphEdit
@onready var status_label: Label = $VBoxContainer/HBoxContainer/StatusLabel

# Sidebar references
@onready var placeholder_label: Label = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/PlaceholderLabel
@onready var editor_form: VBoxContainer = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/EditorForm
@onready var sidebar_id_edit: LineEdit = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/EditorForm/IdRow/SidebarIdEdit
@onready var sidebar_name_edit: LineEdit = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/EditorForm/NameRow/SidebarNameEdit
@onready var sidebar_icon_edit: LineEdit = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/EditorForm/IconRow/SidebarIconEdit
@onready var sidebar_desc_edit: LineEdit = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/EditorForm/DescRow/SidebarDescEdit
@onready var sidebar_max_spin: SpinBox = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/EditorForm/MaxRow/SidebarMaxSpin
@onready var sidebar_cost_spin: SpinBox = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/EditorForm/CostRow/SidebarCostSpin
@onready var sidebar_mult_spin: SpinBox = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/EditorForm/MultRow/SidebarMultSpin
@onready var prereq_list_vbox: VBoxContainer = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/EditorForm/PrereqScroll/PrereqListVBox
@onready var sidebar_delete_btn: Button = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/EditorForm/SidebarDeleteBtn
@onready var select_icon_btn: Button = $VBoxContainer/HBoxContainer2/Sidebar/SidebarVBox/ScrollContainer/PropertiesVBox/EditorForm/IconRow/SelectIconBtn

const SAVE_PATH = "res://data/skills.json"
var _selected_node: GraphNode = null
var _updating_sidebar: bool = false
var _file_dialog: FileDialog = null

func _ready() -> void:
	# Configure GraphEdit snapping and line curvature
	graph_edit.snapping_enabled = true
	graph_edit.snapping_distance = 80
	graph_edit.connection_lines_curvature = 0.0
	
	# Enable right-click disconnection on both ports
	graph_edit.right_disconnects = true
	graph_edit.add_valid_left_disconnect_type(0)
	graph_edit.add_valid_right_disconnect_type(0)
	# Register valid connection type to allow connection dragging between nodes
	graph_edit.add_valid_connection_type(0, 0)

	# Connect GraphEdit signals
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	graph_edit.node_selected.connect(_on_node_selected)
	graph_edit.node_deselected.connect(_on_node_deselected)
	
	# Connect Sidebar Input signals
	sidebar_id_edit.text_changed.connect(_on_sidebar_text_changed)
	sidebar_name_edit.text_changed.connect(_on_sidebar_text_changed)
	sidebar_icon_edit.text_changed.connect(_on_sidebar_text_changed)
	sidebar_desc_edit.text_changed.connect(_on_sidebar_text_changed)
	
	sidebar_max_spin.value_changed.connect(_on_sidebar_value_changed)
	sidebar_cost_spin.value_changed.connect(_on_sidebar_value_changed)
	sidebar_mult_spin.value_changed.connect(_on_sidebar_value_changed)
	
	sidebar_delete_btn.pressed.connect(_on_sidebar_delete_pressed)
	select_icon_btn.pressed.connect(_on_select_icon_btn_pressed)
	
	# Load existing data on start
	load_data()


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	status_label.text = "接続しました: %s -> %s" % [from_node, to_node]
	_update_prereq_checklist()


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	status_label.text = "接続解除しました: %s -> %s" % [from_node, to_node]
	_update_prereq_checklist()


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	# Disconnect any lines connected to the deleted nodes first
	var connections = graph_edit.get_connection_list()
	for conn in connections:
		if conn.from_node in nodes or conn.to_node in nodes:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
			
	for node_name in nodes:
		var node = graph_edit.get_node(NodePath(node_name))
		if node:
			if _selected_node == node:
				_clear_sidebar()
			node.queue_free()
	status_label.text = "選択ノードを削除しました。"


func _on_node_selected(node: Node) -> void:
	if not node is GraphNode:
		return
	_selected_node = node
	
	_updating_sidebar = true
	
	placeholder_label.visible = false
	editor_form.visible = true
	
	sidebar_id_edit.text = node.get_meta("skill_id", "")
	sidebar_name_edit.text = node.get_meta("skill_name", "")
	sidebar_icon_edit.text = node.get_meta("icon_char", "❓")
	sidebar_desc_edit.text = node.get_meta("description", "")
	sidebar_max_spin.value = node.get_meta("max_level", 5)
	sidebar_cost_spin.value = node.get_meta("base_cost", 1)
	sidebar_mult_spin.value = node.get_meta("cost_multiplier", 1.5)
	
	_update_prereq_checklist()
	
	_updating_sidebar = false


func _on_node_deselected(node: Node) -> void:
	if _selected_node == node:
		_clear_sidebar()


func _clear_sidebar() -> void:
	_selected_node = null
	placeholder_label.visible = true
	editor_form.visible = false
	for child in prereq_list_vbox.get_children():
		child.queue_free()


func _on_sidebar_text_changed(_new_text: String) -> void:
	if _updating_sidebar or not _selected_node:
		return
	_selected_node.set_meta("skill_id", sidebar_id_edit.text.strip_edges())
	_selected_node.set_meta("skill_name", sidebar_name_edit.text)
	
	var icon_val = sidebar_icon_edit.text
	_selected_node.set_meta("icon_char", icon_val)
	_selected_node.set_meta("description", sidebar_desc_edit.text)
	
	_update_node_icon_preview(_selected_node, icon_val)


func _on_sidebar_value_changed(_value: float) -> void:
	if _updating_sidebar or not _selected_node:
		return
	_selected_node.set_meta("max_level", int(sidebar_max_spin.value))
	_selected_node.set_meta("base_cost", int(sidebar_cost_spin.value))
	_selected_node.set_meta("cost_multiplier", sidebar_mult_spin.value)


func _on_sidebar_delete_pressed() -> void:
	if _selected_node:
		var node_name = _selected_node.name
		_clear_sidebar()
		_on_delete_nodes_request([node_name])


func _update_prereq_checklist() -> void:
	if not _selected_node:
		return
		
	# Clear existing checklist
	for child in prereq_list_vbox.get_children():
		child.queue_free()
		
	var current_node_name = _selected_node.name
	
	# Get currently connected nodes (prerequisites of _selected_node)
	var current_prereqs = []
	var connections = graph_edit.get_connection_list()
	for conn in connections:
		if conn.to_node == current_node_name:
			current_prereqs.append(conn.from_node)
			
	# Populate checklist with all OTHER nodes
	for child in graph_edit.get_children():
		if child is GraphNode and child != _selected_node:
			var other_node = child
			var other_id = other_node.get_meta("skill_id", "")
			var other_name = other_node.get_meta("skill_name", "")
			
			var checkbox = CheckBox.new()
			checkbox.text = "%s (%s)" % [other_name if not other_name.is_empty() else other_id, other_id]
			checkbox.button_pressed = other_node.name in current_prereqs
			
			# Connect toggled signal
			checkbox.toggled.connect(func(pressed: bool):
				if not _selected_node or _updating_sidebar:
					return
				if pressed:
					# Check if already connected to prevent duplicate connections
					var already_connected = false
					for conn in graph_edit.get_connection_list():
						if conn.from_node == other_node.name and conn.to_node == _selected_node.name:
							already_connected = true
							break
					if not already_connected:
						graph_edit.connect_node(other_node.name, 0, _selected_node.name, 0)
						status_label.text = "接続しました: %s -> %s" % [other_node.name, _selected_node.name]
				else:
					# Disconnect
					graph_edit.disconnect_node(other_node.name, 0, _selected_node.name, 0)
					status_label.text = "接続解除しました: %s -> %s" % [other_node.name, _selected_node.name]
			)
			prereq_list_vbox.add_child(checkbox)


func add_new_node(id := "", name_str := "", icon := "❓", desc := "", max_lvl := 5, cost := 1, mult := 1.5, pos := Vector2(100, 100)) -> GraphNode:
	var node = GraphNode.new()
	node.title = "" # No title text to keep it visual
	node.position_offset = (pos / 80.0).round() * 80.0
	node.resizable = false
	node.custom_minimum_size = Vector2(80, 80)
	node.size = Vector2(80, 80)
	
	# Override styles to merge titlebar and panel, making it a unified small square
	var flat_box = StyleBoxFlat.new()
	flat_box.bg_color = Color(0.15, 0.15, 0.25, 1.0)
	flat_box.border_width_left = 2
	flat_box.border_width_top = 2
	flat_box.border_width_right = 2
	flat_box.border_width_bottom = 2
	flat_box.border_color = Color(0.3, 0.3, 0.5, 1.0)
	flat_box.corner_radius_top_left = 6
	flat_box.corner_radius_top_right = 6
	flat_box.corner_radius_bottom_left = 6
	flat_box.corner_radius_bottom_right = 6
	
	var flat_box_selected = flat_box.duplicate()
	flat_box_selected.border_color = Color(0.8, 0.8, 1.0, 1.0)
	flat_box_selected.bg_color = Color(0.2, 0.2, 0.35, 1.0)
	
	node.add_theme_stylebox_override("panel", flat_box)
	node.add_theme_stylebox_override("panel_selected", flat_box_selected)
	
	var empty_box = StyleBoxEmpty.new()
	node.add_theme_stylebox_override("titlebar", empty_box)
	node.add_theme_stylebox_override("titlebar_selected", empty_box)
	
	# Single child container
	var container = CenterContainer.new()
	container.name = "IconContainer"
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(container)
	
	# Label for the emoji icon
	var lbl = Label.new()
	lbl.name = "IconLabel"
	lbl.text = icon
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl)

	# TextureRect for PNG icon
	var tex_rect = TextureRect.new()
	tex_rect.name = "IconTexture"
	tex_rect.custom_minimum_size = Vector2(48, 48)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(tex_rect)
	
	# Store references in metadata
	node.set_meta("skill_id", id)
	node.set_meta("skill_name", name_str)
	node.set_meta("icon_char", icon)
	node.set_meta("description", desc)
	node.set_meta("max_level", max_lvl)
	node.set_meta("base_cost", cost)
	node.set_meta("cost_multiplier", mult)
	
	_update_node_icon_preview(node, icon)
	
	graph_edit.add_child(node)
	
	# Enable left and right port for the single child (slot 0)
	# Left (input/prereq) is Cyan (Color(0.2, 0.7, 1.0)), Right (output/unlocks) is Orange (Color(1.0, 0.5, 0.1))
	node.set_slot(0, true, 0, Color(0.2, 0.7, 1.0), true, 0, Color(1.0, 0.5, 0.1))
	
	return node


func _on_add_button_pressed() -> void:
	# すでに使用されているスキルIDを探索してリスト化する
	var used_ids = []
	for child in graph_edit.get_children():
		if child is GraphNode:
			var id_val = child.get_meta("skill_id", "")
			used_ids.append(id_val)
			
	# 重複しないID "new_skill_n" (nは1以上の自然数) を自動生成する
	var n = 1
	var new_id = "new_skill_%d" % n
	while new_id in used_ids:
		n += 1
		new_id = "new_skill_%d" % n
		
	# スキル名も分かりやすく連番で生成
	var new_name = "新しいスキル %d" % n

	# Add a new node at the center of the viewport
	var center = graph_edit.scroll_offset + graph_edit.size / 2.0 - Vector2(40, 40)
	var node = add_new_node(new_id, new_name, "❓", "説明を入力してください", 5, 1, 1.5, center)
	status_label.text = "ノードを追加しました: %s" % new_id
	# Auto-select the newly added node
	node.selected = true
	_on_node_selected(node)


func save_data() -> void:
	var data = {"skills": {}}
	var node_map = {} # Map node name to skill_id
	
	# 1. Collect all nodes and their fields
	var graph_nodes: Array[GraphNode] = []
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_nodes.append(child)
			
			var skill_id = child.get_meta("skill_id", "").strip_edges()
			if skill_id.is_empty():
				status_label.text = "エラー: IDが空のノードがあります。保存できません。"
				return
				
			if data["skills"].has(skill_id):
				status_label.text = "エラー: 重複するID '%s' があります。保存できません。" % skill_id
				return
				
			node_map[child.name] = skill_id
			
			data["skills"][skill_id] = {
				"name": child.get_meta("skill_name", ""),
				"icon": child.get_meta("icon_char", "❓"),
				"description": child.get_meta("description", ""),
				"max_level": int(child.get_meta("max_level", 5)),
				"base_cost": int(child.get_meta("base_cost", 1)),
				"cost_multiplier": float(child.get_meta("cost_multiplier", 1.5)),
				"x": child.position_offset.x,
				"y": child.position_offset.y,
				"prerequisites": [] # Will populate in next step
			}
			
	# 2. Populate prerequisites from connection list
	var connections = graph_edit.get_connection_list()
	for conn in connections:
		var from_id = node_map.get(conn.from_node, "")
		var to_id = node_map.get(conn.to_node, "")
		if not from_id.is_empty() and not to_id.is_empty():
			# from_id is the prerequisite of to_id
			var to_data = data["skills"][to_id]
			if not from_id in to_data["prerequisites"]:
				to_data["prerequisites"].append(from_id)
				
	# 3. Write to JSON file
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		status_label.text = "データを正常に保存しました: %s" % SAVE_PATH
	else:
		status_label.text = "エラー: ファイルの書き込みに失敗しました。"


func load_data() -> void:
	# Clear existing connections and nodes
	graph_edit.clear_connections()
	_clear_sidebar()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
			
	if not FileAccess.file_exists(SAVE_PATH):
		status_label.text = "データファイルが見つかりません。新規作成します。"
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		status_label.text = "エラー: ファイルの読み込みに失敗しました。"
		return
		
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(text) != OK:
		status_label.text = "エラー: JSONパースに失敗しました。"
		return
		
	var data = json.get_data()
	if not data is Dictionary or not data.has("skills"):
		status_label.text = "エラー: 不正なデータ形式です。"
		return
		
	var skills = data["skills"] as Dictionary
	var created_nodes = {}
	
	# 1. Instantiate GraphNodes
	for skill_id in skills:
		var s = skills[skill_id]
		var pos = Vector2(s.get("x", 100), s.get("y", 100))
		var node = add_new_node(
			skill_id,
			s.get("name", ""),
			s.get("icon", "❓"),
			s.get("description", ""),
			s.get("max_level", 5),
			s.get("base_cost", 1),
			s.get("cost_multiplier", 1.5),
			pos
		)
		created_nodes[skill_id] = node.name
		
	# Wait a frame to ensure GraphNode names are registered in GraphEdit
	await get_tree().process_frame
	
	# 2. Restore connections
	for skill_id in skills:
		var s = skills[skill_id]
		var prereqs = s.get("prerequisites", [])
		var to_node_name = created_nodes.get(skill_id, "")
		for prereq_id in prereqs:
			var from_node_name = created_nodes.get(prereq_id, "")
			if not from_node_name.is_empty() and not to_node_name.is_empty():
				graph_edit.connect_node(from_node_name, 0, to_node_name, 0)
				
	status_label.text = "データを読み込みました。"


func _update_node_icon_preview(node: GraphNode, icon_val: String) -> void:
	var container = node.get_node_or_null("IconContainer")
	if not container:
		return
	var lbl = container.get_node_or_null("IconLabel") as Label
	var tex_rect = container.get_node_or_null("IconTexture") as TextureRect
	
	if not lbl or not tex_rect:
		return
		
	if icon_val.begins_with("res://") and ResourceLoader.exists(icon_val):
		var tex = load(icon_val)
		if tex is Texture2D:
			tex_rect.texture = tex
			tex_rect.visible = true
			lbl.visible = false
			return
			
	# Fallback to emoji label
	tex_rect.texture = null
	tex_rect.visible = false
	lbl.text = icon_val if not icon_val.is_empty() else "❓"
	lbl.visible = true


func _on_select_icon_btn_pressed() -> void:
	if not _file_dialog:
		_file_dialog = FileDialog.new()
		_file_dialog.title = "アイコン画像を選択"
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_RESOURCES
		_file_dialog.add_filter("*.png", "PNG Images")
		_file_dialog.add_filter("*.jpg,*.jpeg", "JPEG Images")
		_file_dialog.add_filter("*.svg", "SVG Images")
		_file_dialog.file_selected.connect(_on_file_selected)
		add_child(_file_dialog)
	
	# Reset current dir to resources root
	_file_dialog.current_dir = "res://"
	_file_dialog.popup_centered(Vector2i(800, 600))


func _on_file_selected(path: String) -> void:
	if _selected_node:
		sidebar_icon_edit.text = path
		_on_sidebar_text_changed(path)
