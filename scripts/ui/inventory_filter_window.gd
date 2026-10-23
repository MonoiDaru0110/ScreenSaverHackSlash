extends BaseWindow
## Inventory Filter and Sorting Settings Window.
## Allows configuring sorting and filtering rules per equipment type (main/sub/accessory).

@onready var title_label: Label = %TitleLabel
@onready var btn_close: Button = %CloseBtn

# Sort Section Controls (Dropdowns)
@onready var opt_sort_key: OptionButton = %SortKeyOption
@onready var opt_sort_order: OptionButton = %SortOrderOption

# Rarities
@onready var chk_rarity_common: CheckBox = %ChkRarityCommon
@onready var chk_rarity_uncommon: CheckBox = %ChkRarityUncommon
@onready var chk_rarity_rare: CheckBox = %ChkRarityRare
@onready var chk_rarity_epic: CheckBox = %ChkRarityEpic
@onready var chk_rarity_legend: CheckBox = %ChkRarityLegend
@onready var chk_rarity_mythic: CheckBox = %ChkRarityMythic

# Normal Skills
@onready var normal_skills_grid: GridContainer = %NormalSkillsGrid
@onready var btn_normal_mode: Button = %BtnNormalMode
@onready var btn_normal_clear: Button = %BtnNormalClear

# Special Skills (OptionButton)
@onready var opt_special_skill: OptionButton = %SpecialSkillOption

var target_type: String = "main" # "main", "sub", "accessory"
var _normal_skill_checkboxes: Dictionary = {} # { "skill_id": CheckBox }
var _special_skill_ids: Array[String] = [] # index -> special_id
var _updating_ui: bool = false

var _style_btn_normal: StyleBoxFlat
var _style_btn_hover: StyleBoxFlat
var _style_btn_pressed: StyleBoxFlat
var _style_btn_execute: StyleBoxFlat
var _style_btn_execute_hover: StyleBoxFlat

var _tex_chk_unchecked: ImageTexture
var _tex_chk_checked: ImageTexture


func _ready() -> void:
	custom_minimum_size = Vector2(850, 650)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	window_title = "インベントリ設定"
	header_color = Color(0.24, 0.20, 0.35, 1.0)
	separator_color = Color(0.42, 0.35, 0.58, 1.0)
	header_height = 48.0
	super._ready()
	
	_init_button_styles()
	_init_checkbox_textures()
	
	# Apply standard button styles
	_apply_button_styles(btn_normal_mode)
	_apply_button_styles(btn_normal_clear)
	_apply_button_styles(opt_sort_key)
	_apply_button_styles(opt_sort_order)
	_apply_button_styles(opt_special_skill)
	
	if btn_close and not btn_close.pressed.is_connected(_on_close_pressed):
		btn_close.pressed.connect(_on_close_pressed)
	
	# Build Sort Dropdowns
	_build_sort_dropdowns_ui()
	opt_sort_key.item_selected.connect(_on_sort_key_selected)
	opt_sort_order.item_selected.connect(_on_sort_order_selected)
	
	# Rarity Checkboxes
	_setup_rarity_checkbox(chk_rarity_common, "コモン")
	_setup_rarity_checkbox(chk_rarity_uncommon, "アンコモン")
	_setup_rarity_checkbox(chk_rarity_rare, "レア")
	_setup_rarity_checkbox(chk_rarity_epic, "エピック")
	_setup_rarity_checkbox(chk_rarity_legend, "レジェンド")
	_setup_rarity_checkbox(chk_rarity_mythic, "ミシック")
	
	# Normal Skills
	btn_normal_mode.pressed.connect(_on_normal_mode_pressed)
	btn_normal_clear.pressed.connect(_on_normal_clear_pressed)
	
	# Special Skills
	opt_special_skill.item_selected.connect(_on_special_skill_selected)
	
	# Build dynamic skill lists
	_build_normal_skills_ui()
	_build_special_skills_ui()
	
	# Remove all focus highlight borders recursively
	_remove_focus_highlights(self)
	
	# Connect GameData signal
	GameData.inventory_filter_changed.connect(_on_data_filter_changed)


func open_for_type(type: String) -> void:
	target_type = type
	var type_label := "メイン"
	match type:
		"sub":
			type_label = "サブ"
		"accessory":
			type_label = "アクセサリー"
		_:
			type_label = "メイン"
			
	window_title = "インベントリ設定(%s)" % type_label
	if title_label:
		title_label.text = window_title
		
	sync_from_data()
	visible = true


