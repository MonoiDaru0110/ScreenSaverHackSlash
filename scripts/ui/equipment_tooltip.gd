extends PanelContainer
class_name EquipmentTooltip

@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var equipment_icon: EquipmentIcon = %EquipmentIcon
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var equip_skill_label: Label = %EquipSkillLabel


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
		equip_skill_label = %EquipSkillLabel as Label


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
		
	# スキル説明の構築（全スキルを改行区切りで1つのLabelにセット）
	if equip_skill_label:
		var item_equip_skills = item_data.get("equip_skill", [])
		var lines := PackedStringArray()
		for skill in item_equip_skills:
			lines.append("%s+%d: %s" % [
				skill.get("name", ""),
				skill.get("level", 1),
				skill.get("desc", "")
			])
		equip_skill_label.text = "\n".join(lines)
