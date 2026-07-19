extends CanvasLayer
## Heads-up display showing gold, bounce count, and corner hit announcements.

@onready var gold_label: Label = $Sidebar/SidebarLayout/FooterBottomSection/CenterContainer/GoldLabel
@onready var token_label: Label = $Sidebar/SidebarLayout/FooterTopSection/CenterContainer/TokenLabel
@onready var bounce_label: Label = $BounceLabel
@onready var corner_label: Label = $CornerLabel
@onready var corner_announce: Label = $CornerAnnounce

@onready var btn_size: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton1
@onready var btn_speed: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton2
@onready var btn_boost: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton3
@onready var btn_ascend: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton4

# Tab UI references
@onready var btn_equipment_tab: Button = %EquipmentTabBtn
@onready var btn_skill_tree_tab: Button = %SkillTreeTabBtn
@onready var grid_equipment: GridContainer = %GridContainer
@onready var skill_tree_viewport: Control = %SkillTreeViewport
@onready var skill_tree_window: PanelContainer = %SkillTreeWindow
@onready var skill_tree_scroll: SkillTreeController = %SkillTreeScroll
@onready var btn_close_window: Button = %CloseWindowBtn

# Inventory UI references
@onready var inventory_window: PanelContainer = %InventoryWindow
@onready var btn_close_inventory: Button = %CloseInventoryBtn
@onready var main_title_label: Label = %MainTitleLabel
@onready var sub_title_label: Label = %SubTitleLabel
@onready var accessory_title_label: Label = %AccessoryTitleLabel
@onready var main_grid: GridContainer = %MainGrid
@onready var sub_grid: GridContainer = %SubGrid
@onready var accessory_grid: GridContainer = %AccessoryGrid
@onready var equipment_log_container: VBoxContainer = %EquipmentLogContainer

var _skill_tree_scene: PackedScene = preload("res://scenes/skills/skill_tree_data.tscn")
var _skill_tree_instance: Control
var _tab_style_active: StyleBoxFlat
var _tab_style_inactive: StyleBoxFlat
var _is_skill_tree_open: bool = false
var _is_inventory_open: bool = false
var _has_centered_on_startup: bool = false
var _slot_buttons: Dictionary = {}

# パフォーマンス最適化: アップグレードボタン更新のスロットリング
var _upgrade_buttons_dirty: bool = false
var _upgrade_update_timer: Timer = null

# パフォーマンス最適化: ボタン子ラベルのキャッシュ
var _lbl_title_size: Label
var _lbl_cost_size: Label
var _lbl_title_speed: Label
var _lbl_cost_speed: Label
var _lbl_title_boost: Label
var _lbl_cost_boost: Label
var _lbl_title_ascend: Label
var _lbl_cost_ascend: Label


