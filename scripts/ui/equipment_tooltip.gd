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


func setup(item_data: Dictionary) -> void:
	_ensure_nodes()
	
	var item_name: String = item_data.get("name", "")
	var item_rarity: String = item_data.get("rarity", "コモン")
	var item_level: int = item_data.get("level", 1)
	
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
		
		if is_spec:
			special_lines.append("[color=%s]・%s +%d: %s[/color]" % [special_color_hex, sk_name, sk_lvl, raw_desc])
		else:
			normal_lines.append("[color=%s]・%s [Lv.%d][/color]" % [normal_color_hex, raw_desc, sk_lvl])
			
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
