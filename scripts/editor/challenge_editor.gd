extends Control

const SAVE_PATH = "res://data/challenges.json"

# UI ノード参照
@onready var challenge_list: ItemList = %ChallengeList
@onready var move_up_btn: Button = %MoveUpBtn
@onready var move_down_btn: Button = %MoveDownBtn
@onready var add_challenge_btn: Button = %AddChallengeBtn
@onready var duplicate_challenge_btn: Button = %DuplicateChallengeBtn
@onready var delete_challenge_btn: Button = %DeleteChallengeBtn
@onready var save_btn: Button = %SaveBtn
@onready var reload_btn: Button = %ReloadBtn
@onready var back_btn: Button = %BackBtn
@onready var status_label: Label = %StatusLabel

# 基本情報
@onready var id_edit: LineEdit = %IdLineEdit
@onready var order_spin_box: SpinBox = %OrderSpinBox
@onready var name_edit: LineEdit = %NameLineEdit
@onready var icon_edit: LineEdit = %IconLineEdit
@onready var select_icon_btn: Button = %SelectIconBtn
@onready var clear_icon_btn: Button = %ClearIconBtn
@onready var icon_file_dialog: FileDialog = %IconFileDialog
@onready var desc_edit: TextEdit = %DescTextEdit
@onready var reward_template_edit: LineEdit = get_node_or_null("%RewardTemplateLineEdit") as LineEdit
@onready var reward_type_opt: OptionButton = get_node_or_null("%RewardTypeOption") as OptionButton

# レベル一覧管理コンテナ
@onready var sec2_title: Label = %Sec2Title
@onready var add_level_btn: Button = %AddLevelBtn
@onready var levels_container: VBoxContainer = %LevelsContainer

# プレビュー
@onready var preview_icon: Label = %PreviewIcon
@onready var preview_icon_texture: TextureRect = %PreviewIconTexture
@onready var preview_name: Label = %PreviewName
@onready var preview_detail_title: Label = %PreviewDetailTitle
@onready var preview_detail_penalty: Label = %PreviewDetailPenalty
@onready var preview_detail_target: Label = %PreviewDetailTarget
@onready var preview_detail_reward: Label = %PreviewDetailReward

var _challenges_list: Array[Dictionary] = [] # 順序を保持する配列: [ { "id": "c1", ... }, ... ]
var _challenges_data: Dictionary = {} # { "c1": { "id": "c1", "name": ..., "levels": [...] } }
var _selected_id: String = ""
var _updating_form: bool = false


func _format_reward_desc(template: String, val: float) -> String:
	if GameData:
		return GameData.format_challenge_reward_desc(template, val)
	if template.is_empty():
		return ""
	var val_str: String
	if is_equal_approx(val, round(val)):
		val_str = str(int(round(val)))
	else:
		val_str = str(val)
	if "{val}" in template:
		return template.replace("{val}", val_str)
	elif "%s" in template:
		return template.replace("%s", val_str)
	elif "%d" in template:
		return template % int(round(val))
	elif "%.1f" in template or "%.2f" in template or "%f" in template:
		return template % val
	return template + " " + val_str


func _ready() -> void:
	if challenge_list:
		challenge_list.fixed_icon_size = Vector2i(24, 24)
	if reward_type_opt:
		reward_type_opt.clear()
		reward_type_opt.add_item("➕ 加算系 (+b)", 0)
		reward_type_opt.set_item_metadata(0, "add")
		reward_type_opt.add_item("✖️ 乗算系 (xb)", 1)
		reward_type_opt.set_item_metadata(1, "mult")
		reward_type_opt.item_selected.connect(_on_reward_type_selected)
	_connect_signals()
	load_data()


