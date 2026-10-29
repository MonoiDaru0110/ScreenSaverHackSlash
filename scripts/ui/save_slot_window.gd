class_name SaveSlotWindow
extends BaseWindow
## Window controller for multi-slot save and load with custom names.

signal slot_saved(slot_id: String, slot_name: String)
signal slot_loaded(slot_id: String)
signal slot_deleted(slot_id: String)

@onready var slot_list_container: VBoxContainer = %SlotListContainer
@onready var add_slot_btn: Button = %AddSlotBtn
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog
@onready var current_slot_label: Label = %CurrentSlotLabel

var _line_edits: Dictionary = {}
var _pending_action: String = ""
var _pending_slot_id: String = ""
var _pending_slot_name: String = ""


func _ready() -> void:
	super._ready()
	if add_slot_btn:
		add_slot_btn.pressed.connect(_on_add_slot_pressed)
	if confirm_dialog:
		confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	GameData.save_slots_updated.connect(refresh_slots)
	refresh_slots()


func open_window() -> void:
	visible = true
	refresh_slots()


func close_window() -> void:
	visible = false
	closed.emit()


func refresh_slots() -> void:
	if not slot_list_container:
		return

	# Clear previous items
	for child in slot_list_container.get_children():
		child.queue_free()
	_line_edits.clear()

	var meta := GameData.get_save_slots_meta()
	var current_id: String = GameData.current_slot_id
	var slots: Array = meta.get("slots", [])

	if current_slot_label:
		var cur_meta := GameData.get_slot_meta(current_id)
		var cur_name: String = cur_meta.get("name", current_id)
		current_slot_label.text = "現在のプレイ中スロット: %s [%s]" % [current_id.replace("slot_", "スロット "), cur_name]

	if add_slot_btn:
		add_slot_btn.disabled = slots.size() >= GameData.MAX_SLOT_COUNT
		add_slot_btn.tooltip_text = "最大10スロットまで作成できます (現在: %d/10)" % slots.size()

	for slot_data in slots:
		if not slot_data is Dictionary:
			continue
		var card := _create_slot_card(slot_data, current_id)
		slot_list_container.add_child(card)