func _ready() -> void:
	# Configure StyleBoxFlat for button states programmatically
	# to prevent Godot Editor from overwriting the .tscn scene file styles.
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.33, 0.15, 0.85, 1)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.45, 0.25, 0.92, 1)
	style_normal.corner_radius_top_left = 3
	style_normal.corner_radius_top_right = 3
	style_normal.corner_radius_bottom_right = 3
	style_normal.corner_radius_bottom_left = 3

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.42, 0.25, 0.92, 1)
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(0.55, 0.38, 0.98, 1)
	style_hover.corner_radius_top_left = 3
	style_hover.corner_radius_top_right = 3
	style_hover.corner_radius_bottom_right = 3
	style_hover.corner_radius_bottom_left = 3

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.22, 0.08, 0.6, 1)
	style_pressed.border_width_left = 2
	style_pressed.border_width_top = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_bottom = 2
	style_pressed.border_color = Color(0.32, 0.14, 0.75, 1)
	style_pressed.corner_radius_top_left = 3
	style_pressed.corner_radius_top_right = 3
	style_pressed.corner_radius_bottom_right = 3
	style_pressed.corner_radius_bottom_left = 3

	var style_disabled := StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.24, 0.14, 0.42, 1) # Closer to default with slightly higher brightness/saturation
	style_disabled.border_width_left = 2
	style_disabled.border_width_top = 2
	style_disabled.border_width_right = 2
	style_disabled.border_width_bottom = 2
	style_disabled.border_color = Color(0.28, 0.18, 0.48, 1)
	style_disabled.corner_radius_top_left = 3
	style_disabled.corner_radius_top_right = 3
	style_disabled.corner_radius_bottom_right = 3
	style_disabled.corner_radius_bottom_left = 3

	var style_focus := StyleBoxEmpty.new() # Removes focus outline border highlighting

	for btn in [btn_size, btn_speed, btn_boost, btn_ascend]:
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("disabled", style_disabled)
		btn.add_theme_stylebox_override("focus", style_focus)
		
		# Make font sizes slightly larger and align the coin emoji visually
		btn.get_node("Content/TitleLabel").add_theme_font_size_override("font_size", 18)
		btn.get_node("Content/CostLabel").add_theme_font_size_override("font_size", 16)

	# Tab button styles setup
	_tab_style_active = StyleBoxFlat.new()
	_tab_style_active.bg_color = Color(0.33, 0.15, 0.85, 1)
	_tab_style_active.border_width_left = 2
	_tab_style_active.border_width_top = 2
	_tab_style_active.border_width_right = 2
	_tab_style_active.border_width_bottom = 2
	_tab_style_active.border_color = Color(0.45, 0.25, 0.92, 1)
	_tab_style_active.corner_radius_top_left = 3
	_tab_style_active.corner_radius_top_right = 3
	_tab_style_active.corner_radius_bottom_right = 3
	_tab_style_active.corner_radius_bottom_left = 3

	_tab_style_inactive = StyleBoxFlat.new()
	_tab_style_inactive.bg_color = Color(0.12, 0.12, 0.2, 1)
	_tab_style_inactive.border_width_left = 2
	_tab_style_inactive.border_width_top = 2
	_tab_style_inactive.border_width_right = 2
	_tab_style_inactive.border_width_bottom = 2
	_tab_style_inactive.border_color = Color(0.2, 0.2, 0.35, 1)
	_tab_style_inactive.corner_radius_top_left = 3
	_tab_style_inactive.corner_radius_top_right = 3
	_tab_style_inactive.corner_radius_bottom_right = 3
	_tab_style_inactive.corner_radius_bottom_left = 3

	btn_equipment_tab.add_theme_stylebox_override("focus", style_focus)
	btn_skill_tree_tab.add_theme_stylebox_override("focus", style_focus)
	
	btn_equipment_tab.pressed.connect(_on_equipment_tab_pressed)
	btn_skill_tree_tab.pressed.connect(_on_skill_tree_tab_pressed)

	# Instantiate and add skill tree container to viewport
	_skill_tree_instance = _skill_tree_scene.instantiate()
	skill_tree_viewport.add_child(_skill_tree_instance)
	
	# Load skills dynamically from JSON
	_load_skills_from_json()

	GameData.gold_changed.connect(_on_gold_changed)
	GameData.tokens_changed.connect(_on_tokens_changed)
	GameData.stats_changed.connect(_on_stats_changed)
	GameData.corner_hit_occurred.connect(_on_corner_hit)
	GameData.upgrades_changed.connect(_on_upgrades_changed)
	
	btn_size.pressed.connect(_on_size_pressed)
	btn_speed.pressed.connect(_on_speed_pressed)
	btn_boost.pressed.connect(_on_boost_pressed)
	btn_ascend.pressed.connect(_on_ascend_pressed)
	btn_close_window.pressed.connect(close_skill_tree)
	
	skill_tree_window.visible = false
	
	_init_slot_buttons()
	GameData.equipment_changed.connect(_on_equipment_changed)
	btn_close_inventory.pressed.connect(close_inventory)
	
	# アップグレードボタン更新スロットリングタイマーの初期化 (0.2秒間隔 = 5回/秒)
	_upgrade_update_timer = Timer.new()
	_upgrade_update_timer.wait_time = 0.2
	_upgrade_update_timer.one_shot = true
	_upgrade_update_timer.timeout.connect(_on_upgrade_update_timer)
	add_child(_upgrade_update_timer)
	
	# Initialize equipment grid frames and adjust separation spacing
	_setup_grid_frames()
	
	# ボタン子ラベルのキャッシュ
	_lbl_title_size = btn_size.get_node("Content/TitleLabel")
	_lbl_cost_size = btn_size.get_node("Content/CostLabel")
	_lbl_title_speed = btn_speed.get_node("Content/TitleLabel")
	_lbl_cost_speed = btn_speed.get_node("Content/CostLabel")
	_lbl_title_boost = btn_boost.get_node("Content/TitleLabel")
	_lbl_cost_boost = btn_boost.get_node("Content/CostLabel")
	_lbl_title_ascend = btn_ascend.get_node("Content/TitleLabel")
	_lbl_cost_ascend = btn_ascend.get_node("Content/CostLabel")
	
	close_inventory()
	_update_all()