func _init_checkbox_textures() -> void:
	var size := 16
	
	var img_un := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img_un.fill(Color(0, 0, 0, 0))
	var border_un := Color(0.80, 0.76, 0.95, 1.0)
	var bg_un := Color(0.18, 0.15, 0.28, 1.0)
	
	for y in range(size):
		for x in range(size):
			if x >= 1 and x < size - 1 and y >= 1 and y < size - 1:
				if x == 1 or x == size - 2 or y == 1 or y == size - 2:
					img_un.set_pixel(x, y, border_un)
				else:
					img_un.set_pixel(x, y, bg_un)
	_tex_chk_unchecked = ImageTexture.create_from_image(img_un)
	
	var img_ch := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img_ch.fill(Color(0, 0, 0, 0))
	var border_ch := Color(0.90, 0.60, 1.0, 1.0)
	var bg_ch := Color(0.45, 0.22, 0.75, 1.0)
	var mark_col := Color(1.0, 1.0, 1.0, 1.0)
	
	for y in range(size):
		for x in range(size):
			if x >= 1 and x < size - 1 and y >= 1 and y < size - 1:
				if x == 1 or x == size - 2 or y == 1 or y == size - 2:
					img_ch.set_pixel(x, y, border_ch)
				else:
					img_ch.set_pixel(x, y, bg_ch)
					
	var check_pixels := [
		Vector2i(4, 8), Vector2i(4, 9),
		Vector2i(5, 9), Vector2i(5, 10),
		Vector2i(6, 10), Vector2i(6, 11),
		Vector2i(7, 11), Vector2i(7, 12),
		Vector2i(8, 10), Vector2i(8, 11),
		Vector2i(9, 9), Vector2i(9, 10),
		Vector2i(10, 8), Vector2i(10, 9),
		Vector2i(11, 7), Vector2i(11, 8),
		Vector2i(12, 6), Vector2i(12, 7)
	]
	for p in check_pixels:
		if p.x < size and p.y < size:
			img_ch.set_pixel(p.x, p.y, mark_col)
			
	_tex_chk_checked = ImageTexture.create_from_image(img_ch)


