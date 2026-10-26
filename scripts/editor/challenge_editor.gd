extends Control

const SAVE_PATH = "res://data/challenges.json"

# UI ノード参照
@onready var challenge_list: ItemList = %ChallengeList
@onready var add_challenge_btn: Button = %AddChallengeBtn
@onready var duplicate_challenge_btn: Button = %DuplicateChallengeBtn
@onready var delete_challenge_btn: Button = %DeleteChallengeBtn
@onready var save_btn: Button = %SaveBtn
@onready var reload_btn: Button = %ReloadBtn
@onready var back_btn: Button = %BackBtn
@onready var status_label: Label = %StatusLabel

# 基本情報
@onready var id_edit: LineEdit = %IdLineEdit
@onready var name_edit: LineEdit = %NameLineEdit
@onready var icon_edit: LineEdit = %IconLineEdit
@onready var desc_edit: TextEdit = %DescTextEdit

# レベル一覧管理コンテナ
@onready var sec2_title: Label = %Sec2Title
@onready var add_level_btn: Button = %AddLevelBtn
@onready var levels_container: VBoxContainer = %LevelsContainer

# プレビュー
@onready var preview_icon: Label = %PreviewIcon
@onready var preview_name: Label = %PreviewName
@onready var preview_detail_title: Label = %PreviewDetailTitle
@onready var preview_detail_penalty: Label = %PreviewDetailPenalty
@onready var preview_detail_target: Label = %PreviewDetailTarget
@onready var preview_detail_reward: Label = %PreviewDetailReward

var _challenges_data: Dictionary = {} # { "c1": { "id": "c1", "name": ..., "levels": [...] } }
var _selected_id: String = ""
var _updating_form: bool = false


func _ready() -> void:
	_connect_signals()
	load_data()


func _connect_signals() -> void:
	if challenge_list: challenge_list.item_selected.connect(_on_challenge_selected)
	if add_challenge_btn: add_challenge_btn.pressed.connect(_on_add_challenge_pressed)
	if duplicate_challenge_btn: duplicate_challenge_btn.pressed.connect(_on_duplicate_challenge_pressed)
	if delete_challenge_btn: delete_challenge_btn.pressed.connect(_on_delete_challenge_pressed)
	if save_btn: save_btn.pressed.connect(_on_save_pressed)
	if reload_btn: reload_btn.pressed.connect(load_data)
	if back_btn: back_btn.pressed.connect(_on_back_pressed)

	if id_edit: id_edit.text_changed.connect(_on_general_form_changed)
	if name_edit: name_edit.text_changed.connect(_on_general_form_changed)
	if icon_edit: icon_edit.text_changed.connect(_on_general_form_changed)
	if desc_edit: desc_edit.text_changed.connect(_on_general_form_changed)

	if add_level_btn: add_level_btn.pressed.connect(_on_add_level_pressed)


func load_data() -> void:
	var path := SAVE_PATH
	if not FileAccess.file_exists(path):
		# フォールバック: GameDataの定義から読み込み
		if GameData and not GameData.CHALLENGE_DEFS.is_empty():
			_challenges_data = GameData.CHALLENGE_DEFS.duplicate(true)
			_ensure_all_levels_structure()
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
		status_label.text = "データを読み込みました (%d件)" % _challenges_data.size()
		_refresh_challenge_list()
	else:
		status_label.text = "不正なJSON形式です。"


func _ensure_all_levels_structure() -> void:
	for ch_id in _challenges_data:
		var ch: Dictionary = _challenges_data[ch_id]
		if not ch.has("levels") or not ch["levels"] is Array or ch["levels"].is_empty():
			var default_lv: Dictionary = {
				"level": 1,
				"duration": float(ch.get("duration", 60.0)),
				"target_type": str(ch.get("target_type", "gold")),
				"target_val": float(ch.get("target_val", 2500.0)),
				"reward_desc": str(ch.get("reward_desc", "")),
				"memo": "初期レベル"
			}
			ch["levels"] = [default_lv]


