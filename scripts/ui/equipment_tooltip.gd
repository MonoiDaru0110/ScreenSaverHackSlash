extends PanelContainer
class_name EquipmentTooltip

@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var equipment_icon: EquipmentIcon = %EquipmentIcon
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var badge_label: Label = get_node_or_null("%BadgeLabel") as Label
@onready var rarity_label: RichTextLabel = get_node_or_null("%RarityLabel") as RichTextLabel
@onready var skill_scroll: ScrollContainer = get_node_or_null("%SkillScroll") as ScrollContainer
@onready var normal_skill_label: RichTextLabel = get_node_or_null("%NormalSkillLabel") as RichTextLabel
@onready var normal_section_header: Label = get_node_or_null("%NormalSectionHeader") as Label
@onready var special_skill_label: RichTextLabel = get_node_or_null("%SpecialSkillLabel") as RichTextLabel
@onready var special_section_header: Label = get_node_or_null("%SpecialSectionHeader") as Label
@onready var separator_2: ColorRect = get_node_or_null("%Separator2") as ColorRect
@onready var equip_skill_label: Control = get_node_or_null("%EquipSkillLabel") as Control
@onready var normal_section: VBoxContainer = get_node_or_null("%NormalSection") as VBoxContainer

signal skill_pick_changed(picked_ids: Array[String])

@export var is_embedded: bool = false
@export var max_skill_height: float = 0.0

var current_picked_skill_ids: Array[String] = []
var current_max_picks: int = 0
var _dynamic_skill_rows_container: VBoxContainer = null
var _skill_checkbox_map: Dictionary = {}


func _ready() -> void:
	if not is_embedded:
		z_index = 50
		z_as_relative = false
		_ensure_nodes()
		_set_all_mouse_ignore(self)
	else:
		z_index = 0
		z_as_relative = true
		_ensure_nodes()


func _set_all_mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_all_mouse_ignore(child)


func _ensure_nodes() -> void:
	if not tooltip_panel:
		tooltip_panel = %TooltipPanel as PanelContainer
	if not equipment_icon:
		equipment_icon = %EquipmentIcon as EquipmentIcon
	if not badge_label:
		badge_label = get_node_or_null("%BadgeLabel") as Label
	if not name_label:
		name_label = %NameLabel as Label
	if not rarity_label:
		rarity_label = get_node_or_null("%RarityLabel") as RichTextLabel
	if not level_label:
		level_label = %LevelLabel as Label
	if not skill_scroll:
		skill_scroll = get_node_or_null("%SkillScroll") as ScrollContainer
	if not normal_section:
		normal_section = get_node_or_null("%NormalSection") as VBoxContainer
	if not normal_skill_label:
		normal_skill_label = get_node_or_null("%NormalSkillLabel") as RichTextLabel
	if not normal_section_header:
		normal_section_header = get_node_or_null("%NormalSectionHeader") as Label
	if not special_skill_label:
		special_skill_label = get_node_or_null("%SpecialSkillLabel") as RichTextLabel
	if not special_section_header:
		special_section_header = get_node_or_null("%SpecialSectionHeader") as Label
	if not separator_2:
		separator_2 = get_node_or_null("%Separator2") as ColorRect
	if not equip_skill_label:
		equip_skill_label = get_node_or_null("%EquipSkillLabel") as Control


