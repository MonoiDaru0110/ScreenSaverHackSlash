class_name AutomationCardBase
extends PanelContainer
## Base component for automation cards with distinct header bar and rounded body.

@export var card_title: String = "カードタイトル":
	set(val):
		card_title = val
		_ensure_nodes()
		if _title_label:
			_title_label.text = val

@export var header_color: Color = Color(0.36, 0.36, 0.40, 1.0):
	set(val):
		header_color = val
		_apply_header_style()

@export var body_color: Color = Color(0.20, 0.20, 0.23, 0.95):
	set(val):
		body_color = val
		_apply_body_style()

@export var border_color: Color = Color(0.34, 0.34, 0.38, 0.8):
	set(val):
		border_color = val
		_apply_body_style()

@export var separator_color: Color = Color(0.48, 0.48, 0.54, 1.0):
	set(val):
		separator_color = val
		_ensure_nodes()
		if _separator:
			_separator.color = val

var _header_panel: PanelContainer
var _title_label: Label
var _header_controls: HBoxContainer
var _separator: ColorRect
var _body_panel: PanelContainer
var _content_container: VBoxContainer


func _ready() -> void:
	_ensure_nodes()
	_apply_header_style()
	_apply_body_style()
	if _title_label:
		_title_label.text = card_title
	if _separator:
		_separator.color = separator_color


func _ensure_nodes() -> void:
	if not _header_panel:
		_header_panel = get_node_or_null("%HeaderPanel") as PanelContainer
		if not _header_panel:
			_header_panel = get_node_or_null("CardVBox/HeaderPanel") as PanelContainer
	if not _title_label:
		_title_label = get_node_or_null("%CardTitleLabel") as Label
		if not _title_label:
			_title_label = get_node_or_null("CardVBox/HeaderPanel/HeaderMargin/HeaderHBox/CardTitleLabel") as Label
	if not _header_controls:
		_header_controls = get_node_or_null("%HeaderControls") as HBoxContainer
		if not _header_controls:
			_header_controls = get_node_or_null("CardVBox/HeaderPanel/HeaderMargin/HeaderHBox/HeaderControls") as HBoxContainer
	if not _separator:
		_separator = get_node_or_null("%Separator") as ColorRect
		if not _separator:
			_separator = get_node_or_null("CardVBox/Separator") as ColorRect
	if not _body_panel:
		_body_panel = get_node_or_null("%BodyPanel") as PanelContainer
		if not _body_panel:
			_body_panel = get_node_or_null("CardVBox/BodyPanel") as PanelContainer
	if not _content_container:
		_content_container = get_node_or_null("%ContentContainer") as VBoxContainer
		if not _content_container:
			_content_container = get_node_or_null("CardVBox/BodyPanel/BodyMargin/ContentContainer") as VBoxContainer


func _apply_header_style() -> void:
	_ensure_nodes()
	if not _header_panel:
		return
	var style := _header_panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style = style.duplicate() as StyleBoxFlat
	else:
		style = StyleBoxFlat.new()
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
	style.bg_color = header_color
	_header_panel.add_theme_stylebox_override("panel", style)


func _apply_body_style() -> void:
	_ensure_nodes()
	if not _body_panel:
		return
	var style := _body_panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style = style.duplicate() as StyleBoxFlat
	else:
		style = StyleBoxFlat.new()
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	style.bg_color = body_color
	style.border_color = border_color
	_body_panel.add_theme_stylebox_override("panel", style)


# ==============================================================================
# チェックボックス装飾ヘルパー (チャレンジウィンドウ風の鮮やかな緑チェックマーク)
# ==============================================================================

static var _cached_checked_tex: ImageTexture
static var _cached_unchecked_tex: ImageTexture


static func setup_green_checkbox(cb: CheckBox) -> void:
	if not cb:
		return
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_icon_override("checked", get_green_checked_texture())
	cb.add_theme_icon_override("unchecked", get_unchecked_texture())
	cb.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	cb.add_theme_color_override("font_pressed_color", Color(0.92, 0.94, 0.98, 1.0))
	cb.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	cb.add_theme_color_override("font_hover_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	cb.add_theme_constant_override("h_separation", 8)


static func get_green_checked_texture() -> Texture2D:
	if _cached_checked_tex:
		return _cached_checked_tex
	var size := 22
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var green := Color(0.32, 0.72, 0.18, 1.0) # チャレンジウィンドウのクリアバッジ緑
	var border := Color(0.18, 0.45, 0.08, 1.0) # 濃い緑の枠線
	var white := Color(1.0, 1.0, 1.0, 1.0)

	for y in range(size):
		for x in range(size):
			var is_corner := (x == 0 and (y == 0 or y == size - 1)) or (x == size - 1 and (y == 0 or y == size - 1))
			if is_corner:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var is_border := (x == 0 or x == size - 1 or y == 0 or y == size - 1)
			img.set_pixel(x, y, border if is_border else green)

	# チェックマーク "✓" の描画
	_draw_thick_line(img, Vector2i(5, 11), Vector2i(9, 15), white, 2)
	_draw_thick_line(img, Vector2i(9, 15), Vector2i(17, 6), white, 2)

	_cached_checked_tex = ImageTexture.create_from_image(img)
	return _cached_checked_tex


static func get_unchecked_texture() -> Texture2D:
	if _cached_unchecked_tex:
		return _cached_unchecked_tex
	var size := 22
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bg := Color(0.13, 0.13, 0.16, 1.0)
	var border := Color(0.38, 0.38, 0.44, 1.0)

	for y in range(size):
		for x in range(size):
			var is_corner := (x == 0 and (y == 0 or y == size - 1)) or (x == size - 1 and (y == 0 or y == size - 1))
			if is_corner:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var is_border := (x == 0 or x == size - 1 or y == 0 or y == size - 1)
			img.set_pixel(x, y, border if is_border else bg)

	_cached_unchecked_tex = ImageTexture.create_from_image(img)
	return _cached_unchecked_tex


static func _draw_thick_line(img: Image, from: Vector2i, to: Vector2i, col: Color, width: int) -> void:
	var dx := absi(to.x - from.x)
	var dy := -absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var err := dx + dy
	var x := from.x
	var y := from.y
	var half := width / 2
	while true:
		for ox in range(-half, width - half):
			for oy in range(-half, width - half):
				var px := x + ox
				var py := y + oy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, col)
		if x == to.x and y == to.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

