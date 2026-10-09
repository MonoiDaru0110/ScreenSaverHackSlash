class_name BaseWindow
extends PanelContainer
## Reusable Base Window component with desktop GUI-style distinctive titlebar and dark body.

signal closed()

@export var window_title: String = "ウィンドウ":
	set(val):
		window_title = val
		_ensure_nodes()
		if _title_label:
			_title_label.text = val

@export var header_color: Color = Color(0.14, 0.20, 0.30, 1.0):
	set(val):
		header_color = val
		_apply_header_style()

@export var body_color: Color = Color(0.08, 0.08, 0.14, 1.0):
	set(val):
		body_color = val
		_apply_body_style()

@export var separator_color: Color = Color(0.2, 0.2, 0.35, 1.0):
	set(val):
		separator_color = val
		_ensure_nodes()
		if _separator:
			_separator.color = val

@export var header_height: float = 48.0:
	set(val):
		header_height = val
		_apply_header_height()

@export var show_close_button: bool = true:
	set(val):
		show_close_button = val
		_ensure_nodes()
		if _close_btn:
			_close_btn.visible = val

var _header_panel: PanelContainer
var _header_margin: MarginContainer
var _header_hbox: HBoxContainer
var _title_label: Label
var _header_controls: HBoxContainer
var _separator: ColorRect
var _body_panel: PanelContainer
var _body_margin: MarginContainer
var _content_container: VBoxContainer
var _close_btn: CloseButton


func _ensure_nodes() -> void:
	if not _header_panel:
		_header_panel = get_node_or_null("WindowVBox/HeaderPanel") as PanelContainer
	if not _header_margin:
		_header_margin = get_node_or_null("WindowVBox/HeaderPanel/HeaderMargin") as MarginContainer
	if not _header_hbox:
		_header_hbox = get_node_or_null("WindowVBox/HeaderPanel/HeaderMargin/HeaderHBox") as HBoxContainer
	if not _title_label and _header_hbox:
		_title_label = _header_hbox.get_node_or_null("TitleLabel") as Label
	if not _header_controls and _header_hbox:
		_header_controls = _header_hbox.get_node_or_null("HeaderControls") as HBoxContainer
	if not _close_btn and _header_hbox:
		for child in _header_hbox.get_children():
			if child is CloseButton:
				_close_btn = child
				break
	if not _close_btn:
		_close_btn = get_node_or_null("WindowVBox/HeaderPanel/HeaderMargin/HeaderHBox/CloseBtn") as CloseButton
	if not _close_btn:
		_close_btn = get_node_or_null("WindowVBox/HeaderPanel/HeaderMargin/HeaderHBox/CloseWindowBtn") as CloseButton
	if not _close_btn:
		_close_btn = get_node_or_null("WindowVBox/HeaderPanel/HeaderMargin/HeaderHBox/CloseInventoryBtn") as CloseButton
	if not _separator:
		_separator = get_node_or_null("WindowVBox/Separator") as ColorRect
	if not _body_panel:
		_body_panel = get_node_or_null("WindowVBox/BodyPanel") as PanelContainer
	if not _body_margin:
		_body_margin = get_node_or_null("WindowVBox/BodyPanel/BodyMargin") as MarginContainer
	if not _content_container:
		_content_container = get_node_or_null("WindowVBox/BodyPanel/BodyMargin/ContentContainer") as VBoxContainer


func _ready() -> void:
	_ensure_nodes()
	
	# Make root container background transparent since Header and Body panels draw their own backgrounds
	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", empty_style)
	
	if _title_label:
		_title_label.text = window_title
	
	_apply_header_style()
	_apply_body_style()
	_apply_header_height()
	
	if _separator:
		_separator.color = separator_color
		
	if _close_btn:
		_close_btn.visible = show_close_button
		if not _close_btn.pressed.is_connected(_on_close_btn_pressed):
			_close_btn.pressed.connect(_on_close_btn_pressed)


func _apply_header_style() -> void:
	_ensure_nodes()
	if not _header_panel:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = header_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	_header_panel.add_theme_stylebox_override("panel", style)


func _apply_body_style() -> void:
	_ensure_nodes()
	if not _body_panel:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = body_color
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_body_panel.add_theme_stylebox_override("panel", style)


func _apply_header_height() -> void:
	_ensure_nodes()
	if _header_panel:
		_header_panel.custom_minimum_size = Vector2(0, header_height)
	if _close_btn:
		var btn_sz := header_height + 2.0
		_close_btn.custom_minimum_size = Vector2(btn_sz, btn_sz)
		_close_btn.apply_styles()


func _on_close_btn_pressed() -> void:
	closed.emit()


func get_content_container() -> VBoxContainer:
	return _content_container


func get_header_controls() -> HBoxContainer:
	return _header_controls


func get_title_label() -> Label:
	return _title_label


func get_close_button() -> CloseButton:
	return _close_btn
