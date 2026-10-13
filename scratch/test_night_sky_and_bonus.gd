extends SceneTree

func _init() -> void:
	print("--- Running Test for Updated Saturated Purple Sky & Larger Bonus Text ---")
	
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		printerr("FAILED: Could not load main.tscn")
		quit(1)
		return
	
	var main = main_scene.instantiate()
	root.add_child(main)
	
	var hud = main.get_node("HUD")
	var reinc_window = hud.get_node("%ReincarnationWindow")
	
	# Verify SkyBackground node exists and has shader material
	var sky_bg = reinc_window.get_node("SkyBackground") as ColorRect
	assert(sky_bg != null, "SkyBackground should exist in ReincarnationWindow")
	assert(sky_bg.material != null, "SkyBackground should have material")
	print("[PASS] Night sky background shader material verified.")
	
	# Verify Bonus text font sizes
	var current_title = reinc_window.get_node("BodyMargin/MainLayout/BottomArea/CenterActionBox/BonusBar/CurrentBonusBox/Title") as Label
	var lbl_equip_bonus = reinc_window.get_node("%LblEquipLevelBonus") as Label
	var lbl_auto_skills = reinc_window.get_node("%LblAutoSkillsBonus") as Label
	var lbl_multiplier = reinc_window.get_node("%LblMultiplierBonus") as Label
	var arrow_label = reinc_window.get_node("BodyMargin/MainLayout/BottomArea/CenterActionBox/BonusBar/ArrowLabel") as Label
	var next_title = reinc_window.get_node("BodyMargin/MainLayout/BottomArea/CenterActionBox/BonusBar/NextBonusBox/Title") as Label
	var lbl_next_equip = reinc_window.get_node("%LblNextEquipLevelBonus") as Label
	var btn_reinc = reinc_window.get_node("%ReincarnateBtn") as Button
	
	var cur_title_font = current_title.get_theme_font_size("font_size")
	var equip_font = lbl_equip_bonus.get_theme_font_size("font_size")
	var arrow_font = arrow_label.get_theme_font_size("font_size")
	var btn_font = btn_reinc.get_theme_font_size("font_size")
	
	print("Current Title Font Size:", cur_title_font)
	print("Bonus Line Font Size:", equip_font)
	print("Arrow Font Size:", arrow_font)
	print("Reincarnate Button Font Size:", btn_font)
	
	assert(cur_title_font >= 28, "Bonus title font size should be >= 28 (got %d)" % cur_title_font)
	assert(equip_font >= 23, "Bonus line font size should be >= 23 (got %d)" % equip_font)
	assert(arrow_font >= 56, "Arrow font size should be >= 56 (got %d)" % arrow_font)
	assert(btn_font >= 21, "Reincarnate button font size should be >= 21 (got %d)" % btn_font)
	print("[PASS] Bonus text font sizes successfully enlarged (Title 28, Lines 23, Arrow 56, Button 21).")
	
	# Switch to Reincarnation view and trigger UI updates
	var btn_reincarnation_tab = hud.get_node("%ReincarnationTabBtn") as Button
	btn_reincarnation_tab.pressed.emit()
	assert(reinc_window.visible == true, "Reincarnation window should be visible")
	
	print("--- ALL VERIFICATIONS PASSED ---")
	quit(0)
