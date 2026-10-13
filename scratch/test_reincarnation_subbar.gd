extends SceneTree

func _init() -> void:
	print("--- Running Test for Reincarnation Sub-Bar & Layout Adjustment ---")
	
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		printerr("FAILED: Could not load main.tscn")
		quit(1)
		return
	
	var main = main_scene.instantiate()
	root.add_child(main)
	
	var hud = main.get_node("HUD")
	var home_subnav = hud.get_node("%SubNavContainer")
	var reinc_subnav = hud.get_node("%ReincarnationSubNavContainer")
	var reinc_window = hud.get_node("%ReincarnationWindow")
	var body_margin = reinc_window.get_node("%BodyMargin")
	
	var btn_home = hud.get_node("%HomeTabBtn") as Button
	var btn_reinc = hud.get_node("%ReincarnationTabBtn") as Button
	
	# Initial state: Home view active
	assert(home_subnav.visible == true, "Home subnav should be visible initially")
	assert(reinc_subnav.visible == false, "Reincarnation subnav should be hidden initially")
	assert(reinc_window.visible == false, "Reincarnation window should be hidden initially")
	print("[PASS] Initial state correctly shows Home SubNav and hides Reincarnation SubNav.")
	
	# Verify Reincarnation Window margin_top is adjusted
	var margin_top = body_margin.get_theme_constant("margin_top")
	assert(margin_top >= 120, "Reincarnation Window margin_top should be >= 120 (got %d)" % margin_top)
	print("[PASS] Reincarnation Window margin_top is %d (clears top bar and sub-bar)." % margin_top)
	
	# Switch to Reincarnation view
	btn_reinc.pressed.emit()
	assert(reinc_window.visible == true, "Reincarnation window should be visible")
	assert(reinc_subnav.visible == true, "Reincarnation subnav should be visible in Reincarnation view")
	assert(home_subnav.visible == false, "Home subnav should be hidden in Reincarnation view")
	print("[PASS] Switching to Reincarnation view shows Reincarnation SubNav and hides Home SubNav.")
	
	# Switch back to Home view
	btn_home.pressed.emit()
	assert(reinc_window.visible == false, "Reincarnation window should be hidden")
	assert(home_subnav.visible == true, "Home subnav should be visible in Home view")
	assert(reinc_subnav.visible == false, "Reincarnation subnav should be hidden in Home view")
	print("[PASS] Switching back to Home view correctly restores Home SubNav.")
	
	print("--- ALL REINCARNATION SUB-BAR TESTS PASSED ---")
	quit(0)
