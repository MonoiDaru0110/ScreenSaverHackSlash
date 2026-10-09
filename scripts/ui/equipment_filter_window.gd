extends PanelContainer
## Equipment Filter Settings Window.
## Allows configuring auto-filtering rules for dropped equipment.

signal closed

@onready var btn_close: Button = %CloseBtn
@onready var btn_reset: Button = %ResetBtn

# Lv Tiers
@onready var chk_lv_low: CheckBox = %ChkLvLow
@onready var chk_lv_med: CheckBox = %ChkLvMed
@onready var chk_lv_high: CheckBox = %ChkLvHigh

# Rarities
@onready var chk_rarity_common: CheckBox = %ChkRarityCommon
@onready var chk_rarity_uncommon: CheckBox = %ChkRarityUncommon
@onready var chk_rarity_rare: CheckBox = %ChkRarityRare
@onready var chk_rarity_epic: CheckBox = %ChkRarityEpic
@onready var chk_rarity_legend: CheckBox = %ChkRarityLegend
@onready var chk_rarity_mythic: CheckBox = %ChkRarityMythic
@onready var btn_rarity_all: Button = %BtnRarityAll
@onready var btn_rarity_clear: Button = %BtnRarityClear

# Normal Skills
@onready var normal_skills_grid: GridContainer = %NormalSkillsGrid
@onready var btn_normal_mode: Button = %BtnNormalMode
@onready var btn_normal_clear: Button = %BtnNormalClear

# Special Skills (OptionButton)
@onready var opt_special_skill: OptionButton = %SpecialSkillOption

var _normal_skill_checkboxes: Dictionary = {} # { "skill_id": CheckBox }
var _special_skill_ids: Array[String] = [] # index -> special_id
var _updating_ui: bool = false

var _style_btn_normal: StyleBoxFlat
var _style_btn_hover: StyleBoxFlat
var _style_btn_pressed: StyleBoxFlat

var _tex_chk_unchecked: ImageTexture
var _tex_chk_checked: ImageTexture


func _ready() -> void:
	custom_minimum_size = Vector2(580, 430)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	_init_button_styles()
	_init_checkbox_textures()
	
	# Apply button styles
	_apply_button_styles(btn_reset)
	_apply_button_styles(btn_close)
	_apply_button_styles(btn_rarity_all)
	_apply_button_styles(btn_rarity_clear)
	_apply_button_styles(btn_normal_mode)
	_apply_button_styles(btn_normal_clear)
	_apply_button_styles(opt_special_skill)
	
	btn_close.pressed.connect(_on_close_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)
	
	# Lv Tier Checkboxes
	_setup_standard_checkbox(chk_lv_low)
	_setup_standard_checkbox(chk_lv_med)
	_setup_standard_checkbox(chk_lv_high)
	chk_lv_low.toggled.connect(func(v): _on_lv_tier_toggled("low", v))
	chk_lv_med.toggled.connect(func(v): _on_lv_tier_toggled("medium", v))
	chk_lv_high.toggled.connect(func(v): _on_lv_tier_toggled("high", v))
	
	# Rarity Checkboxes
	_setup_rarity_checkbox(chk_rarity_common, "コモン")
	_setup_rarity_checkbox(chk_rarity_uncommon, "アンコモン")
	_setup_rarity_checkbox(chk_rarity_rare, "レア")
	_setup_rarity_checkbox(chk_rarity_epic, "エピック")
	_setup_rarity_checkbox(chk_rarity_legend, "レジェンド")
	_setup_rarity_checkbox(chk_rarity_mythic, "ミシック")
	
	btn_rarity_all.pressed.connect(_on_rarity_all_pressed)
	btn_rarity_clear.pressed.connect(_on_rarity_clear_pressed)
	
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
	
	# Sync with GameData
	GameData.equipment_filter_changed.connect(sync_from_data)
	sync_from_data()