func _init_button_styles() -> void:
	_style_btn_normal = StyleBoxFlat.new()
	_style_btn_normal.bg_color = Color(0.20, 0.17, 0.30, 1.0)
	_style_btn_normal.border_width_left = 1
	_style_btn_normal.border_width_top = 1
	_style_btn_normal.border_width_right = 1
	_style_btn_normal.border_width_bottom = 1
	_style_btn_normal.border_color = Color(0.48, 0.40, 0.68, 1.0)
	_style_btn_normal.corner_radius_top_left = 3
	_style_btn_normal.corner_radius_top_right = 3
	_style_btn_normal.corner_radius_bottom_right = 3
	_style_btn_normal.corner_radius_bottom_left = 3
	_style_btn_normal.content_margin_left = 8
	_style_btn_normal.content_margin_right = 8
	_style_btn_normal.content_margin_top = 3
	_style_btn_normal.content_margin_bottom = 3
	
	_style_btn_hover = StyleBoxFlat.new()
	_style_btn_hover.bg_color = Color(0.30, 0.25, 0.45, 1.0)
	_style_btn_hover.border_width_left = 1
	_style_btn_hover.border_width_top = 1
	_style_btn_hover.border_width_right = 1
	_style_btn_hover.border_width_bottom = 1
	_style_btn_hover.border_color = Color(0.70, 0.60, 0.95, 1.0)
	_style_btn_hover.corner_radius_top_left = 3
	_style_btn_hover.corner_radius_top_right = 3
	_style_btn_hover.corner_radius_bottom_right = 3
	_style_btn_hover.corner_radius_bottom_left = 3
	_style_btn_hover.content_margin_left = 8
	_style_btn_hover.content_margin_right = 8
	_style_btn_hover.content_margin_top = 3
	_style_btn_hover.content_margin_bottom = 3
	
	_style_btn_pressed = StyleBoxFlat.new()
	_style_btn_pressed.bg_color = Color(0.14, 0.11, 0.22, 1.0)
	_style_btn_pressed.border_width_left = 1
	_style_btn_pressed.border_width_top = 1
	_style_btn_pressed.border_width_right = 1
	_style_btn_pressed.border_width_bottom = 1
	_style_btn_pressed.border_color = Color(0.55, 0.45, 0.78, 1.0)
	_style_btn_pressed.corner_radius_top_left = 3
	_style_btn_pressed.corner_radius_top_right = 3
	_style_btn_pressed.corner_radius_bottom_right = 3
	_style_btn_pressed.corner_radius_bottom_left = 3
	_style_btn_pressed.content_margin_left = 8
	_style_btn_pressed.content_margin_right = 8
	_style_btn_pressed.content_margin_top = 3
	_style_btn_pressed.content_margin_bottom = 3

	# Execute sort button style (Gold accent)
	_style_btn_execute = StyleBoxFlat.new()
	_style_btn_execute.bg_color = Color(0.35, 0.25, 0.10, 1.0)
	_style_btn_execute.border_width_left = 1
	_style_btn_execute.border_width_top = 1
	_style_btn_execute.border_width_right = 1
	_style_btn_execute.border_width_bottom = 1
	_style_btn_execute.border_color = Color(0.95, 0.75, 0.25, 1.0)
	_style_btn_execute.corner_radius_top_left = 3
	_style_btn_execute.corner_radius_top_right = 3
	_style_btn_execute.corner_radius_bottom_right = 3
	_style_btn_execute.corner_radius_bottom_left = 3
	_style_btn_execute.content_margin_left = 12
	_style_btn_execute.content_margin_right = 12
	_style_btn_execute.content_margin_top = 3
	_style_btn_execute.content_margin_bottom = 3

	_style_btn_execute_hover = StyleBoxFlat.new()
	_style_btn_execute_hover.bg_color = Color(0.48, 0.35, 0.15, 1.0)
	_style_btn_execute_hover.border_width_left = 1
	_style_btn_execute_hover.border_width_top = 1
	_style_btn_execute_hover.border_width_right = 1
	_style_btn_execute_hover.border_width_bottom = 1
	_style_btn_execute_hover.border_color = Color(1.0, 0.88, 0.40, 1.0)
	_style_btn_execute_hover.corner_radius_top_left = 3
	_style_btn_execute_hover.corner_radius_top_right = 3
	_style_btn_execute_hover.corner_radius_bottom_right = 3
	_style_btn_execute_hover.corner_radius_bottom_left = 3
	_style_btn_execute_hover.content_margin_left = 12
	_style_btn_execute_hover.content_margin_right = 12
	_style_btn_execute_hover.content_margin_top = 3
	_style_btn_execute_hover.content_margin_bottom = 3


func _apply_button_styles(btn: Button) -> void:
	if not btn:
		return
	btn.add_theme_stylebox_override("normal", _style_btn_normal)
	btn.add_theme_stylebox_override("hover", _style_btn_hover)
	btn.add_theme_stylebox_override("pressed", _style_btn_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.92, 0.90, 0.98, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.80, 0.95, 1.0))
	
	if btn is OptionButton:
		var popup: PopupMenu = (btn as OptionButton).get_popup()
		if popup:
			popup.add_theme_font_size_override("font_size", 15)
			var style_popup := StyleBoxFlat.new()
			style_popup.bg_color = Color(0.12, 0.10, 0.18, 0.98)
			style_popup.border_width_left = 1
			style_popup.border_width_top = 1
			style_popup.border_width_right = 1
			style_popup.border_width_bottom = 1
			style_popup.border_color = Color(0.48, 0.40, 0.68, 1.0)
			popup.add_theme_stylebox_override("panel", style_popup)


func _apply_execute_button_style(btn: Button) -> void:
	if not btn:
		return
	btn.add_theme_stylebox_override("normal", _style_btn_execute)
	btn.add_theme_stylebox_override("hover", _style_btn_execute_hover)
	btn.add_theme_stylebox_override("pressed", _style_btn_execute)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


func _build_sort_dropdowns_ui() -> void:
	# 項目プルダウン (0: レア度, 1: レベル, 2: 入手順)
	opt_sort_key.clear()
	opt_sort_key.add_item("レア度")
	opt_sort_key.add_item("レベル")
	opt_sort_key.add_item("入手順")
	
	# 順序プルダウン (0: 降順, 1: 昇順)
	opt_sort_order.clear()
	opt_sort_order.add_item("▼ 降順")
	opt_sort_order.add_item("▲ 昇順")


