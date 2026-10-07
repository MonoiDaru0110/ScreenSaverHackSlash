extends Control

# スイッチUIのレイアウト定数
const UI_WIDTH := 260.0
const UI_HEIGHT := 104.0

const BEZEL_RECT := Rect2(10.0, 10.0, 240.0, 52.0)
const BTN_GOLD_RECT := Rect2(14.0, 14.0, 114.0, 44.0)
const BTN_TOKEN_RECT := Rect2(132.0, 14.0, 114.0, 44.0)
const BTN_RESET_RECT := Rect2(70.0, 68.0, 120.0, 26.0)

var skill_level: int = 1
var _hovered_btn: String = "" # "gold", "token", "reset", ""


func _ready() -> void:
	custom_minimum_size = Vector2(UI_WIDTH, UI_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	GameData.switch_changed.connect(queue_redraw)
	GameData.upgrades_changed.connect(_on_upgrades_changed)
	GameData.equipment_changed.connect(_on_equipment_changed)
	_update_level()
	queue_redraw()


func _process(_delta: float) -> void:
	# ブースト中またはホバー中の発光パルスアニメーション
	if is_inside_tree() and is_visible_in_tree() and GameData.is_switch_active():
		queue_redraw()


func set_skill_data(sk_data: Dictionary) -> void:
	skill_level = int(sk_data.get("level", 1))
	queue_redraw()


func _update_level() -> void:
	skill_level = GameData.get_special_skill_total_level("spec_switch")


func _on_upgrades_changed() -> void:
	_update_level()
	queue_redraw()


func _on_equipment_changed() -> void:
	_update_level()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		var old_hover := _hovered_btn
		if BTN_GOLD_RECT.has_point(pos):
			_hovered_btn = "gold"
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		elif BTN_TOKEN_RECT.has_point(pos):
			_hovered_btn = "token"
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		elif BTN_RESET_RECT.has_point(pos):
			_hovered_btn = "reset"
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			_hovered_btn = ""
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		if old_hover != _hovered_btn:
			queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if BTN_GOLD_RECT.has_point(pos):
			# 押下されたボタンを再度押してもデフォルトに戻らず、そのまま選択状態を維持
			GameData.set_switch_target("gold")
			accept_event()
		elif BTN_TOKEN_RECT.has_point(pos):
			# 押下されたボタンを再度押してもデフォルトに戻らず、そのまま選択状態を維持
			GameData.set_switch_target("token")
			accept_event()
		elif BTN_RESET_RECT.has_point(pos):
			# リセットボタンを押すとデフォルト状態に戻る
			GameData.reset_switch()
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if _hovered_btn != "":
			_hovered_btn = ""
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var sac_type := GameData.switch_sacrificed_type
	var is_active := GameData.is_switch_active()
	var mult := GameData.get_switch_multiplier()
	var mult_str := "x%s" % GameData.format_num(mult)
	var time := Time.get_ticks_msec() * 0.001
	var pulse := 0.8 + 0.2 * sin(time * 4.0)

	# --- 1. 背景パネル (外枠カード・不透明度の高いレクトを拡張) ---
	var card_rect := Rect2(0, 0, UI_WIDTH, UI_HEIGHT)
	var card_bg := Color(0.08, 0.06, 0.12, 0.92)
	var card_border := Color(0.28, 0.22, 0.38, 0.6)
	draw_rect(card_rect, card_bg)
	draw_rect(card_rect, card_border, false, 1.0)

	# --- 2. ロッカースイッチのベゼル（外枠・溝の立体感） ---
	# 外側の盛り上がりベゼル枠
	draw_rect(BEZEL_RECT.grow(1.5), Color(0.18, 0.16, 0.22))
	# 内側の深いくぼみ（陰影）
	draw_rect(BEZEL_RECT, Color(0.05, 0.04, 0.07))
	# ベゼル上辺の内側影
	draw_line(Vector2(BEZEL_RECT.position.x, BEZEL_RECT.position.y + 1),
			  Vector2(BEZEL_RECT.end.x, BEZEL_RECT.position.y + 1),
			  Color(0.0, 0.0, 0.0, 0.8), 2.0)
	# ベゼル下辺のハイライト
	draw_line(Vector2(BEZEL_RECT.position.x, BEZEL_RECT.end.y - 1),
			  Vector2(BEZEL_RECT.end.x, BEZEL_RECT.end.y - 1),
			  Color(0.35, 0.32, 0.45, 0.4), 1.0)

	# 中央ピボット分割ライン (シーソーの支点軸)
	var mid_x := (BTN_GOLD_RECT.end.x + BTN_TOKEN_RECT.position.x) * 0.5
	draw_line(Vector2(mid_x, BEZEL_RECT.position.y + 2), Vector2(mid_x, BEZEL_RECT.end.y - 2), Color(0.03, 0.02, 0.04), 3.0)

	# --- 3. ロッカーボタン描画 ---
	_draw_rocker_button("gold", BTN_GOLD_RECT, sac_type, mult_str, pulse, font)
	_draw_rocker_button("token", BTN_TOKEN_RECT, sac_type, mult_str, pulse, font)

	# --- 4. リセットボタン描画 ---
	_draw_reset_button(is_active, font)


func _draw_rocker_button(type: String, base_rect: Rect2, sac_type: String, mult_str: String, pulse: float, font: Font) -> void:
	var is_hovered := (_hovered_btn == type)
	var is_disabled := (sac_type == type)
	var other_type := "token" if type == "gold" else "gold"
	var is_boosted := (sac_type == other_type)

	var btn_rect := base_rect
	var bg_color: Color
	var border_color: Color
	var display_text: String
	var text_color: Color
	var font_size := 16

	if is_disabled:
		# 【沈み込み状態】(奥に押し込まれたロッカースイッチ)
		btn_rect = Rect2(base_rect.position.x, base_rect.position.y + 3.0, base_rect.size.x, base_rect.size.y - 4.0)
		bg_color = Color(0.28, 0.06, 0.06)
		border_color = Color(0.70, 0.18, 0.18)
		
		# 暗いインナーシャドウ
		draw_rect(btn_rect, bg_color)
		draw_rect(btn_rect, border_color, false, 1.2)
		# 上部の深い落ち影（沈み込みを表現）
		draw_line(Vector2(btn_rect.position.x, btn_rect.position.y + 1),
				  Vector2(btn_rect.end.x, btn_rect.position.y + 1),
				  Color(0.0, 0.0, 0.0, 0.7), 3.0)
		
		var icon := "🪙" if type == "gold" else "💎"
		display_text = "%s 無効" % icon
		text_color = Color(1.0, 0.35, 0.35)
		font_size = 17

	elif is_boosted:
		# 【浮き上がり状態】(手前にせり出したロッカースイッチ)
		btn_rect = Rect2(base_rect.position.x, base_rect.position.y - 2.5, base_rect.size.x, base_rect.size.y + 2.0)
		
		# ドロップシャドウ（手前に浮いている立体感）
		var shadow_rect := Rect2(btn_rect.position.x, btn_rect.end.y - 1.0, btn_rect.size.x, 4.0)
		draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.6))
		
		var icon := "🪙" if type == "gold" else "💎"
		display_text = "%s %s" % [icon, mult_str]
		
		if type == "gold":
			bg_color = Color(0.35, 0.28, 0.08)
			border_color = Color(1.0, 0.85, 0.25) * pulse
			text_color = Color(1.0, 0.95, 0.4)
		else:
			bg_color = Color(0.08, 0.26, 0.35)
			border_color = Color(0.3, 0.85, 1.0) * pulse
			text_color = Color(0.4, 0.9, 1.0)
			
		font_size = 17

		draw_rect(btn_rect, bg_color)
		draw_rect(btn_rect, border_color, false, 2.0)
		# 上端の強いハイライトライン（上面反射）
		draw_line(Vector2(btn_rect.position.x + 1, btn_rect.position.y + 1),
				  Vector2(btn_rect.end.x - 1, btn_rect.position.y + 1),
				  Color(1.0, 1.0, 1.0, 0.65), 1.5)

	else:
		# 【ニュートラル状態】(水平・フラット)
		bg_color = Color(0.18, 0.17, 0.22) if not is_hovered else Color(0.25, 0.23, 0.30)
		border_color = Color(0.35, 0.33, 0.42) if not is_hovered else Color(0.55, 0.50, 0.65)
		draw_rect(btn_rect, bg_color)
		draw_rect(btn_rect, border_color, false, 1.2)
		
		# 上端ハイライト、下端シャドウ
		draw_line(Vector2(btn_rect.position.x + 1, btn_rect.position.y + 1),
				  Vector2(btn_rect.end.x - 1, btn_rect.position.y + 1),
				  Color(0.5, 0.5, 0.6, 0.3), 1.0)
		draw_line(Vector2(btn_rect.position.x + 1, btn_rect.end.y - 1),
				  Vector2(btn_rect.end.x - 1, btn_rect.end.y - 1),
				  Color(0.05, 0.05, 0.07, 0.6), 1.0)
				  
		var icon := "🪙" if type == "gold" else "💎"
		display_text = "%s x1" % icon
		text_color = Color(0.92, 0.92, 0.96)
		font_size = 17

	# テキストをボタンの中心（上下・左右幾何学的中心）に正確に配置
	var text_width := font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_x := btn_rect.position.x + (btn_rect.size.x - text_width) * 0.5
	var center_y := btn_rect.position.y + btn_rect.size.y * 0.5
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline_y := center_y + (ascent - descent) * 0.5
	
	draw_string(font, Vector2(text_x, baseline_y), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _draw_reset_button(is_active: bool, font: Font) -> void:
	var is_hovered := (_hovered_btn == "reset")
	var bg_color: Color
	var border_color: Color
	var text_color: Color
	var label := "リセット"
	
	if is_active:
		# アクティブ時：リセット可能であることを明示
		if is_hovered:
			bg_color = Color(0.32, 0.18, 0.38, 0.95)
			border_color = Color(0.85, 0.45, 0.95)
			text_color = Color(1.0, 1.0, 1.0)
		else:
			bg_color = Color(0.20, 0.12, 0.25, 0.85)
			border_color = Color(0.55, 0.30, 0.65)
			text_color = Color(0.90, 0.80, 0.95)
	else:
		# ニュートラル時：デフォルト状態
		if is_hovered:
			bg_color = Color(0.18, 0.16, 0.22, 0.75)
			border_color = Color(0.40, 0.38, 0.48)
			text_color = Color(0.80, 0.80, 0.85)
		else:
			bg_color = Color(0.12, 0.11, 0.16, 0.60)
			border_color = Color(0.25, 0.22, 0.30, 0.5)
			text_color = Color(0.50, 0.48, 0.55)

	draw_rect(BTN_RESET_RECT, bg_color)
	draw_rect(BTN_RESET_RECT, border_color, false, 1.0)

	var font_size := 13
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_x := BTN_RESET_RECT.position.x + (BTN_RESET_RECT.size.x - text_width) * 0.5
	var center_y := BTN_RESET_RECT.position.y + BTN_RESET_RECT.size.y * 0.5
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline_y := center_y + (ascent - descent) * 0.5
	
	draw_string(font, Vector2(text_x, baseline_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