func _connect_signals() -> void:
	if challenge_list: challenge_list.item_selected.connect(_on_challenge_selected)
	if move_up_btn: move_up_btn.pressed.connect(_on_move_up_pressed)
	if move_down_btn: move_down_btn.pressed.connect(_on_move_down_pressed)
	if add_challenge_btn: add_challenge_btn.pressed.connect(_on_add_challenge_pressed)
	if duplicate_challenge_btn: duplicate_challenge_btn.pressed.connect(_on_duplicate_challenge_pressed)
	if delete_challenge_btn: delete_challenge_btn.pressed.connect(_on_delete_challenge_pressed)
	if save_btn: save_btn.pressed.connect(_on_save_pressed)
	if reload_btn: reload_btn.pressed.connect(load_data)
	if back_btn: back_btn.pressed.connect(_on_back_pressed)

	if order_spin_box: order_spin_box.value_changed.connect(_on_order_spin_changed)
	if id_edit: id_edit.text_changed.connect(_on_general_form_changed)
	if name_edit: name_edit.text_changed.connect(_on_general_form_changed)
	if icon_edit: icon_edit.text_changed.connect(_on_general_form_changed)
	if select_icon_btn: select_icon_btn.pressed.connect(_on_select_icon_pressed)
	if clear_icon_btn: clear_icon_btn.pressed.connect(_on_clear_icon_pressed)
	if icon_file_dialog: icon_file_dialog.file_selected.connect(_on_icon_file_selected)
	if desc_edit: desc_edit.text_changed.connect(_on_general_form_changed)
	if reward_template_edit: reward_template_edit.text_changed.connect(_on_general_form_changed)

	if add_level_btn: add_level_btn.pressed.connect(_on_add_level_pressed)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed or event.alt_pressed:
			if event.keycode == KEY_UP:
				_on_move_up_pressed()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				_on_move_down_pressed()
				get_viewport().set_input_as_handled()


func load_data() -> void:
	var path := SAVE_PATH
	if not FileAccess.file_exists(path):
		# フォールバック: GameDataの定義から読み込み
		if GameData and not GameData.CHALLENGE_DEFS.is_empty():
			_challenges_data = GameData.CHALLENGE_DEFS.duplicate(true)
			_ensure_all_levels_structure()
			_build_list_from_data()
			status_label.text = "GameDataからデータを初期化しました。"
			_refresh_challenge_list()
			return
		status_label.text = "ファイルが存在しません: %s" % path
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		status_label.text = "ファイルの読み込みに失敗しました。"
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		status_label.text = "JSONパースエラー: " + json.get_error_message()
		return

	var data: Variant = json.get_data()
	if data is Dictionary and data.has("challenges"):
		_challenges_data = data["challenges"].duplicate(true)
		_ensure_all_levels_structure()
		_build_list_from_data()
		status_label.text = "データを読み込みました (%d件)" % _challenges_list.size()
		_refresh_challenge_list()
	else:
		status_label.text = "不正なJSON形式です。"


func _build_list_from_data() -> void:
	_challenges_list.clear()
	var keys := _challenges_data.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	for k in keys:
		var item: Dictionary = _challenges_data[k]
		_challenges_list.append(item)
	_sync_data_from_list()


func _sync_data_from_list() -> void:
	_challenges_data.clear()
	for i in range(_challenges_list.size()):
		var ch: Dictionary = _challenges_list[i]
		var ch_id: String = ch.get("id", "c%d" % (i + 1))
		_challenges_data[ch_id] = ch


func _renumber_challenges(new_selected_index: int = -1) -> void:
	for i in range(_challenges_list.size()):
		var ch: Dictionary = _challenges_list[i]
		var new_id: String = "c%d" % (i + 1)
		ch["id"] = new_id

	if new_selected_index >= 0 and new_selected_index < _challenges_list.size():
		_selected_id = _challenges_list[new_selected_index].get("id", "")
	elif not _challenges_list.is_empty():
		_selected_id = _challenges_list[0].get("id", "")
	else:
		_selected_id = ""

	_sync_data_from_list()


func _get_selected_index() -> int:
	if _selected_id.is_empty():
		return -1
	for i in range(_challenges_list.size()):
		if _challenges_list[i].get("id", "") == _selected_id:
			return i
	return -1


func _on_move_up_pressed() -> void:
	var idx := _get_selected_index()
	if idx <= 0:
		return
	var item: Dictionary = _challenges_list[idx]
	_challenges_list[idx] = _challenges_list[idx - 1]
	_challenges_list[idx - 1] = item
	_renumber_challenges(idx - 1)
	status_label.text = "『%s』を #%d に移動しました (ID: %s)" % [item.get("name", ""), idx, _selected_id]
	_refresh_challenge_list()


func _on_move_down_pressed() -> void:
	var idx := _get_selected_index()
	if idx < 0 or idx >= _challenges_list.size() - 1:
		return
	var item: Dictionary = _challenges_list[idx]
	_challenges_list[idx] = _challenges_list[idx + 1]
	_challenges_list[idx + 1] = item
	_renumber_challenges(idx + 1)
	status_label.text = "『%s』を #%d に移動しました (ID: %s)" % [item.get("name", ""), idx + 2, _selected_id]
	_refresh_challenge_list()


