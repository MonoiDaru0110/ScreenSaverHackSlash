class_name ImpactReactorWindow
extends BaseWindow
## 衝撃炉（Impact Reactor）ウィンドウコントローラー
## ロゴの壁衝突によって蓄積される衝撃エネルギーを通貨とし、各種キネティック強化を行う。

var _buy_count_mode: int = 1 # 1, 5, 10, -1 (MAX)

@onready var energy_label: Label = %EnergyLabel
@onready var gain_label: Label = %GainLabel
@onready var bounce_label: Label = %BounceLabel

@onready var btn_buy_1: Button = %BtnBuy1
@onready var btn_buy_5: Button = %BtnBuy5
@onready var btn_buy_10: Button = %BtnBuy10
@onready var btn_buy_max: Button = %BtnBuyMax

@onready var cards_grid: GridContainer = %CardsGrid

var _upgrade_card_nodes: Dictionary = {}


func _ready() -> void:
	super._ready()
	_setup_buttons()
	_create_upgrade_cards()
	_update_all_ui()

	GameData.impact_energy_changed.connect(_on_impact_energy_changed)
	GameData.reactor_upgraded.connect(_on_reactor_upgraded)
	GameData.stats_changed.connect(_on_stats_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			_update_all_ui()


func _setup_buttons() -> void:
	if btn_buy_1:
		btn_buy_1.pressed.connect(func(): _set_buy_mode(1))
	if btn_buy_5:
		btn_buy_5.pressed.connect(func(): _set_buy_mode(5))
	if btn_buy_10:
		btn_buy_10.pressed.connect(func(): _set_buy_mode(10))
	if btn_buy_max:
		btn_buy_max.pressed.connect(func(): _set_buy_mode(-1))
	_update_buy_mode_buttons()


func _set_buy_mode(mode: int) -> void:
	_buy_count_mode = mode
	_update_buy_mode_buttons()
	_update_all_cards()


func _update_buy_mode_buttons() -> void:
	var active_color := Color(0.12, 0.65, 0.85, 1.0)
	var normal_color := Color(0.2, 0.25, 0.35, 1.0)

	var btns := [
		{"node": btn_buy_1, "mode": 1},
		{"node": btn_buy_5, "mode": 5},
		{"node": btn_buy_10, "mode": 10},
		{"node": btn_buy_max, "mode": -1}
	]

	for b in btns:
		var btn: Button = b["node"]
		if not btn:
			continue
		var is_selected: bool = (b["mode"] == _buy_count_mode)
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate() if btn.has_theme_stylebox("normal") else StyleBoxFlat.new()
		style.bg_color = active_color if is_selected else normal_color
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		btn.add_theme_stylebox_override("normal", style)


func _create_upgrade_cards() -> void:
	if not cards_grid:
		return

	for child in cards_grid.get_children():
		child.queue_free()
	_upgrade_card_nodes.clear()

	var upgrade_keys := [
		"impact_gold_boost",
		"kinetic_absorption",
		"elastic_acceleration",
		"resonance_tokens",
		"critical_charge",
		"corner_yield"
	]

	for u_id in upgrade_keys:
		if not GameData.REACTOR_UPGRADES.has(u_id):
			continue
		var card := _build_card(u_id)
		cards_grid.add_child(card)
		_upgrade_card_nodes[u_id] = card


func _build_card(upgrade_id: String) -> PanelContainer:
	var def: Dictionary = GameData.REACTOR_UPGRADES[upgrade_id]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.14, 0.20, 1.0)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.20, 0.35, 0.48, 0.8)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# 上部: タイトルとレベル
	var top_hbox := HBoxContainer.new()
	vbox.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = str(def.get("name", ""))
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(title_lbl)

	var level_lbl := Label.new()
	level_lbl.name = "LevelLabel"
	level_lbl.text = "Lv. 0"
	level_lbl.add_theme_font_size_override("font_size", 16)
	level_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95, 1.0))
	top_hbox.add_child(level_lbl)

	# 説明文
	var desc_lbl := Label.new()
	desc_lbl.name = "DescLabel"
	desc_lbl.text = str(def.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.82, 1.0))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# 現在値表示
	var current_val_lbl := Label.new()
	current_val_lbl.name = "CurrentValLabel"
	current_val_lbl.text = "現在効果: +0%"
	current_val_lbl.add_theme_font_size_override("font_size", 13)
	current_val_lbl.add_theme_color_override("font_color", Color(0.40, 0.80, 0.60, 1.0))
	vbox.add_child(current_val_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 下部: コストと購入ボタン
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(bottom_hbox)

	var cost_lbl := Label.new()
	cost_lbl.name = "CostLabel"
	cost_lbl.text = "必要エネルギー: 0"
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35, 1.0))
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(cost_lbl)

	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.custom_minimum_size = Vector2(120, 36)
	buy_btn.text = "強化"
	buy_btn.focus_mode = Control.FOCUS_NONE

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.48, 0.68, 1.0)
	btn_normal.corner_radius_top_left = 4
	btn_normal.corner_radius_top_right = 4
	btn_normal.corner_radius_bottom_right = 4
	btn_normal.corner_radius_bottom_left = 4
	btn_normal.border_width_left = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color(0.25, 0.70, 0.95, 0.8)
	buy_btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.18, 0.58, 0.80, 1.0)
	buy_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_disabled := btn_normal.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(0.15, 0.18, 0.22, 0.7)
	btn_disabled.border_color = Color(0.25, 0.28, 0.32, 0.5)
	buy_btn.add_theme_stylebox_override("disabled", btn_disabled)

	buy_btn.pressed.connect(func(): _on_buy_upgrade_pressed(upgrade_id))
	bottom_hbox.add_child(buy_btn)

	return panel


