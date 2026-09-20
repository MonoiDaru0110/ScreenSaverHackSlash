extends PanelContainer
## Controller for the Top-tier Reincarnation (Transcendence) Window.
## Features 2-column layout: Token Infusion, Passive Bonuses, Special Skills on Left;
## Vertical Reincarnation Skill Tree on Right.

signal closed()

@onready var btn_toggle_infuse: Button = %ToggleInfuseBtn
@onready var progress_infuse: ProgressBar = %InfuseProgressBar
@onready var lbl_big_stars: Label = %BigStarsLabel
@onready var lbl_infused_tokens: Label = %InfusedTokensLabel

# Passive bonus labels
@onready var lbl_equip_lvl_bonus: Label = %LblEquipLevelBonus
@onready var lbl_auto_skills_bonus: Label = %LblAutoSkillsBonus
@onready var lbl_multiplier_bonus: Label = %LblMultiplierBonus
@onready var lbl_next_equip_lvl_bonus: Label = %LblNextEquipLevelBonus
@onready var lbl_next_auto_skills_bonus: Label = %LblNextAutoSkillsBonus
@onready var lbl_next_multiplier_bonus: Label = %LblNextMultiplierBonus

# Containers
@onready var special_skills_list: VBoxContainer = %SpecialSkillsList
@onready var reinc_tree_scroll: ReincarnationSkillTreeController = %ReincTreeScroll
@onready var reinc_tree_viewport: Control = %ReincTreeViewport

# Skill Detail Panel references
@onready var lbl_detail_icon: Label = %DetailIconLabel
@onready var lbl_detail_name: Label = %DetailNameLabel
@onready var lbl_detail_desc: Label = %DetailDescLabel
@onready var btn_upgrade_detail_skill: Button = %BtnUpgradeDetailSkill

@onready var btn_close: Button = %CloseBtn
@onready var btn_reincarnate: Button = %ReincarnateBtn

var _reinc_skill_nodes: Array[ReincarnationSkillNode] = []
var _selected_skill_node: ReincarnationSkillNode = null
var _has_centered_reinc_tree: bool = false

# Data definition for Special Skills
const SPECIAL_SKILLS_DATA = [
	{
		"id": "spec_diversity",
		"name": "多様性",
		"desc": "異なるレアリティの装備数に応じて全獲得倍率が爆発的に増加"
	},
	{
		"id": "spec_aura",
		"name": "星輝のオーラ",
		"desc": "転生後、自動でオーラを発動しゴールド・トークン獲得を常時アシスト"
	},
	{
		"id": "spec_warp",
		"name": "時空の歪み",
		"desc": "壁バウンス時の基本速度と加速能力を永続的に底上げ"
	},
	{
		"id": "spec_resonance",
		"name": "クリティカル共鳴",
		"desc": "ダイレクトヒット時のトークン・装備ドロップ率を倍増"
	}
]


func _ready() -> void:
	_setup_button_styles()

	btn_close.pressed.connect(_on_close_pressed)
	btn_toggle_infuse.pressed.connect(_on_toggle_infuse_pressed)
	btn_reincarnate.pressed.connect(_on_reincarnate_pressed)
	if btn_upgrade_detail_skill:
		btn_upgrade_detail_skill.pressed.connect(_on_upgrade_detail_skill_pressed)

	GameData.tokens_changed.connect(func(_val): update_ui())
	GameData.stars_changed.connect(func(_val): update_ui())
	GameData.upgrades_changed.connect(update_ui)
	visibility_changed.connect(func():
		if not visible:
			_hide_skill_tooltip()
			set_process(false)
		else:
			if reinc_tree_scroll and not _has_centered_reinc_tree:
				_has_centered_reinc_tree = true
				await get_tree().process_frame
				reinc_tree_scroll.center_on_root()
	)
	tree_exiting.connect(_hide_skill_tooltip)

	set_process(false)
	update_ui()


