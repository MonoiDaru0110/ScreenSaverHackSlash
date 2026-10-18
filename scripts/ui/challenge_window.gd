class_name ChallengeWindow
extends BaseWindow
## Window controller for Challenge mode.
## Features 2-column layout statically defined in challenge_window.tscn:
## - Left: Challenge List (3x3 Grid of 9 Cards)
## - Right: Detail View (Name, status badge, penalty, target, rewards, action button)

@onready var _banner_panel: PanelContainer = %BannerPanel
@onready var _banner_active_box: VBoxContainer = %BannerActiveBox
@onready var _banner_title_label: Label = %BannerTitleLabel
@onready var _banner_time_label: Label = %BannerTimeLabel
@onready var _banner_progress_bar: ProgressBar = %BannerProgressBar
@onready var _banner_progress_label: Label = %BannerProgressLabel

# 2-column elements
@onready var _grid_container: GridContainer = %ChallengeGrid
var _list_item_nodes: Dictionary = {} # challenge_id -> Dictionary of node refs
var _selected_challenge_id: String = "c1"

# Right Detail Panel references
@onready var _detail_title_name: Label = %DetailTitleName
@onready var _detail_status_badge: Label = %DetailStatusBadge
@onready var _detail_desc_box: VBoxContainer = %DetailDescBox
@onready var _detail_penalty_label: Label = %DetailPenaltyLabel
@onready var _detail_target_label: Label = %DetailTargetLabel
@onready var _detail_reward_label: Label = %DetailRewardLabel
@onready var _detail_action_btn: Button = %DetailActionBtn
@onready var _detail_action_btn_label: Label = %DetailActionBtnLabel


func _ready() -> void:
	super._ready()
	_setup_challenge_ui()
	
	GameData.challenge_started.connect(_on_challenge_started)
	GameData.challenge_progress_updated.connect(_on_challenge_progress_updated)
	GameData.challenge_completed.connect(_on_challenge_completed)
	GameData.challenge_failed.connect(_on_challenge_failed)
	GameData.challenge_state_changed.connect(_update_all_ui)

	_update_all_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_update_all_ui()


func _setup_challenge_ui() -> void:
	if _detail_action_btn and not _detail_action_btn.pressed.is_connected(_on_detail_action_pressed):
		_detail_action_btn.pressed.connect(_on_detail_action_pressed)

	_list_item_nodes.clear()
	if not _grid_container:
		return

	var sorted_keys: Array = GameData.CHALLENGE_DEFS.keys()
	sorted_keys.sort()

	var all_defs: Array = []
	for ch_id in sorted_keys:
		all_defs.append(GameData.CHALLENGE_DEFS[ch_id])

	# ダミーチャレンジ定義（9枠分）
	var dummy_defs: Array = [
		{"id": "c7_dummy", "name": "？？？？？", "icon": "🔒", "is_dummy": true, "desc": "今後のアップデートで解放予定のチャレンジです。", "reward_desc": "？？？"},
		{"id": "c8_dummy", "name": "？？？？？", "icon": "🔒", "is_dummy": true, "desc": "今後のアップデートで解放予定のチャレンジです。", "reward_desc": "？？？"},
		{"id": "c9_dummy", "name": "？？？？？", "icon": "🔒", "is_dummy": true, "desc": "今後のアップデートで解放予定のチャレンジです。", "reward_desc": "？？？"},
	]
	for d in dummy_defs:
		if all_defs.size() < 9:
			all_defs.append(d)

	var cards := _grid_container.get_children()
	for i in range(mini(cards.size(), all_defs.size())):
		var btn := cards[i] as Button
		if not btn:
			continue
		var def: Dictionary = all_defs[i]
		var ch_id: String = def.get("id", "")
		var is_dummy: bool = def.get("is_dummy", false)

		var badge_panel := btn.get_node_or_null("Margin/Inner/BadgePanel") as PanelContainer
		var status_mini := btn.get_node_or_null("Margin/Inner/BadgePanel/StatusMini") as Label
		var icon_lbl := btn.get_node_or_null("Margin/Inner/IconLabel") as Label
		var name_lbl := btn.get_node_or_null("Margin/Inner/NameLabel") as Label

		if icon_lbl:
			icon_lbl.text = def.get("icon", "⚔️")
			icon_lbl.modulate = Color(0.5, 0.5, 0.5, 0.7) if is_dummy else Color(1.0, 1.0, 1.0, 1.0)
		if name_lbl:
			if is_dummy:
				name_lbl.text = "準備中"
			else:
				var num_str := ch_id.replace("c", "")
				name_lbl.text = "#%s: %s" % [num_str, def.get("name", "")]
			name_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0) if is_dummy else Color(1.0, 1.0, 1.0, 1.0))

		btn.pressed.connect(func(): _select_challenge(ch_id))

		_list_item_nodes[ch_id] = {
			"button": btn,
			"name_lbl": name_lbl,
			"icon_lbl": icon_lbl,
			"status_mini": status_mini,
			"badge_panel": badge_panel,
			"def": def
		}

	if not _selected_challenge_id in sorted_keys and not sorted_keys.is_empty():
		_selected_challenge_id = sorted_keys[0]