func _update_card(upgrade_id: String) -> void:
	if not _upgrade_card_nodes.has(upgrade_id):
		return
	var card: PanelContainer = _upgrade_card_nodes[upgrade_id]
	var def: Dictionary = GameData.REACTOR_UPGRADES.get(upgrade_id, {})
	var cur_lvl: int = GameData.get_reactor_upgrade_level(upgrade_id)

	var count_to_buy := 1
	if _buy_count_mode == -1:
		count_to_buy = maxi(1, GameData.get_reactor_upgrade_max_count(upgrade_id))
	else:
		count_to_buy = _buy_count_mode

	var cost: float = GameData.get_reactor_upgrade_cost(upgrade_id, count_to_buy)
	var can_afford: bool = (GameData.impact_energy >= cost and not is_inf(cost) and not is_nan(cost))

	var level_lbl: Label = card.find_child("LevelLabel", true, false)
	if level_lbl:
		level_lbl.text = "Lv. %s" % GameData.format_num(float(cur_lvl))

	var cur_val_lbl: Label = card.find_child("CurrentValLabel", true, false)
	if cur_val_lbl:
		cur_val_lbl.text = _format_current_effect(upgrade_id, cur_lvl)

	var cost_lbl: Label = card.find_child("CostLabel", true, false)
	if cost_lbl:
		cost_lbl.text = "必要エネルギー: %s" % GameData.format_num(cost)

	var buy_btn: Button = card.find_child("BuyButton", true, false)
	if buy_btn:
		var btn_text := "強化 (+%d)" % count_to_buy if count_to_buy > 1 else "強化"
		buy_btn.text = btn_text
		buy_btn.disabled = not can_afford


func _format_current_effect(upgrade_id: String, cur_lvl: int) -> String:
	match upgrade_id:
		"impact_gold_boost":
			var mult := (GameData.get_reactor_gold_multiplier() - 1.0) * 100.0
			return "現在効果: 衝突ゴールド +%s%%" % GameData.format_num(mult)
		"kinetic_absorption":
			var gain := GameData.get_bounce_impact_energy_gain()
			return "現在効果: 1衝突につき %s エネルギー" % GameData.format_num(gain)
		"elastic_acceleration":
			var spd_pct := (GameData.get_reactor_speed_multiplier() - 1.0) * 100.0
			return "現在効果: ロゴ速度 +%s%%" % GameData.format_num(spd_pct)
		"resonance_tokens":
			var tok_pct := (GameData.get_reactor_token_multiplier() - 1.0) * 100.0
			return "現在効果: 角トークン +%s%%" % GameData.format_num(tok_pct)
		"critical_charge":
			var crit_pct := GameData.get_reactor_crit_rate_bonus()
			return "現在効果: クリティカル率 +%s%%" % GameData.format_num(crit_pct)
		"corner_yield":
			var c_gold_pct := (GameData.get_reactor_corner_gold_multiplier() - 1.0) * 100.0
			return "現在効果: 角ゴールド +%s%%" % GameData.format_num(c_gold_pct)
	return ""


func _on_buy_upgrade_pressed(upgrade_id: String) -> void:
	var count_to_buy := 1
	if _buy_count_mode == -1:
		count_to_buy = maxi(1, GameData.get_reactor_upgrade_max_count(upgrade_id))
	else:
		count_to_buy = _buy_count_mode

	if GameData.buy_reactor_upgrade(upgrade_id, count_to_buy):
		_update_all_ui()


func _update_all_cards() -> void:
	for u_id in _upgrade_card_nodes:
		_update_card(u_id)


func _update_status_bar() -> void:
	if energy_label:
		energy_label.text = "所持エネルギー: %s" % GameData.format_num(GameData.impact_energy)
	if gain_label:
		gain_label.text = "獲得/衝突: %s" % GameData.format_num(GameData.get_bounce_impact_energy_gain())
	if bounce_label:
		bounce_label.text = "総衝突数: %s" % GameData.format_num(float(GameData.total_bounces))


func _update_all_ui() -> void:
	_update_status_bar()
	_update_all_cards()


func _on_impact_energy_changed(_new_amount: float) -> void:
	if is_visible_in_tree():
		_update_status_bar()
		_update_all_cards()


func _on_reactor_upgraded(_upgrade_id: String, _new_level: int) -> void:
	if is_visible_in_tree():
		_update_all_ui()


func _on_stats_changed() -> void:
	if is_visible_in_tree():
		_update_status_bar()
