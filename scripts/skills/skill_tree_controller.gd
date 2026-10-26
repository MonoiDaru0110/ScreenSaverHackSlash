extends Control
class_name SkillTreeController

@export var min_zoom := 0.3
@export var max_zoom := 2.0
@export var zoom_speed := 0.1

@onready var viewport: Control = %SkillTreeViewport

var _zoom := 1.0
var _is_dragging := false
var _last_mouse_pos := Vector2.ZERO
var filter_unlocked_only: bool = true

var _cached_skill_nodes: Array[SkillNode] = []
var _skill_nodes_cached: bool = false

# スキルツリーの親子関係とウィンドウ対応ルートノードのキャッシュ
var _skill_node_map: Dictionary = {} # skill_id -> SkillNode
var _main_root_ids: Array[String] = [] # prerequisites.is_empty() なノード
var _window_root_ids: Array[String] = [] # prerequisites に main_root_id を持つノード (各ウィンドウ対応ルートノード)
var _node_ancestor_window_roots: Dictionary = {} # skill_id -> Array[String]
var _graph_cached: bool = false

func _get_skill_nodes() -> Array[SkillNode]:
	if _skill_nodes_cached:
		return _cached_skill_nodes
	_cached_skill_nodes.clear()
	if viewport:
		var found = viewport.find_children("*", "SkillNode", true, false)
		for node in found:
			if node is SkillNode:
				_cached_skill_nodes.append(node as SkillNode)
	_skill_nodes_cached = true
	return _cached_skill_nodes

func invalidate_skill_node_cache() -> void:
	_skill_nodes_cached = false
	_cached_skill_nodes.clear()
	_graph_cached = false
	_skill_node_map.clear()
	_main_root_ids.clear()
	_window_root_ids.clear()
	_node_ancestor_window_roots.clear()

func _rebuild_skill_graph() -> void:
	_skill_node_map.clear()
	_main_root_ids.clear()
	_window_root_ids.clear()
	_node_ancestor_window_roots.clear()
	
	var nodes = _get_skill_nodes()
	for node in nodes:
		if not node.skill_id.is_empty():
			_skill_node_map[node.skill_id] = node
			
	# 1. メインルートノードの特定（"root_node" または 前提スキルが空のノード）
	for node in nodes:
		if node.skill_id == "root_node" or node.prerequisites.is_empty():
			if not _main_root_ids.has(node.skill_id):
				_main_root_ids.append(node.skill_id)
			
	# 2. 各ウィンドウ対応ルートノードの特定（前提スキルにメインルートノードを含むノード、または明示的なアンロックノード）
	for node in nodes:
		if _main_root_ids.has(node.skill_id):
			continue
		var is_window_root := false
		for p in node.prerequisites:
			if _main_root_ids.has(p):
				is_window_root = true
				break
		if is_window_root or node.skill_id in ["equip_drop_unlock", "challenge_unlock", "challange_unlock", "blacksmith_unlock", "amplifier_unlock"]:
			if not _window_root_ids.has(node.skill_id):
				_window_root_ids.append(node.skill_id)
				
	# 3. 各ノードの祖先ウィンドウルートノードを探索・キャッシュ
	for node in nodes:
		var ancestors: Array[String] = []
		_find_ancestor_window_roots(node.skill_id, ancestors, {})
		_node_ancestor_window_roots[node.skill_id] = ancestors
		
	_graph_cached = true

func _find_ancestor_window_roots(current_id: String, out_roots: Array[String], visited: Dictionary) -> void:
	if visited.has(current_id):
		return
	visited[current_id] = true
	
	if _window_root_ids.has(current_id):
		if not out_roots.has(current_id):
			out_roots.append(current_id)
		return
		
	if _main_root_ids.has(current_id):
		return
		
	var node = _skill_node_map.get(current_id) as SkillNode
	if not node:
		return
		
	for p in node.prerequisites:
		_find_ancestor_window_roots(p, out_roots, visited)