func _on_order_spin_changed(new_val: float) -> void:
	if _updating_form:
		return
	var target_no := int(new_val)
	var target_idx := target_no - 1
	var cur_idx := _get_selected_index()
	if cur_idx == -1 or cur_idx == target_idx:
		return
	target_idx = clampi(target_idx, 0, _challenges_list.size() - 1)
	var item: Dictionary = _challenges_list[cur_idx]
	_challenges_list.remove_at(cur_idx)
	_challenges_list.insert(target_idx, item)
	_renumber_challenges(target_idx)
	status_label.text = "『%s』を #%d に移動しました (ID: %s)" % [item.get("name", ""), target_idx + 1, _selected_id]
	_refresh_challenge_list()


func _ensure_all_levels_structure() -> void:
	for ch_id in _challenges_data:
		var ch: Dictionary = _challenges_data[ch_id]
		if not ch.has("levels") or not ch["levels"] is Array or ch["levels"].is_empty():
			var default_lv: Dictionary = {
				"level": 1,
				"duration": float(ch.get("duration", 30.0)),
				"target_type": str(ch.get("target_type", "gold")),
				"target_val": float(ch.get("target_val", 2500.0)),
				"reward_desc": str(ch.get("reward_desc", "")),
				"reward_val": float(ch.get("reward_val", 0.0)),
				"memo": "初期レベル"
			}
			ch["levels"] = [default_lv]


func _load_icon_texture(path_or_str: String) -> Texture2D:
	var s := path_or_str.strip_edges()
	if s.is_empty():
		return null
	if (s.begins_with("res://") or s.begins_with("user://")) and ResourceLoader.exists(s):
		var res := load(s)
		if res is Texture2D:
			return res
	return null


func _refresh_challenge_list() -> void:
	challenge_list.clear()
	var target_index := -1
	for i in range(_challenges_list.size()):
		var item: Dictionary = _challenges_list[i]
		var key: String = item.get("id", "c%d" % (i + 1))
		var icon_str: String = item.get("icon", "⚔️")
		var name_str: String = item.get("name", key)
		var lv_count: int = item.get("levels", []).size()
		var num_str := str(i + 1)
		var tex := _load_icon_texture(icon_str)
		if tex:
			var label_str := "#%s: %s (全%d段階)" % [num_str, name_str, lv_count]
			challenge_list.add_item(label_str, tex)
		else:
			var label_str := "%s #%s: %s (全%d段階)" % [icon_str, num_str, name_str, lv_count]
			challenge_list.add_item(label_str)
		challenge_list.set_item_metadata(i, key)
		if key == _selected_id:
			target_index = i

	if target_index != -1:
		challenge_list.select(target_index)
		_fill_form(_selected_id)
	elif _challenges_list.size() > 0:
		challenge_list.select(0)
		_selected_id = _challenges_list[0].get("id", "c1")
		_fill_form(_selected_id)
	else:
		_selected_id = ""
		_clear_form()


func _fill_form(ch_id: String) -> void:
	if not _challenges_data.has(ch_id):
		return

	_updating_form = true
	var item: Dictionary = _challenges_data[ch_id]
	id_edit.text = ch_id
	name_edit.text = item.get("name", "")
	icon_edit.text = item.get("icon", "")
	desc_edit.text = item.get("desc", "")
	if reward_template_edit:
		reward_template_edit.text = item.get("reward_template", "")
	if reward_type_opt:
		var r_type: String = item.get("reward_type", "add")
		reward_type_opt.select(1 if r_type == "mult" else 0)

	var cur_idx := _get_selected_index()
	if order_spin_box:
		order_spin_box.max_value = maxi(1, _challenges_list.size())
		order_spin_box.value = cur_idx + 1

	if move_up_btn:
		move_up_btn.disabled = (cur_idx <= 0)
	if move_down_btn:
		move_down_btn.disabled = (cur_idx < 0 or cur_idx >= _challenges_list.size() - 1)

	_refresh_levels_ui()
	_updating_form = false
	_update_preview()