func update_ui() -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return

	# トグルボタン状態
	var is_infusing = GameData.is_infusing_tokens
	btn_toggle_infuse.modulate = Color.WHITE
	btn_toggle_infuse.focus_mode = Control.FOCUS_NONE
	btn_toggle_infuse.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_toggle_infuse.add_theme_stylebox_override("disabled", _style_btn_disabled)

	if is_infusing:
		btn_toggle_infuse.text = "注入を中止"
		btn_toggle_infuse.add_theme_stylebox_override("normal", _style_btn_red_normal)
		btn_toggle_infuse.add_theme_stylebox_override("hover", _style_btn_red_hover)
		btn_toggle_infuse.add_theme_stylebox_override("pressed", _style_btn_red_pressed)
	else:
		btn_toggle_infuse.text = "トークンを注入"
		btn_toggle_infuse.add_theme_stylebox_override("normal", _style_btn_normal)
		btn_toggle_infuse.add_theme_stylebox_override("hover", _style_btn_hover)
		btn_toggle_infuse.add_theme_stylebox_override("pressed", _style_btn_pressed)

	# スター所持表示
	lbl_big_stars.text = "⚛️ %s" % _format_number(GameData.stars)

	# 2倍スケーリング閾値とプログレスバー
	var next_cost = GameData.get_next_star_cost()
	progress_infuse.max_value = next_cost
	progress_infuse.value = min(GameData.infused_tokens, next_cost)
	lbl_infused_tokens.text = "💎 %s / %s" % [
		_format_number(GameData.infused_tokens),
		_format_number(next_cost)
	]

	# 基礎パッシブボーナスの更新
	var cur_equip_lvl = GameData.get_base_equip_level_bonus()
	var cur_auto_skills = GameData.get_auto_unlocked_skill_count()
	var cur_mult = GameData.get_reincarnation_multiplier()

	lbl_equip_lvl_bonus.text = "装備レベル+%d" % cur_equip_lvl
	lbl_auto_skills_bonus.text = "スキル自動解放+%d" % cur_auto_skills
	if cur_mult >= 1e10:
		lbl_multiplier_bonus.text = "ゴールド/トークン倍率×%s" % GameData.format_num(cur_mult)
	else:
		lbl_multiplier_bonus.text = "ゴールド/トークン倍率×%.2f" % cur_mult

	var next_equip_lvl = GameData.get_pending_base_equip_level_bonus()
	var next_auto_skills = GameData.get_pending_auto_unlocked_skill_count()
	var next_mult = GameData.get_pending_reincarnation_multiplier()

	lbl_next_equip_lvl_bonus.text = "装備レベル+%d" % next_equip_lvl
	lbl_next_auto_skills_bonus.text = "スキル自動解放+%d" % next_auto_skills
	if next_mult >= 1e10:
		lbl_next_multiplier_bonus.text = "ゴールド/トークン倍率×%s" % GameData.format_num(next_mult)
	else:
		lbl_next_multiplier_bonus.text = "ゴールド/トークン倍率×%.2f" % next_mult

	var highlight_color := Color(0.4, 0.95, 0.6)
	var normal_color := Color(0.75, 0.85, 0.95)
	lbl_next_equip_lvl_bonus.add_theme_color_override("font_color", highlight_color if next_equip_lvl > cur_equip_lvl else normal_color)
	lbl_next_auto_skills_bonus.add_theme_color_override("font_color", highlight_color if next_auto_skills > cur_auto_skills else normal_color)
	lbl_next_multiplier_bonus.add_theme_color_override("font_color", highlight_color if next_mult > cur_mult else normal_color)

	btn_reincarnate.disabled = not GameData.has_spent_stars_in_current_cycle()

	# リスト項目の軽量更新
	_update_skill_widgets()


var _special_skill_widgets: Array[Dictionary] = []
var _is_ui_built: bool = false


var _style_btn_normal: StyleBoxFlat
var _style_btn_hover: StyleBoxFlat
var _style_btn_pressed: StyleBoxFlat
var _style_btn_disabled: StyleBoxFlat

var _style_btn_red_normal: StyleBoxFlat
var _style_btn_red_hover: StyleBoxFlat
var _style_btn_red_pressed: StyleBoxFlat