func _select_challenge(ch_id: String) -> void:
	_selected_challenge_id = ch_id
	_update_all_ui()


func _update_all_ui() -> void:
	_update_banner()
	for ch_id in _list_item_nodes:
		_update_list_item(ch_id)
	_update_detail_panel()


func _update_banner() -> void:
	if not _banner_panel:
		return

	var is_active := GameData.is_challenge_active()
	_banner_panel.visible = true # 常時表示

	if is_active:
		var def: Dictionary = GameData.CHALLENGE_DEFS.get(GameData.active_challenge_id, {})
		var num_str := GameData.active_challenge_id.replace("c", "")
		_banner_title_label.text = "挑戦中: #%s %s" % [num_str, def.get("name", "")]
		_update_active_progress_ui(GameData.challenge_current_val, GameData.challenge_target_val, GameData.challenge_time_left)
	else:
		_banner_title_label.text = "進行中のチャレンジ: なし"
		_banner_time_label.text = "⏳ 残り: --.- 秒"
		if _banner_progress_bar:
			_banner_progress_bar.max_value = 100.0
			_banner_progress_bar.value = 0.0
		if _banner_progress_label:
			_banner_progress_label.text = "進捗: -- / -- (0%)"


func _update_active_progress_ui(cur: float, target: float, time_left: float) -> void:
	if not _banner_time_label:
		return
	_banner_time_label.text = "⏳ 残り: %.1f 秒" % maxf(0.0, time_left)

	var def: Dictionary = GameData.CHALLENGE_DEFS.get(GameData.active_challenge_id, {})
	var cur_sym := "🪙" if def.get("target_type", "gold") == "gold" else "💎"
	var pct := 0.0 if target <= 0.0 else (cur / target) * 100.0

	if _banner_progress_bar:
		_banner_progress_bar.max_value = target
		_banner_progress_bar.value = minf(cur, target)

	if _banner_progress_label:
		_banner_progress_label.text = "%s %s / %s (%.0f%%)" % [
			cur_sym,
			GameData.format_num(cur),
			GameData.format_num(target),
			pct
		]


