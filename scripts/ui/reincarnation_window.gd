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

# Containers
@onready var special_skills_list: VBoxContainer = %SpecialSkillsList
@onready var tree_nodes_container: VBoxContainer = %TreeNodesContainer

@onready var btn_close: Button = %CloseBtn
@onready var btn_reincarnate: Button = %ReincarnateBtn
@onready var lbl_reincarnation_count: Label = %ReincarnationCountLabel

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

# Data definition for Vertical Skill Tree
const TREE_NODES_DATA = [
	{
		"id": "tree_node_root",
		"name": "⚛️ Root: 宇宙の源流",
		"desc": "最上位転生システムの基本ノード (初期開放)",
		"cost": 0,
		"type": "root"
	},
	{
		"id": "tree_node_equip_lvl",
		"name": "装備鍛錬 (装備レベル底上げ)",
		"desc": "転生時、ドロップ装備の初期レベルを +Lv. 5 底上げ",
		"cost": 1,
		"type": "node"
	},
	{
		"id": "tree_node_auto_skills",
		"name": "スキル覚醒 (初期自動習得)",
		"desc": "転生時、基礎スキルツリーの初期スキルを 2個 自動解禁",
		"cost": 2,
		"type": "node"
	},
	{
		"id": "tree_node_mult",
		"name": "エーテル共鳴 (全体倍率アップ)",
		"desc": "転生後の全リソース獲得倍率を +25% 増加",
		"cost": 3,
		"type": "node"
	},
	{
		"id": "tree_node_slot",
		"name": "スロット拡張 (スキル配置枠)",
		"desc": "上位スキルツリーの同時配置スロット枠を +1 解禁",
		"cost": 5,
		"type": "node"
	},
	{
		"id": "tree_node_breakthrough",
		"name": "限界突破 (最終超越)",
		"desc": "全アビリティの上限を突破し、転生パッシブ倍率を 1.5倍",
		"cost": 10,
		"type": "node"
	}
]


func _ready() -> void:
	btn_close.pressed.connect(_on_close_pressed)
	btn_toggle_infuse.pressed.connect(_on_toggle_infuse_pressed)
	btn_reincarnate.pressed.connect(_on_reincarnate_pressed)

	GameData.tokens_changed.connect(func(_val): update_ui())
	GameData.stars_changed.connect(func(_val): update_ui())
	GameData.upgrades_changed.connect(update_ui)
	visibility_changed.connect(func():
		if not visible:
			_hide_skill_tooltip()
	)
	tree_exiting.connect(_hide_skill_tooltip)

	set_process(false)
	update_ui()


func update_ui() -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return

	# トグルボタン状態
	var is_infusing = GameData.is_infusing_tokens
	if is_infusing:
		btn_toggle_infuse.text = "⏹️ 注入を中止"
		btn_toggle_infuse.modulate = Color(1.0, 0.45, 0.45, 1.0)
	else:
		btn_toggle_infuse.text = "🔮 トークンを注入"
		btn_toggle_infuse.modulate = Color(0.7, 0.5, 1.0, 1.0)

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
	lbl_equip_lvl_bonus.text = "・ 装備初期レベル底上げ: +Lv. %d" % GameData.get_base_equip_level_bonus()
	lbl_auto_skills_bonus.text = "・ 初期自動解禁スキル数: +%d 個" % GameData.get_auto_unlocked_skill_count()
	lbl_multiplier_bonus.text = "・ 転生オール倍率: x %.2f" % GameData.get_reincarnation_multiplier()

	# 転生回数表示
	lbl_reincarnation_count.text = "現在の転生回数: Lv. %d" % GameData.reincarnation_level

	var pending_count = GameData.pending_reincarnation_upgrades.size()
	btn_reincarnate.disabled = pending_count == 0 and GameData.reincarnation_level == 0

	# リスト項目の軽量更新
	_update_skill_widgets()


var _special_skill_widgets: Array[Dictionary] = []
var _tree_node_widgets: Array[Dictionary] = []
var _is_ui_built: bool = false


