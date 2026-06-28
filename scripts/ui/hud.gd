extends CanvasLayer
## Heads-up display showing gold, bounce count, and corner hit announcements.

@onready var gold_label: Label = $Sidebar/SidebarLayout/FooterBottomSection/CenterContainer/GoldLabel
@onready var token_label: Label = $Sidebar/SidebarLayout/FooterTopSection/CenterContainer/TokenLabel
@onready var bounce_label: Label = $BounceLabel
@onready var corner_label: Label = $CornerLabel
@onready var corner_announce: Label = $CornerAnnounce

@onready var btn_logo: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton1
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

var _skill_tree_scene: PackedScene = preload("res://scenes/skills/skill_tree_data.tscn")
var _skill_tree_instance: Control
var _tab_style_active: StyleBoxFlat
var _tab_style_inactive: StyleBoxFlat
var _is_skill_tree_open: bool = false
var _has_centered_on_startup: bool = false


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

	for btn in [btn_logo, btn_speed, btn_boost, btn_ascend]:
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
	
	btn_logo.pressed.connect(_on_logo_pressed)
	btn_speed.pressed.connect(_on_speed_pressed)
	btn_boost.pressed.connect(_on_boost_pressed)
	btn_ascend.pressed.connect(_on_ascend_pressed)
	btn_close_window.pressed.connect(close_skill_tree)
	
	skill_tree_window.visible = false
	
	_on_equipment_tab_pressed() 
	_update_all()


func _on_gold_changed(_amount: int) -> void:
	gold_label.text = "🪙 " + _format_number(GameData.gold)
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

	# --- Upgrade 1: Logo ---
	var cost_logo := GameData.get_logo_upgrade_cost()
	var logo_ok := gold >= cost_logo
	btn_logo.disabled = !logo_ok
	var lbl_title_logo: Label = btn_logo.get_node("Content/TitleLabel")
	lbl_title_logo.text = "ロゴ追加  Lv. %d" % GameData.logo_count
	lbl_title_logo.add_theme_color_override("font_color", Color.WHITE if logo_ok else Color(1, 1, 1, 0.4))
	var lbl_cost_logo: Label = btn_logo.get_node("Content/CostLabel")
	lbl_cost_logo.text = "🪙 " + _format_number(cost_logo)
	lbl_cost_logo.add_theme_color_override("font_color", Color.RED if !logo_ok else Color(0.85, 0.85, 0.85))

	# --- Upgrade 2: Speed ---
	var cost_speed := GameData.get_speed_upgrade_cost()
	var speed_ok := gold >= cost_speed
	btn_speed.disabled = !speed_ok
	var lbl_title_speed: Label = btn_speed.get_node("Content/TitleLabel")
	lbl_title_speed.text = "速度強化  Lv. %d" % GameData.speed_level
	lbl_title_speed.add_theme_color_override("font_color", Color.WHITE if speed_ok else Color(1, 1, 1, 0.4))
	var lbl_cost_speed: Label = btn_speed.get_node("Content/CostLabel")
	lbl_cost_speed.text = "🪙 " + _format_number(cost_speed)
	lbl_cost_speed.add_theme_color_override("font_color", Color.RED if !speed_ok else Color(0.85, 0.85, 0.85))

	# --- Upgrade 3: Gold/Token Boost ---
	var cost_boost := GameData.get_boost_upgrade_cost()
	var boost_ok := gold >= cost_boost
	btn_boost.disabled = !boost_ok
	var lbl_title_boost: Label = btn_boost.get_node("Content/TitleLabel")
	lbl_title_boost.text = "ゴールド・トークン増加  Lv. %d" % GameData.boost_level
	lbl_title_boost.add_theme_color_override("font_color", Color.WHITE if boost_ok else Color(1, 1, 1, 0.4))
	var lbl_cost_boost: Label = btn_boost.get_node("Content/CostLabel")
	lbl_cost_boost.text = "🪙 " + _format_number(cost_boost)
	lbl_cost_boost.add_theme_color_override("font_color", Color.RED if !boost_ok else Color(0.85, 0.85, 0.85))

	# --- Upgrade 4: Ascension ---
	var ascend_ok := GameData.can_ascend()
	btn_ascend.disabled = !ascend_ok
	var lbl_title_ascend: Label = btn_ascend.get_node("Content/TitleLabel")
	lbl_title_ascend.text = "アセンション  Lv. %d" % GameData.ascension_level
	lbl_title_ascend.add_theme_color_override("font_color", Color.WHITE if ascend_ok else Color(1, 1, 1, 0.4))
	var lbl_cost_ascend: Label = btn_ascend.get_node("Content/CostLabel")
	lbl_cost_ascend.text = "🪙 1,000"
	lbl_cost_ascend.add_theme_color_override("font_color", Color.RED if !ascend_ok else Color(0.85, 0.85, 0.85))


func _on_logo_pressed() -> void:
	GameData.buy_logo_upgrade()


func _on_speed_pressed() -> void:
	GameData.buy_speed_upgrade()


func _on_boost_pressed() -> void:
	GameData.buy_boost_upgrade()


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
	# Equipment tab is always shown now. If clicked, close the skill tree if it's open.
	if _is_skill_tree_open:
		close_skill_tree()
	
	btn_equipment_tab.add_theme_stylebox_override("normal", _tab_style_active)
	btn_skill_tree_tab.add_theme_stylebox_override("normal", _tab_style_inactive)


func _on_skill_tree_tab_pressed() -> void:
	# Toggle skill tree window open/close
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
	
	# Update tab buttons styling
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
	
	# Update tab buttons styling (back to active equipment)
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
