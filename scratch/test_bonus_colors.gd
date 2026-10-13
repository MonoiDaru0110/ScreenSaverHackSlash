extends SceneTree

func _init() -> void:
	print("--- Running Test for Bonus Colors (White Values & Purple-tinted White Titles) ---")
	
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		printerr("FAILED: Could not load main.tscn")
		quit(1)
		return
	
	var main = main_scene.instantiate()
	root.add_child(main)
	
	var hud = main.get_node("HUD")
	var reinc_window = hud.get_node("%ReincarnationWindow")
	
	var cur_title = reinc_window.get_node("BodyMargin/MainLayout/BottomArea/CenterActionBox/BonusBar/CurrentBonusBox/Title") as Label
	var next_title = reinc_window.get_node("BodyMargin/MainLayout/BottomArea/CenterActionBox/BonusBar/NextBonusBox/Title") as Label
	var arrow = reinc_window.get_node("BodyMargin/MainLayout/BottomArea/CenterActionBox/BonusBar/ArrowLabel") as Label
	var lbl_equip = reinc_window.get_node("%LblEquipLevelBonus") as Label
	var lbl_auto = reinc_window.get_node("%LblAutoSkillsBonus") as Label
	var lbl_mult = reinc_window.get_node("%LblMultiplierBonus") as Label
	var lbl_next_equip = reinc_window.get_node("%LblNextEquipLevelBonus") as Label
	var lbl_next_auto = reinc_window.get_node("%LblNextAutoSkillsBonus") as Label
	var lbl_next_mult = reinc_window.get_node("%LblNextMultiplierBonus") as Label
	
	# Open reincarnation window (calls update_ui())
	var btn_reincarnation_tab = hud.get_node("%ReincarnationTabBtn") as Button
	btn_reincarnation_tab.pressed.emit()
	
	# Verify titles are purple-tinted white
	var cur_title_color = cur_title.get_theme_color("font_color")
	var next_title_color = next_title.get_theme_color("font_color")
	print("Current Title Color:", cur_title_color)
	print("Next Title Color:", next_title_color)
	assert(cur_title_color.b > cur_title_color.g, "Current title should be purple-tinted white")
	assert(next_title_color.b > next_title_color.g, "Next title should be purple-tinted white")
	assert(cur_title_color.r > 0.85 and cur_title_color.g > 0.80, "Title color should be close to white")
	
	# Verify bonus values and arrow are pure white
	for lbl in [lbl_equip, lbl_auto, lbl_mult, lbl_next_equip, lbl_next_auto, lbl_next_mult, arrow]:
		var col = lbl.get_theme_color("font_color")
		print(lbl.name, "Color:", col)
		assert(col == Color.WHITE, "%s should be pure white Color.WHITE, got %s" % [lbl.name, col])
	
	print("[PASS] All bonus label colors and title colors verified successfully.")
	print("--- ALL VERIFICATIONS PASSED ---")
	quit(0)