func _refresh_levels_ui() -> void:
	if not levels_container or _selected_id.is_empty() or not _challenges_data.has(_selected_id):
		return

	# 既存のレベルカードをクリア
	for child in levels_container.get_children():
		child.queue_free()

	var ch: Dictionary = _challenges_data[_selected_id]
	var levels: Array = ch.get("levels", [])
	if levels.is_empty():
		levels.append({
			"level": 1,
			"duration": 30.0,
			"target_type": "gold",
			"target_val": 2500.0,
			"reward_desc": "恒久効果: 基本ゴールド獲得量 +15%",
			"reward_val": 15.0,
			"memo": "初期レベル"
		})
		ch["levels"] = levels

	if sec2_title:
		sec2_title.text = "🏆 各レベルごとの内容設定 (全%d段階)" % levels.size()

	# 各レベルごとの編集ブロックを生成
	for i in levels.size():
		var lv: Dictionary = levels[i]
		var lv_idx := i
		var lv_num := i + 1
		lv["level"] = lv_num

		var panel := PanelContainer.new()
		var p_style := StyleBoxFlat.new()
		p_style.bg_color = Color(0.12, 0.13, 0.20, 1.0)
		p_style.border_width_left = 2
		p_style.border_width_top = 1
		p_style.border_width_right = 1
		p_style.border_width_bottom = 1
		p_style.border_color = Color(0.28, 0.35, 0.55, 0.8)
		p_style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", p_style)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		panel.add_child(margin)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 8)
		margin.add_child(card_vbox)

		# 1. レベルカードヘッダー
		var head_hbox := HBoxContainer.new()
		head_hbox.add_theme_constant_override("separation", 8)
		card_vbox.add_child(head_hbox)

		var lv_title_lbl := Label.new()
		lv_title_lbl.text = "🏆 Level %d" % lv_num
		lv_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
		lv_title_lbl.add_theme_font_size_override("font_size", 16)
		head_hbox.add_child(lv_title_lbl)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head_hbox.add_child(spacer)

		# 削除ボタン（最低1レベルは残す）
		if levels.size() > 1:
			var del_btn := Button.new()
			del_btn.text = "🗑️ Lv.%d を削除" % lv_num
			del_btn.custom_minimum_size = Vector2(110, 28)
			del_btn.pressed.connect(func(): _on_delete_specific_level(lv_idx))
			head_hbox.add_child(del_btn)

		# 2. 制限時間 & 目標ノルマ行
		var quota_hbox := HBoxContainer.new()
		quota_hbox.add_theme_constant_override("separation", 12)
		card_vbox.add_child(quota_hbox)

		# 制限時間
		var dur_lbl := Label.new()
		dur_lbl.text = "制限時間:"
		quota_hbox.add_child(dur_lbl)

		var dur_spin := SpinBox.new()
		dur_spin.min_value = 1.0
		dur_spin.max_value = 3600.0
		dur_spin.step = 1.0
		dur_spin.suffix = "秒"
		dur_spin.value = float(lv.get("duration", 60.0))
		dur_spin.custom_minimum_size = Vector2(100, 0)
		dur_spin.value_changed.connect(func(val: float):
			lv["duration"] = val
			if lv_idx == 0: ch["duration"] = val
			_update_preview()
		)
		quota_hbox.add_child(dur_spin)

		# 目標種別
		var type_lbl := Label.new()
		type_lbl.text = "目標種別:"
		quota_hbox.add_child(type_lbl)

		var type_opt := OptionButton.new()
		type_opt.add_item("🪙 ゴールド (gold)", 0)
		type_opt.set_item_metadata(0, "gold")
		type_opt.add_item("💎 トークン (token)", 1)
		type_opt.set_item_metadata(1, "token")
		var cur_type: String = str(lv.get("target_type", "gold"))
		type_opt.select(1 if cur_type == "token" else 0)
		type_opt.item_selected.connect(func(idx: int):
			var selected_type: String = type_opt.get_item_metadata(idx)
			lv["target_type"] = selected_type
			if lv_idx == 0: ch["target_type"] = selected_type
			_update_preview()
		)
		quota_hbox.add_child(type_opt)

		# 目標数値
		var val_lbl := Label.new()
		val_lbl.text = "目標値:"
		quota_hbox.add_child(val_lbl)

		var val_edit := LineEdit.new()
		val_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_edit.placeholder_text = "例: 2500, 50000, 1e8 ..."
		var cur_val: float = float(lv.get("target_val", 2500.0))
		val_edit.text = str(cur_val)

		var prev_lbl := Label.new()
		prev_lbl.custom_minimum_size = Vector2(120, 0)
		prev_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9, 1.0))
		prev_lbl.text = "( %s )" % _format_val(cur_val)

		val_edit.text_changed.connect(func(new_txt: String):
			var num_val := _parse_val(new_txt)
			lv["target_val"] = num_val
			if lv_idx == 0: ch["target_val"] = num_val
			prev_lbl.text = "( %s )" % _format_val(num_val)
			_update_preview()
		)
		quota_hbox.add_child(val_edit)
		quota_hbox.add_child(prev_lbl)

		# 3. クリア報酬設定（累積ボーナス値入力 & 動的生成プレビュー）
		var reward_head_hbox := HBoxContainer.new()
		reward_head_hbox.add_theme_constant_override("separation", 8)
		card_vbox.add_child(reward_head_hbox)

		var reward_lbl := Label.new()
		reward_lbl.text = "🎁 クリア報酬 (Lv.%d 達成時):" % lv_num
		reward_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55, 1.0))
		reward_head_hbox.add_child(reward_lbl)

		var val_head_lbl := Label.new()
		val_head_lbl.text = "累積ボーナス値:"
		val_head_lbl.add_theme_color_override("font_color", Color(0.55, 0.9, 0.65, 1.0))
		reward_head_hbox.add_child(val_head_lbl)

		var reward_val_spin := SpinBox.new()
		reward_val_spin.min_value = 0.0
		reward_val_spin.max_value = 999999.0
		reward_val_spin.step = 0.01
		reward_val_spin.value = float(lv.get("reward_val", 0.0))
		reward_val_spin.custom_minimum_size = Vector2(95, 0)
		reward_head_hbox.add_child(reward_val_spin)

		var reward_preview_lbl := Label.new()
		reward_preview_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reward_preview_lbl.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8, 1.0))

		var cur_tmpl: String = ch.get("reward_template", "")
		var cur_r_val: float = float(lv.get("reward_val", 0.0))
		var initial_desc := _format_reward_desc(cur_tmpl, cur_r_val)
		if initial_desc.is_empty():
			initial_desc = str(lv.get("reward_desc", ""))
		lv["reward_desc"] = initial_desc
		reward_preview_lbl.text = "➜ " + initial_desc
		reward_head_hbox.add_child(reward_preview_lbl)

		reward_val_spin.value_changed.connect(func(new_val: float):
			lv["reward_val"] = new_val
			var tmpl: String = ch.get("reward_template", "")
			var desc: String = _format_reward_desc(tmpl, new_val)
			lv["reward_desc"] = desc
			if lv_idx == 0:
				ch["reward_val"] = new_val
				ch["reward_desc"] = desc
			reward_preview_lbl.text = "➜ " + desc
			_update_preview()
		)

		# 4. メモ行
		var memo_hbox := HBoxContainer.new()
		memo_hbox.add_theme_constant_override("separation", 8)
		card_vbox.add_child(memo_hbox)

		var memo_lbl := Label.new()
		memo_lbl.text = "📝 メモ:"
		memo_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75, 1.0))
		memo_hbox.add_child(memo_lbl)

		var memo_edit := LineEdit.new()
		memo_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		memo_edit.placeholder_text = "仕様やバランス等の備考"
		memo_edit.text = str(lv.get("memo", ""))
		memo_edit.text_changed.connect(func(new_txt: String):
			lv["memo"] = new_txt.strip_edges()
		)
		memo_hbox.add_child(memo_edit)

		levels_container.add_child(panel)


