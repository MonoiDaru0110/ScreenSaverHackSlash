extends CanvasLayer
## Heads-up display showing gold, bounce count, and corner hit announcements.

@onready var gold_label: Label = $Sidebar/SidebarLayout/FooterBottomSection/CenterContainer/GoldLabel
@onready var token_label: Label = $Sidebar/SidebarLayout/FooterTopSection/CenterContainer/TokenLabel
@onready var bounce_label: Label = $BounceLabel
@onready var corner_label: Label = $CornerLabel
@onready var corner_announce: Label = $CornerAnnounce

@onready var btn_logo: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton1
@onready var btn_speed: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton2
@onready var btn_boost: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton3
@onready var btn_ascend: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton4


func _ready() -> void:
	# Configure StyleBoxFlat for button states programmatically
	# to prevent Godot Editor from overwriting the .tscn scene file styles.
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.33, 0.15, 0.85, 1)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.45, 0.25, 0.92, 1)
	style_normal.corner_radius_top_left = 3
	style_normal.corner_radius_top_right = 3
	style_normal.corner_radius_bottom_right = 3
	style_normal.corner_radius_bottom_left = 3

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.42, 0.25, 0.92, 1)
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(0.55, 0.38, 0.98, 1)
	style_hover.corner_radius_top_left = 3
	style_hover.corner_radius_top_right = 3
	style_hover.corner_radius_bottom_right = 3
	style_hover.corner_radius_bottom_left = 3

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.22, 0.08, 0.6, 1)
	style_pressed.border_width_left = 2
	style_pressed.border_width_top = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_bottom = 2
	style_pressed.border_color = Color(0.32, 0.14, 0.75, 1)
	style_pressed.corner_radius_top_left = 3
	style_pressed.corner_radius_top_right = 3
	style_pressed.corner_radius_bottom_right = 3
	style_pressed.corner_radius_bottom_left = 3

	var style_disabled := StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.24, 0.14, 0.42, 1) # Closer to default with slightly higher brightness/saturation
	style_disabled.border_width_left = 2
	style_disabled.border_width_top = 2
	style_disabled.border_width_right = 2
	style_disabled.border_width_bottom = 2
	style_disabled.border_color = Color(0.28, 0.18, 0.48, 1)
	style_disabled.corner_radius_top_left = 3
	style_disabled.corner_radius_top_right = 3
	style_disabled.corner_radius_bottom_right = 3
	style_disabled.corner_radius_bottom_left = 3

	var style_focus := StyleBoxEmpty.new() # Removes focus outline border highlighting

	for btn in [btn_logo, btn_speed, btn_boost, btn_ascend]:
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("disabled", style_disabled)
		btn.add_theme_stylebox_override("focus", style_focus)
		
		# Make font sizes slightly larger and align the coin emoji visually
		btn.get_node("Content/TitleLabel").add_theme_font_size_override("font_size", 18)
		btn.get_node("Content/CostLabel").add_theme_font_size_override("font_size", 16)

	GameData.gold_changed.connect(_on_gold_changed)
	GameData.tokens_changed.connect(_on_tokens_changed)
	GameData.stats_changed.connect(_on_stats_changed)
	GameData.corner_hit_occurred.connect(_on_corner_hit)
	GameData.upgrades_changed.connect(_on_upgrades_changed)
	
	btn_logo.pressed.connect(_on_logo_pressed)
	btn_speed.pressed.connect(_on_speed_pressed)
	btn_boost.pressed.connect(_on_boost_pressed)
	btn_ascend.pressed.connect(_on_ascend_pressed)
	
	_update_all()


func _on_gold_changed(_amount: int) -> void:
	gold_label.text = "🪙 " + _format_number(GameData.gold)
	_update_upgrade_buttons()


func _on_tokens_changed(_amount: int) -> void:
	token_label.text = "💎 " + _format_number(GameData.tokens)


func _on_stats_changed() -> void:
	bounce_label.text = "Bounces: " + _format_number(GameData.total_bounces)
	corner_label.text = "★ Corners: " + str(GameData.corner_hits)


func _on_upgrades_changed() -> void:
	_update_upgrade_buttons()