func _create_slot_card(slot: Dictionary, current_id: String) -> PanelContainer:
	var slot_id: String = slot.get("id", "slot_1")
	var slot_name: String = slot.get("name", "スロット")
	var has_data: bool = bool(slot.get("has_data", false))
	var is_current: bool = (slot_id == current_id)

	var card := PanelContainer.new()
	card.name = "SlotCard_" + slot_id

	# Card Frame Styling
	var card_style := StyleBoxFlat.new()
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_right = 6
	card_style.corner_radius_bottom_left = 6

	if is_current:
		card_style.bg_color = Color(0.09, 0.12, 0.22, 0.95)
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.border_color = Color(0.38, 0.65, 0.98, 0.95)
	else:
		card_style.bg_color = Color(0.05, 0.06, 0.11, 0.92)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.18, 0.20, 0.30, 0.85)

	card.add_theme_stylebox_override("panel", card_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# --- 1. Top Header Row ---
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(header_hbox)

	# Slot ID badge
	var slot_num_str := slot_id.replace("slot_", "スロット ")
	var id_badge := Label.new()
	id_badge.text = slot_num_str
	id_badge.add_theme_font_size_override("font_size", 14)
	id_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0) if is_current else Color(0.85, 0.88, 0.95, 1.0))
	id_badge.custom_minimum_size = Vector2(75, 28)
	id_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_hbox.add_child(id_badge)

	# Slot Name LineEdit
	var name_edit := LineEdit.new()
	name_edit.text = slot_name
	name_edit.placeholder_text = "セーブデータ名を入力..."
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(240, 32)
	name_edit.max_length = 32

	var edit_style := StyleBoxFlat.new()
	edit_style.bg_color = Color(0.11, 0.13, 0.20, 1.0)
	edit_style.border_width_left = 1
	edit_style.border_width_top = 1
	edit_style.border_width_right = 1
	edit_style.border_width_bottom = 1
	edit_style.border_color = Color(0.28, 0.34, 0.50, 0.9)
	edit_style.corner_radius_top_left = 4
	edit_style.corner_radius_top_right = 4
	edit_style.corner_radius_bottom_right = 4
	edit_style.corner_radius_bottom_left = 4
	edit_style.content_margin_left = 8
	edit_style.content_margin_right = 8
	name_edit.add_theme_stylebox_override("normal", edit_style)
	name_edit.add_theme_font_size_override("font_size", 13)
	name_edit.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	header_hbox.add_child(name_edit)
	_line_edits[slot_id] = name_edit

	# Current active badge
	if is_current:
		var current_badge := Label.new()
		current_badge.text = "[現在プレイ中]"
		current_badge.add_theme_font_size_override("font_size", 12)
		current_badge.add_theme_color_override("font_color", Color(0.38, 0.85, 1.0, 1.0))
		header_hbox.add_child(current_badge)

	# Status indicator
	var status_lbl := Label.new()
	status_lbl.text = "● 保存済み" if has_data else "○ 空きスロット"
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.40, 0.92, 0.55, 1.0) if has_data else Color(0.55, 0.58, 0.68, 0.8))
	header_hbox.add_child(status_lbl)

	# --- 2. Middle Details Row ---
	if has_data:
		var details_grid := GridContainer.new()
		details_grid.columns = 4
		details_grid.add_theme_constant_override("h_separation", 16)
		details_grid.add_theme_constant_override("v_separation", 4)
		vbox.add_child(details_grid)

		var time_str: String = slot.get("timestamp", "-")
		var play_time_val: float = float(slot.get("play_time", 0.0))
		var asc_lvl: int = int(slot.get("ascension_level", 0))
		var reinc_lvl: int = int(slot.get("reincarnation_level", 0))
		var gold_val: float = float(slot.get("gold", 0.0))
		var token_val: float = float(slot.get("tokens", 0.0))
		var star_val: int = int(slot.get("stars", 0))

		_add_detail_label(details_grid, "📅 保存日時:", time_str, Color(0.75, 0.8, 0.9))
		_add_detail_label(details_grid, "⏱️ プレイ時間:", GameData.format_play_time(play_time_val), Color(0.75, 0.8, 0.9))
		_add_detail_label(details_grid, "🌀 アセンション:", "Lv. %d" % asc_lvl, Color(0.9, 0.75, 1.0))
		_add_detail_label(details_grid, "⚛️ 転生:", "Lv. %d" % reinc_lvl, Color(0.9, 0.65, 1.0))

		_add_detail_label(details_grid, "🪙 ゴールド:", GameData.format_num(gold_val), Color(1.0, 0.85, 0.3))
		_add_detail_label(details_grid, "💎 トークン:", GameData.format_num(token_val), Color(0.35, 0.85, 1.0))
		_add_detail_label(details_grid, "⚛️ スター:", str(star_val), Color(0.9, 0.65, 1.0))
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "（セーブデータはまだ保存されていません。「セーブ」を押すと現在の進行状況を保存します）"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.68, 0.7))
		vbox.add_child(empty_lbl)

	# --- 3. Bottom Action Buttons Row ---
	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 8)
	actions_hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(actions_hbox)

	# Save Button
	var btn_save := Button.new()
	btn_save.text = "💾 セーブ"
	btn_save.custom_minimum_size = Vector2(96, 30)
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.tooltip_text = "現在の進行状況をこのスロットに保存します"
	_style_button(btn_save, Color(0.18, 0.45, 0.75, 1.0), Color(0.25, 0.55, 0.90, 1.0), Color(0.12, 0.32, 0.55, 1.0))
	btn_save.pressed.connect(func(): _on_slot_save_pressed(slot_id, has_data))
	actions_hbox.add_child(btn_save)

	# Load Button
	var btn_load := Button.new()
	btn_load.text = "🔄 ロード"
	btn_load.custom_minimum_size = Vector2(96, 30)
	btn_load.focus_mode = Control.FOCUS_NONE
	btn_load.disabled = not has_data
	btn_load.tooltip_text = "このスロットのデータをロードします"
	_style_button(btn_load, Color(0.20, 0.28, 0.48, 1.0), Color(0.28, 0.38, 0.62, 1.0), Color(0.14, 0.20, 0.36, 1.0))
	btn_load.pressed.connect(func(): _on_slot_load_pressed(slot_id))
	actions_hbox.add_child(btn_load)

	# Delete Button
	var btn_delete := Button.new()
	btn_delete.text = "🗑️ 削除"
	btn_delete.custom_minimum_size = Vector2(80, 30)
	btn_delete.focus_mode = Control.FOCUS_NONE
	btn_delete.disabled = not has_data
	btn_delete.tooltip_text = "このスロットのセーブデータを消去します"
	_style_button(btn_delete, Color(0.55, 0.18, 0.18, 1.0), Color(0.72, 0.24, 0.24, 1.0), Color(0.40, 0.12, 0.12, 1.0))
	btn_delete.pressed.connect(func(): _on_slot_delete_pressed(slot_id))
	actions_hbox.add_child(btn_delete)

	return card


func _add_detail_label(grid: GridContainer, label_title: String, label_value: String, val_color: Color) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var title_lbl := Label.new()
	title_lbl.text = label_title
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.60, 0.65, 0.75, 0.85))
	hbox.add_child(title_lbl)

	var val_lbl := Label.new()
	val_lbl.text = label_value
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", val_color)
	hbox.add_child(val_lbl)

	grid.add_child(hbox)