func _setup_button_styles() -> void:
	if _style_btn_normal != null:
		return

	_style_btn_normal = StyleBoxFlat.new()
	_style_btn_normal.bg_color = Color(0.55, 0.15, 0.75, 1.0)
	_style_btn_normal.border_color = Color(0.85, 0.45, 1.0, 1.0)
	_style_btn_normal.set_border_width_all(2)
	_style_btn_normal.set_corner_radius_all(6)

	_style_btn_hover = StyleBoxFlat.new()
	_style_btn_hover.bg_color = Color(0.65, 0.22, 0.85, 1.0)
	_style_btn_hover.border_color = Color(0.95, 0.55, 1.0, 1.0)
	_style_btn_hover.set_border_width_all(2)
	_style_btn_hover.set_corner_radius_all(6)

	_style_btn_pressed = StyleBoxFlat.new()
	_style_btn_pressed.bg_color = Color(0.42, 0.10, 0.60, 1.0)
	_style_btn_pressed.border_color = Color(0.85, 0.45, 1.0, 1.0)
	_style_btn_pressed.set_border_width_all(2)
	_style_btn_pressed.set_corner_radius_all(6)

	_style_btn_disabled = StyleBoxFlat.new()
	_style_btn_disabled.bg_color = Color(0.20, 0.14, 0.28, 0.9)
	_style_btn_disabled.border_color = Color(0.28, 0.20, 0.38, 0.8)
	_style_btn_disabled.set_border_width_all(2)
	_style_btn_disabled.set_corner_radius_all(6)

	# 赤色ボタンスタイル (注入中止用)
	_style_btn_red_normal = StyleBoxFlat.new()
	_style_btn_red_normal.bg_color = Color(0.68, 0.18, 0.22, 1.0)
	_style_btn_red_normal.border_color = Color(0.95, 0.40, 0.45, 1.0)
	_style_btn_red_normal.set_border_width_all(2)
	_style_btn_red_normal.set_corner_radius_all(6)

	_style_btn_red_hover = StyleBoxFlat.new()
	_style_btn_red_hover.bg_color = Color(0.80, 0.24, 0.28, 1.0)
	_style_btn_red_hover.border_color = Color(1.0, 0.55, 0.60, 1.0)
	_style_btn_red_hover.set_border_width_all(2)
	_style_btn_red_hover.set_corner_radius_all(6)

	_style_btn_red_pressed = StyleBoxFlat.new()
	_style_btn_red_pressed.bg_color = Color(0.50, 0.12, 0.16, 1.0)
	_style_btn_red_pressed.border_color = Color(0.85, 0.32, 0.36, 1.0)
	_style_btn_red_pressed.set_border_width_all(2)
	_style_btn_red_pressed.set_corner_radius_all(6)

	if btn_reincarnate:
		btn_reincarnate.add_theme_stylebox_override("normal", _style_btn_normal)
		btn_reincarnate.add_theme_stylebox_override("hover", _style_btn_hover)
		btn_reincarnate.add_theme_stylebox_override("pressed", _style_btn_pressed)
		btn_reincarnate.add_theme_stylebox_override("disabled", _style_btn_disabled)
		btn_reincarnate.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn_reincarnate.add_theme_color_override("font_disabled_color", Color(0.7, 0.65, 0.8, 0.5))
		btn_reincarnate.focus_mode = Control.FOCUS_NONE

	if btn_upgrade_detail_skill:
		btn_upgrade_detail_skill.add_theme_stylebox_override("normal", _style_btn_normal)
		btn_upgrade_detail_skill.add_theme_stylebox_override("hover", _style_btn_hover)
		btn_upgrade_detail_skill.add_theme_stylebox_override("pressed", _style_btn_pressed)
		btn_upgrade_detail_skill.add_theme_stylebox_override("disabled", _style_btn_disabled)
		btn_upgrade_detail_skill.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn_upgrade_detail_skill.focus_mode = Control.FOCUS_NONE