func set_max_skill_height(h: float) -> void:
	max_skill_height = h
	if skill_scroll:
		if max_skill_height > 0.0:
			skill_scroll.custom_minimum_size.y = max_skill_height
			skill_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			skill_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			skill_scroll.custom_minimum_size.y = 0
			skill_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			skill_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(item_data: Dictionary, badge_text: String = "", bonus_skill_level: int = -1) -> void:
	_ensure_nodes()
	
	var item_name: String = item_data.get("name", "")
	var item_rarity: String = item_data.get("rarity", "コモン")
	var item_level: int = item_data.get("level", 1)

	# 比較用バッジ（装備中スロット名、完成通知など）の表示
	if badge_label:
		if badge_text != "":
			badge_label.text = "【%s】" % badge_text
			badge_label.visible = true
		else:
			badge_label.visible = false
	elif badge_text != "" and name_label:
		var parent_box := name_label.get_parent()
		if parent_box:
			var dynamic_badge := parent_box.get_node_or_null("BadgeLabel") as Label
			if not dynamic_badge:
				dynamic_badge = Label.new()
				dynamic_badge.name = "BadgeLabel"
				dynamic_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				dynamic_badge.add_theme_font_size_override("font_size", 12)
				dynamic_badge.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 0.95))
				parent_box.add_child(dynamic_badge)
				parent_box.move_child(dynamic_badge, 0)
			dynamic_badge.text = "【%s】" % badge_text
			dynamic_badge.visible = true
	elif name_label:
		var parent_box := name_label.get_parent()
		if parent_box:
			var dynamic_badge := parent_box.get_node_or_null("BadgeLabel") as Label
			if dynamic_badge:
				dynamic_badge.visible = false
	
	# レア度カラーを枠線に適用（is_embedded の場合は完成予想用のオレンジ枠、ただし is_result の場合は確定レア度枠）
	var is_result: bool = item_data.get("is_result", false)
	var orange_color := Color(0.90, 0.47, 0.14, 1.0)
	var border_color := GameData.get_rarity_color(item_rarity) if (not is_embedded or is_result) else orange_color
	if item_data.has("border_color"):
		border_color = item_data["border_color"]
	if tooltip_panel:
		var style_box := tooltip_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if style_box:
			style_box.border_color = border_color
			tooltip_panel.add_theme_stylebox_override("panel", style_box)
		
	# アイコンの更新（is_embedded かつ not is_result の場合は鍛冶用背景を設定し、アイコン内のレベル表記を非表示）
	if equipment_icon:
		equipment_icon.set_show_icon_base(true)
		var icon_data: Dictionary = item_data.duplicate()
		if is_embedded and not is_result:
			icon_data["hide_level"] = true
			if not icon_data.has("bg_path"):
				icon_data["bg_path"] = "res://images/equip_bg/equip_bg_blacksmith.png"
		equipment_icon.update_item(icon_data)
		
	var forge_count: int = item_data.get("forge_count", 0)
	if name_label:
		if forge_count > 0:
			name_label.text = "%s[+%d]" % [item_name, forge_count]
		else:
			name_label.text = item_name
		if is_embedded and not is_result:
			name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 1))
		else:
			name_label.add_theme_color_override("font_color", GameData.get_rarity_color(item_rarity))
	if rarity_label:
		if item_data.has("rarity_bbcode") and not str(item_data["rarity_bbcode"]).is_empty():
			rarity_label.text = str(item_data["rarity_bbcode"])
			rarity_label.visible = true
		elif is_result or not is_embedded:
			var r_col := GameData.get_rarity_color(item_rarity)
			rarity_label.text = "[color=#%s]%s[/color]" % [r_col.to_html(false), item_rarity]
			rarity_label.visible = true
		else:
			rarity_label.visible = false
	if level_label:
		if item_data.has("level_str"):
			level_label.text = str(item_data["level_str"])
		else:
			level_label.text = "Lv.%d" % item_level
	set_max_skill_height(max_skill_height)
		
	# 装備中ボーナスレベルの判定
	var is_equipped := false
	var it_id: String = item_data.get("id", "")
	if not it_id.is_empty() and GameData.is_item_equipped(it_id) != "":
		is_equipped = true
	elif badge_text.find("装備中") != -1:
		is_equipped = true

	var bonus_lvl := 0
	if bonus_skill_level >= 0:
		bonus_lvl = bonus_skill_level
	elif is_equipped and not GameData.is_equip_disabled_challenge_active():
		bonus_lvl = GameData.get_c1_equipment_skill_bonus()

	var special_bonus_lvl := 0
	if bonus_skill_level >= 0:
		special_bonus_lvl = int(round(float(bonus_skill_level) * 0.1))
	elif is_equipped and not GameData.is_equip_disabled_challenge_active():
		special_bonus_lvl = GameData.get_c1_special_skill_bonus()

	# スキル説明の構築（通常スキルは深い青、特殊スキルは特殊スキルの紫）
	var item_equip_skills = item_data.get("equip_skill", [])
	var normal_lines := PackedStringArray()
	var special_lines := PackedStringArray()
	var normal_color_hex := "#6470f0"
	var special_color_hex := "#" + GameData.special_skill_color.to_html(false)
	
	if item_data.has("placeholder_message"):
		var msg: String = str(item_data["placeholder_message"])
		normal_lines.append("[color=#958fa8]%s[/color]" % msg)
		special_lines.append("[color=#58557a]・なし[/color]")
	else:
		for skill in item_equip_skills:
			var sk_name: String = skill.get("name", "")
			var sk_lvl: int = skill.get("level", 1)
			var is_spec: bool = skill.get("is_special", false)
			var raw_desc: String = skill.get("desc", "")
			var b_lvl := special_bonus_lvl if is_spec else bonus_lvl
			var effective_lvl := sk_lvl + b_lvl
			var display_desc := raw_desc

			# ボーナスが適用されている場合、効果テキストを実効レベルで再生成
			if b_lvl > 0:
				var sk_id: String = skill.get("id", "")
				if sk_id.is_empty():
					if is_spec:
						for k in GameData.special_skill_defs:
							if GameData.special_skill_defs[k].get("name", "") == sk_name:
								sk_id = k
								break
					else:
						for k in GameData.equipment_skill_defs:
							if GameData.equipment_skill_defs[k].get("name", "") == sk_name:
								sk_id = k
								break
				if not sk_id.is_empty():
					display_desc = GameData.format_equipment_skill_desc(sk_id, effective_lvl, is_spec)

			var crit_b_lvl: int = int(skill.get("crit_bonus_lvl", 0))
			var display_bonus: int = b_lvl
			if is_result and crit_b_lvl > 0:
				display_bonus = crit_b_lvl

			if is_spec:
				var forge_b: int = int(skill.get("forge_bonus_level", 0)) if (is_embedded and not is_result) else 0
				if forge_b > 0:
					var base_lvl: int = int(skill.get("base_level", sk_lvl - forge_b))
					var spec_tag := "[color=#73f273](+%d)[/color]" % forge_b
					special_lines.append("[color=%s]・%s [Lv. %d%s]: %s[/color]" % [special_color_hex, sk_name, base_lvl, spec_tag, display_desc])
				elif display_bonus > 0:
					var spec_tag := "[color=#73f273](+%d)[/color]" % display_bonus
					special_lines.append("[color=%s]・%s [Lv. %d%s]: %s[/color]" % [special_color_hex, sk_name, sk_lvl, spec_tag, display_desc])
				else:
					special_lines.append("[color=%s]・%s [Lv. %d]: %s[/color]" % [special_color_hex, sk_name, sk_lvl, display_desc])
			else:
				var forge_b: int = int(skill.get("forge_bonus_level", 0)) if (is_embedded and not is_result) else 0
				if forge_b > 0:
					var base_lvl: int = int(skill.get("base_level", sk_lvl - forge_b))
					var norm_tag := "[color=#73f273](+%d)[/color]" % forge_b
					normal_lines.append("[color=%s]・%s [Lv. %d%s][/color]" % [normal_color_hex, display_desc, base_lvl, norm_tag])
				elif display_bonus > 0:
					var norm_tag := "[color=#73f273](+%d)[/color]" % display_bonus
					normal_lines.append("[color=%s]・%s [Lv. %d%s][/color]" % [normal_color_hex, display_desc, sk_lvl, norm_tag])
				else:
					normal_lines.append("[color=%s]・%s [Lv. %d][/color]" % [normal_color_hex, display_desc, sk_lvl])
			
	if normal_lines.is_empty():
		normal_lines.append("[color=#58557a]・なし[/color]")
	if special_lines.is_empty():
		special_lines.append("[color=#58557a]・なし[/color]")
		
	# スキル間の余白（フォントサイズ1px分のわずかなスペースでほんの少しだけ隙間を空ける）
	var skill_spacing := "\n[font_size=1] \n[/font_size]"
	var can_pick_skills: bool = item_data.get("can_pick_skills", false)
	var max_pick_count: int = item_data.get("max_pick_count", 0)
	var picked_skill_ids_in: Array = item_data.get("picked_skill_ids", [])

	if is_embedded and not is_result and can_pick_skills and max_pick_count > 0 and not item_data.has("placeholder_message"):
		current_max_picks = max_pick_count
		current_picked_skill_ids.clear()
		for id in picked_skill_ids_in:
			current_picked_skill_ids.append(str(id))
		_setup_pickable_normal_skills(item_equip_skills, normal_color_hex)
	else:
		_cleanup_pickable_normal_skills()
		if normal_skill_label:
			normal_skill_label.visible = true
			normal_skill_label.text = skill_spacing.join(normal_lines)
		if normal_section_header:
			normal_section_header.text = "通常スキル候補" if (is_embedded and not is_result) else "通常スキル"

	if special_skill_label:
		special_skill_label.text = skill_spacing.join(special_lines)
	if special_section_header:
		special_section_header.text = "特殊スキル候補" if (is_embedded and not is_result) else "特殊スキル"
		special_section_header.add_theme_color_override("font_color", GameData.special_skill_color)
		
	# 旧ノードへのフォールバック（存在する場合）
	if equip_skill_label:
		var all_lines := PackedStringArray()
		all_lines.append_array(normal_lines)
		all_lines.append_array(special_lines)
		if equip_skill_label is RichTextLabel:
			(equip_skill_label as RichTextLabel).text = "\n".join(all_lines)
		elif equip_skill_label is Label:
			(equip_skill_label as Label).text = "\n".join(all_lines)