func _style_button(btn: Button, base_color: Color, hover_color: Color, pressed_color: Color) -> void:
	var normal_st := StyleBoxFlat.new()
	normal_st.bg_color = base_color
	normal_st.border_width_left = 1
	normal_st.border_width_top = 1
	normal_st.border_width_right = 1
	normal_st.border_width_bottom = 1
	normal_st.border_color = base_color.lightened(0.2)
	normal_st.corner_radius_top_left = 4
	normal_st.corner_radius_top_right = 4
	normal_st.corner_radius_bottom_right = 4
	normal_st.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("normal", normal_st)

	var hover_st := normal_st.duplicate() as StyleBoxFlat
	hover_st.bg_color = hover_color
	hover_st.border_color = hover_color.lightened(0.3)
	btn.add_theme_stylebox_override("hover", hover_st)

	var pressed_st := normal_st.duplicate() as StyleBoxFlat
	pressed_st.bg_color = pressed_color
	btn.add_theme_stylebox_override("pressed", pressed_st)

	var disabled_st := normal_st.duplicate() as StyleBoxFlat
	disabled_st.bg_color = Color(0.12, 0.14, 0.20, 0.5)
	disabled_st.border_color = Color(0.18, 0.20, 0.28, 0.5)
	btn.add_theme_stylebox_override("disabled", disabled_st)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 12)


func _get_entered_name(slot_id: String) -> String:
	if _line_edits.has(slot_id) and is_instance_valid(_line_edits[slot_id]):
		var txt: String = _line_edits[slot_id].text.strip_edges()
		if not txt.is_empty():
			return txt
	var num := slot_id.replace("slot_", "")
	return "スロット " + num


func _on_slot_save_pressed(slot_id: String, has_data: bool) -> void:
	var name_to_save := _get_entered_name(slot_id)
	if has_data:
		_show_confirm("save", slot_id, name_to_save)
	else:
		_execute_save(slot_id, name_to_save)


func _on_slot_load_pressed(slot_id: String) -> void:
	var name_to_load := _get_entered_name(slot_id)
	_show_confirm("load", slot_id, name_to_load)


func _on_slot_delete_pressed(slot_id: String) -> void:
	var name_to_delete := _get_entered_name(slot_id)
	_show_confirm("delete", slot_id, name_to_delete)


func _show_confirm(action_type: String, slot_id: String, slot_name: String) -> void:
	_pending_action = action_type
	_pending_slot_id = slot_id
	_pending_slot_name = slot_name

	if not confirm_dialog:
		_on_confirm_dialog_confirmed()
		return

	match action_type:
		"save":
			confirm_dialog.title = "💾 上書きセーブの確認"
			confirm_dialog.dialog_text = "「%s」に上書きセーブしますか？\n（既存のセーブデータは上書きされます）" % slot_name
			confirm_dialog.ok_button_text = "上書きセーブ"
		"load":
			confirm_dialog.title = "🔄 ロードの確認"
			confirm_dialog.dialog_text = "「%s」のデータをロードしますか？\n（現在の未セーブ進行状況は失われます）" % slot_name
			confirm_dialog.ok_button_text = "ロードする"
		"delete":
			confirm_dialog.title = "🗑️ スロットデータの削除"
			confirm_dialog.dialog_text = "「%s」のセーブデータを削除しますか？\n（この操作は取り消せません）" % slot_name
			confirm_dialog.ok_button_text = "削除する"

	confirm_dialog.popup_centered()


func _on_confirm_dialog_confirmed() -> void:
	match _pending_action:
		"save":
			_execute_save(_pending_slot_id, _pending_slot_name)
		"load":
			_execute_load(_pending_slot_id)
		"delete":
			_execute_delete(_pending_slot_id)
	_pending_action = ""
	_pending_slot_id = ""
	_pending_slot_name = ""


func _execute_save(slot_id: String, s_name: String) -> void:
	var success := GameData.save_to_slot(slot_id, s_name)
	if success:
		slot_saved.emit(slot_id, s_name)
		refresh_slots()


func _execute_load(slot_id: String) -> void:
	var s_meta := GameData.get_slot_meta(slot_id)
	var s_name: String = s_meta.get("name", slot_id)
	var success := GameData.load_from_slot(slot_id)
	if success:
		slot_loaded.emit(slot_id)
		close_window()


func _execute_delete(slot_id: String) -> void:
	var success := GameData.delete_save_slot(slot_id)
	if success:
		slot_deleted.emit(slot_id)
		refresh_slots()


func _on_add_slot_pressed() -> void:
	var new_id := GameData.add_save_slot()
	if not new_id.is_empty():
		refresh_slots()
