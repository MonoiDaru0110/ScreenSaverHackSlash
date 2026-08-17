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
		"id": "spec_aura",
		"name": "特殊スキル「星輝のオーラ」",
		"desc": "転生後、自動でオーラを発動しゴールド・トークン獲得を常時アシスト",
		"cost": 3
	},
	{
		"id": "spec_warp",
		"name": "特殊スキル「時空の歪み」",
		"desc": "壁バウンス時の基本速度と加速能力を永続的に底上げ",
		"cost": 4
	},
	{
		"id": "spec_resonance",
		"name": "特殊スキル「クリティカル共鳴」",
		"desc": "ダイレクトヒット時のトークン・装備ドロップ率を倍増",
		"cost": 6
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

	update_ui()


func update_ui() -> void:
	if not is_inside_tree():
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

	# リスト項目の再描画
	_render_special_skills()
	_render_vertical_skill_tree()


func _render_special_skills() -> void:
	for child in special_skills_list.get_children():
		child.queue_free()

	for skill in SPECIAL_SKILLS_DATA:
		var item_panel = PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(0, 50)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 4)
		item_panel.add_child(margin)

		var hbox = HBoxContainer.new()
		margin.add_child(hbox)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(vbox)

		var title_lbl = Label.new()
		title_lbl.text = skill["name"]
		title_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 1.0))
		title_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(title_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = skill["desc"]
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(desc_lbl)

		var id = skill["id"]
		var cost = skill["cost"]
		var active_lvl = GameData.active_reincarnation_upgrades.get(id, 0)
		var pending_lvl = GameData.pending_reincarnation_upgrades.get(id, 0)

		if active_lvl > 0:
			var badge = Label.new()
			badge.text = "✅ 解禁済み"
			badge.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
			badge.add_theme_font_size_override("font_size", 12)
			hbox.add_child(badge)
		elif pending_lvl > 0:
			var badge = Label.new()
			badge.text = "🔒 [予約済み]"
			badge.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
			badge.add_theme_font_size_override("font_size", 12)
			hbox.add_child(badge)
		else:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(90, 32)
			btn.text = "⚛️ %d 予約" % cost
			btn.add_theme_font_size_override("font_size", 12)
			btn.disabled = GameData.stars < cost
			btn.pressed.connect(func(): _reserve_skill(id, cost))
			hbox.add_child(btn)

		special_skills_list.add_child(item_panel)


func _render_vertical_skill_tree() -> void:
	for child in tree_nodes_container.get_children():
		child.queue_free()

	for i in range(TREE_NODES_DATA.size()):
		var node_data = TREE_NODES_DATA[i]

		# 縦接続線の描画 (Root以外)
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

		var id = node_data["id"]
		var cost = node_data["cost"]

		if node_data["type"] == "root":
			var badge = Label.new()
			badge.text = "⚡ 常時有効"
			badge.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
			badge.add_theme_font_size_override("font_size", 12)
			hbox.add_child(badge)
		else:
			var active_lvl = GameData.active_reincarnation_upgrades.get(id, 0)
			var pending_lvl = GameData.pending_reincarnation_upgrades.get(id, 0)

			if active_lvl > 0:
				var badge = Label.new()
				badge.text = "✅ 解禁済み"
				badge.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
				badge.add_theme_font_size_override("font_size", 12)
				hbox.add_child(badge)
			elif pending_lvl > 0:
				var badge = Label.new()
				badge.text = "🔒 [予約済み]"
				badge.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
				badge.add_theme_font_size_override("font_size", 12)
				hbox.add_child(badge)
			else:
				var btn = Button.new()
				btn.custom_minimum_size = Vector2(100, 34)
				btn.text = "⚛️ %d 予約" % cost
				btn.add_theme_font_size_override("font_size", 13)
				btn.disabled = GameData.stars < cost
				btn.pressed.connect(func(): _reserve_skill(id, cost))
				hbox.add_child(btn)

		tree_nodes_container.add_child(card)


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
