extends Control

const SAVE_PATH = "res://data/equipment_skills.json"

@onready var skill_list: ItemList = %SkillList
@onready var id_line_edit: LineEdit = %IdLineEdit
@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var unit_val_spin_box: SpinBox = %UnitValSpinBox
@onready var desc_line_edit: LineEdit = %DescLineEdit
@onready var memo_text_edit: TextEdit = %MemoTextEdit

@onready var add_btn: Button = %AddBtn
@onready var delete_btn: Button = %DeleteBtn
@onready var save_btn: Button = %SaveBtn
@onready var status_label: Label = %StatusLabel

var _skills_data: Dictionary = {} # { "skill_id": { ... } }
var _selected_id: String = ""
var _updating_form: bool = false


func _ready() -> void:
	_connect_signals()
	load_data()


func _connect_signals() -> void:
	if skill_list: skill_list.item_selected.connect(_on_item_selected)
	if add_btn: add_btn.pressed.connect(_on_add_pressed)
	if delete_btn: delete_btn.pressed.connect(_on_delete_pressed)
	if save_btn: save_btn.pressed.connect(_on_save_pressed)
	
	if id_line_edit: id_line_edit.text_changed.connect(_on_form_changed)
	if name_line_edit: name_line_edit.text_changed.connect(_on_form_changed)
	if unit_val_spin_box: unit_val_spin_box.value_changed.connect(func(_val): _on_form_changed(""))
	if desc_line_edit: desc_line_edit.text_changed.connect(_on_form_changed)
	if memo_text_edit: memo_text_edit.text_changed.connect(func(): _on_form_changed(""))


func load_data() -> void:
	var path := SAVE_PATH
	if not FileAccess.file_exists(path):
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
		
	var data = json.get_data()
	if data is Dictionary and data.has("equipment_skills"):
		_skills_data = data["equipment_skills"].duplicate(true)
		status_label.text = "データを読み込みました。"
		_refresh_skill_list()
	else:
		status_label.text = "不正なJSON形式です。"


func _refresh_skill_list() -> void:
	skill_list.clear()
	var keys := _skills_data.keys()
	keys.sort()
	
	var target_index := -1
	for i in keys.size():
		var key = keys[i]
		var item_data: Dictionary = _skills_data[key]
		var disp_name: String = item_data.get("name", key)
		var label_str := "%s (%s)" % [disp_name, key]
		skill_list.add_item(label_str)
		skill_list.set_item_metadata(i, key)
		if key == _selected_id:
			target_index = i
			
	if target_index != -1:
		skill_list.select(target_index)
		_fill_form(_selected_id)
	elif keys.size() > 0:
		skill_list.select(0)
		_selected_id = keys[0]
		_fill_form(_selected_id)
	else:
		_selected_id = ""
		_clear_form()


func _fill_form(skill_id: String) -> void:
	if not _skills_data.has(skill_id):
		return
		
	_updating_form = true
	var item: Dictionary = _skills_data[skill_id]
	id_line_edit.text = skill_id
	name_line_edit.text = item.get("name", "")
	unit_val_spin_box.value = float(item.get("unit_value", 1.0))
	desc_line_edit.text = item.get("desc_template", "")
	memo_text_edit.text = item.get("memo", "")
	_updating_form = false


func _clear_form() -> void:
	_updating_form = true
	id_line_edit.text = ""
	name_line_edit.text = ""
	unit_val_spin_box.value = 1.0
	desc_line_edit.text = ""
	memo_text_edit.text = ""
	_updating_form = false


func _on_item_selected(index: int) -> void:
	var key: String = skill_list.get_item_metadata(index)
	_selected_id = key
	_fill_form(key)


func _on_form_changed(_new_text: String) -> void:
	if _updating_form or _selected_id.is_empty():
		return
		
	var new_id := id_line_edit.text.strip_edges()
	if new_id.is_empty():
		return
		
	var name_str := name_line_edit.text.strip_edges()
	var unit_val := float(unit_val_spin_box.value)
	var desc_str := desc_line_edit.text.strip_edges()
	var memo_str := memo_text_edit.text.strip_edges()
	
	# IDが変更された場合のキー付替え
	if new_id != _selected_id:
		if _skills_data.has(new_id):
			status_label.text = "⚠️ ID '%s' はすでに存在します。" % new_id
			return
		_skills_data.erase(_selected_id)
		_selected_id = new_id
		
	_skills_data[_selected_id] = {
		"id": _selected_id,
		"name": name_str,
		"unit_value": unit_val,
		"desc_template": desc_str,
		"memo": memo_str
	}
	
	status_label.text = "編集内容を更新しました (%s)" % _selected_id
	
	# リスト表示文字列を更新
	var selected_items := skill_list.get_selected_items()
	if selected_items.size() > 0:
		var idx := selected_items[0]
		skill_list.set_item_text(idx, "%s (%s)" % [name_str, _selected_id])
		skill_list.set_item_metadata(idx, _selected_id)


func _on_add_pressed() -> void:
	var n := 1
	var new_id := "new_equip_skill_%d" % n
	while _skills_data.has(new_id):
		n += 1
		new_id = "new_equip_skill_%d" % n
		
	_skills_data[new_id] = {
		"id": new_id,
		"name": "新しい装備スキル %d" % n,
		"unit_value": 10.0,
		"desc_template": "移動速度 +%d",
		"memo": "仕様メモを入力してください"
	}
	_selected_id = new_id
	status_label.text = "新規装備スキルを追加しました: %s" % new_id
	_refresh_skill_list()


func _on_delete_pressed() -> void:
	if _selected_id.is_empty() or not _skills_data.has(_selected_id):
		status_label.text = "削除するスキルが選択されていません。"
		return
		
	_skills_data.erase(_selected_id)
	status_label.text = "スキル '%s' を削除しました。" % _selected_id
	_selected_id = ""
	_refresh_skill_list()


func _on_save_pressed() -> void:
	var data := {"equipment_skills": _skills_data}
	var json_string := JSON.stringify(data, "\t")
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		status_label.text = "保存用にファイルを開けませんでした: %s" % SAVE_PATH
		return
		
	file.store_string(json_string)
	file.close()
	
	status_label.text = "💾 %s にデータを保存しました！" % SAVE_PATH