func _update_list_item(ch_id: String) -> void:
	if not _list_item_nodes.has(ch_id):
		return
	var item: Dictionary = _list_item_nodes[ch_id]
	var btn: Button = item["button"]
	var mini_badge: Label = item["status_mini"]
	var badge_panel: PanelContainer = item.get("badge_panel")

	var is_selected := (ch_id == _selected_challenge_id)
	var is_cleared: bool = GameData.is_challenge_cleared(ch_id)
	var is_active: bool = GameData.is_challenge_active(ch_id)

	if badge_panel and mini_badge:
		if is_active:
			badge_panel.visible = true
			mini_badge.text = "⚔️"
			mini_badge.add_theme_font_size_override("font_size", 20)
			var active_style := StyleBoxFlat.new()
			active_style.bg_color = Color(0.72, 0.52, 0.10, 1.0) # ゴールド
			active_style.border_width_left = 1
			active_style.border_width_top = 1
			active_style.border_width_right = 1
			active_style.border_width_bottom = 1
			active_style.border_color = Color(0.95, 0.85, 0.40, 1.0)
			active_style.corner_radius_top_left = 4
			active_style.corner_radius_top_right = 6
			active_style.corner_radius_bottom_right = 4
			active_style.corner_radius_bottom_left = 4
			badge_panel.add_theme_stylebox_override("panel", active_style)
		elif is_cleared:
			badge_panel.visible = true
			mini_badge.text = "✓"
			mini_badge.add_theme_font_size_override("font_size", 26)
			var clear_style := StyleBoxFlat.new()
			clear_style.bg_color = Color(0.32, 0.72, 0.18, 1.0) # 黄緑色 (Lime Green)
			clear_style.border_width_left = 1
			clear_style.border_width_top = 1
			clear_style.border_width_right = 1
			clear_style.border_width_bottom = 1
			clear_style.border_color = Color(0.18, 0.45, 0.08, 1.0) # 濃い黄緑の境界線
			clear_style.corner_radius_top_left = 4
			clear_style.corner_radius_top_right = 6
			clear_style.corner_radius_bottom_right = 4
			clear_style.corner_radius_bottom_left = 4
			badge_panel.add_theme_stylebox_override("panel", clear_style)
			mini_badge.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0)) # 純白
		else:
			badge_panel.visible = false

	# スキルツリーウィンドウのスクロール背景色 Color(0.15, 0.15, 0.24) を適用
	var bg_col: Color = Color(0.15, 0.15, 0.24, 1.0)
	var border_col: Color = Color(0.88, 0.68, 0.14, 1.0) if is_selected else Color(0.35, 0.28, 0.10, 0.8)

	_apply_item_style(btn, bg_col, border_col, is_selected)


func _apply_item_style(btn: Button, bg_col: Color, border_col: Color, is_selected: bool) -> void:
	var st_normal := StyleBoxFlat.new()
	st_normal.bg_color = bg_col
	var b_width := 2 if is_selected else 1
	st_normal.border_width_left = b_width
	st_normal.border_width_top = b_width
	st_normal.border_width_right = b_width
	st_normal.border_width_bottom = b_width
	st_normal.border_color = border_col
	st_normal.set_corner_radius_all(6)

	var st_hover := st_normal.duplicate() as StyleBoxFlat
	st_hover.bg_color = bg_col.darkened(0.15)
	if not is_selected:
		st_hover.border_color = border_col.lightened(0.2)

	var st_pressed := st_normal.duplicate() as StyleBoxFlat
	st_pressed.bg_color = bg_col.darkened(0.25)

	btn.add_theme_stylebox_override("normal", st_normal)
	btn.add_theme_stylebox_override("hover", st_hover)
	btn.add_theme_stylebox_override("pressed", st_pressed)