func _refresh_challenge_list() -> void:
	challenge_list.clear()
	var keys := _challenges_data.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)

	var target_index := -1
	for i in keys.size():
		var key = keys[i]
		var item: Dictionary = _challenges_data[key]
		var icon_str: String = item.get("icon", "⚔️")
		var name_str: String = item.get("name", key)
		var lv_count: int = item.get("levels", []).size()
		var label_str := "%s %s: %s (全%d段階)" % [icon_str, key, name_str, lv_count]
		challenge_list.add_item(label_str)
		challenge_list.set_item_metadata(i, key)
		if key == _selected_id:
			target_index = i

	if target_index != -1:
		challenge_list.select(target_index)
		_fill_form(_selected_id)
	elif keys.size() > 0:
		challenge_list.select(0)
		_selected_id = keys[0]
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
			"duration": 60.0,
			"target_type": "gold",
			"target_val": 2500.0,
			"reward_desc": "恒久効果: 基本ゴールド獲得量 +15%",
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

		# 3. クリア報酬説明テキスト行（各レベルごとに直接編集可能）
		var reward_vbox := VBoxContainer.new()
		reward_vbox.add_theme_constant_override("separation", 4)
		card_vbox.add_child(reward_vbox)

		var reward_head_hbox := HBoxContainer.new()
		reward_vbox.add_child(reward_head_hbox)

		var reward_lbl := Label.new()
		reward_lbl.text = "🎁 クリア報酬説明テキスト (Lv.%d 達成時):" % lv_num
		reward_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55, 1.0))
		reward_head_hbox.add_child(reward_lbl)

		var reward_edit := LineEdit.new()
		reward_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reward_edit.placeholder_text = "例: 恒久効果: 基本ゴールド獲得量 +%d%%" % (15 * lv_num)
		reward_edit.text = str(lv.get("reward_desc", ""))
		reward_edit.text_changed.connect(func(new_txt: String):
			lv["reward_desc"] = new_txt.strip_edges()
			if lv_idx == 0: ch["reward_desc"] = lv["reward_desc"]
			_update_preview()
		)
		reward_vbox.add_child(reward_edit)

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
	for child in levels_container.get_children():
		child.queue_free()
	_updating_form = false
	_update_preview()


func _on_challenge_selected(index: int) -> void:
	var key: String = challenge_list.get_item_metadata(index)
	_selected_id = key
	_fill_form(key)


func _on_general_form_changed(_text: String = "") -> void:
	if _updating_form or _selected_id.is_empty() or not _challenges_data.has(_selected_id):
		return

	var new_id := id_edit.text.strip_edges()
	if new_id.is_empty():
		return

	var ch: Dictionary = _challenges_data[_selected_id]
	if new_id != _selected_id:
		if _challenges_data.has(new_id):
			status_label.text = "⚠️ ID '%s' はすでに存在します。" % new_id
			return
		_challenges_data.erase(_selected_id)
		_selected_id = new_id
		ch["id"] = new_id

	ch["name"] = name_edit.text.strip_edges()
	ch["icon"] = icon_edit.text.strip_edges()
	ch["desc"] = desc_edit.text.strip_edges()
	_challenges_data[_selected_id] = ch

	status_label.text = "チャレンジ情報を更新 (%s)" % _selected_id
	_update_list_item_text()
	_update_preview()


func _on_add_challenge_pressed() -> void:
	var n := 1
	var new_id := "c%d" % n
	while _challenges_data.has(new_id):
		n += 1
		new_id = "c%d" % n

	_challenges_data[new_id] = {
		"id": new_id,
		"name": "新規チャレンジ %d" % n,
		"icon": "⚔️",
		"desc": "チャレンジの制限ルールを入力してください",
		"levels": [
			{
				"level": 1,
				"duration": 60.0,
				"target_type": "gold",
				"target_val": 5000.0 * n,
				"reward_desc": "恒久効果: ボーナス獲得量 +%d%%" % (10 * n),
				"memo": "初期レベル"
			}
		]
	}
	_selected_id = new_id
	status_label.text = "新規チャレンジを追加しました: %s" % new_id
	_refresh_challenge_list()