func is_node_progression_visible(node: SkillNode) -> bool:
	if not _graph_cached:
		_rebuild_skill_graph()
		
	# メインルートノードは常に可視
	if _main_root_ids.has(node.skill_id):
		return true
		
	# 各ウィンドウ対応ルートノードも常に可視（未解放でも見えている状態）
	if _window_root_ids.has(node.skill_id):
		return true
		
	# その先のノード: 祖先のウィンドウ対応ルートノードが解放されている場合のみ可視
	var ancestor_roots: Array = _node_ancestor_window_roots.get(node.skill_id, [])
	if ancestor_roots.is_empty():
		return true # 祖先が見つからないノードはフォールバックとして表示
		
	for w_id in ancestor_roots:
		if GameData.get_skill_level(w_id) > 0:
			return true
			
	return false

func _ready() -> void:
	clip_contents = true
	if not Engine.is_editor_hint():
		GameData.skill_upgraded.connect(_on_skill_upgraded)
	
	# Wait a frame to ensure the instanced skill tree data is loaded
	await get_tree().process_frame
	if viewport:
		# Set mouse filter to PASS so background clicks propagate to this controller.
		viewport.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Also make sure the instanced SkillTreeData itself passes mouse events.
		var child_size = Vector2(400, 400)
		for child in viewport.get_children():
			if not child is SkillNode and child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_PASS
				child_size = child.size
				
		# Set pivot offset to ZERO so scaling calculation from top-left is accurate
		viewport.pivot_offset = Vector2.ZERO
		
		# Center the viewport initially
		var parent_size = size
		viewport.position = (parent_size - child_size) / 2.0
		
	visibility_changed.connect(update_culling)

func toggle_filter_unlocked_only() -> bool:
	filter_unlocked_only = not filter_unlocked_only
	update_culling()
	return filter_unlocked_only

func is_node_filter_visible(node: SkillNode) -> bool:
	# 進行度に基づく可視性（ウィンドウ対応ルートノード解放でその先が見える）
	return is_node_progression_visible(node)

func _on_skill_upgraded(_skill_id: String, _new_level: int) -> void:
	update_culling()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			# Mouse Wheel Zoom
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_mouse(zoom_speed)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_mouse(-zoom_speed)
				accept_event()
		
		# Dragging / Panning initiation
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.is_pressed():
				_is_dragging = true
				_last_mouse_pos = event.global_position
				mouse_default_cursor_shape = Control.CURSOR_DRAG
				accept_event()
			else:
				_is_dragging = false
				mouse_default_cursor_shape = Control.CURSOR_ARROW
				accept_event()
				
	elif event is InputEventMouseMotion:
		if _is_dragging:
			var diff = event.global_position - _last_mouse_pos
			# Directly shift the viewport coordinate system for panning
			if viewport:
				viewport.position += diff
				update_culling()
			_last_mouse_pos = event.global_position
			accept_event()


func _zoom_at_mouse(factor: float) -> void:
	if not viewport:
		return
		
	var old_zoom = _zoom
	_zoom = clamp(_zoom + factor, min_zoom, max_zoom)
	if old_zoom == _zoom:
		return
		
	# Get mouse local position on the viewport control before scaling
	var mouse_local = viewport.get_local_mouse_position()
	
	# Apply scale
	viewport.scale = Vector2(_zoom, _zoom)
	
	# Adjust position to keep the mouse point stable
	var shift = mouse_local * (_zoom - old_zoom)
	viewport.position -= shift
	update_culling()