func _on_gold_changed(_amount: int) -> void:
	gold_label.text = "🪙 " + _format_number(GameData.gold)
	# アップグレードボタンの更新をスロットリング (0.2秒に1回に制限)
	if not _upgrade_buttons_dirty:
		_upgrade_buttons_dirty = true
		_upgrade_update_timer.start()


func _on_upgrade_update_timer() -> void:
	if _upgrade_buttons_dirty:
		_upgrade_buttons_dirty = false
		_update_upgrade_buttons()


func _on_tokens_changed(_amount: int) -> void:
	token_label.text = "💎 " + _format_number(GameData.tokens)


func _on_stats_changed() -> void:
	bounce_label.text = "Bounces: " + _format_number(GameData.total_bounces)
	corner_label.text = "★ Corners: " + str(GameData.corner_hits)


func _on_upgrades_changed() -> void:
	_update_upgrade_buttons()


func _on_corner_hit() -> void:
	## Show a big announcement when a corner hit occurs.
	corner_announce.text = "★ CORNER HIT! ★"
	corner_announce.modulate.a = 1.0
	corner_announce.scale = Vector2(1.3, 1.3)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(corner_announce, "modulate:a", 0.0, 2.0)\
		.set_ease(Tween.EASE_IN).set_delay(0.5)
	tween.tween_property(corner_announce, "scale", Vector2.ONE, 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _update_all() -> void:
	_on_gold_changed(GameData.gold)
	_on_tokens_changed(GameData.tokens)
	_on_stats_changed()
	_update_upgrade_buttons()


func _update_upgrade_buttons() -> void:
	var gold := GameData.gold

	# --- Upgrade 1: Logo Size ---
	var cost_size := GameData.get_size_upgrade_cost()
	var size_ok := gold >= cost_size
	btn_size.disabled = !size_ok
	_lbl_title_size.text = "ロゴサイズ強化  Lv. %d" % GameData.size_level
	_lbl_title_size.add_theme_color_override("font_color", Color.WHITE if size_ok else Color(1, 1, 1, 0.4))
	_lbl_cost_size.text = "🪙 " + _format_number(cost_size)
	_lbl_cost_size.add_theme_color_override("font_color", Color.RED if !size_ok else Color(0.85, 0.85, 0.85))

	# --- Upgrade 2: Speed ---
	var cost_speed := GameData.get_speed_upgrade_cost()
	var speed_ok := gold >= cost_speed
	btn_speed.disabled = !speed_ok
	_lbl_title_speed.text = "速度強化  Lv. %d" % GameData.speed_level
	_lbl_title_speed.add_theme_color_override("font_color", Color.WHITE if speed_ok else Color(1, 1, 1, 0.4))
	_lbl_cost_speed.text = "🪙 " + _format_number(cost_speed)
	_lbl_cost_speed.add_theme_color_override("font_color", Color.RED if !speed_ok else Color(0.85, 0.85, 0.85))

	# --- Upgrade 3: Gold/Token Boost ---
	var cost_boost := GameData.get_boost_upgrade_cost()
	var boost_ok := gold >= cost_boost
	btn_boost.disabled = !boost_ok
	_lbl_title_boost.text = "ゴールド・トークン増加  Lv. %d" % GameData.boost_level
	_lbl_title_boost.add_theme_color_override("font_color", Color.WHITE if boost_ok else Color(1, 1, 1, 0.4))
	_lbl_cost_boost.text = "🪙 " + _format_number(cost_boost)
	_lbl_cost_boost.add_theme_color_override("font_color", Color.RED if !boost_ok else Color(0.85, 0.85, 0.85))

	# --- Upgrade 4: Ascension ---
	var ascend_ok := GameData.can_ascend()
	btn_ascend.disabled = !ascend_ok
	_lbl_title_ascend.text = "アセンション  Lv. %d" % GameData.ascension_level
	_lbl_title_ascend.add_theme_color_override("font_color", Color.WHITE if ascend_ok else Color(1, 1, 1, 0.4))
	_lbl_cost_ascend.text = "🪙 1,000"
	_lbl_cost_ascend.add_theme_color_override("font_color", Color.RED if !ascend_ok else Color(0.85, 0.85, 0.85))





func _on_speed_pressed() -> void:
	GameData.buy_speed_upgrade()


func _on_boost_pressed() -> void:
	GameData.buy_boost_upgrade()


func _on_size_pressed() -> void:
	GameData.buy_size_upgrade()


func _on_ascend_pressed() -> void:
	GameData.perform_ascension()


## Formats a number with comma separators (e.g., 1,234,567).
func _format_number(n: int) -> String:
	var s := str(n)
	if n < 1000:
		return s
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "," + result
	return result


func _on_equipment_tab_pressed() -> void:
	if _is_skill_tree_open:
		close_skill_tree()
	
	if _is_inventory_open:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	if _is_inventory_open:
		return
		
	_is_inventory_open = true
	inventory_window.visible = true
	_update_inventory_ui()
	
	btn_equipment_tab.add_theme_stylebox_override("normal", _tab_style_active)
	btn_skill_tree_tab.add_theme_stylebox_override("normal", _tab_style_inactive)


func close_inventory() -> void:
	if not _is_inventory_open:
		return
		
	_is_inventory_open = false
	inventory_window.visible = false
	
	btn_equipment_tab.add_theme_stylebox_override("normal", _tab_style_inactive)
	# If skill tree is also closed, keep equipment tab highlighted as default idle state
	if not _is_skill_tree_open:
		btn_equipment_tab.add_theme_stylebox_override("normal", _tab_style_active)


func _on_skill_tree_tab_pressed() -> void:
	if _is_inventory_open:
		close_inventory()
		
	if _is_skill_tree_open:
		close_skill_tree()
	else:
		open_skill_tree()


func open_skill_tree() -> void:
	if _is_skill_tree_open:
		return
	
	_is_skill_tree_open = true
	skill_tree_window.visible = true
	_update_skill_nodes()
	
	btn_equipment_tab.add_theme_stylebox_override("normal", _tab_style_inactive)
	btn_skill_tree_tab.add_theme_stylebox_override("normal", _tab_style_active)
	
	# ゲーム起動時（初回オープン時）のみ中央位置合わせを行う
	if not _has_centered_on_startup:
		_has_centered_on_startup = true
		# サイズが完全に解決するまで最大10フレーム待つ
		for i in range(10):
			await get_tree().process_frame
			if skill_tree_window.size.x > 100 and skill_tree_scroll.size.x > 100:
				break
		# トランスフォームの整合性を確実にするためにもう1フレーム待つ
		await get_tree().process_frame
		if is_instance_valid(skill_tree_scroll):
			skill_tree_scroll.center_on_root(skill_tree_window)


func close_skill_tree() -> void:
	if not _is_skill_tree_open:
		return
	
	_is_skill_tree_open = false
	skill_tree_window.visible = false
	
	btn_equipment_tab.add_theme_stylebox_override("normal", _tab_style_active)
	btn_skill_tree_tab.add_theme_stylebox_override("normal", _tab_style_inactive)


func _on_skill_node_pressed(node: SkillNode) -> void:
	if not node.is_playable():
		return
		
	var current_lvl = GameData.get_skill_level(node.skill_id)
	if current_lvl >= node.max_level:
		return
	
	var cost = node.get_upgrade_cost(current_lvl)
	# シグナル（tokens_changed, skill_upgraded）を介して各ノードの見た目は自動更新されるため、
	# ここで手動で全ノードを走査し直す必要はありません
	GameData.buy_skill_upgrade(node.skill_id, cost, node.max_level)


func _update_skill_nodes() -> void:
	if not _skill_tree_instance:
		return
	for child in _skill_tree_instance.get_children():
		if child is SkillNode:
			child._update_ui()


func _load_skills_from_json() -> void:
	if not _skill_tree_instance:
		return
		
	var json_path = "res://data/skills.json"
	if not FileAccess.file_exists(json_path):
		printerr("スキルデータファイルが見つかりません: ", json_path)
		return
		
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		printerr("スキルデータファイルのオープンに失敗しました: ", json_path)
		return
		
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(text) != OK:
		printerr("スキルデータファイルのJSONパースに失敗しました。")
		return
		
	var data = json.get_data()
	if not data is Dictionary or not data.has("skills"):
		printerr("スキルデータのフォーマットが不正です。")
		return
		
	var skills = data["skills"] as Dictionary
	var skill_node_scene = preload("res://scenes/skills/skill_node.tscn")
	var created_nodes: Array[SkillNode] = []
	
	# 1. すべてのノードをインスタンス化して追加
	for skill_id in skills:
		var s = skills[skill_id]
		var node = skill_node_scene.instantiate() as SkillNode
		node.skill_id = skill_id
		node.skill_name = s.get("name", "")
		node.icon_char = s.get("icon", "❓")
		node.description = s.get("description", "")
		node.max_level = int(s.get("max_level", 5))
		node.base_cost = int(s.get("base_cost", 1))
		node.cost_multiplier = float(s.get("cost_multiplier", 1.5))
		# パネル間の隙間を微調整（枠のさらなる太枠化に伴い、元の0.95倍から1.1倍に変更）して辺の長さを調整する
		node.position = Vector2(s.get("x", 0), s.get("y", 0)) * 1.1
		
		# prerequisites の変換 (Array -> Array[String])
		var prereqs_raw = s.get("prerequisites", [])
		var prereqs: Array[String] = []
		for p in prereqs_raw:
			prereqs.append(str(p))
		node.prerequisites = prereqs
		
		_skill_tree_instance.add_child(node)
		created_nodes.append(node)
		
	# 2. すべてのノードが追加された後、シグナルを接続し初期描画を行う
	for node in created_nodes:
		node.pressed.connect(_on_skill_node_pressed.bind(node))
		# 初期表示の更新（他ノードとの接続線を引く処理を含む）
		node.refresh()


# --- Equipment UI Logic ---

func _init_slot_buttons() -> void:
	for child in grid_equipment.get_children():
		if child is SlotButton:
			_slot_buttons[child.slot_key] = child
	_update_slots_ui()


func _update_slots_ui() -> void:
	for slot_key in _slot_buttons:
		var btn = _slot_buttons[slot_key] as SlotButton
		var eq = GameData.equipped_items.get(slot_key)
		
		var slot_name := "Main"
		if slot_key == "sub":
			slot_name = "Sub"
		elif slot_key.begins_with("accessory_"):
			slot_name = "Accessory " + slot_key.substr(10)
			
		btn.update_slot_ui(slot_name, eq)


func _update_inventory_ui() -> void:
	if not _is_inventory_open:
		return
		
	var inv_main: Array = GameData.inventories.get("main", [])
	var inv_sub: Array = GameData.inventories.get("sub", [])
	var inv_acc: Array = GameData.inventories.get("accessory", [])
	
	main_title_label.text = "⚔️ メイン (%d / %d)" % [inv_main.size(), GameData.MAX_TYPE_INVENTORY_SIZE]
	sub_title_label.text = "🛡️ サブ (%d / %d)" % [inv_sub.size(), GameData.MAX_TYPE_INVENTORY_SIZE]
	accessory_title_label.text = "💍 アクセサリー (%d / %d)" % [inv_acc.size(), GameData.MAX_TYPE_INVENTORY_SIZE]
	
	_populate_grid(main_grid, inv_main)
	_populate_grid(sub_grid, inv_sub)
	_populate_grid(accessory_grid, inv_acc)


class InventoryEmptySlot extends Button:
	var grid_type: String = ""
	var slot_index: int = -1
	
	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not data is Dictionary:
			return false
		return data.get("type", "") == grid_type

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if data is Dictionary:
			if data.has("item_index"):
				var from_index: int = data.get("item_index", -1)
				GameData.swap_inventory_items(grid_type, from_index, slot_index)
			elif data.has("from_slot"):
				GameData.unequip_item_to_index(data.get("slot_key", ""), slot_index)


func _populate_grid(grid: GridContainer, items: Array) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
		
	var grid_type := "main"
	if grid == sub_grid:
		grid_type = "sub"
	elif grid == accessory_grid:
		grid_type = "accessory"
		
	var item_scene := preload("res://scenes/ui/inventory_item_ui.tscn")
	for i in range(GameData.MAX_TYPE_INVENTORY_SIZE):
		if i < items.size():
			var item_ui := item_scene.instantiate()
			grid.add_child(item_ui)
			item_ui.setup(items[i])
		else:
			var slot_btn := InventoryEmptySlot.new()
			slot_btn.grid_type = grid_type
			slot_btn.slot_index = i
			slot_btn.custom_minimum_size = Vector2(64, 64)
			slot_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			slot_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(slot_btn)
			slot_btn.text = ""
			
			var style_empty = StyleBoxFlat.new()
			style_empty.bg_color = Color(0.05, 0.05, 0.08, 0.6)
			style_empty.border_width_left = 3
			style_empty.border_width_top = 3
			style_empty.border_width_right = 3
			style_empty.border_width_bottom = 3
			style_empty.border_color = Color(0.0, 0.0, 0.0, 1.0)
			style_empty.corner_radius_top_left = 6
			style_empty.corner_radius_top_right = 6
			style_empty.corner_radius_bottom_right = 6
			style_empty.corner_radius_bottom_left = 6
			slot_btn.add_theme_stylebox_override("normal", style_empty)
			slot_btn.add_theme_stylebox_override("hover", style_empty)
			slot_btn.add_theme_stylebox_override("pressed", style_empty)
			slot_btn.add_theme_stylebox_override("disabled", style_empty)


func _on_equipment_changed() -> void:
	_update_slots_ui()
	_update_inventory_ui()


func show_equipment_drop_pop(item_data: Dictionary) -> void:
	var item_name: String = item_data.get("name", "")
	var item_type: String = item_data.get("type", "")
	var item_icon: String = item_data.get("icon", "")
	var item_level: int = item_data.get("level", 1)
	var item_rarity: String = item_data.get("rarity", "コモン")
	
	var pop := PanelContainer.new()
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var rarity_color := GameData.get_rarity_color(item_rarity)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.8) # Slightly transparent black
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = rarity_color
	pop.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	pop.add_child(hbox)
	
	# Add texture icon if available
	if item_icon != "":
		var tex := load(item_icon)
		if tex:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.custom_minimum_size = Vector2(32, 32)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox.add_child(rect)
			
	var label := Label.new()
	label.text = "[%s] %s (Lv.%d) を手に入れた！" % [item_rarity, item_name, item_level]
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", rarity_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(label)
	
	equipment_log_container.add_child(pop)
	
	# Animate popup (fade in, wait, fade out, then queue_free)
	pop.modulate.a = 0.0
	var tween := pop.create_tween()
	tween.tween_property(pop, "modulate:a", 1.0, 0.15)
	tween.tween_property(pop, "modulate:a", 0.0, 0.3).set_delay(3.0)
	tween.chain().tween_callback(pop.queue_free)


