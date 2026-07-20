extends PanelContainer
class_name SkillTooltip

@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var desc_label: Label = %DescLabel
@onready var icon_rect: TextureRect = %IconRect

var _target_node: SkillNode = null

# スキルごとのテーマカラー
const SKILL_COLORS := {
	"集中": Color(0.3, 0.5, 0.9),
	"見切り": Color(0.9, 0.3, 0.3),
	"巨大化": Color(0.3, 0.8, 0.4),
	"強撃": Color(0.95, 0.6, 0.2),
	"加速": Color(0.2, 0.8, 0.85),
	"幸運": Color(0.95, 0.85, 0.2)
}


func _ready() -> void:
	_ensure_nodes()
	_set_all_mouse_ignore(self)


func _set_all_mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_all_mouse_ignore(child)


func _ensure_nodes() -> void:
	if not tooltip_panel:
		tooltip_panel = %TooltipPanel as PanelContainer
	if not name_label:
		name_label = %NameLabel as Label
	if not level_label:
		level_label = %LevelLabel as Label
	if not desc_label:
		desc_label = %DescLabel as Label
	if not icon_rect:
		icon_rect = %IconRect as TextureRect


func setup(skill_data: Dictionary) -> void:
	_ensure_nodes()
	
	var skill_name: String = skill_data.get("name", "")
	var skill_level: int = skill_data.get("level", 1)
	var skill_desc: String = skill_data.get("desc", "")
	
	# スキルカラーの取得
	var skill_color: Color = SKILL_COLORS.get(skill_name, Color(0.6, 0.5, 0.8))
	
	# アイコンパネルの設定
	var icon_panel = get_node_or_null("TooltipMargin/TooltipPanel/PaddingMargin/VBoxContainer/Header/IconPanel")
	if icon_panel:
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = skill_color.darkened(0.4)
		icon_style.border_width_left = 5
		icon_style.border_width_top = 5
		icon_style.border_width_right = 5
		icon_style.border_width_bottom = 5
		icon_style.border_color = skill_color
		icon_style.corner_radius_top_left = 4
		icon_style.corner_radius_top_right = 4
		icon_style.corner_radius_bottom_right = 4
		icon_style.corner_radius_bottom_left = 4
		icon_panel.add_theme_stylebox_override("panel", icon_style)
		
		# アイコン画像または頭文字の表示
		var custom_icon_char: String = skill_data.get("icon_char", "")
		var icon_char_label = icon_panel.get_node_or_null("IconChar") as Label
		
		if custom_icon_char.begins_with("res://"):
			# 画像アイコンの場合
			if icon_char_label:
				icon_char_label.visible = false
			if icon_rect:
				icon_rect.visible = true
				icon_rect.texture = load(custom_icon_char)
		else:
			# 通常の頭文字表示の場合
			if icon_rect:
				icon_rect.visible = false
			if icon_char_label:
				icon_char_label.visible = true
				var disp_char = custom_icon_char if not custom_icon_char.is_empty() else skill_name.substr(0, 1)
				icon_char_label.text = disp_char
				icon_char_label.add_theme_color_override("font_color", skill_color.lightened(0.3))
	
	# テキストの設定
	if name_label:
		name_label.text = skill_name
		name_label.add_theme_color_override("font_color", skill_color.lightened(0.2))
	if level_label:
		if skill_data.has("level_string"):
			level_label.text = skill_data.get("level_string", "")
		else:
			level_label.text = "Lv.%d" % skill_level
	if desc_label:
		desc_label.text = skill_desc
		
	# ツールチップ本体の外枠（アウトライン）のカラー変更
	if tooltip_panel:
		var tooltip_style := tooltip_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if tooltip_style:
			tooltip_style.border_color = skill_color
			tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)


func setup_from_node(skill_node: SkillNode) -> void:
	_ensure_nodes()
	
	_target_node = skill_node
	
	# シグナルへの接続 (購入時やトークン変動時にその場で再更新)
	if not GameData.skill_upgraded.is_connected(_on_skill_data_changed):
		GameData.skill_upgraded.connect(_on_skill_data_changed)
	if not GameData.tokens_changed.is_connected(_on_tokens_changed):
		GameData.tokens_changed.connect(_on_tokens_changed)
	
	var current_level = GameData.skill_levels.get(skill_node.skill_id, 0)
	var max_level = skill_node.max_level
	var cost = skill_node.get_upgrade_cost(current_level)
	
	var lvl_str = "MAX" if current_level >= max_level else "Lvl %d/%d" % [current_level, max_level]
	var cost_str = "最大レベルに達しました" if current_level >= max_level else "コスト: 💎 %d" % cost
	
	var skill_name = skill_node.skill_name if not skill_node.skill_name.is_empty() else skill_node.skill_id
	var full_desc = skill_node.description
	if not cost_str.is_empty():
		full_desc += "\n" + cost_str
		
	# 1. アイコンパネルのスタイルと枠線の完全流用
	var icon_panel = get_node_or_null("TooltipMargin/TooltipPanel/PaddingMargin/VBoxContainer/Header/IconPanel")
	var border_color = Color(0.35, 0.4, 0.55) # デフォルト色
	
	if icon_panel:
		# SkillNodeから現在適用されているスタイルボックスを直接取得して流用する
		var node_style = skill_node.get_theme_stylebox("normal")
		if node_style is StyleBoxFlat:
			var icon_style = node_style.duplicate() as StyleBoxFlat
			# ツールチップの小さなアイコン内に収まるよう拡張マージンをリセット
			icon_style.expand_margin_left = 0
			icon_style.expand_margin_top = 0
			icon_style.expand_margin_right = 0
			icon_style.expand_margin_bottom = 0
			# 枠線の太さを3pxにスケールダウンして、36x36の枠内でちょうど良くなるように調整
			icon_style.border_width_left = 6
			icon_style.border_width_top = 6
			icon_style.border_width_right = 6
			icon_style.border_width_bottom = 6
			icon_panel.add_theme_stylebox_override("panel", icon_style)
			border_color = icon_style.border_color
		
		# アイコン画像または頭文字の表示
		var icon_char_label = icon_panel.get_node_or_null("IconChar") as Label
		
		if skill_node._icon_texture:
			# 画像アイコンがある場合
			if icon_char_label:
				icon_char_label.visible = false
			if icon_rect:
				icon_rect.visible = true
				icon_rect.texture = skill_node._icon_texture
		else:
			# 通常の頭文字表示の場合
			if icon_rect:
				icon_rect.visible = false
			if icon_char_label:
				icon_char_label.visible = true
				icon_char_label.text = skill_node.icon_char
				icon_char_label.add_theme_color_override("font_color", border_color.lightened(0.2))
				
	# 2. テキストの設定
	if name_label:
		name_label.text = skill_name
		name_label.add_theme_color_override("font_color", border_color.lightened(0.2))
	if level_label:
		level_label.text = lvl_str
	if desc_label:
		desc_label.text = full_desc
		
	# 3. ツールチップ本体の外枠（アウトライン）のカラー変更
	if tooltip_panel:
		var tooltip_style := tooltip_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if tooltip_style:
			tooltip_style.border_color = border_color
			tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)


func _on_skill_data_changed(upgraded_skill_id: String, _new_level: int) -> void:
	if _target_node and _target_node.skill_id == upgraded_skill_id:
		# ノード側の更新がすべて完了した次フレームで同期更新を行う
		call_deferred(&"setup_from_node", _target_node)


func _on_tokens_changed(_new_tokens: int) -> void:
	if _target_node:
		call_deferred(&"setup_from_node", _target_node)