func _setup_standard_checkbox(chk: CheckBox) -> void:
	if not chk:
		return
	chk.focus_mode = Control.FOCUS_NONE
	chk.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chk.add_theme_icon_override("unchecked", _tex_chk_unchecked)
	chk.add_theme_icon_override("checked", _tex_chk_checked)
	chk.add_theme_icon_override("unchecked_disabled", _tex_chk_unchecked)
	chk.add_theme_icon_override("checked_disabled", _tex_chk_checked)
	chk.add_theme_color_override("font_color", Color(0.85, 0.82, 0.94, 1.0))
	chk.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	chk.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	chk.add_theme_color_override("font_hover_pressed_color", Color(1.0, 1.0, 1.0, 1.0))


func _setup_rarity_checkbox(chk: CheckBox, rarity_name: String) -> void:
	if not chk:
		return
	var col := GameData.get_rarity_color(rarity_name)
	chk.focus_mode = Control.FOCUS_NONE
	chk.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chk.add_theme_icon_override("unchecked", _tex_chk_unchecked)
	chk.add_theme_icon_override("checked", _tex_chk_checked)
	chk.add_theme_icon_override("unchecked_disabled", _tex_chk_unchecked)
	chk.add_theme_icon_override("checked_disabled", _tex_chk_checked)
	chk.add_theme_color_override("font_color", col)
	chk.add_theme_color_override("font_hover_color", col.lightened(0.25))
	chk.add_theme_color_override("font_pressed_color", col.lightened(0.15))
	chk.add_theme_color_override("font_hover_pressed_color", col.lightened(0.30))
	chk.toggled.connect(func(v): _on_rarity_toggled(rarity_name, v))


func _remove_focus_highlights(node: Node) -> void:
	var empty_style := StyleBoxEmpty.new()
	if node is Control:
		node.focus_mode = Control.FOCUS_NONE
		if node is Button:
			node.add_theme_stylebox_override("focus", empty_style)
	for child in node.get_children():
		_remove_focus_highlights(child)


func _build_normal_skills_ui() -> void:
	for child in normal_skills_grid.get_children():
		child.queue_free()
	_normal_skill_checkboxes.clear()
	
	var defs := GameData.equipment_skill_defs
	for sk_id in defs:
		var def: Dictionary = defs[sk_id]
		var sk_name: String = def.get("name", sk_id)
		
		var chk := CheckBox.new()
		chk.text = sk_name
		_setup_standard_checkbox(chk)
		chk.add_theme_font_size_override("font_size", 15)
		chk.toggled.connect(func(v): _on_normal_skill_toggled(sk_id, v))
		
		normal_skills_grid.add_child(chk)
		_normal_skill_checkboxes[sk_id] = chk


func _build_special_skills_ui() -> void:
	opt_special_skill.clear()
	_special_skill_ids.clear()
	
	opt_special_skill.add_item("指定なし")
	_special_skill_ids.append("")
	
	opt_special_skill.add_item("特殊スキルあり")
	_special_skill_ids.append("__has_special__")
	
	opt_special_skill.add_item("特殊スキルなし")
	_special_skill_ids.append("__no_special__")
	
	var spec_defs := GameData.special_skill_defs
	for spec_id in spec_defs:
		var def: Dictionary = spec_defs[spec_id]
		var spec_name: String = def.get("name", spec_id)
		opt_special_skill.add_item(spec_name)
		_special_skill_ids.append(spec_id)
		
	var spec_color := GameData.special_skill_color
	opt_special_skill.add_theme_color_override("font_color", spec_color)
	opt_special_skill.add_theme_color_override("font_hover_color", spec_color.lightened(0.2))
	opt_special_skill.add_theme_color_override("font_pressed_color", spec_color)


