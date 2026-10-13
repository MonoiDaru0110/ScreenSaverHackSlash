extends Control
class_name EquipmentIcon

@onready var slot_base: Panel = $SlotBase
@onready var bg_texture_rect: TextureRect = $BgTextureRect
@onready var icon_rect: TextureRect = $BgTextureRect/IconRect
@onready var question_label: Label = $BgTextureRect/QuestionLabel
@onready var level_label: Label = $LevelLabel
@onready var equip_border: Panel = $EquipBorder
@onready var icon_base: Panel = $IconBase
@onready var forge_label: Label = $ForgeLabel

func _ready() -> void:
	_ensure_nodes()

func _ensure_nodes() -> void:
	if not slot_base:
		slot_base = get_node_or_null("SlotBase") as Panel
	if not bg_texture_rect:
		bg_texture_rect = get_node_or_null("BgTextureRect") as TextureRect
	if not icon_rect and bg_texture_rect:
		icon_rect = bg_texture_rect.get_node_or_null("IconRect") as TextureRect
	if not question_label and bg_texture_rect:
		question_label = bg_texture_rect.get_node_or_null("QuestionLabel") as Label
	if not level_label:
		level_label = get_node_or_null("LevelLabel") as Label
	if not equip_border:
		equip_border = get_node_or_null("EquipBorder") as Panel
	if not icon_base:
		icon_base = get_node_or_null("IconBase") as Panel
	if not forge_label:
		forge_label = get_node_or_null("ForgeLabel") as Label

func update_item(eq: Variant) -> void:
	_ensure_nodes()
	if eq != null and not eq.is_empty():
		var item_icon: String = eq.get("icon", "")
		var item_rarity: String = eq.get("rarity", "コモン")
		var forge_count: int = eq.get("forge_count", 0)
		var show_question: bool = eq.get("show_question", false) or item_icon == "?"
		
		if slot_base:
			slot_base.visible = true
		if bg_texture_rect:
			bg_texture_rect.visible = true
			var bg_path := GameData.get_rarity_bg_path(item_rarity)
			var bg_tex := load(bg_path)
			bg_texture_rect.texture = bg_tex
		
		if show_question:
			if icon_rect:
				icon_rect.visible = false
			if question_label:
				question_label.visible = true
		else:
			if question_label:
				question_label.visible = false
			if icon_rect:
				if item_icon != "":
					var tex := load(item_icon)
					icon_rect.texture = tex
					icon_rect.visible = true
				else:
					icon_rect.texture = null
					icon_rect.visible = false
		
		if level_label:
			if eq.has("level_str"):
				level_label.text = str(eq.get("level_str"))
			elif eq.has("level"):
				level_label.text = "Lv%d" % eq.get("level", 1)
			else:
				level_label.text = ""
		
		if forge_label:
			if forge_count > 0:
				forge_label.text = "+%d" % forge_count
				forge_label.visible = true
			else:
				forge_label.text = ""
				forge_label.visible = false
	else:
		if slot_base:
			slot_base.visible = false
		if bg_texture_rect:
			bg_texture_rect.texture = null
			bg_texture_rect.visible = false
		if icon_rect:
			icon_rect.texture = null
			icon_rect.visible = false
		if question_label:
			question_label.visible = false
		if level_label:
			level_label.text = ""
		if forge_label:
			forge_label.text = ""
			forge_label.visible = false

func set_equipped_border(is_visible: bool) -> void:
	_ensure_nodes()
	if equip_border:
		equip_border.visible = is_visible

func set_show_icon_base(is_visible: bool) -> void:
	_ensure_nodes()
	if icon_base:
		icon_base.visible = is_visible