func _update_detail_panel() -> void:
	if not _detail_title_name:
		return

	var def: Dictionary = {}
	if _list_item_nodes.has(_selected_challenge_id):
		def = _list_item_nodes[_selected_challenge_id].get("def", {})
	else:
		def = GameData.CHALLENGE_DEFS.get(_selected_challenge_id, {})

	if def.is_empty():
		return

	var ch_id: String = _selected_challenge_id
	var is_dummy: bool = def.get("is_dummy", false)
	var is_cleared: bool = GameData.is_challenge_cleared(ch_id) if not is_dummy else false
	var is_current_active: bool = GameData.is_challenge_active(ch_id) if not is_dummy else false

	# タイトル設定
	if is_dummy:
		_detail_title_name.text = def.get("name", "？？？？？")
	else:
		var num_str := ch_id.replace("c", "")
		_detail_title_name.text = "#%s: %s" % [num_str, def.get("name", "")]

	# 状態バッジ
	if is_dummy:
		_detail_status_badge.text = "【 準備中 】"
		_detail_status_badge.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	elif is_current_active:
		_detail_status_badge.text = "【 挑戦中 】"
		_detail_status_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	elif is_cleared:
		_detail_status_badge.text = "✔ CLEAR!"
		_detail_status_badge.add_theme_color_override("font_color", Color(0.4, 0.95, 0.55, 1.0))
	else:
		_detail_status_badge.text = "未達成"
		_detail_status_badge.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1.0))

	# 制限内容
	_detail_penalty_label.text = def.get("desc", "")

	var target_currency := "🪙" if def.get("target_type", "gold") == "gold" else "💎"

	# 達成ノルマ
	if is_dummy:
		_detail_target_label.text = "現在準備中です。解放をお楽しみに！"
	else:
		var target_str := GameData.format_num(float(def.get("target_val", 0.0)))
		var duration_str := "%d秒" % int(def.get("duration", 60.0))
		_detail_target_label.text = "制限時間 %s 以内に %s %s を獲得" % [duration_str, target_currency, target_str]

	# 報酬内容
	_detail_reward_label.text = def.get("reward_desc", "")

	# アクションボタン
	_detail_action_btn.text = ""
	if is_dummy:
		if _detail_action_btn_label:
			_detail_action_btn_label.text = "準備中"
		_detail_action_btn.disabled = true
		_apply_btn_style(_detail_action_btn, Color(0.2, 0.2, 0.25, 0.6), Color(0.35, 0.35, 0.4, 0.5), Color(0.55, 0.55, 0.6, 0.8))
	elif is_current_active:
		if _detail_action_btn_label:
			_detail_action_btn_label.text = "挑戦を中止"
		_detail_action_btn.disabled = false
		_apply_btn_style(_detail_action_btn, Color(0.55, 0.16, 0.16, 1.0), Color(0.85, 0.30, 0.30, 1.0), Color(1.0, 0.92, 0.92, 1.0))
	elif is_cleared:
		if _detail_action_btn_label:
			_detail_action_btn_label.text = "再挑戦する"
		_detail_action_btn.disabled = false
		_apply_btn_style(_detail_action_btn, Color(0.88, 0.68, 0.14, 1.0), Color(1.0, 0.85, 0.35, 1.0), Color(1.0, 1.0, 1.0, 1.0))
	else:
		if _detail_action_btn_label:
			_detail_action_btn_label.text = "挑戦する"
		_detail_action_btn.disabled = false
		_apply_btn_style(_detail_action_btn, Color(0.88, 0.68, 0.14, 1.0), Color(1.0, 0.85, 0.35, 1.0), Color(1.0, 1.0, 1.0, 1.0))


func _apply_btn_style(btn: Button, bg_col: Color, border_col: Color, text_col: Color = Color(0.95, 0.95, 0.98, 1.0)) -> void:
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_disabled_color", text_col.darkened(0.3))
	if btn == _detail_action_btn and _detail_action_btn_label:
		_detail_action_btn_label.add_theme_color_override("font_color", text_col)

	var st_normal := StyleBoxFlat.new()
	st_normal.bg_color = bg_col
	st_normal.border_width_left = 1
	st_normal.border_width_top = 1
	st_normal.border_width_right = 1
	st_normal.border_width_bottom = 1
	st_normal.border_color = border_col
	st_normal.set_corner_radius_all(6)

	var st_hover := st_normal.duplicate() as StyleBoxFlat
	st_hover.bg_color = bg_col.lightened(0.15)
	st_hover.border_color = border_col.lightened(0.15)

	var st_pressed := st_normal.duplicate() as StyleBoxFlat
	st_pressed.bg_color = bg_col.darkened(0.15)
	st_pressed.border_color = border_col

	var st_disabled := st_normal.duplicate() as StyleBoxFlat
	st_disabled.bg_color = bg_col.darkened(0.35)
	st_disabled.border_color = border_col.darkened(0.35)

	var st_focus := StyleBoxEmpty.new()

	btn.add_theme_stylebox_override("normal", st_normal)
	btn.add_theme_stylebox_override("hover", st_hover)
	btn.add_theme_stylebox_override("pressed", st_pressed)
	btn.add_theme_stylebox_override("disabled", st_disabled)
	btn.add_theme_stylebox_override("focus", st_focus)


func _on_detail_action_pressed() -> void:
	if _selected_challenge_id.is_empty():
		return
	if GameData.is_challenge_active(_selected_challenge_id):
		GameData.cancel_challenge()
	else:
		GameData.start_challenge(_selected_challenge_id)


func _on_retire_pressed() -> void:
	GameData.cancel_challenge()


func _on_challenge_started(_challenge_id: String) -> void:
	_update_all_ui()


func _on_challenge_progress_updated(cur: float, target: float, time_left: float) -> void:
	_update_active_progress_ui(cur, target, time_left)


func _on_challenge_completed(_challenge_id: String) -> void:
	_update_all_ui()


func _on_challenge_failed(_challenge_id: String) -> void:
	_update_all_ui()