func _build_ui_once() -> void:
	if _is_ui_built:
		return
	_is_ui_built = true

	_setup_button_styles()

	# --- 1. 特殊スキルの固定構築 ---
	for child in special_skills_list.get_children():
		child.queue_free()
	_special_skill_widgets.clear()

	for skill in SPECIAL_SKILLS_DATA:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 72)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_stylebox_override("normal", _style_btn_normal)
		btn.add_theme_stylebox_override("hover", _style_btn_hover)
		btn.add_theme_stylebox_override("pressed", _style_btn_pressed)
		btn.add_theme_stylebox_override("disabled", _style_btn_disabled)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 4)
		btn.add_child(content)

		var header_hbox := HBoxContainer.new()
		header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		header_hbox.add_theme_constant_override("separation", 10)
		content.add_child(header_hbox)

		var title_lbl := Label.new()
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_lbl.text = skill["name"]
		title_lbl.add_theme_font_size_override("font_size", 22)
		header_hbox.add_child(title_lbl)

		var level_label := Label.new()
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_label.text = "+0 [+0]"
		level_label.add_theme_font_size_override("font_size", 20)
		header_hbox.add_child(level_label)

		var cost_label := Label.new()
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_label.text = "⚛️ 1"
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 20)
		content.add_child(cost_label)

		var id: String = skill["id"]
		var sk_name: String = skill["name"]
		btn.pressed.connect(func(): _reserve_special_skill(id))
		btn.mouse_entered.connect(func(): _show_skill_tooltip(id, sk_name))
		btn.mouse_exited.connect(_hide_skill_tooltip)

		_special_skill_widgets.append({
			"id": id,
			"title_label": title_lbl,
			"level_label": level_label,
			"cost_label": cost_label,
			"btn": btn
		})

		special_skills_list.add_child(btn)

	# --- 2. 転生スキルツリーの構築 ---
	_load_reincarnation_skills_from_json()