func _clear_form() -> void:
	_updating_form = true
	id_edit.text = ""
	name_edit.text = ""
	icon_edit.text = ""
	desc_edit.text = ""
	if reward_template_edit:
		reward_template_edit.text = ""
	if reward_type_opt:
		reward_type_opt.select(0)
	for child in levels_container.get_children():
		child.queue_free()
	_updating_form = false
	_update_preview()


func _on_challenge_selected(index: int) -> void:
	var key: String = challenge_list.get_item_metadata(index)
	_selected_id = key
	_fill_form(key)


func _on_reward_type_selected(idx: int) -> void:
	if _updating_form or _selected_id.is_empty():
		return
	var item_idx := _get_selected_index()
	if item_idx == -1:
		return
	var ch: Dictionary = _challenges_list[item_idx]
	var sel_type: String = reward_type_opt.get_item_metadata(idx)
	ch["reward_type"] = sel_type
	_challenges_list[item_idx] = ch
	_challenges_data[_selected_id] = ch
	status_label.text = "ボーナス計算方式を更新: %s (#%d %s)" % ["加算系 (+b)" if sel_type == "add" else "乗算系 (xb)", item_idx + 1, _selected_id]


func _on_general_form_changed(_text: String = "") -> void:
	if _updating_form or _selected_id.is_empty():
		return
	var idx := _get_selected_index()
	if idx == -1:
		return

	var ch: Dictionary = _challenges_list[idx]
	ch["name"] = name_edit.text.strip_edges()
	ch["icon"] = icon_edit.text.strip_edges()
	ch["desc"] = desc_edit.text.strip_edges()
	if reward_template_edit:
		var tmpl := reward_template_edit.text.strip_edges()
		ch["reward_template"] = tmpl
		var levels: Array = ch.get("levels", [])
		for lv in levels:
			if lv is Dictionary:
				lv["reward_desc"] = _format_reward_desc(tmpl, float(lv.get("reward_val", 0.0)))
		if levels.size() > 0:
			ch["reward_desc"] = levels[0].get("reward_desc", "")

	if reward_type_opt:
		var sel_idx := reward_type_opt.selected
		if sel_idx >= 0:
			ch["reward_type"] = reward_type_opt.get_item_metadata(sel_idx)

	_challenges_list[idx] = ch
	_challenges_data[_selected_id] = ch

	status_label.text = "チャレンジ情報を更新 (#%d %s)" % [idx + 1, _selected_id]
	_update_list_item_text()
	_update_preview()
	if reward_template_edit and reward_template_edit.has_focus():
		_refresh_levels_ui()


