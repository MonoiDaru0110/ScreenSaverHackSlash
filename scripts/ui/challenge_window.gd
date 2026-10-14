class_name ChallengeWindow
extends BaseWindow
## Window controller for Challenge mode.
## Features 2-column layout:
## - Left: Challenge List (Items show challenge icon and name)
## - Right: Detail View (Name, icon, restriction, target/duration, rewards, challenge/retry/retire button, and active progress)

var _banner_panel: PanelContainer
var _banner_active_box: VBoxContainer
var _banner_title_label: Label
var _banner_time_label: Label
var _banner_progress_bar: ProgressBar
var _banner_progress_label: Label
var _btn_retire: Button

# 2-column elements
var _grid_container: GridContainer
var _list_item_nodes: Dictionary = {} # challenge_id -> Dictionary of node refs
var _selected_challenge_id: String = "c1"

# Right Detail Panel references
var _detail_title_icon: Label
var _detail_title_name: Label
var _detail_status_badge: Label
var _detail_desc_box: VBoxContainer
var _detail_penalty_label: Label
var _detail_target_label: Label
var _detail_reward_label: Label
var _detail_action_btn: Button
var _detail_action_btn_label: Label
var _detail_progress_box: VBoxContainer
var _detail_progress_bar: ProgressBar
var _detail_progress_label: Label
var _detail_time_label: Label


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
	var content := get_content_container()
	if not content:
		return

	# BodyMargin のパディングをゼロにして、セパレータと右側背景がウィンドウの上下・右端まで直結するようにする
	var body_margin := get_node_or_null("WindowVBox/BodyPanel/BodyMargin") as MarginContainer
	if body_margin:
		body_margin.add_theme_constant_override("margin_left", 0)
		body_margin.add_theme_constant_override("margin_top", 0)
		body_margin.add_theme_constant_override("margin_right", 0)
		body_margin.add_theme_constant_override("margin_bottom", 0)

	# ContentContainer の separation を 0 にして隙間をなくす
	content.add_theme_constant_override("separation", 0)

	# 既存の子をクリア
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

	# --- 1. 上部: 現在のチャレンジ進捗表示バー (常時表示) ---
	_banner_panel = PanelContainer.new()
	_banner_panel.custom_minimum_size = Vector2(0, 56)
	_banner_panel.visible = true # 常時表示
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.16, 0.13, 0.05, 0.95)
	banner_style.border_width_left = 0
	banner_style.border_width_top = 0
	banner_style.border_width_right = 0
	banner_style.border_width_bottom = 2
	banner_style.border_color = Color(0.88, 0.68, 0.14, 0.8)
	_banner_panel.add_theme_stylebox_override("panel", banner_style)
	content.add_child(_banner_panel)

	var banner_margin := MarginContainer.new()
	banner_margin.add_theme_constant_override("margin_left", 20)
	banner_margin.add_theme_constant_override("margin_top", 10)
	banner_margin.add_theme_constant_override("margin_right", 20)
	banner_margin.add_theme_constant_override("margin_bottom", 10)
	_banner_panel.add_child(banner_margin)

	# 挑戦中のステータス表示
	_banner_active_box = VBoxContainer.new()
	_banner_active_box.add_theme_constant_override("separation", 6)
	banner_margin.add_child(_banner_active_box)

	var active_top_row := HBoxContainer.new()
	active_top_row.add_theme_constant_override("separation", 16)
	_banner_active_box.add_child(active_top_row)

	_banner_title_label = Label.new()
	_banner_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36, 1.0))
	_banner_title_label.add_theme_font_size_override("font_size", 15)
	_banner_title_label.text = "進行中のチャレンジ: なし"
	active_top_row.add_child(_banner_title_label)

	_banner_time_label = Label.new()
	_banner_time_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55, 1.0))
	_banner_time_label.add_theme_font_size_override("font_size", 14)
	_banner_time_label.text = "⏳ 残り: --.- 秒"
	active_top_row.add_child(_banner_time_label)

	var active_bot_row := HBoxContainer.new()
	active_bot_row.add_theme_constant_override("separation", 12)
	_banner_active_box.add_child(active_bot_row)

	_banner_progress_bar = ProgressBar.new()
	_banner_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner_progress_bar.custom_minimum_size = Vector2(0, 14)
	_banner_progress_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.06, 0.03, 0.9)
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.88, 0.68, 0.14, 1.0)
	bar_fill.set_corner_radius_all(4)
	_banner_progress_bar.add_theme_stylebox_override("background", bar_bg)
	_banner_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	active_bot_row.add_child(_banner_progress_bar)

	_banner_progress_label = Label.new()
	_banner_progress_label.custom_minimum_size = Vector2(180, 0)
	_banner_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_banner_progress_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1.0))
	_banner_progress_label.add_theme_font_size_override("font_size", 13)
	_banner_progress_label.text = "進捗: -- / -- (0%)"
	active_bot_row.add_child(_banner_progress_label)

	# --- 2. メイン部: 2カラム分割 (直線セパレータによる左右分割) ---
	var columns_hbox := HBoxContainer.new()
	columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_hbox.add_theme_constant_override("separation", 0) # セパレータと左右エリアを密着
	content.add_child(columns_hbox)

	# 2-A: 左側 一覧エリア (横3列 × 縦3行の正方形グリッド)
	var left_margin := MarginContainer.new()
	left_margin.custom_minimum_size = Vector2(740, 0)
	left_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_margin.add_theme_constant_override("margin_left", 20)
	left_margin.add_theme_constant_override("margin_top", 16)
	left_margin.add_theme_constant_override("margin_right", 20)
	left_margin.add_theme_constant_override("margin_bottom", 16)
	columns_hbox.add_child(left_margin)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_margin.add_child(left_scroll)

	_grid_container = GridContainer.new()
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_container.columns = 3
	_grid_container.add_theme_constant_override("h_separation", 18)
	_grid_container.add_theme_constant_override("v_separation", 18)
	left_scroll.add_child(_grid_container)

	# 2-B: 中央の垂直セパレータ（上下端まで直通する直線）
	var v_sep := ColorRect.new()
	v_sep.custom_minimum_size = Vector2(2, 0)
	v_sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_sep.color = Color(0.88, 0.68, 0.14, 0.55) # 上部バーの色調に合わせた直線
	columns_hbox.add_child(v_sep)

	# 2-C: 右側 詳細エリア (角丸レクトを撤廃し、上下端・右端まで一面に薄い背景色 Color(0.15, 0.15, 0.24) を敷く)
	var right_bg_panel := PanelContainer.new()
	right_bg_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_bg_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_bg_style := StyleBoxFlat.new()
	right_bg_style.bg_color = Color(0.15, 0.15, 0.24, 1.0) # スキルツリースクロール背景色
	right_bg_style.border_width_left = 0
	right_bg_style.border_width_top = 0
	right_bg_style.border_width_right = 0
	right_bg_style.border_width_bottom = 0
	right_bg_style.corner_radius_bottom_right = 6 # ウィンドウ右下のラウンドのみに合わせる
	right_bg_panel.add_theme_stylebox_override("panel", right_bg_style)
	columns_hbox.add_child(right_bg_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 24)
	right_margin.add_theme_constant_override("margin_top", 20)
	right_margin.add_theme_constant_override("margin_right", 24)
	right_margin.add_theme_constant_override("margin_bottom", 20)
	right_bg_panel.add_child(right_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 16)
	right_margin.add_child(right_vbox)

	# --- 右側ヘッダー: チャレンジ名 + 状態バッジ (絵文字アイコン削除) ---
	var detail_header := HBoxContainer.new()
	detail_header.add_theme_constant_override("separation", 12)
	right_vbox.add_child(detail_header)

	_detail_title_name = Label.new()
	_detail_title_name.text = "チャレンジ名"
	_detail_title_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_detail_title_name.add_theme_font_size_override("font_size", 26)
	detail_header.add_child(_detail_title_name)

	_detail_status_badge = Label.new()
	_detail_status_badge.text = "未達成"
	_detail_status_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_status_badge.add_theme_font_size_override("font_size", 16)
	detail_header.add_child(_detail_status_badge)

	# 区切り線
	var right_sep := ColorRect.new()
	right_sep.custom_minimum_size = Vector2(0, 2)
	right_sep.color = Color(0.60, 0.48, 0.18, 0.6)
	right_vbox.add_child(right_sep)

	# 詳細情報ブロック (制限・ノルマ・報酬)
	_detail_desc_box = VBoxContainer.new()
	_detail_desc_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_desc_box.add_theme_constant_override("separation", 22)
	right_vbox.add_child(_detail_desc_box)

	# 1. ペナルティ
	var penalty_section := VBoxContainer.new()
	penalty_section.add_theme_constant_override("separation", 6)
	_detail_desc_box.add_child(penalty_section)

	var penalty_head := Label.new()
	penalty_head.text = "ペナルティ"
	penalty_head.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	penalty_head.add_theme_font_size_override("font_size", 18)
	penalty_section.add_child(penalty_head)

	_detail_penalty_label = Label.new()
	_detail_penalty_label.text = "ペナルティ内容"
	_detail_penalty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_penalty_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_detail_penalty_label.add_theme_font_size_override("font_size", 18)
	penalty_section.add_child(_detail_penalty_label)

	# 2. 目標
	var target_section := VBoxContainer.new()
	target_section.add_theme_constant_override("separation", 6)
	_detail_desc_box.add_child(target_section)

	var target_head := Label.new()
	target_head.text = "目標"
	target_head.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	target_head.add_theme_font_size_override("font_size", 18)
	target_section.add_child(target_head)

	_detail_target_label = Label.new()
	_detail_target_label.text = "目標内容"
	_detail_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_target_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_detail_target_label.add_theme_font_size_override("font_size", 18)
	target_section.add_child(_detail_target_label)

	# 3. 報酬
	var reward_section := VBoxContainer.new()
	reward_section.add_theme_constant_override("separation", 6)
	_detail_desc_box.add_child(reward_section)

	var reward_head := Label.new()
	reward_head.text = "報酬"
	reward_head.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	reward_head.add_theme_font_size_override("font_size", 18)
	reward_section.add_child(reward_head)

	_detail_reward_label = Label.new()
	_detail_reward_label.text = "報酬内容"
	_detail_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_reward_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_detail_reward_label.add_theme_font_size_override("font_size", 18)
	reward_section.add_child(_detail_reward_label)

	# 4. 右側最下部: 挑戦する / リタイア ボタン (高さ1.5倍: 48 -> 72, フォントサイズ拡大: 16 -> 24)
	_detail_action_btn = Button.new()
	_detail_action_btn.custom_minimum_size = Vector2(0, 72)
	_detail_action_btn.focus_mode = Control.FOCUS_NONE
	_detail_action_btn.text = "" # Labelノードでテキストを描画するため空文字
	_detail_action_btn.pressed.connect(_on_detail_action_pressed)
	right_vbox.add_child(_detail_action_btn)

	_detail_action_btn_label = Label.new()
	_detail_action_btn_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_action_btn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_action_btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_action_btn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_action_btn_label.add_theme_font_size_override("font_size", 24)
	_detail_action_btn_label.text = "挑戦する"
	_detail_action_btn.add_child(_detail_action_btn_label)

	# --- 3. 左側リストのアイテム構築 (3x3 グリッド = 計9個) ---
	_list_item_nodes.clear()
	var sorted_keys: Array = GameData.CHALLENGE_DEFS.keys()
	sorted_keys.sort()
	for ch_id in sorted_keys:
		var def: Dictionary = GameData.CHALLENGE_DEFS[ch_id]
		_create_grid_item(def)

	# ダミーチャレンジを追加して3x3（計9個）を埋める
	var dummy_defs: Array = [
		{"id": "c7_dummy", "name": "？？？？？", "icon": "🔒", "is_dummy": true, "desc": "今後のアップデートで解放予定のチャレンジです。", "reward_desc": "？？？"},
		{"id": "c8_dummy", "name": "？？？？？", "icon": "🔒", "is_dummy": true, "desc": "今後のアップデートで解放予定のチャレンジです。", "reward_desc": "？？？"},
		{"id": "c9_dummy", "name": "？？？？？", "icon": "🔒", "is_dummy": true, "desc": "今後のアップデートで解放予定のチャレンジです。", "reward_desc": "？？？"},
	]
	var needed_dummies := maxi(0, 9 - sorted_keys.size())
	for i in range(mini(needed_dummies, dummy_defs.size())):
		_create_grid_item(dummy_defs[i])

	if not _selected_challenge_id in sorted_keys and not sorted_keys.is_empty():
		_selected_challenge_id = sorted_keys[0]