func _load_reincarnation_skills_from_json() -> void:
	if not reinc_tree_viewport:
		return

	for child in reinc_tree_viewport.get_children():
		child.queue_free()
	_reinc_skill_nodes.clear()

	var file_path = "res://data/reincarnation_skills.json"
	if not FileAccess.file_exists(file_path):
		push_warning("Reincarnation skills data file not found: %s" % file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("Failed to open %s" % file_path)
		return

	var json_str = file.get_as_text()
	file.close()

	var test_json_conv = JSON.new()
	var error = test_json_conv.parse(json_str)
	if error != OK:
		push_warning("JSON Parse Error in %s: %s" % [file_path, test_json_conv.get_error_message()])
		return

	var data = test_json_conv.data
	if not data is Dictionary or not data.has("skills"):
		return

	var skills_dict: Dictionary = data["skills"]
	var node_scene = preload("res://scenes/skills/reincarnation_skill_node.tscn")

	for s_id in skills_dict:
		var s_data: Dictionary = skills_dict[s_id]
		var node = node_scene.instantiate() as ReincarnationSkillNode
		node.skill_id = s_id
		node.skill_name = s_data.get("name", "")
		node.icon_char = s_data.get("icon", "⚛️")
		node.description = s_data.get("description", "")
		node.base_cost = s_data.get("base_cost", 1)
		var x: float = s_data.get("x", 0.0)
		var y: float = s_data.get("y", 0.0)
		node.position = Vector2(x, y)

		var prereqs = s_data.get("prerequisites", [])
		var prereq_array: Array[String] = []
		for p in prereqs:
			prereq_array.append(str(p))
		node.prerequisites = prereq_array

		node.pressed.connect(func(): _on_reinc_skill_node_pressed(node))
		reinc_tree_viewport.add_child(node)
		_reinc_skill_nodes.append(node)

	for node in _reinc_skill_nodes:
		node.refresh()

	if _reinc_skill_nodes.size() > 0:
		_select_skill_node(_reinc_skill_nodes[0])

	await get_tree().process_frame
	if is_instance_valid(reinc_tree_scroll):
		reinc_tree_scroll.center_on_root()


func _select_skill_node(node: ReincarnationSkillNode) -> void:
	if _selected_skill_node and is_instance_valid(_selected_skill_node):
		_selected_skill_node.is_selected = false
	_selected_skill_node = node
	if _selected_skill_node and is_instance_valid(_selected_skill_node):
		_selected_skill_node.is_selected = true
	_update_detail_panel()


func _on_reinc_skill_node_pressed(node: ReincarnationSkillNode) -> void:
	if _selected_skill_node != node:
		_select_skill_node(node)
	else:
		_try_upgrade_selected_skill()


func _on_upgrade_detail_skill_pressed() -> void:
	_try_upgrade_selected_skill()


func _try_upgrade_selected_skill() -> void:
	if not _selected_skill_node or not is_instance_valid(_selected_skill_node):
		return
	var node = _selected_skill_node
	if node.is_acquired():
		return
	if not node.is_playable():
		return
	var cost: int = node.base_cost
	if GameData.stars < cost:
		return
	if GameData.unlock_reincarnation_skill(node.skill_id, cost):
		update_ui()
		_update_detail_panel()


func _update_detail_panel() -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return
	if not lbl_detail_name:
		return

	if not _selected_skill_node or not is_instance_valid(_selected_skill_node):
		lbl_detail_icon.text = "⚛️"
		lbl_detail_name.text = "スキル未選択"
		lbl_detail_desc.text = "ツリー上のスキルノードをクリックして選択してください。"
		btn_upgrade_detail_skill.disabled = true
		btn_upgrade_detail_skill.text = "-"
		return

	var node = _selected_skill_node
	lbl_detail_icon.text = node.icon_char
	lbl_detail_name.text = node.skill_name
	lbl_detail_desc.text = node.description

	var is_acquired: bool = node.is_acquired()
	var cost: int = node.base_cost
	var is_playable: bool = node.is_playable()
	var can_afford: bool = (GameData.stars >= cost)

	if is_acquired:
		btn_upgrade_detail_skill.disabled = true
		btn_upgrade_detail_skill.text = "習得済み"
		btn_upgrade_detail_skill.add_theme_color_override("font_disabled_color", Color(0.7, 0.7, 0.8, 0.6))
	elif not is_playable:
		btn_upgrade_detail_skill.disabled = true
		btn_upgrade_detail_skill.text = "⚛️ %s" % _format_number(cost)
		btn_upgrade_detail_skill.add_theme_color_override("font_disabled_color", Color(0.95, 0.4, 0.4, 0.85))
	elif not can_afford:
		btn_upgrade_detail_skill.disabled = true
		btn_upgrade_detail_skill.text = "⚛️ %s" % _format_number(cost)
		btn_upgrade_detail_skill.add_theme_color_override("font_disabled_color", Color(0.95, 0.4, 0.4, 0.85))
	else:
		btn_upgrade_detail_skill.disabled = false
		btn_upgrade_detail_skill.text = "⚛️ %s" % _format_number(cost)
		btn_upgrade_detail_skill.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0, 1.0))


func _update_skill_widgets() -> void:
	if not _is_ui_built:
		_build_ui_once()

	for w in _special_skill_widgets:
		var active_lvl: int = GameData.get_special_skill_active_level(w.id)
		var pending_lvl: int = GameData.pending_reincarnation_upgrades.get(w.id, 0)
		var target_lvl: int = active_lvl + pending_lvl
		var next_cost: int = target_lvl + 1

		w.level_label.text = "+%d [+%d]" % [active_lvl, pending_lvl]
		w.cost_label.text = "⚛️ %s" % _format_number(next_cost)
		var can_afford: bool = (GameData.stars >= next_cost)
		w.btn.disabled = not can_afford

		if can_afford:
			w.title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			w.level_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
			w.cost_label.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0, 1.0))
		else:
			w.title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.4))
			w.level_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 0.4))
			w.cost_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4, 0.85))

	for node in _reinc_skill_nodes:
		if is_instance_valid(node):
			node.queue_update_ui()

	_update_detail_panel()