func _on_add_challenge_pressed() -> void:
	var next_num := _challenges_list.size() + 1
	var new_id := "c%d" % next_num
	var default_template := "ボーナス獲得量 +{val}%"
	var default_val := 10.0 * next_num
	var new_ch: Dictionary = {
		"id": new_id,
		"name": "新規チャレンジ %d" % next_num,
		"icon": "⚔️",
		"desc": "チャレンジの制限ルールを入力してください",
		"reward_template": default_template,
		"reward_type": "add",
		"levels": [
			{
				"level": 1,
				"duration": 60.0,
				"target_type": "gold",
				"target_val": 5000.0 * next_num,
				"reward_val": default_val,
				"reward_desc": _format_reward_desc(default_template, default_val),
				"memo": "初期レベル"
			}
		]
	}
	_challenges_list.append(new_ch)
	_renumber_challenges(_challenges_list.size() - 1)
	status_label.text = "新規チャレンジを追加しました: #%d (%s)" % [next_num, new_id]
	_refresh_challenge_list()


func _on_duplicate_challenge_pressed() -> void:
	var idx := _get_selected_index()
	if idx == -1:
		return
	var src: Dictionary = _challenges_list[idx].duplicate(true)
	src["name"] = "%s (コピー)" % src.get("name", "")
	_challenges_list.insert(idx + 1, src)
	_renumber_challenges(idx + 1)
	status_label.text = "チャレンジを複製しました: %s" % _selected_id
	_refresh_challenge_list()


func _on_delete_challenge_pressed() -> void:
	var idx := _get_selected_index()
	if idx == -1:
		status_label.text = "削除するチャレンジが選択されていません。"
		return
	var deleted_name: String = _challenges_list[idx].get("name", _selected_id)
	_challenges_list.remove_at(idx)
	var new_select_idx := clampi(idx, 0, _challenges_list.size() - 1)
	_renumber_challenges(new_select_idx)
	status_label.text = "チャレンジ '%s' を削除し、ナンバリングを再整理しました。" % deleted_name
	_refresh_challenge_list()