var _style_btn_normal: StyleBoxFlat
var _style_btn_hover: StyleBoxFlat
var _style_btn_pressed: StyleBoxFlat
var _style_btn_disabled: StyleBoxFlat


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
		title_lbl.add_theme_font_size_override("font_size", 18)
		header_hbox.add_child(title_lbl)

		var level_label := Label.new()
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_label.text = "+0→+0"
		level_label.add_theme_font_size_override("font_size", 17)
		header_hbox.add_child(level_label)

		var cost_label := Label.new()
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_label.text = "⚛️ 1"
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 16)
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

	# --- 2. 縦型ツリーノードの固定構築 ---
	for child in tree_nodes_container.get_children():
		child.queue_free()
	_tree_node_widgets.clear()

	for i in range(TREE_NODES_DATA.size()):
		var node_data = TREE_NODES_DATA[i]

		if i > 0:
			var line_container = CenterContainer.new()
			line_container.custom_minimum_size = Vector2(0, 16)
			var line = ColorRect.new()
			line.custom_minimum_size = Vector2(3, 16)
			line.color = Color(0.5, 0.35, 0.75, 0.8)
			line_container.add_child(line)
			tree_nodes_container.add_child(line_container)

		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 64)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 6)
		card.add_child(margin)

		var hbox = HBoxContainer.new()
		margin.add_child(hbox)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(vbox)

		var name_lbl = Label.new()
		name_lbl.text = node_data["name"]
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5) if node_data["type"] == "root" else Color(0.8, 0.9, 1.0))
		name_lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = node_data["desc"]
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(desc_lbl)

		var id: String = node_data["id"]
		var cost: int = node_data["cost"]
		var is_root: bool = (node_data["type"] == "root")

		if is_root:
			var badge = Label.new()
			badge.text = "⚡ 常時有効"
			badge.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
			badge.add_theme_font_size_override("font_size", 12)
			hbox.add_child(badge)
		else:
			var badge_active := Label.new()
			badge_active.text = "✅ 解禁済み"
			badge_active.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
			badge_active.add_theme_font_size_override("font_size", 12)
			hbox.add_child(badge_active)

			var badge_pending := Label.new()
			badge_pending.text = "🔒 [予約済み]"
			badge_pending.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
			badge_pending.add_theme_font_size_override("font_size", 12)
			hbox.add_child(badge_pending)

			var btn := Button.new()
			btn.custom_minimum_size = Vector2(100, 34)
			btn.text = "⚛️ %d 予約" % cost
			btn.add_theme_font_size_override("font_size", 13)
			btn.pressed.connect(func(): _reserve_skill(id, cost))
			hbox.add_child(btn)

			_tree_node_widgets.append({
				"id": id,
				"cost": cost,
				"badge_active": badge_active,
				"badge_pending": badge_pending,
				"btn": btn
			})

		tree_nodes_container.add_child(card)


func _update_skill_widgets() -> void:
	if not _is_ui_built:
		_build_ui_once()

	for w in _special_skill_widgets:
		var active_lvl: int = GameData.get_special_skill_active_level(w.id)
		var pending_lvl: int = GameData.pending_reincarnation_upgrades.get(w.id, 0)
		var target_lvl: int = active_lvl + pending_lvl
		var next_cost: int = target_lvl + 1

		w.level_label.text = "+%d→+%d" % [active_lvl, target_lvl]
		w.cost_label.text = "⚛️ %d" % next_cost
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

	for w in _tree_node_widgets:
		var active_lvl: int = GameData.active_reincarnation_upgrades.get(w.id, 0)
		var pending_lvl: int = GameData.pending_reincarnation_upgrades.get(w.id, 0)
		var is_active := active_lvl > 0
		var is_pending := not is_active and pending_lvl > 0

		w.badge_active.visible = is_active
		w.badge_pending.visible = is_pending
		w.btn.visible = not is_active and not is_pending
		if w.btn.visible:
			w.btn.disabled = (GameData.stars < w.cost)


func _reserve_special_skill(id: String) -> void:
	var active_lvl: int = GameData.get_special_skill_active_level(id)
	var pending_lvl: int = GameData.pending_reincarnation_upgrades.get(id, 0)
	var target_lvl: int = active_lvl + pending_lvl
	var next_cost: int = target_lvl + 1

	if GameData.reserve_reincarnation_upgrade(id, next_cost):
		update_ui()
		_update_active_tooltip()


func _reserve_skill(id: String, cost: int) -> void:
	if GameData.reserve_reincarnation_upgrade(id, cost):
		update_ui()


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


func _format_number(value: int) -> String:
	var string_val = str(value)
	var result = ""
	var count = 0
	for i in range(string_val.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = string_val[i] + result
		count += 1
	return result


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
		var s25 := "%.0f" % m25 if m25 < 1e12 else "%.2e" % m25
		var s50 := "%.0f" % m50 if m50 < 1e12 else "%.2e" % m50
		raw_desc = "装備レア度3種以上で%s倍、6種で%s倍" % [s25, s50]
	else:
		var base_desc := _get_skill_base_desc(skill_id)
		raw_desc = "%s (Lv.%d)" % [base_desc, level]

	var regex := RegEx.new()
	regex.compile("(?:\\+|x|×|\\*)?\\d+(?:\\.\\d+)?%?")
	var highlighted_desc := regex.sub(raw_desc, "[color=%s]$0[/color]" % green_color, true)

	return "%s %s: %s" % [sk_name_bb, level_str, highlighted_desc]


func _get_skill_base_desc(skill_id: String) -> String:
	for sk in SPECIAL_SKILLS_DATA:
		if sk.get("id", "") == skill_id:
			return sk.get("desc", "")
	return ""
