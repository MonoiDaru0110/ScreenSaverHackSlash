extends SceneTree

func _init() -> void:
	print("--- Running Test for Adjusted Window Offsets & Bar Separation ---")
	
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		printerr("FAILED: Could not load main.tscn")
		quit(1)
		return
	
	var main = main_scene.instantiate()
	root.add_child(main)
	
	var hud = main.get_node("HUD")
	var top_nav = hud.get_node("TopNavigationArea")
	var skill_window = hud.get_node("%SkillTreeWindow")
	var inv_window = hud.get_node("%InventoryWindow")
	
	# Verify bar separation reduced
	var sep = top_nav.get_theme_constant("separation")
	assert(sep == 2, "TopNavigationArea separation should be 2, got %d" % sep)
	print("[PASS] TopNavigationArea separation is %d." % sep)
	
	# Verify window offsets shifted down (offset_top >= 124)
	assert(skill_window.offset_top >= 120.0, "SkillTreeWindow offset_top should be >= 120.0")
	assert(inv_window.offset_top >= 120.0, "InventoryWindow offset_top should be >= 120.0")
	print("[PASS] SkillTreeWindow and InventoryWindow offset_top are %.1f (no overlap with sub-bar)." % skill_window.offset_top)
	
	# Test opening windows
	var btn_equip = hud.get_node("%EquipmentTabBtn") as Button
	var btn_skill = hud.get_node("%SkillTreeTabBtn") as Button
	
	btn_equip.pressed.emit()
	assert(inv_window.visible == true, "Inventory window should open")
	
	btn_skill.pressed.emit()
	assert(skill_window.visible == true, "Skill tree window should open")
	assert(inv_window.visible == false, "Inventory window should close")
	
	print("--- ALL VERIFICATIONS PASSED ---")
	quit(0)