func _setup_pickable_normal_skills(item_equip_skills: Array, normal_color_hex: String) -> void:
	_cleanup_pickable_normal_skills()
	if normal_skill_label:
		normal_skill_label.visible = false

	if not _dynamic_skill_rows_container:
		_dynamic_skill_rows_container = VBoxContainer.new()
		_dynamic_skill_rows_container.name = "DynamicSkillRows"
		_dynamic_skill_rows_container.add_theme_constant_override("separation", 2)
		if normal_section:
			normal_section.add_child(_dynamic_skill_rows_container)

	_dynamic_skill_rows_container.visible = true

	var has_normal_skill := false
	for skill in item_equip_skills:
		if skill.get("is_special", false):
			continue
		has_normal_skill = true

		var sk_id: String = skill.get("id", "")
		var sk_name: String = skill.get("name", "")
		var sk_lvl: int = skill.get("level", 1)
		var raw_desc: String = skill.get("desc", "")
		if sk_id.is_empty():
			for k in GameData.equipment_skill_defs:
				if GameData.equipment_skill_defs[k].get("name", "") == sk_name:
					sk_id = k
					break

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 6)

		var chk_wrapper := MarginContainer.new()
		chk_wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		chk_wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
		chk_wrapper.add_theme_constant_override("margin_top", 2)
		row.add_child(chk_wrapper)

		var chk := CheckBox.new()
		chk.focus_mode = Control.FOCUS_NONE
		chk.mouse_filter = Control.MOUSE_FILTER_STOP
		chk.button_pressed = current_picked_skill_ids.has(sk_id)
		chk.text = ""
		chk.add_theme_constant_override("h_separation", 0)

		var unchk_tex := _get_custom_checkbox_texture(false)
		var chk_tex := _get_custom_checkbox_texture(true)
		chk.add_theme_icon_override("unchecked", unchk_tex)
		chk.add_theme_icon_override("unchecked_disabled", unchk_tex)
		chk.add_theme_icon_override("checked", chk_tex)
		chk.add_theme_icon_override("checked_disabled", chk_tex)

		chk_wrapper.add_child(chk)
		_skill_checkbox_map[sk_id] = chk

		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.scroll_active = false
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var forge_b: int = int(skill.get("forge_bonus_level", 0))
		if forge_b > 0:
			var base_lvl: int = int(skill.get("base_level", sk_lvl - forge_b))
			var norm_tag := "[color=#73f273](+%d)[/color]" % forge_b
			lbl.text = "[color=%s]%s [Lv. %d%s][/color]" % [normal_color_hex, raw_desc, base_lvl, norm_tag]
		else:
			lbl.text = "[color=%s]%s [Lv. %d][/color]" % [normal_color_hex, raw_desc, sk_lvl]
		row.add_child(lbl)

		# チェックボックストグル時の処理
		chk.toggled.connect(func(pressed: bool):
			_on_skill_checkbox_toggled(sk_id, pressed)
		)

		# ラベルクリックでもトグル可能にする
		lbl.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var target_chk: CheckBox = _skill_checkbox_map.get(sk_id)
				if target_chk:
					target_chk.button_pressed = not target_chk.button_pressed
		)

		_dynamic_skill_rows_container.add_child(row)

	if not has_normal_skill:
		var empty_lbl := RichTextLabel.new()
		empty_lbl.bbcode_enabled = true
		empty_lbl.fit_content = true
		empty_lbl.scroll_active = false
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_lbl.text = "[color=#58557a]・なし[/color]"
		_dynamic_skill_rows_container.add_child(empty_lbl)

	_update_pick_header()