func _reserve_special_skill(id: String) -> void:
	var active_lvl: int = GameData.get_special_skill_active_level(id)
	var pending_lvl: int = GameData.pending_reincarnation_upgrades.get(id, 0)
	var target_lvl: int = active_lvl + pending_lvl
	var next_cost: int = target_lvl + 1

	if GameData.reserve_reincarnation_upgrade(id, next_cost):
		update_ui()
		_update_active_tooltip()


func _on_toggle_infuse_pressed() -> void:
	GameData.toggle_token_infusion()
	update_ui()


func _on_reincarnate_pressed() -> void:
	GameData.execute_reincarnation()
	update_ui()


func _on_close_pressed() -> void:
	_hide_skill_tooltip()
	visible = false
	closed.emit()


func _format_number(value) -> String:
	return GameData.format_num(float(value))


# --- Tooltip Implementation for Special Skills ---
var _tooltip_panel: PanelContainer = null
var _tooltip_desc_current: RichTextLabel = null
var _tooltip_desc_target: RichTextLabel = null
var _active_tooltip_skill_id: String = ""
var _active_tooltip_skill_name: String = ""


func _process(_delta: float) -> void:
	if _tooltip_panel and _tooltip_panel.visible:
		_update_tooltip_position()


func _create_skill_tooltip_node() -> void:
	if _tooltip_panel != null:
		return

	# 影用外枠パネル (EquipmentTooltip準拠)
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.top_level = true
	_tooltip_panel.z_index = 100
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.custom_minimum_size = Vector2(300, 0)

	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.5)
	shadow_style.set_corner_radius_all(8)
	_tooltip_panel.add_theme_stylebox_override("panel", shadow_style)

	var tooltip_margin := MarginContainer.new()
	tooltip_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_margin.add_theme_constant_override("margin_left", 4)
	tooltip_margin.add_theme_constant_override("margin_top", 4)
	tooltip_margin.add_theme_constant_override("margin_right", 4)
	tooltip_margin.add_theme_constant_override("margin_bottom", 4)
	_tooltip_panel.add_child(tooltip_margin)

	# メインパネル (紫色の境界線、ダーク背景)
	var inner_panel := PanelContainer.new()
	inner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	inner_style.border_color = GameData.special_skill_color
	inner_style.set_border_width_all(2)
	inner_style.set_corner_radius_all(6)
	inner_panel.add_theme_stylebox_override("panel", inner_style)
	tooltip_margin.add_child(inner_panel)

	var padding_margin := MarginContainer.new()
	padding_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding_margin.add_theme_constant_override("margin_left", 12)
	padding_margin.add_theme_constant_override("margin_top", 10)
	padding_margin.add_theme_constant_override("margin_right", 12)
	padding_margin.add_theme_constant_override("margin_bottom", 10)
	inner_panel.add_child(padding_margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	padding_margin.add_child(vbox)

	# 1. 現在レベルのスキル説明文
	_tooltip_desc_current = RichTextLabel.new()
	_tooltip_desc_current.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_desc_current.bbcode_enabled = true
	_tooltip_desc_current.fit_content = true
	_tooltip_desc_current.scroll_active = false
	_tooltip_desc_current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_desc_current.custom_minimum_size = Vector2(280, 0)
	_tooltip_desc_current.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip_desc_current.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tooltip_desc_current.add_theme_font_size_override("normal_font_size", 12)
	_tooltip_desc_current.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9, 1.0))
	_tooltip_desc_current.add_theme_constant_override("line_separation", 4)
	vbox.add_child(_tooltip_desc_current)

	# 2. 矢印 (中央揃え)
	var arrow_lbl := Label.new()
	arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_lbl.text = "↓"
	arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	arrow_lbl.add_theme_font_size_override("font_size", 13)
	arrow_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.9, 1.0))
	vbox.add_child(arrow_lbl)

	# 3. 予約後レベルのスキル説明文
	_tooltip_desc_target = RichTextLabel.new()
	_tooltip_desc_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_desc_target.bbcode_enabled = true
	_tooltip_desc_target.fit_content = true
	_tooltip_desc_target.scroll_active = false
	_tooltip_desc_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_desc_target.custom_minimum_size = Vector2(280, 0)
	_tooltip_desc_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip_desc_target.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tooltip_desc_target.add_theme_font_size_override("normal_font_size", 12)
	_tooltip_desc_target.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9, 1.0))
	_tooltip_desc_target.add_theme_constant_override("line_separation", 4)
	vbox.add_child(_tooltip_desc_target)

	add_child(_tooltip_panel)