func _on_duplicate_challenge_pressed() -> void:
	if _selected_id.is_empty() or not _challenges_data.has(_selected_id):
		return
	var src: Dictionary = _challenges_data[_selected_id].duplicate(true)
	var n := 1
	var new_id := "%s_copy%d" % [_selected_id, n]
	while _challenges_data.has(new_id):
		n += 1
		new_id = "%s_copy%d" % [_selected_id, n]

	src["id"] = new_id
	src["name"] = "%s (コピー)" % src.get("name", "")
	_challenges_data[new_id] = src
	_selected_id = new_id
	status_label.text = "チャレンジを複製しました: %s" % new_id
	_refresh_challenge_list()


func _on_delete_challenge_pressed() -> void:
	if _selected_id.is_empty() or not _challenges_data.has(_selected_id):
		status_label.text = "削除するチャレンジが選択されていません。"
		return

	_challenges_data.erase(_selected_id)
	status_label.text = "チャレンジ '%s' を削除しました。" % _selected_id
	_selected_id = ""
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

	var new_lv := {
		"level": next_num,
		"duration": last_dur,
		"target_type": last_type,
		"target_val": last_val * 2.0,
		"reward_desc": "恒久効果: Lv.%d 達成ボーナス" % next_num,
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
			ch["reward_desc"] = lv1.get("reward_desc", "")

		_refresh_levels_ui()
		status_label.text = "レベルを削除しました (%s)" % _selected_id
		_update_list_item_text()
		_update_preview()


func _on_save_pressed() -> void:
	var data := {"challenges": _challenges_data}
	var json_string := JSON.stringify(data, "\t")

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		status_label.text = "保存用にファイルを開けませんでした: %s" % SAVE_PATH
		return

	file.store_string(json_string)
	file.close()

	# GameData singleton に即時反映
	if GameData:
		GameData.CHALLENGE_DEFS = _challenges_data.duplicate(true)
		for ch_id in GameData.CHALLENGE_DEFS:
			var ch: Dictionary = GameData.CHALLENGE_DEFS[ch_id]
			var levels: Array = ch.get("levels", [])
			if levels.size() > 0 and levels[0] is Dictionary:
				var lv1: Dictionary = levels[0]
				ch["duration"] = lv1.get("duration", 60.0)
				ch["target_type"] = lv1.get("target_type", "gold")
				ch["target_val"] = lv1.get("target_val", 1000.0)
				ch["reward_desc"] = lv1.get("reward_desc", "")

	status_label.text = "💾 %s に保存し、ゲームデータに反映しました！" % SAVE_PATH


func _on_back_pressed() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		visible = false


func _update_list_item_text() -> void:
	var selected_items := challenge_list.get_selected_items()
	if selected_items.size() > 0 and _challenges_data.has(_selected_id):
		var ch: Dictionary = _challenges_data[_selected_id]
		var icon_str: String = ch.get("icon", "⚔️")
		var name_str: String = ch.get("name", _selected_id)
		var lv_count: int = ch.get("levels", []).size()
		var label_str := "%s %s: %s (全%d段階)" % [icon_str, _selected_id, name_str, lv_count]
		challenge_list.set_item_text(selected_items[0], label_str)


func _update_preview() -> void:
	if _selected_id.is_empty() or not _challenges_data.has(_selected_id):
		if preview_name: preview_name.text = "選択なし"
		if preview_icon: preview_icon.text = "⚔️"
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
	var num_str := _selected_id.replace("c", "")

	if preview_icon: preview_icon.text = icon_str
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
		var duration_str := "%d秒" % int(lv1.get("duration", 60.0))
		if preview_detail_target:
			preview_detail_target.text = "Lv.1ノルマ: 制限時間 %s 以内に %s %s を獲得" % [duration_str, target_currency, target_str]
	else:
		if preview_detail_target: preview_detail_target.text = "ノルマ未設定"

	if preview_detail_reward:
		var reward_lines: Array[String] = []
		for i in levels.size():
			var lv_item: Dictionary = levels[i]
			var r_text: String = lv_item.get("reward_desc", "")
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
