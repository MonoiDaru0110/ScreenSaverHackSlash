class_name CloseButton
extends Button
## Reusable Close (×) Button component for windows.
## Provides unified visual styling, strict square aspect ratio, and large crisp centered × mark.

@export var mark_color: Color = Color(0.24, 0.08, 0.05, 1.0)
@export var mark_hover_color: Color = Color(0.18, 0.06, 0.04, 1.0)
@export var mark_pressed_color: Color = Color(0.12, 0.04, 0.02, 1.0)
@export var bg_normal_color: Color = Color(0.70, 0.26, 0.18, 1.0)
@export var bg_hover_color: Color = Color(0.82, 0.34, 0.24, 1.0)
@export var bg_pressed_color: Color = Color(0.55, 0.18, 0.12, 1.0)
@export var border_color: Color = Color(0.0, 0.0, 0.0, 1.0)

@onready var _mark_label: Label = get_node_or_null("%MarkLabel")


func _ready() -> void:
	if not _mark_label:
		_mark_label = get_node_or_null("MarkLabel")
	if not _mark_label:
		_mark_label = Label.new()
		_mark_label.name = "MarkLabel"
		_mark_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_mark_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_mark_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		_mark_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_mark_label)

	text = ""
	apply_styles()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func apply_styles() -> void:
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = bg_normal_color
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = border_color
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_right = 4
	style_normal.corner_radius_bottom_left = 6
	style_normal.content_margin_left = 0
	style_normal.content_margin_top = 0
	style_normal.content_margin_right = 0
	style_normal.content_margin_bottom = 0
	
	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = bg_hover_color
	
	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = bg_pressed_color
	
	add_theme_stylebox_override("normal", style_normal)
	add_theme_stylebox_override("hover", style_hover)
	add_theme_stylebox_override("pressed", style_pressed)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	var h: float = custom_minimum_size.y if custom_minimum_size.y > 0 else (custom_minimum_size.x if custom_minimum_size.x > 0 else 50.0)
	custom_minimum_size = Vector2(h, h)
	
	if _mark_label:
		_mark_label.text = "×"
		_mark_label.add_theme_color_override("font_color", mark_color)
		var font_sz := int(round(h * 0.92))
		_mark_label.add_theme_font_size_override("font_size", font_sz)


func _on_mouse_entered() -> void:
	if _mark_label:
		_mark_label.add_theme_color_override("font_color", mark_hover_color)


func _on_mouse_exited() -> void:
	if _mark_label:
		_mark_label.add_theme_color_override("font_color", mark_color)


func _on_button_down() -> void:
	if _mark_label:
		_mark_label.add_theme_color_override("font_color", mark_pressed_color)


func _on_button_up() -> void:
	if _mark_label:
		if is_hovered():
			_mark_label.add_theme_color_override("font_color", mark_hover_color)
		else:
			_mark_label.add_theme_color_override("font_color", mark_color)