func _show_skill_tooltip(skill_id: String, skill_name: String) -> void:
	_create_skill_tooltip_node()
	_active_tooltip_skill_id = skill_id
	_active_tooltip_skill_name = skill_name

	_update_active_tooltip()
	_tooltip_panel.visible = true
	_update_tooltip_position()
	set_process(true)


func _update_active_tooltip() -> void:
	if _active_tooltip_skill_id.is_empty() or not is_instance_valid(_tooltip_panel):
		return

	var active_lvl: int = GameData.get_special_skill_active_level(_active_tooltip_skill_id)
	var pending_lvl: int = GameData.pending_reincarnation_upgrades.get(_active_tooltip_skill_id, 0)
	var target_lvl: int = active_lvl + pending_lvl

	_tooltip_desc_current.text = _format_special_skill_bbcode(_active_tooltip_skill_id, _active_tooltip_skill_name, active_lvl)
	_tooltip_desc_target.text = _format_special_skill_bbcode(_active_tooltip_skill_id, _active_tooltip_skill_name, target_lvl)

	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.reset_size()


func _hide_skill_tooltip() -> void:
	_active_tooltip_skill_id = ""
	_active_tooltip_skill_name = ""
	if is_instance_valid(_tooltip_panel):
		_tooltip_panel.visible = false
	set_process(false)


func _update_tooltip_position() -> void:
	if not is_instance_valid(_tooltip_panel) or not _tooltip_panel.visible:
		return

	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.reset_size()

	var mouse_pos := get_global_mouse_position()
	var offset := Vector2(16, 16)
	var target_pos := mouse_pos + offset

	var viewport_rect := get_viewport().get_visible_rect()
	var tooltip_size := _tooltip_panel.size

	if target_pos.x + tooltip_size.x > viewport_rect.size.x - 8:
		target_pos.x = mouse_pos.x - tooltip_size.x - 16
	if target_pos.y + tooltip_size.y > viewport_rect.size.y - 8:
		target_pos.y = mouse_pos.y - tooltip_size.y - 16

	_tooltip_panel.global_position = target_pos


func _format_special_skill_bbcode(skill_id: String, skill_name: String, level: int) -> String:
	var green_color := "#b2ebb2"
	var spec_hex: String = GameData.special_skill_color.to_html()
	var sk_name_bb := "[color=#%s]%s[/color]" % [spec_hex, skill_name]
	var level_str := "[color=%s]+%d[/color]" % [green_color, level]

	var raw_desc := ""
	if level == 0:
		raw_desc = "効果なし"
	elif skill_id == "spec_diversity":
		var m25 := pow(25.0, float(level))
		var m50 := pow(50.0, float(level))
		var s25 := GameData.format_num(m25)
		var s50 := GameData.format_num(m50)
		raw_desc = "装備レア度3種以上で%s倍、6種で%s倍" % [s25, s50]
	else:
		var base_desc := _get_skill_base_desc(skill_id)
		raw_desc = "%s (Lv.%d)" % [base_desc, level]

	var regex := RegEx.new()
	regex.compile("(?:\\+|x|×|\\*)?(?:\\d{1,3}(?:,\\d{3})+|\\d+)(?:\\.\\d+)?(?:[eE][+-]?\\d+)?%?")
	var highlighted_desc := regex.sub(raw_desc, "[color=%s]$0[/color]" % green_color, true)

	return "%s %s: %s" % [sk_name_bb, level_str, highlighted_desc]


func _get_skill_base_desc(skill_id: String) -> String:
	for sk in SPECIAL_SKILLS_DATA:
		if sk.get("id", "") == skill_id:
			return sk.get("desc", "")
	return ""