func sync_from_data() -> void:
	_updating_ui = true
	var settings: Dictionary = GameData.inventory_filter_settings.get(target_type, {})
	
	# 1. Sort Settings
	var sort_key: String = settings.get("sort_key", "rarity")
	var sort_order: String = settings.get("sort_order", "desc")
	
	match sort_key:
		"rarity":
			opt_sort_key.selected = 0
		"level":
			opt_sort_key.selected = 1
		"obtain":
			opt_sort_key.selected = 2
		_:
			opt_sort_key.selected = 0
			
	match sort_order:
		"desc":
			opt_sort_order.selected = 0
		"asc":
			opt_sort_order.selected = 1
		_:
			opt_sort_order.selected = 0
	
	# 2. Rarities
	var rarities: Dictionary = settings.get("rarities", {})
	chk_rarity_common.button_pressed = rarities.get("コモン", true)
	chk_rarity_uncommon.button_pressed = rarities.get("アンコモン", true)
	chk_rarity_rare.button_pressed = rarities.get("レア", true)
	chk_rarity_epic.button_pressed = rarities.get("エピック", true)
	chk_rarity_legend.button_pressed = rarities.get("レジェンド", true)
	chk_rarity_mythic.button_pressed = rarities.get("ミシック", true)
	
	# 3. Normal Skills
	var normal_skills: Dictionary = settings.get("normal_skills", {})
	for sk_id in _normal_skill_checkboxes:
		var chk: CheckBox = _normal_skill_checkboxes[sk_id]
		chk.button_pressed = normal_skills.get(sk_id, false)
		
	var mode: String = settings.get("normal_skill_mode", "OR")
	_update_normal_mode_button(mode)
	
	# 4. Special Skills (OptionButton)
	var selected_spec: String = settings.get("special_skill", "")
	var target_index := 0
	for i in range(_special_skill_ids.size()):
		if _special_skill_ids[i] == selected_spec:
			target_index = i
			break
	opt_special_skill.selected = target_index
		
	_updating_ui = false


func _update_normal_mode_button(mode: String) -> void:
	if mode == "AND":
		btn_normal_mode.text = "条件: AND"
	else:
		btn_normal_mode.text = "条件: OR"
	btn_normal_mode.tooltip_text = ""


func _on_sort_key_selected(index: int) -> void:
	if _updating_ui:
		return
	if not GameData.inventory_filter_settings.has(target_type):
		return
	var key := "rarity"
	match index:
		0:
			key = "rarity"
		1:
			key = "level"
		2:
			key = "obtain"
	GameData.inventory_filter_settings[target_type]["sort_key"] = key
	GameData.sort_and_filter_inventory(target_type)


func _on_sort_order_selected(index: int) -> void:
	if _updating_ui:
		return
	if not GameData.inventory_filter_settings.has(target_type):
		return
	var order := "desc" if index == 0 else "asc"
	GameData.inventory_filter_settings[target_type]["sort_order"] = order
	GameData.sort_and_filter_inventory(target_type)


func _on_rarity_toggled(rarity_name: String, enabled: bool) -> void:
	if _updating_ui:
		return
	if not GameData.inventory_filter_settings.has(target_type):
		return
	if not GameData.inventory_filter_settings[target_type].has("rarities"):
		GameData.inventory_filter_settings[target_type]["rarities"] = {}
	GameData.inventory_filter_settings[target_type]["rarities"][rarity_name] = enabled
	GameData.sort_and_filter_inventory(target_type)


func _on_normal_skill_toggled(sk_id: String, enabled: bool) -> void:
	if _updating_ui:
		return
	if not GameData.inventory_filter_settings.has(target_type):
		return
	if not GameData.inventory_filter_settings[target_type].has("normal_skills"):
		GameData.inventory_filter_settings[target_type]["normal_skills"] = {}
	GameData.inventory_filter_settings[target_type]["normal_skills"][sk_id] = enabled
	GameData.sort_and_filter_inventory(target_type)


func _on_normal_mode_pressed() -> void:
	var cur_mode: String = GameData.inventory_filter_settings[target_type].get("normal_skill_mode", "OR")
	var new_mode := "AND" if cur_mode == "OR" else "OR"
	GameData.inventory_filter_settings[target_type]["normal_skill_mode"] = new_mode
	_update_normal_mode_button(new_mode)
	GameData.sort_and_filter_inventory(target_type)


func _on_normal_clear_pressed() -> void:
	GameData.inventory_filter_settings[target_type]["normal_skills"] = {}
	sync_from_data()
	GameData.sort_and_filter_inventory(target_type)


func _on_special_skill_selected(index: int) -> void:
	if _updating_ui:
		return
	if not GameData.inventory_filter_settings.has(target_type):
		return
	if index >= 0 and index < _special_skill_ids.size():
		GameData.inventory_filter_settings[target_type]["special_skill"] = _special_skill_ids[index]
	else:
		GameData.inventory_filter_settings[target_type]["special_skill"] = ""
	GameData.sort_and_filter_inventory(target_type)


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _on_data_filter_changed(changed_type: String) -> void:
	if visible and changed_type == target_type:
		sync_from_data()