func _on_corner_hit() -> void:
	## Show a big announcement when a corner hit occurs.
	corner_announce.text = "★ CORNER HIT! ★"
	corner_announce.modulate.a = 1.0
	corner_announce.scale = Vector2(1.3, 1.3)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(corner_announce, "modulate:a", 0.0, 2.0)\
		.set_ease(Tween.EASE_IN).set_delay(0.5)
	tween.tween_property(corner_announce, "scale", Vector2.ONE, 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _update_all() -> void:
	_on_gold_changed(GameData.gold)
	_on_tokens_changed(GameData.tokens)
	_on_stats_changed()
	_update_upgrade_buttons()


func _update_upgrade_buttons() -> void:
	var gold := GameData.gold

	# --- Upgrade 1: Logo ---
	var cost_logo := GameData.get_logo_upgrade_cost()
	var logo_ok := gold >= cost_logo
	btn_logo.disabled = !logo_ok
	var lbl_title_logo: Label = btn_logo.get_node("Content/TitleLabel")
	lbl_title_logo.text = "ロゴ追加  Lv. %d" % GameData.logo_count
	lbl_title_logo.add_theme_color_override("font_color", Color.WHITE if logo_ok else Color(1, 1, 1, 0.4))
	var lbl_cost_logo: Label = btn_logo.get_node("Content/CostLabel")
	lbl_cost_logo.text = "🪙 " + _format_number(cost_logo)
	lbl_cost_logo.add_theme_color_override("font_color", Color.RED if !logo_ok else Color(0.85, 0.85, 0.85))

	# --- Upgrade 2: Speed ---
	var cost_speed := GameData.get_speed_upgrade_cost()
	var speed_ok := gold >= cost_speed
	btn_speed.disabled = !speed_ok
	var lbl_title_speed: Label = btn_speed.get_node("Content/TitleLabel")
	lbl_title_speed.text = "速度強化  Lv. %d" % GameData.speed_level
	lbl_title_speed.add_theme_color_override("font_color", Color.WHITE if speed_ok else Color(1, 1, 1, 0.4))
	var lbl_cost_speed: Label = btn_speed.get_node("Content/CostLabel")
	lbl_cost_speed.text = "🪙 " + _format_number(cost_speed)
	lbl_cost_speed.add_theme_color_override("font_color", Color.RED if !speed_ok else Color(0.85, 0.85, 0.85))

	# --- Upgrade 3: Gold/Token Boost ---
	var cost_boost := GameData.get_boost_upgrade_cost()
	var boost_ok := gold >= cost_boost
	btn_boost.disabled = !boost_ok
	var lbl_title_boost: Label = btn_boost.get_node("Content/TitleLabel")
	lbl_title_boost.text = "ゴールド・トークン増加  Lv. %d" % GameData.boost_level
	lbl_title_boost.add_theme_color_override("font_color", Color.WHITE if boost_ok else Color(1, 1, 1, 0.4))
	var lbl_cost_boost: Label = btn_boost.get_node("Content/CostLabel")
	lbl_cost_boost.text = "🪙 " + _format_number(cost_boost)
	lbl_cost_boost.add_theme_color_override("font_color", Color.RED if !boost_ok else Color(0.85, 0.85, 0.85))

	# --- Upgrade 4: Ascension ---
	var ascend_ok := GameData.can_ascend()
	btn_ascend.disabled = !ascend_ok
	var lbl_title_ascend: Label = btn_ascend.get_node("Content/TitleLabel")
	lbl_title_ascend.text = "アセンション  Lv. %d" % GameData.ascension_level
	lbl_title_ascend.add_theme_color_override("font_color", Color.WHITE if ascend_ok else Color(1, 1, 1, 0.4))
	var lbl_cost_ascend: Label = btn_ascend.get_node("Content/CostLabel")
	lbl_cost_ascend.text = "🪙 1,000"
	lbl_cost_ascend.add_theme_color_override("font_color", Color.RED if !ascend_ok else Color(0.85, 0.85, 0.85))


func _on_logo_pressed() -> void:
	GameData.buy_logo_upgrade()


func _on_speed_pressed() -> void:
	GameData.buy_speed_upgrade()


func _on_boost_pressed() -> void:
	GameData.buy_boost_upgrade()


func _on_ascend_pressed() -> void:
	GameData.perform_ascension()


## Formats a number with comma separators (e.g., 1,234,567).
func _format_number(n: int) -> String:
	var s := str(n)
	if n < 1000:
		return s
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "," + result
	return result
