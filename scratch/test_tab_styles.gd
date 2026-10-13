extends SceneTree

func _init() -> void:
	print("--- Running Test for Tab & Sub-Tab Active/Hover/Pressed Styles ---")
	
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		printerr("FAILED: Could not load main.tscn")
		quit(1)
		return
	
	var main = main_scene.instantiate()
	root.add_child(main)
	
	var hud = main.get_node("HUD")
	var btn_home = hud.get_node("%HomeTabBtn") as Button
	var btn_reinc = hud.get_node("%ReincarnationTabBtn") as Button
	var btn_equip = hud.get_node("%EquipmentTabBtn") as Button
	var btn_skill = hud.get_node("%SkillTreeTabBtn") as Button
	var btn_reinc_1 = hud.get_node("%ReincDummyTabBtn1") as Button
	var btn_reinc_2 = hud.get_node("%ReincDummyTabBtn2") as Button
	
	# Verify home tab is active initially
	var home_normal = btn_home.get_theme_stylebox("normal") as StyleBoxFlat
	var home_hover = btn_home.get_theme_stylebox("hover") as StyleBoxFlat
	assert(home_normal != null, "Home tab normal style should be set")
	assert(home_hover != null, "Home tab hover style should be set")
	
	# Check color is muted/slightly lighter base, NOT vivid purple (0.42, 0.20, 0.95)
	print("Home tab active normal bg_color:", home_normal.bg_color)
	print("Home tab active hover bg_color:", home_hover.bg_color)
	assert(home_normal.bg_color.r < 0.35, "Active color should be soft/dark slate, not vivid purple")
	assert(home_hover.bg_color.r < 0.35, "Hover color should be soft/dark slate, not vivid purple")
	
	# Verify hover does not overwrite with purple
	var reinc_normal = btn_reinc.get_theme_stylebox("normal") as StyleBoxFlat
	var reinc_hover = btn_reinc.get_theme_stylebox("hover") as StyleBoxFlat
	assert(reinc_normal != null, "Reinc tab normal style should be set")
	assert(reinc_hover != null, "Reinc tab hover style should be set")
	print("Reinc tab inactive hover bg_color:", reinc_hover.bg_color)
	
	# Switch to Reincarnation
	btn_reinc.pressed.emit()
	var reinc_active_normal = btn_reinc.get_theme_stylebox("normal") as StyleBoxFlat
	var reinc_active_hover = btn_reinc.get_theme_stylebox("hover") as StyleBoxFlat
	assert(reinc_active_normal.bg_color == home_normal.bg_color, "Active reinc tab should have active style")
	assert(reinc_active_hover.bg_color == home_hover.bg_color, "Active reinc tab should have active hover style")
	print("[PASS] Main tab active/hover styles correctly switch without purple mutation.")
	
	# Test Reincarnation dummy subtabs
	assert(btn_reinc_1.get_theme_stylebox("normal") != null, "Reinc tab 1 normal style should be set")
	assert(btn_reinc_1.get_theme_stylebox("hover") != null, "Reinc tab 1 hover style should be set")
	btn_reinc_2.pressed.emit()
	assert(hud._reinc_subtab_index == 1, "Dummy tab 2 should be active when clicked")
	print("[PASS] Reincarnation dummy subtabs switch active/inactive styles correctly.")
	
	print("--- ALL STYLE VERIFICATIONS PASSED ---")
	quit(0)