func _init_checkbox_textures() -> void:
	var size := 16
	
	# 1. Unchecked: 明るくはっきりとしたシルバーパープルの枠線 + 暗すぎない背景色
	var img_un := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img_un.fill(Color(0, 0, 0, 0))
	var border_un := Color(0.80, 0.76, 0.95, 1.0) # 明るいシルバーパープル
	var bg_un := Color(0.18, 0.15, 0.28, 1.0)     # 視認しやすい背景色
	
	for y in range(size):
		for x in range(size):
			if x >= 1 and x < size - 1 and y >= 1 and y < size - 1:
				if x == 1 or x == size - 2 or y == 1 or y == size - 2:
					img_un.set_pixel(x, y, border_un)
				else:
					img_un.set_pixel(x, y, bg_un)
	_tex_chk_unchecked = ImageTexture.create_from_image(img_un)
	
	# 2. Checked: 明るい枠線 + 鮮やかなパープル背景 + くっきり白いチェックマーク "✓"
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
					
	# チェックマークピクセル
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
	_style_btn_normal.content_margin_left = 6
	_style_btn_normal.content_margin_right = 6
	_style_btn_normal.content_margin_top = 2
	_style_btn_normal.content_margin_bottom = 2
	
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
	_style_btn_hover.content_margin_left = 6
	_style_btn_hover.content_margin_right = 6
	_style_btn_hover.content_margin_top = 2
	_style_btn_hover.content_margin_bottom = 2
	
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
	_style_btn_pressed.content_margin_left = 6
	_style_btn_pressed.content_margin_right = 6
	_style_btn_pressed.content_margin_top = 2
	_style_btn_pressed.content_margin_bottom = 2


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


func _setup_standard_checkbox(chk: CheckBox) -> void:
	if not chk:
		return
	chk.focus_mode = Control.FOCUS_NONE
	chk.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	# カスタムアイコン設定 (非選択時の明るい四角枠 & 選択時のチェックマーク)
	chk.add_theme_icon_override("unchecked", _tex_chk_unchecked)
	chk.add_theme_icon_override("checked", _tex_chk_checked)
	chk.add_theme_icon_override("unchecked_disabled", _tex_chk_unchecked)
	chk.add_theme_icon_override("checked_disabled", _tex_chk_checked)
	
	# 未選択時でもくっきりと読める明るいフォント色
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
	
	# カスタムアイコン設定
	chk.add_theme_icon_override("unchecked", _tex_chk_unchecked)
	chk.add_theme_icon_override("checked", _tex_chk_checked)
	chk.add_theme_icon_override("unchecked_disabled", _tex_chk_unchecked)
	chk.add_theme_icon_override("checked_disabled", _tex_chk_checked)
	
	# レア度色（鮮やかで未選択時も沈まない）
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
		var desc: String = def.get("desc_template", "")
		var memo: String = def.get("memo", "")
		var tooltip := "%s\n%s" % [sk_name, memo if not memo.is_empty() else desc]
		
		var chk := CheckBox.new()
		chk.text = sk_name
		chk.tooltip_text = tooltip
		_setup_standard_checkbox(chk)
		chk.add_theme_font_size_override("font_size", 12)
		chk.toggled.connect(func(v): _on_normal_skill_toggled(sk_id, v))
		
		normal_skills_grid.add_child(chk)
		_normal_skill_checkboxes[sk_id] = chk


