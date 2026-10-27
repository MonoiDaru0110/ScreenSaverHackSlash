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
@onready var _detail_desc_box: VBoxContainer = %DetailDescBox
@onready var _detail_penalty_label: Label = %DetailPenaltyLabel
@onready var _detail_target_label: Label = %DetailTargetLabel
@onready var _detail_reward_label: Label = %DetailRewardLabel
@onready var _detail_action_btn: Button = %DetailActionBtn
@onready var _detail_action_btn_label: Label = %DetailActionBtnLabel
@onready var _open_editor_btn: Button = get_node_or_null("%OpenChallengeEditorBtn")


func _ready() -> void:
	super._ready()
	_setup_challenge_ui()
	
	GameData.challenge_started.connect(_on_challenge_started)
	GameData.challenge_progress_updated.connect(_on_challenge_progress_updated)
	GameData.challenge_completed.connect(_on_challenge_completed)
	GameData.challenge_failed.connect(_on_challenge_failed)
	GameData.challenge_state_changed.connect(_update_all_ui)
	GameData.skill_upgraded.connect(func(_id, _lvl): _update_all_ui())

	_update_all_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_update_all_ui()


func _setup_challenge_ui() -> void:
	if _detail_action_btn and not _detail_action_btn.pressed.is_connected(_on_detail_action_pressed):
		_detail_action_btn.pressed.connect(_on_detail_action_pressed)

	if _open_editor_btn and not _open_editor_btn.pressed.is_connected(_on_open_editor_pressed):
		_open_editor_btn.pressed.connect(_on_open_editor_pressed)

	_list_item_nodes.clear()
	if not _grid_container:
		return

	var sorted_keys: Array = GameData.CHALLENGE_DEFS.keys()
	sorted_keys.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)

	var all_defs: Array = []
	for ch_id in sorted_keys:
		all_defs.append(GameData.CHALLENGE_DEFS[ch_id])

	var cards := _grid_container.get_children()
	for i in range(cards.size()):
		var btn := cards[i] as Button
		if not btn:
			continue
		if i >= all_defs.size():
			btn.visible = false
			continue

		btn.visible = true
		var def: Dictionary = all_defs[i]
		var ch_id: String = def.get("id", "")

		var badge_panel := btn.get_node_or_null("Margin/Inner/BadgePanel") as PanelContainer
		var status_mini := btn.get_node_or_null("Margin/Inner/BadgePanel/StatusMini") as Label
		var icon_lbl := btn.get_node_or_null("Margin/Inner/IconLabel") as Label
		var name_lbl := btn.get_node_or_null("Margin/Inner/NameLabel") as Label
		var inner := btn.get_node_or_null("Margin/Inner") as Control

		# 落ち影用テクスチャ（ソフトで薄いぼかし影のため複数レイヤーを背面に配置）
		var shadow_offsets: Array[Vector2] = [
			Vector2(2.0, 3.0),
			Vector2(4.0, 3.0),
			Vector2(2.0, 5.0),
			Vector2(4.0, 5.0),
			Vector2(3.0, 4.0),
		]
		var shadow_alphas: Array[float] = [0.05, 0.05, 0.05, 0.05, 0.06]
		var shadow_textures: Array[TextureRect] = []

		for s_idx in range(shadow_offsets.size()):
			var s_name := "ShadowTexture_%d" % s_idx
			var s_node := btn.get_node_or_null("Margin/Inner/" + s_name) as TextureRect
			if not s_node and inner:
				s_node = TextureRect.new()
				s_node.name = s_name
				inner.add_child(s_node)
			if s_node:
				s_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				s_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				s_node.custom_minimum_size = Vector2(110, 110)
				s_node.size = Vector2(110, 110)
				s_node.anchor_left = 0.5
				s_node.anchor_right = 0.5
				s_node.anchor_top = 0.0
				s_node.anchor_bottom = 0.0
				var off := shadow_offsets[s_idx]
				s_node.offset_left = -55.0 + off.x
				s_node.offset_right = 55.0 + off.x
				s_node.offset_top = 2.0 + off.y
				s_node.offset_bottom = 112.0 + off.y
				s_node.grow_horizontal = Control.GROW_DIRECTION_BOTH
				s_node.grow_vertical = Control.GROW_DIRECTION_END
				s_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
				s_node.modulate = Color(0.0, 0.0, 0.0, shadow_alphas[s_idx])
				s_node.visible = false
				shadow_textures.append(s_node)

		# 以前の古い ShadowTexture / ProgressBadge があれば非表示化
		var old_shadow := btn.get_node_or_null("Margin/Inner/ShadowTexture") as TextureRect
		if old_shadow:
			old_shadow.visible = false
		var old_badge := btn.get_node_or_null("Margin/Inner/ProgressBadge") as Control
		if old_badge:
			old_badge.visible = false

		var icon_tex := btn.get_node_or_null("Margin/Inner/IconTexture") as TextureRect
		if not icon_tex and inner:
			icon_tex = TextureRect.new()
			icon_tex.name = "IconTexture"
			inner.add_child(icon_tex)

		# 描画順序を完全に保証: shadow_textures（奥）→ icon_tex（手前）
		for st in shadow_textures:
			inner.move_child(st, inner.get_child_count() - 1)
		if icon_tex:
			inner.move_child(icon_tex, inner.get_child_count() - 1)

		# 左上のクリア状況テキスト (n/m) - タイトルと同様にテキストをそのまま配置
		var progress_label := btn.get_node_or_null("Margin/Inner/ProgressTextLabel") as Label
		if not progress_label and inner:
			progress_label = Label.new()
			progress_label.name = "ProgressTextLabel"
			inner.add_child(progress_label)

		if progress_label:
			progress_label.anchor_left = 0.0
			progress_label.anchor_top = 0.0
			progress_label.anchor_right = 0.0
			progress_label.anchor_bottom = 0.0
			progress_label.offset_left = 5.0
			progress_label.offset_top = 3.0
			progress_label.add_theme_font_size_override("font_size", 21)
			progress_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			progress_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
			progress_label.add_theme_constant_override("shadow_offset_x", 2)
			progress_label.add_theme_constant_override("shadow_offset_y", 2)
			progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			progress_label.visible = false
			inner.move_child(progress_label, inner.get_child_count() - 1)

		if icon_tex:
			icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_tex.custom_minimum_size = Vector2(110, 110)
			icon_tex.size = Vector2(110, 110)
			icon_tex.anchor_left = 0.5
			icon_tex.anchor_right = 0.5
			icon_tex.anchor_top = 0.0
			icon_tex.anchor_bottom = 0.0
			icon_tex.offset_left = -55.0
			icon_tex.offset_right = 55.0
			icon_tex.offset_top = 2.0
			icon_tex.offset_bottom = 112.0
			icon_tex.grow_horizontal = Control.GROW_DIRECTION_BOTH
			icon_tex.grow_vertical = Control.GROW_DIRECTION_END
			icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_tex.visible = false

		if icon_lbl:
			icon_lbl.text = def.get("icon", "⚔️")
			icon_lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
			icon_lbl.add_theme_font_size_override("font_size", 54)
			icon_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.35))
			icon_lbl.add_theme_constant_override("shadow_offset_x", 2)
			icon_lbl.add_theme_constant_override("shadow_offset_y", 3)
			icon_lbl.offset_top = -66.0
			icon_lbl.offset_bottom = 6.0
		if name_lbl:
			var num_str := ch_id.replace("c", "")
			name_lbl.text = "#%s %s" % [num_str, def.get("name", "")]
			name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			name_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
			name_lbl.add_theme_constant_override("shadow_offset_x", 1)
			name_lbl.add_theme_constant_override("shadow_offset_y", 1)
			name_lbl.offset_top = -46.0
			name_lbl.offset_bottom = -2.0
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.add_theme_font_size_override("font_size", 21)
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		btn.pressed.connect(func(): _select_challenge(ch_id))

		_list_item_nodes[ch_id] = {
			"button": btn,
			"name_lbl": name_lbl,
			"icon_lbl": icon_lbl,
			"icon_tex": icon_tex,
			"shadow_textures": shadow_textures,
			"progress_label": progress_label,
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


static func _load_icon_texture(path_or_str: String) -> Texture2D:
	var s := path_or_str.strip_edges()
	if s.is_empty():
		return null
	if (s.begins_with("res://") or s.begins_with("user://")) and ResourceLoader.exists(s):
		var res := load(s)
		if res is Texture2D:
			return res
	return null


func _update_list_item(ch_id: String) -> void:
	if not _list_item_nodes.has(ch_id):
		return
	var item: Dictionary = _list_item_nodes[ch_id]
	var btn: Button = item["button"]
	var mini_badge: Label = item["status_mini"]
	var badge_panel: PanelContainer = item.get("badge_panel")
	var icon_lbl: Label = item.get("icon_lbl")
	var icon_tex: TextureRect = item.get("icon_tex")
	var shadow_textures: Array = item.get("shadow_textures", [])
	var progress_label: Label = item.get("progress_label")
	var name_lbl: Label = item.get("name_lbl")
	var def: Dictionary = item.get("def", {})

	var is_unlocked := GameData.is_challenge_item_unlocked(ch_id)
	var is_selected := (ch_id == _selected_challenge_id)
	var def_max: int = GameData.get_challenge_def_max_level(ch_id)
	var max_lvl: int = GameData.get_challenge_max_level(ch_id)
	var cleared_lvl: int = GameData.get_challenge_cleared_level(ch_id)
	var is_max_cleared: bool = (cleared_lvl >= def_max) if is_unlocked else false
	var is_active: bool = GameData.is_challenge_active(ch_id) if is_unlocked else false

	var num_str := ch_id.replace("c", "")
	if not is_unlocked:
		if progress_label:
			progress_label.visible = false
		for st in shadow_textures:
			st.visible = false
		if icon_tex:
			icon_tex.visible = false
		if icon_lbl:
			icon_lbl.visible = true
			icon_lbl.text = "🔒"
			icon_lbl.modulate = Color(0.65, 0.65, 0.70, 0.8)
		if name_lbl:
			name_lbl.text = "#%s ？？？？？" % num_str
			name_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70, 0.8))
	else:
		if progress_label:
			progress_label.visible = true
			progress_label.text = "%d/%d" % [cleared_lvl, max_lvl]
			if cleared_lvl >= max_lvl:
				progress_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.45, 1.0))
			else:
				progress_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

		var icon_val: String = str(def.get("icon", "⚔️"))
		var tex := _load_icon_texture(icon_val)
		if tex:
			for st in shadow_textures:
				st.texture = tex
				st.visible = true
			if icon_tex:
				icon_tex.texture = tex
				icon_tex.visible = true
			if icon_lbl:
				icon_lbl.visible = false
		else:
			for st in shadow_textures:
				st.visible = false
			if icon_tex:
				icon_tex.visible = false
			if icon_lbl:
				icon_lbl.text = icon_val
				icon_lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
				icon_lbl.visible = true
		if name_lbl:
			name_lbl.text = "#%s %s" % [num_str, def.get("name", "")]
			name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	if badge_panel and mini_badge:
		if not is_unlocked:
			badge_panel.visible = false
		elif is_active:
			badge_panel.visible = true
			mini_badge.text = "⚔️"
			mini_badge.add_theme_font_size_override("font_size", 20)
			var active_style := StyleBoxFlat.new()
			active_style.bg_color = Color(0.18, 0.48, 0.85, 1.0) # 鮮やかなブルー
			active_style.border_width_left = 1
			active_style.border_width_top = 1
			active_style.border_width_right = 1
			active_style.border_width_bottom = 1
			active_style.border_color = Color(0.5, 0.82, 1.0, 1.0)
			active_style.corner_radius_top_left = 4
			active_style.corner_radius_top_right = 6
			active_style.corner_radius_bottom_right = 4
			active_style.corner_radius_bottom_left = 4
			badge_panel.add_theme_stylebox_override("panel", active_style)
		elif is_max_cleared:
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

	# スチールブルー調のカード背景 Color(0.26, 0.44, 0.66) を適用（少し明るく彩度を高めた青）
	var bg_col: Color = Color(0.12, 0.15, 0.22, 1.0) if not is_unlocked else Color(0.26, 0.44, 0.66, 1.0)
	var border_col: Color
	if is_selected:
		border_col = Color(0.55, 0.85, 1.0, 1.0)
	elif not is_unlocked:
		border_col = Color(0.18, 0.24, 0.32, 0.6)
	else:
		border_col = Color(0.16, 0.28, 0.44, 1.0)

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
	var is_unlocked := GameData.is_challenge_item_unlocked(ch_id) if not is_dummy else false
	var is_cleared: bool = GameData.is_challenge_cleared(ch_id) if (not is_dummy and is_unlocked) else false
	var is_current_active: bool = GameData.is_challenge_active(ch_id) if (not is_dummy and is_unlocked) else false

	var def_max := GameData.get_challenge_def_max_level(ch_id)
	var max_lvl := GameData.get_challenge_max_level(ch_id)
	var cleared_lvl := GameData.get_challenge_cleared_level(ch_id)
	var target_lvl := GameData.get_challenge_target_level(ch_id)
	var lv_def: Dictionary = GameData.get_challenge_level_def(ch_id, target_lvl)
	var num_str := ch_id.replace("c", "")

	# タイトル設定
	var title_text := ""
	if is_dummy:
		title_text = def.get("name", "？？？？？")
	elif not is_unlocked:
		title_text = "#%s ？？？？？" % num_str
	else:
		if def_max > 1:
			title_text = "#%s %s(Lv%d/%d)" % [num_str, def.get("name", ""), target_lvl, max_lvl]
		else:
			title_text = "#%s %s" % [num_str, def.get("name", "")]
	_detail_title_name.text = title_text

	# 利用可能幅（約405px）に収まる最大のフォントサイズを動的に計算（最大28px、最小18px）
	# 短いタイトルも程よい大きさ（28px）に抑え、長いタイトルも横幅内に収まる
	var max_avail_w := 405.0
	var font := _detail_title_name.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font
	var chosen_size := 28
	if font:
		for sz in range(28, 17, -1):
			var text_w := font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			if text_w <= max_avail_w:
				chosen_size = sz
				break
			chosen_size = sz
	else:
		var char_len := title_text.length()
		if char_len > 24:
			chosen_size = 18
		elif char_len > 20:
			chosen_size = 20
		elif char_len > 16:
			chosen_size = 22
		elif char_len > 12:
			chosen_size = 25
		else:
			chosen_size = 28
	_detail_title_name.add_theme_font_size_override("font_size", chosen_size)

	# 制限内容
	if not is_unlocked and not is_dummy:
		var unlock_hint := ""
		match ch_id:
			"c3", "c4": unlock_hint = "スキルツリーの「新チャレンジ解放Ⅰ」を習得すると解放されます。"
			"c5", "c6": unlock_hint = "スキルツリーの「新チャレンジ解放Ⅱ」を習得すると解放されます。"
			"c7", "c8": unlock_hint = "スキルツリーの「新チャレンジ解放Ⅲ」を習得すると解放されます。"
			_: unlock_hint = "スキルツリーで新チャレンジ解放スキルを習得すると解放されます。"
		_detail_penalty_label.text = unlock_hint
		_detail_penalty_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70, 0.8))
	else:
		_detail_penalty_label.text = def.get("desc", "")
		_detail_penalty_label.add_theme_color_override("font_color", Color(0.98, 0.42, 0.28, 1.0)) # オレンジが勝った赤
	_detail_penalty_label.add_theme_font_size_override("font_size", 24)

	var target_currency := "🪙" if lv_def.get("target_type", "gold") == "gold" else "💎"

	# 達成ノルマ（目標コスト / 制限時間[s]形式、例: 🪙5000 / 60[s]）
	if is_dummy:
		_detail_target_label.text = "現在準備中です。解放をお楽しみに！"
		_detail_target_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70, 0.8))
	elif not is_unlocked:
		_detail_target_label.text = "？？？？？"
		_detail_target_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70, 0.8))
	else:
		var eff_target_val := GameData.get_challenge_effective_target_val(ch_id, target_lvl)
		var eff_duration := GameData.get_challenge_effective_duration(ch_id, target_lvl)
		var target_str := GameData.format_num(eff_target_val)
		var duration_num_str := "%.1f" % eff_duration if fmod(eff_duration, 1.0) != 0.0 else "%d" % int(eff_duration)
		_detail_target_label.text = "%s%s / %s[s]" % [target_currency, target_str, duration_num_str]
		_detail_target_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0)) # 薄い水色
	_detail_target_label.add_theme_font_size_override("font_size", 24)

	# 報酬内容
	# 未クリアのレベルが残っている（cleared_lvl < max_lvl）：次のレベルクリア時の報酬を表記
	# 未クリアのレベルが残っていない（cleared_lvl >= max_lvl）：現在のレベルクリア時の報酬を表記
	if not is_unlocked and not is_dummy:
		_detail_reward_label.text = "？？？？？"
		_detail_reward_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70, 0.8))
	else:
		var has_uncleared_levels := (cleared_lvl < max_lvl)
		var display_reward_lvl: int
		if has_uncleared_levels:
			display_reward_lvl = cleared_lvl + 1
		else:
			display_reward_lvl = maxi(1, cleared_lvl)

		var reward_lv_def := GameData.get_challenge_level_def(ch_id, display_reward_lvl)
		var r_text: String = reward_lv_def.get("reward_desc", def.get("reward_desc", ""))
		var clean_r_text := r_text.replace("恒久効果: ", "").replace("恒久効果：", "").replace("恒久効果", "").strip_edges()
		_detail_reward_label.text = clean_r_text
		_detail_reward_label.add_theme_color_override("font_color", Color(0.40, 0.92, 0.60, 1.0)) # 明るいミントグリーン
	_detail_reward_label.add_theme_font_size_override("font_size", 24)

	# アクションボタン
	_detail_action_btn.text = ""
	if is_dummy or not GameData.is_challenge_unlocked() or not is_unlocked:
		if _detail_action_btn_label:
			_detail_action_btn_label.text = "準備中" if is_dummy else "未解放"
		_detail_action_btn.disabled = true
		_apply_btn_style(_detail_action_btn, Color(0.2, 0.2, 0.25, 0.6), Color(0.35, 0.35, 0.4, 0.5), Color(0.55, 0.55, 0.6, 0.8))
	elif is_current_active:
		if _detail_action_btn_label:
			_detail_action_btn_label.text = "挑戦を中止"
		_detail_action_btn.disabled = false
		_apply_btn_style(_detail_action_btn, Color(0.55, 0.16, 0.16, 1.0), Color(0.85, 0.30, 0.30, 1.0), Color(1.0, 0.92, 0.92, 1.0))
	elif cleared_lvl >= max_lvl:
		if _detail_action_btn_label:
			_detail_action_btn_label.text = "クリア済み"
		_detail_action_btn.disabled = true
		_apply_btn_style(_detail_action_btn, Color(0.15, 0.22, 0.32, 0.7), Color(0.25, 0.35, 0.48, 0.6), Color(0.6, 0.7, 0.8, 0.7))
	elif is_cleared:
		if _detail_action_btn_label:
			_detail_action_btn_label.text = "挑戦する (Lv.%d)" % target_lvl
		_detail_action_btn.disabled = false
		_apply_btn_style(_detail_action_btn, Color(0.18, 0.42, 0.78, 1.0), Color(0.35, 0.65, 0.98, 1.0), Color(1.0, 1.0, 1.0, 1.0))
	else:
		if _detail_action_btn_label:
			_detail_action_btn_label.text = "挑戦する"
		_detail_action_btn.disabled = false
		_apply_btn_style(_detail_action_btn, Color(0.18, 0.42, 0.78, 1.0), Color(0.35, 0.65, 0.98, 1.0), Color(1.0, 1.0, 1.0, 1.0))


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
	st_hover.bg_color = bg_col.darkened(0.15)
	st_hover.border_color = border_col.darkened(0.08)

	var st_pressed := st_normal.duplicate() as StyleBoxFlat
	st_pressed.bg_color = bg_col.darkened(0.25)
	st_pressed.border_color = border_col.darkened(0.15)

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
		var max_lvl: int = GameData.get_challenge_max_level(_selected_challenge_id)
		var cleared_lvl: int = GameData.get_challenge_cleared_level(_selected_challenge_id)
		if cleared_lvl >= max_lvl:
			return
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


func _on_open_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/editor/challenge_editor.tscn")