func _create_grid_item(def: Dictionary) -> void:
	var ch_id: String = def.get("id", "")
	var is_dummy: bool = def.get("is_dummy", false)

	var btn := Button.new()
	# 横3列×縦3行の正方形に近いアスペクト (205x170: サイズを少し縮小して間隔を確保)
	btn.custom_minimum_size = Vector2(205, 170)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 8)
	btn.add_child(margin)

	# 内部レイアウト: Control (全域配置) を使って中央アイコン、下部タイトル、右上チェックマークを配置
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(inner)

	# 1. 右上: チェックマークバッジ（閉じるボタン風の角丸正方形バッジ、緑背景に白いチェックマーク）
	var badge_panel := PanelContainer.new()
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge_panel.offset_left = -40.0
	badge_panel.offset_top = 0.0
	badge_panel.offset_right = 0.0
	badge_panel.offset_bottom = 40.0
	badge_panel.custom_minimum_size = Vector2(40, 40)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.18, 0.65, 0.28, 1.0)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = Color(0.08, 0.35, 0.15, 1.0)
	badge_style.corner_radius_top_left = 4
	badge_style.corner_radius_top_right = 6
	badge_style.corner_radius_bottom_right = 4
	badge_style.corner_radius_bottom_left = 4
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	badge_panel.visible = false
	inner.add_child(badge_panel)

	var status_mini := Label.new()
	status_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_mini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_mini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_mini.set_anchors_preset(Control.PRESET_FULL_RECT)
	status_mini.add_theme_font_size_override("font_size", 24)
	status_mini.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	badge_panel.add_child(status_mini)

	# 2. 中央: アイコン
	var icon_lbl := Label.new()
	icon_lbl.text = def.get("icon", "⚔️")
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.set_anchors_preset(Control.PRESET_CENTER)
	icon_lbl.offset_left = -40.0
	icon_lbl.offset_top = -42.0
	icon_lbl.offset_right = 40.0
	icon_lbl.offset_bottom = 12.0
	icon_lbl.add_theme_font_size_override("font_size", 34)
	if is_dummy:
		icon_lbl.modulate = Color(0.5, 0.5, 0.5, 0.7)
	inner.add_child(icon_lbl)

	# 3. 正方形の下の方: チャレンジタイトル (フォントサイズ拡大: 約1.6倍の21px, #N 番号表示)
	var name_lbl := Label.new()
	if is_dummy:
		name_lbl.text = "準備中"
	else:
		var num_str := ch_id.replace("c", "")
		name_lbl.text = "#%s: %s" % [num_str, def.get("name", "")]
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_lbl.offset_left = 0.0
	name_lbl.offset_top = -36.0
	name_lbl.offset_right = 0.0
	name_lbl.offset_bottom = 0.0
	name_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0) if is_dummy else Color(1.0, 1.0, 1.0, 1.0))
	name_lbl.add_theme_font_size_override("font_size", 21)
	inner.add_child(name_lbl)

	btn.pressed.connect(func(): _select_challenge(ch_id))
	_grid_container.add_child(btn)

	_list_item_nodes[ch_id] = {
		"button": btn,
		"name_lbl": name_lbl,
		"icon_lbl": icon_lbl,
		"status_mini": status_mini,
		"badge_panel": badge_panel,
		"def": def
	}


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
		# 非挑戦時（文言から「チャレンジを選択して～」を削除）
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

	# 右側詳細パネルが現在挑戦中のチャレンジを表示している場合も同期更新
	if _selected_challenge_id == GameData.active_challenge_id and _detail_progress_box and _detail_progress_box.visible:
		if _detail_time_label:
			_detail_time_label.text = "⏳ %.1f 秒" % maxf(0.0, time_left)
		if _detail_progress_bar:
			_detail_progress_bar.max_value = target
			_detail_progress_bar.value = minf(cur, target)
		if _detail_progress_label:
			_detail_progress_label.text = "%s %s / %s (%.0f%%)" % [
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

	if badge_panel:
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
	# 選択中もレクト内部のカラーは変更しない
	var bg_col: Color = Color(0.15, 0.15, 0.24, 1.0)

	# 境界については、選択中のみ境界を強調 (太さ2 & 明瞭なゴールド枠)
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

	# マウスオーバー時は明るくするのではなく少しだけ暗くする
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

	# タイトル設定 (絵文字なし, #N 番号表示)
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

	# アクションボタン: 挑戦中はこのボタン自体が「リタイア（中止）」ボタンに変化する
	_detail_action_btn.text = "" # ボタン本体は空文字
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
	st_pressed.border_color = border_col # 押下時も外周の枠色・強調を変更しない

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
		# 挑戦中ならリタイア実行
		GameData.cancel_challenge()
	else:
		# 未挑戦・再挑戦ならチャレンジ開始
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