func _build_special_skills_ui() -> void:
	opt_special_skill.clear()
	_special_skill_ids.clear()
	
	# Index 0: 指定なし
	opt_special_skill.add_item("指定なし (全て許可)")
	_special_skill_ids.append("")
	
	var spec_defs := GameData.special_skill_defs
	
	var idx := 1
	for spec_id in spec_defs:
		var def: Dictionary = spec_defs[spec_id]
		var spec_name: String = def.get("name", spec_id)
		opt_special_skill.add_item(spec_name)
		_special_skill_ids.append(spec_id)
		idx += 1
		
	var spec_color := GameData.special_skill_color
	opt_special_skill.add_theme_color_override("font_color", spec_color)
	opt_special_skill.add_theme_color_override("font_hover_color", spec_color.lightened(0.2))
	opt_special_skill.add_theme_color_override("font_pressed_color", spec_color)
	
	var popup: PopupMenu = opt_special_skill.get_popup()
	if popup:
		var style_popup := StyleBoxFlat.new()
		style_popup.bg_color = Color(0.12, 0.10, 0.18, 0.98)
		style_popup.border_width_left = 1
		style_popup.border_width_top = 1
		style_popup.border_width_right = 1
		style_popup.border_width_bottom = 1
		style_popup.border_color = Color(0.48, 0.40, 0.68, 1.0)
		popup.add_theme_stylebox_override("panel", style_popup)


func sync_from_data() -> void:
	_updating_ui = true
	var settings := GameData.equipment_filter_settings
	
	# 1. Lv Tiers
	var tiers: Dictionary = settings.get("level_tiers", {})
	chk_lv_low.button_pressed = tiers.get("low", true)
	chk_lv_med.button_pressed = tiers.get("medium", true)
	chk_lv_high.button_pressed = tiers.get("high", true)
	
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
		btn_normal_mode.text = "条件: AND (すべて)"
		btn_normal_mode.tooltip_text = "選択したスキルを【すべて】持っている装備のみ入手します"
	else:
		btn_normal_mode.text = "条件: OR (いずれか)"
		btn_normal_mode.tooltip_text = "選択したスキルの【いずれか1つ以上】を持っている装備を入手します"


func _on_lv_tier_toggled(tier_key: String, enabled: bool) -> void:
	if _updating_ui:
		return
	if not GameData.equipment_filter_settings.has("level_tiers"):
		GameData.equipment_filter_settings["level_tiers"] = {}
	GameData.equipment_filter_settings["level_tiers"][tier_key] = enabled


func _on_rarity_toggled(rarity_name: String, enabled: bool) -> void:
	if _updating_ui:
		return
	if not GameData.equipment_filter_settings.has("rarities"):
		GameData.equipment_filter_settings["rarities"] = {}
	GameData.equipment_filter_settings["rarities"][rarity_name] = enabled


func _on_rarity_all_pressed() -> void:
	var rarities: Dictionary = GameData.equipment_filter_settings.get("rarities", {})
	for r in ["コモン", "アンコモン", "レア", "エピック", "レジェンド", "ミシック"]:
		rarities[r] = true
	sync_from_data()


func _on_rarity_clear_pressed() -> void:
	var rarities: Dictionary = GameData.equipment_filter_settings.get("rarities", {})
	for r in ["コモン", "アンコモン", "レア", "エピック", "レジェンド", "ミシック"]:
		rarities[r] = false
	sync_from_data()


func _on_normal_skill_toggled(sk_id: String, enabled: bool) -> void:
	if _updating_ui:
		return
	if not GameData.equipment_filter_settings.has("normal_skills"):
		GameData.equipment_filter_settings["normal_skills"] = {}
	GameData.equipment_filter_settings["normal_skills"][sk_id] = enabled


func _on_normal_mode_pressed() -> void:
	var cur_mode: String = GameData.equipment_filter_settings.get("normal_skill_mode", "OR")
	var new_mode := "AND" if cur_mode == "OR" else "OR"
	GameData.equipment_filter_settings["normal_skill_mode"] = new_mode
	_update_normal_mode_button(new_mode)


func _on_normal_clear_pressed() -> void:
	GameData.equipment_filter_settings["normal_skills"] = {}
	sync_from_data()


func _on_special_skill_selected(index: int) -> void:
	if _updating_ui:
		return
	if index >= 0 and index < _special_skill_ids.size():
		GameData.equipment_filter_settings["special_skill"] = _special_skill_ids[index]
	else:
		GameData.equipment_filter_settings["special_skill"] = ""


func _on_reset_pressed() -> void:
	GameData.reset_equipment_filter_settings()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