func _on_skill_checkbox_toggled(sk_id: String, pressed: bool) -> void:
	if pressed:
		if not current_picked_skill_ids.has(sk_id):
			if current_picked_skill_ids.size() >= current_max_picks:
				# 上限に達しているためトグルをキャンセル
				var chk: CheckBox = _skill_checkbox_map.get(sk_id)
				if chk:
					chk.set_pressed_no_signal(false)
				return
			current_picked_skill_ids.append(sk_id)
	else:
		current_picked_skill_ids.erase(sk_id)

	_update_pick_header()
	skill_pick_changed.emit(current_picked_skill_ids.duplicate())


func _update_pick_header() -> void:
	if normal_section_header:
		normal_section_header.text = "通常スキル候補  選択済み %d/%d" % [current_picked_skill_ids.size(), current_max_picks]


func _cleanup_pickable_normal_skills() -> void:
	if _dynamic_skill_rows_container:
		for child in _dynamic_skill_rows_container.get_children():
			child.queue_free()
		_dynamic_skill_rows_container.visible = false
	_skill_checkbox_map.clear()


static var _chk_unchecked_icon: Texture2D = null
static var _chk_checked_icon: Texture2D = null

static func _get_custom_checkbox_texture(checked: bool) -> Texture2D:
	if checked and _chk_checked_icon:
		return _chk_checked_icon
	if not checked and _chk_unchecked_icon:
		return _chk_unchecked_icon

	var size := 14
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	if not checked:
		# 未チェック: 外枠を高コントラストな明るい白銀・薄水色、中身を暗い半透明スレートに
		var border_col := Color(0.85, 0.88, 0.98, 0.95)
		var inner_col := Color(0.14, 0.12, 0.20, 0.90)
		for y in range(size):
			for x in range(size):
				if x == 0 or x == size - 1 or y == 0 or y == size - 1:
					img.set_pixel(x, y, border_col)
				else:
					img.set_pixel(x, y, inner_col)
		_chk_unchecked_icon = ImageTexture.create_from_image(img)
		return _chk_unchecked_icon
	else:
		# チェック済み: 鮮やかなオレンジゴールドの背景に、高輝度な白のチェックマーク
		var bg_col := Color(0.95, 0.48, 0.12, 1.0)
		var border_col := Color(1.0, 0.80, 0.35, 1.0)
		for y in range(size):
			for x in range(size):
				if x == 0 or x == size - 1 or y == 0 or y == size - 1:
					img.set_pixel(x, y, border_col)
				else:
					img.set_pixel(x, y, bg_col)
		# チェックマーク（レ点）
		var check_points = [
			Vector2i(3, 7), Vector2i(3, 8),
			Vector2i(4, 8), Vector2i(4, 9),
			Vector2i(5, 9), Vector2i(5, 10),
			Vector2i(6, 8), Vector2i(6, 7),
			Vector2i(7, 6), Vector2i(7, 5),
			Vector2i(8, 4), Vector2i(8, 3),
			Vector2i(9, 2), Vector2i(10, 1)
		]
		for pt in check_points:
			if pt.x >= 0 and pt.x < size and pt.y >= 0 and pt.y < size:
				img.set_pixel(pt.x, pt.y, Color.WHITE)
		_chk_checked_icon = ImageTexture.create_from_image(img)
		return _chk_checked_icon