func _on_add_level_pressed() -> void:
	if _selected_id.is_empty() or not _challenges_data.has(_selected_id):
		return
	var ch: Dictionary = _challenges_data[_selected_id]
	var levels: Array = ch.get("levels", [])
	var last_lv: Dictionary = levels.back() if not levels.is_empty() else {}
	var next_num := levels.size() + 1
	var last_val: float = float(last_lv.get("target_val", 2500.0))
	var last_dur: float = float(last_lv.get("duration", 60.0))
	var last_type: String = str(last_lv.get("target_type", "gold"))
	var last_reward_val: float = float(last_lv.get("reward_val", 10.0))
	var next_reward_val: float = last_reward_val + 5.0
	var tmpl: String = ch.get("reward_template", "")

	var new_lv := {
		"level": next_num,
		"duration": last_dur,
		"target_type": last_type,
		"target_val": last_val * 2.0,
		"reward_val": next_reward_val,
		"reward_desc": _format_reward_desc(tmpl, next_reward_val),
		"memo": ""
	}
	levels.append(new_lv)

	_refresh_levels_ui()
	status_label.text = "Lv.%d を追加しました (%s)" % [next_num, _selected_id]
	_update_list_item_text()
	_update_preview()


func _on_delete_specific_level(idx: int) -> void:
	if _selected_id.is_empty() or not _challenges_data.has(_selected_id):
		return
	var ch: Dictionary = _challenges_data[_selected_id]
	var levels: Array = ch.get("levels", [])
	if levels.size() <= 1:
		status_label.text = "⚠️ 最低1つのレベルが必要です。"
		return

	if idx >= 0 and idx < levels.size():
		levels.remove_at(idx)
		for i in levels.size():
			levels[i]["level"] = i + 1

		# トップレベル互換更新
		if levels.size() > 0:
			var lv1: Dictionary = levels[0]
			ch["duration"] = lv1.get("duration", 60.0)
			ch["target_type"] = lv1.get("target_type", "gold")
			ch["target_val"] = lv1.get("target_val", 1000.0)
			ch["reward_val"] = lv1.get("reward_val", 0.0)
			ch["reward_desc"] = lv1.get("reward_desc", "")

		_refresh_levels_ui()
		status_label.text = "レベルを削除しました (%s)" % _selected_id
		_update_list_item_text()
		_update_preview()


func _on_save_pressed() -> void:
	_sync_data_from_list()
	var ordered_challenges: Dictionary = {}
	for ch in _challenges_list:
		var ch_id: String = ch.get("id", "")
		var tmpl: String = ch.get("reward_template", "")
		var levels: Array = ch.get("levels", [])
		for lv in levels:
			if lv is Dictionary:
				var r_val: float = float(lv.get("reward_val", 0.0))
				lv["reward_desc"] = _format_reward_desc(tmpl, r_val)
		if levels.size() > 0 and levels[0] is Dictionary:
			var lv1: Dictionary = levels[0]
			ch["duration"] = lv1.get("duration", 60.0)
			ch["target_type"] = lv1.get("target_type", "gold")
			ch["target_val"] = lv1.get("target_val", 1000.0)
			ch["reward_val"] = lv1.get("reward_val", 0.0)
			ch["reward_desc"] = lv1.get("reward_desc", "")
		ch["reward_type"] = ch.get("reward_type", "add")
		ordered_challenges[ch_id] = ch

	var data := {"challenges": ordered_challenges}
	var json_string := JSON.stringify(data, "\t")

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		status_label.text = "保存用にファイルを開けませんでした: %s" % SAVE_PATH
		return

	file.store_string(json_string)
	file.close()

	# GameData singleton に即時反映
	if GameData:
		GameData.CHALLENGE_DEFS = ordered_challenges.duplicate(true)
		GameData.challenge_state_changed.emit()

	status_label.text = "💾 %s に保存し、ゲームデータに反映しました！(全%d件)" % [SAVE_PATH, _challenges_list.size()]


func _on_select_icon_pressed() -> void:
	if not icon_file_dialog:
		return
	var cur_path: String = icon_edit.text.strip_edges() if icon_edit else ""
	if cur_path.begins_with("res://") and ResourceLoader.exists(cur_path):
		icon_file_dialog.current_path = cur_path
	else:
		icon_file_dialog.current_dir = "res://"
	icon_file_dialog.popup_centered(Vector2i(700, 500))


func _on_clear_icon_pressed() -> void:
	if icon_edit:
		icon_edit.text = ""
		_on_general_form_changed("")


func _on_icon_file_selected(path: String) -> void:
	if icon_edit:
		icon_edit.text = path
		_on_general_form_changed(path)


func _on_back_pressed() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		visible = false


