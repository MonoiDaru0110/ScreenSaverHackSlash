extends PanelContainer
class_name EquipmentTooltip

@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var equipment_icon: EquipmentIcon = %EquipmentIcon
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var normal_skill_label: RichTextLabel = get_node_or_null("%NormalSkillLabel") as RichTextLabel
@onready var special_skill_label: RichTextLabel = get_node_or_null("%SpecialSkillLabel") as RichTextLabel
@onready var special_section_header: Label = get_node_or_null("%SpecialSectionHeader") as Label
@onready var separator_2: ColorRect = get_node_or_null("%Separator2") as ColorRect
@onready var equip_skill_label: Control = get_node_or_null("%EquipSkillLabel") as Control


func _ready() -> void:
	z_index = 50
	z_as_relative = false
	_ensure_nodes()
	# ツールチップ内の全ノードがマウスイベントを消費しないようにする
	# （EquipmentIcon 内部 of LevelLabel 等も含めて再帰的に設定）
	_set_all_mouse_ignore(self)


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
	if not name_label:
		name_label = %NameLabel as Label
	if not level_label:
		level_label = %LevelLabel as Label
	if not normal_skill_label:
		normal_skill_label = get_node_or_null("%NormalSkillLabel") as RichTextLabel
	if not special_skill_label:
		special_skill_label = get_node_or_null("%SpecialSkillLabel") as RichTextLabel
	if not special_section_header:
		special_section_header = get_node_or_null("%SpecialSectionHeader") as Label
	if not separator_2:
		separator_2 = get_node_or_null("%Separator2") as ColorRect
	if not equip_skill_label:
		equip_skill_label = get_node_or_null("%EquipSkillLabel") as Control


func setup(item_data: Dictionary, badge_text: String = "", bonus_skill_level: int = -1) -> void:
	_ensure_nodes()
	
	var item_name: String = item_data.get("name", "")
	var item_rarity: String = item_data.get("rarity", "コモン")
	var item_level: int = item_data.get("level", 1)

	# 比較用バッジ（装備中スロット名など）の表示
	var badge_label: Label = get_node_or_null("%BadgeLabel")
	if badge_text != "":
		if not badge_label and name_label:
			var parent_box := name_label.get_parent()
			if parent_box:
				badge_label = Label.new()
				badge_label.name = "BadgeLabel"
				badge_label.unique_name_in_owner = true
				badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				badge_label.add_theme_font_size_override("font_size", 12)
				badge_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 0.95))
				badge_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
				badge_label.add_theme_constant_override("shadow_offset_x", 1)
				badge_label.add_theme_constant_override("shadow_offset_y", 1)
				parent_box.add_child(badge_label)
				parent_box.move_child(badge_label, 0)
		if badge_label:
			badge_label.text = "【%s】" % badge_text
			badge_label.visible = true
	else:
		if badge_label:
			badge_label.visible = false
	
	# レア度カラーを枠線に適用
	var rarity_color := GameData.get_rarity_color(item_rarity)
	if tooltip_panel:
		var style_box := tooltip_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if style_box:
			style_box.border_color = rarity_color
			tooltip_panel.add_theme_stylebox_override("panel", style_box)
		
	# アイコンの更新
	if equipment_icon:
		equipment_icon.set_show_icon_base(true)
		equipment_icon.update_item(item_data)
		
	var forge_count: int = item_data.get("forge_count", 0)
	if name_label:
		if forge_count > 0:
			name_label.text = "%s[+%d]" % [item_name, forge_count]
		else:
			name_label.text = item_name
		name_label.add_theme_color_override("font_color", rarity_color)
	if level_label:
		level_label.text = "Lv.%d" % item_level
		
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

	var bonus_tag := ""
	if bonus_lvl > 0:
		bonus_tag = "[color=#73f273](+%d)[/color]" % bonus_lvl

	# スキル説明の構築（通常スキルは深い青、特殊スキルは特殊スキルの紫）
	var item_equip_skills = item_data.get("equip_skill", [])
	var normal_lines := PackedStringArray()
	var special_lines := PackedStringArray()
	var normal_color_hex := "#6470f0"
	var special_color_hex := "#" + GameData.special_skill_color.to_html(false)
	
	for skill in item_equip_skills:
		var sk_name: String = skill.get("name", "")
		var sk_lvl: int = skill.get("level", 1)
		var is_spec: bool = skill.get("is_special", false)
		var raw_desc: String = skill.get("desc", "")
		var effective_lvl := sk_lvl + bonus_lvl
		var display_desc := raw_desc

		# ボーナスが適用されている場合、効果テキストを実効レベルで再生成
		if bonus_lvl > 0:
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

		if is_spec:
			if bonus_lvl > 0:
				special_lines.append("[color=%s]・%s [Lv. %d%s]: %s[/color]" % [special_color_hex, sk_name, sk_lvl, bonus_tag, display_desc])
			else:
				special_lines.append("[color=%s]・%s [Lv. %d]: %s[/color]" % [special_color_hex, sk_name, sk_lvl, display_desc])
		else:
			if bonus_lvl > 0:
				normal_lines.append("[color=%s]・%s [Lv. %d%s][/color]" % [normal_color_hex, display_desc, sk_lvl, bonus_tag])
			else:
				normal_lines.append("[color=%s]・%s [Lv. %d][/color]" % [normal_color_hex, display_desc, sk_lvl])
			
	if normal_lines.is_empty():
		normal_lines.append("[color=#58557a]・なし[/color]")
	if special_lines.is_empty():
		special_lines.append("[color=#58557a]・なし[/color]")
		
	# スキル間の余白（フォントサイズ1px分のわずかなスペースでほんの少しだけ隙間を空ける）
	var skill_spacing := "\n[font_size=1] \n[/font_size]"
	if normal_skill_label:
		normal_skill_label.text = skill_spacing.join(normal_lines)
	if special_skill_label:
		special_skill_label.text = skill_spacing.join(special_lines)
	if special_section_header:
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