func _setup_grid_frames() -> void:
	# Define flat style for slot frames (distinct from main window BG)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.04, 0.04, 0.08, 0.9) # Very dark slot background
	frame_style.border_width_left = 1
	frame_style.border_width_top = 1
	frame_style.border_width_right = 1
	frame_style.border_width_bottom = 1
	frame_style.border_color = Color(0.15, 0.15, 0.22, 0.8) # Muted frame border
	frame_style.corner_radius_top_left = 6
	frame_style.corner_radius_top_right = 6
	frame_style.corner_radius_bottom_right = 6
	frame_style.corner_radius_bottom_left = 6
	frame_style.content_margin_left = 6
	frame_style.content_margin_top = 8
	frame_style.content_margin_right = 6
	frame_style.content_margin_bottom = 8
	
	# Adjust separation spacing (4px) and dynamically inject PanelContainer wrapper frames
	for grid in [main_grid, sub_grid, accessory_grid]:
		if grid:
			grid.add_theme_constant_override("h_separation", 4)
			grid.add_theme_constant_override("v_separation", 4)
			grid.size_flags_vertical = Control.SIZE_FILL
			
			var parent = grid.get_parent()
			if parent:
				var index = grid.get_index()
				parent.remove_child(grid)
				
				var frame := PanelContainer.new()
				frame.name = grid.name + "Frame"
				frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				frame.add_theme_stylebox_override("panel", frame_style)
				
				frame.add_child(grid)
				parent.add_child(frame)
				parent.move_child(frame, index)