func _update_list_item_text() -> void:
	var selected_items := challenge_list.get_selected_items()
	var idx := _get_selected_index()
	if selected_items.size() > 0 and idx != -1:
		var ch: Dictionary = _challenges_list[idx]
		var icon_str: String = ch.get("icon", "⚔️")
		var name_str: String = ch.get("name", _selected_id)
		var lv_count: int = ch.get("levels", []).size()
		var list_idx: int = selected_items[0]
		var num_str := str(idx + 1)
		var tex := _load_icon_texture(icon_str)
		if tex:
			var label_str := "#%s: %s (全%d段階)" % [num_str, name_str, lv_count]
			challenge_list.set_item_text(list_idx, label_str)
			challenge_list.set_item_icon(list_idx, tex)
		else:
			var label_str := "%s #%s: %s (全%d段階)" % [icon_str, num_str, name_str, lv_count]
			challenge_list.set_item_text(list_idx, label_str)
			challenge_list.set_item_icon(list_idx, null)


func _update_preview() -> void:
	if _selected_id.is_empty() or not _challenges_data.has(_selected_id):
		if preview_name: preview_name.text = "選択なし"
		if preview_icon:
			preview_icon.text = "⚔️"
			preview_icon.visible = true
		if preview_icon_texture:
			preview_icon_texture.visible = false
		if preview_detail_title: preview_detail_title.text = "チャレンジ名"
		if preview_detail_penalty: preview_detail_penalty.text = "制限内容"
		if preview_detail_target: preview_detail_target.text = "達成ノルマ"
		if preview_detail_reward: preview_detail_reward.text = "報酬内容"
		return

	var ch: Dictionary = _challenges_data[_selected_id]
	var levels: Array = ch.get("levels", [])
	var icon_str: String = ch.get("icon", "⚔️")
	var name_str: String = ch.get("name", "")
	var desc_str: String = ch.get("desc", "")
	var cur_idx := _get_selected_index()
	var num_str := str(cur_idx + 1) if cur_idx >= 0 else _selected_id.replace("c", "")

	var tex := _load_icon_texture(icon_str)
	if tex:
		if preview_icon_texture:
			preview_icon_texture.texture = tex
			preview_icon_texture.visible = true
		if preview_icon:
			preview_icon.visible = false
	else:
		if preview_icon_texture:
			preview_icon_texture.visible = false
		if preview_icon:
			preview_icon.text = icon_str
			preview_icon.visible = true

	if preview_name: preview_name.text = "#%s: %s" % [num_str, name_str]

	var max_lvl: int = levels.size()
	if preview_detail_title:
		if max_lvl > 1:
			preview_detail_title.text = "#%s: %s (全%d段階)" % [num_str, name_str, max_lvl]
		else:
			preview_detail_title.text = "#%s: %s" % [num_str, name_str]

	if preview_detail_penalty: preview_detail_penalty.text = desc_str

	if levels.size() > 0:
		var lv1: Dictionary = levels[0]
		var target_currency := "🪙" if lv1.get("target_type", "gold") == "gold" else "💎"
		var target_str := _format_val(float(lv1.get("target_val", 0.0)))
		var duration_str := "%d秒" % int(lv1.get("duration", 30.0))
		if preview_detail_target:
			preview_detail_target.text = "Lv.1ノルマ: 制限時間 %s 以内に %s %s を獲得" % [duration_str, target_currency, target_str]
	else:
		if preview_detail_target: preview_detail_target.text = "ノルマ未設定"

	if preview_detail_reward:
		var reward_lines: Array[String] = []
		var tmpl: String = ch.get("reward_template", "")
		for i in levels.size():
			var lv_item: Dictionary = levels[i]
			var r_val: float = float(lv_item.get("reward_val", 0.0))
			var r_text: String = _format_reward_desc(tmpl, r_val)
			if r_text.is_empty():
				r_text = lv_item.get("reward_desc", "")
			reward_lines.append("• Lv.%d: %s" % [i + 1, r_text])
		preview_detail_reward.text = "【クリア時報酬一覧】\n" + "\n".join(reward_lines)


func _parse_val(txt: String) -> float:
	var clean := txt.strip_edges().replace(",", "")
	if clean.is_valid_float():
		return float(clean)
	return 0.0


func _format_val(val: float) -> String:
	if GameData:
		return GameData.format_num(val)
	return "%.0f" % val
