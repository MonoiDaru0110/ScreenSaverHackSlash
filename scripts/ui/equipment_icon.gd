extends Control
class_name EquipmentIcon

@onready var slot_base: Panel = $SlotBase
@onready var bg_texture_rect: TextureRect = $BgTextureRect
@onready var icon_rect: TextureRect = $BgTextureRect/IconRect
@onready var level_label: Label = $LevelLabel
@onready var equip_border: Panel = $EquipBorder
@onready var icon_base: Panel = $IconBase

func _ready() -> void:
	_ensure_nodes()

func _ensure_nodes() -> void:
	if not slot_base:
		slot_base = get_node_or_null("SlotBase") as Panel
	if not bg_texture_rect:
		bg_texture_rect = get_node_or_null("BgTextureRect") as TextureRect
	if not icon_rect and bg_texture_rect:
		icon_rect = bg_texture_rect.get_node_or_null("IconRect") as TextureRect
	if not level_label:
		level_label = get_node_or_null("LevelLabel") as Label
	if not equip_border:
		equip_border = get_node_or_null("EquipBorder") as Panel
	if not icon_base:
		icon_base = get_node_or_null("IconBase") as Panel

func update_item(eq: Variant) -> void:
	_ensure_nodes()
	if eq != null and not eq.is_empty():
		var item_icon: String = eq.get("icon", "")
		var item_level: int = eq.get("level", 1)
		var item_rarity: String = eq.get("rarity", "コモン")
		
		if slot_base:
			slot_base.visible = true
		if bg_texture_rect:
			bg_texture_rect.visible = true
			var bg_path := GameData.get_rarity_bg_path(item_rarity)
			var bg_tex := load(bg_path)
			bg_texture_rect.texture = bg_tex
		if icon_rect:
			if item_icon != "":
				var tex := load(item_icon)
				icon_rect.texture = tex
				icon_rect.visible = true
			else:
				icon_rect.texture = null
				icon_rect.visible = false
		if level_label:
			level_label.text = "Lv%d" % item_level
	else:
		if slot_base:
			slot_base.visible = false
		if bg_texture_rect:
			bg_texture_rect.texture = null
			bg_texture_rect.visible = false
		if icon_rect:
			icon_rect.texture = null
			icon_rect.visible = false
		if level_label:
			level_label.text = ""

func set_equipped_border(is_visible: bool) -> void:
	_ensure_nodes()
	if equip_border:
		equip_border.visible = is_visible

func set_show_icon_base(is_visible: bool) -> void:
	_ensure_nodes()
	if icon_base:
		icon_base.visible = is_visible
