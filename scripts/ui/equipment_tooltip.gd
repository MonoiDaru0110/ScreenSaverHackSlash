extends PanelContainer
class_name EquipmentTooltip

@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var equipment_icon: EquipmentIcon = %EquipmentIcon
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var equip_skill_label: Control = %EquipSkillLabel


func _ready() -> void:
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
	if not equip_skill_label:
		equip_skill_label = %EquipSkillLabel as Control


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
		
	# テキストの更新
	if name_label:
		name_label.text = item_name
		name_label.add_theme_color_override("font_color", rarity_color)
	if level_label:
		level_label.text = "Lv.%d" % item_level
		
	# スキル説明の構築（スキルレベルおよび効果数値の+部分を薄緑色 #b2ebb2 でハイライト）
	if equip_skill_label:
		var item_equip_skills = item_data.get("equip_skill", [])
		var lines := PackedStringArray()
		var green_color := "#b2ebb2" # 右装備欄のスキルレベルカラー Color(0.7, 0.9, 0.7)
		
		var regex := RegEx.new()
		regex.compile("(?:\\+|x|×|\\*)?\\d+(?:\\.\\d+)?%?")
		
		for skill in item_equip_skills:
			var sk_name: String = skill.get("name", "")
			var sk_lvl: int = skill.get("level", 1)
			var is_spec: bool = skill.get("is_special", false)
			
			if is_spec:
				var spec_hex = GameData.special_skill_color.to_html()
				sk_name = "[color=#%s]%s[/color]" % [spec_hex, sk_name]

			var level_str := "[color=%s]+%d[/color]" % [green_color, sk_lvl]
			var raw_desc: String = skill.get("desc", "")
			var highlighted_desc := regex.sub(raw_desc, "[color=%s]$0[/color]" % green_color, true)
			
			lines.append("%s %s: %s" % [sk_name, level_str, highlighted_desc])
			
		if equip_skill_label is RichTextLabel:
			(equip_skill_label as RichTextLabel).text = "\n".join(lines)
		elif equip_skill_label is Label:
			(equip_skill_label as Label).text = "\n".join(lines)