func center_on_root(window: Control = null) -> void:
	# Reset zoom to 1.0 when centering
	_zoom = 1.0
	if viewport:
		viewport.scale = Vector2.ONE
		
	# "root_node" または前提スキル（prerequisites）がないスキルを「ルートスキル」として自動探索する（子孫から検索）
	var root_node: SkillNode = null
	var skill_nodes = _get_skill_nodes()
	for node in skill_nodes:
		if node.skill_id == "root_node":
			root_node = node
			break
		if node.prerequisites.is_empty() and root_node == null:
			root_node = node
			
	if root_node:
		# 1. ターゲット（ウィンドウまたは自身）のグローバル中心を求める
		var target_global_center = Vector2.ZERO
		if window:
			var w_size = window.size
			if w_size.x <= 100 or w_size.y <= 100:
				w_size = window.custom_minimum_size
			if w_size.x <= 100 or w_size.y <= 100:
				w_size = Vector2(1200, 861) # 最終フォールバック
			target_global_center = window.global_position + w_size / 2.0
		else:
			var parent_size = size
			if parent_size.x <= 0 or parent_size.y <= 0:
				parent_size = Vector2(1168, 764)
			target_global_center = global_position + parent_size / 2.0
			
		# 2. ルートノードのグローバル中心を求める
		var node_size = root_node.size
		if node_size.x <= 0 or node_size.y <= 0:
			node_size = root_node.custom_minimum_size
		if node_size.x <= 0 or node_size.y <= 0:
			node_size = Vector2(60, 60) # 60x60 が SkillNode の正しいデフォルトサイズ
			
		var node_global_center = root_node.global_position + node_size / 2.0
		
		# 3. グローバル差分を計算し、viewport の位置に加算する（中間オフセットやトランスフォームのずれを自動吸収）
		var diff = target_global_center - node_global_center
		viewport.position += diff
	else:
		# ルートノードが見つからない場合のフォールバック（全体の中央揃え）
		var child_size = Vector2(600, 600)
		for child in viewport.get_children():
			if not child is SkillNode and child is Control:
				child_size = child.size
				break
		var parent_size = size
		if parent_size.x <= 0 or parent_size.y <= 0:
			parent_size = Vector2(1168, 764)
		viewport.position = (parent_size - child_size) / 2.0
	update_culling()


func update_culling() -> void:
	if not viewport or not is_inside_tree() or not is_visible_in_tree():
		return
		
	var container_rect = get_global_rect()
	var skill_nodes = _get_skill_nodes()
	
	var node_filter_map: Dictionary = {}
	
	# 1. 各 SkillNode の表示状態更新
	for node in skill_nodes:
		if not node is SkillNode:
			continue
			
		var filter_vis := is_node_filter_visible(node)
		node_filter_map[node] = filter_vis
		
		if not filter_vis:
			if node.visible:
				node.visible = false
			continue
			
		var node_rect = node.get_global_rect()
		# 枠線9px分やズームを考慮して余裕を持たせる
		var expanded_rect = node_rect.grow(15.0 * _zoom)
		var is_visible = container_rect.intersects(expanded_rect)
		
		if node.visible != is_visible:
			node.visible = is_visible
			
	# 2. 各 SkillNode の _lines (Line2D 接続線) の表示状態更新
	for node in skill_nodes:
		if not node is SkillNode:
			continue
			
		var node_filter_vis: bool = node_filter_map.get(node, false)
		
		for line in node._lines:
			if is_instance_valid(line) and line is Line2D and line.points.size() >= 2:
				if not node_filter_vis:
					if line.visible:
						line.visible = false
					continue
					
				# 接続元（前提ノード）の可視性もチェック
				var prereq_id: String = line.get_meta("prereq_id", "")
				if not prereq_id.is_empty():
					var parent_node = _skill_node_map.get(prereq_id) as SkillNode
					if parent_node and not node_filter_map.get(parent_node, false):
						if line.visible:
							line.visible = false
						continue
					
				var p1_global = line.to_global(line.points[0])
				var p2_global = line.to_global(line.points[1])
				var line_rect = Rect2(p1_global, Vector2.ZERO).expand(p2_global).grow(5.0 * _zoom)
				var is_visible = container_rect.intersects(line_rect)
				if line.visible != is_visible:
					line.visible = is_visible
