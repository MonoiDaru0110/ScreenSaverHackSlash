extends SceneTree

func _init() -> void:
	print("--- Running Test for Button Glowing & Pulsating Effects ---")
	
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		printerr("FAILED: Could not load main.tscn")
		quit(1)
		return
	
	var main = main_scene.instantiate()
	root.add_child(main)
	
	var hud = main.get_node("HUD")
	var reinc_window = hud.get_node("%ReincarnationWindow")
	var btn_toggle = reinc_window.get_node("%ToggleInfuseBtn") as Button
	var btn_reinc = reinc_window.get_node("%ReincarnateBtn") as Button
	
	# Open reincarnation window
	var btn_reincarnation_tab = hud.get_node("%ReincarnationTabBtn") as Button
	btn_reincarnation_tab.pressed.emit()
	
	# Test 1: Infuse button not active -> should pulse/glow
	GameData.is_infusing_tokens = false
	reinc_window._process(0.016)
	print("Unpressed Infuse Btn Modulate:", btn_toggle.modulate)
	assert(btn_toggle.modulate.r >= 1.0 and btn_toggle.modulate.b >= 1.0, "Infuse button should glow/modulate when unpressed")
	
	# Test 2: Infuse button active -> should be normal Color.WHITE
	GameData.is_infusing_tokens = true
	reinc_window._process(0.016)
	print("Active Infuse Btn Modulate:", btn_toggle.modulate)
	assert(btn_toggle.modulate == Color.WHITE, "Infuse button should be Color.WHITE when active")
	
	# Test 3: Reincarnate button disabled -> should be Color.WHITE
	btn_reinc.disabled = true
	reinc_window._process(0.016)
	print("Disabled Reincarnate Btn Modulate:", btn_reinc.modulate)
	assert(btn_reinc.modulate == Color.WHITE, "Disabled reincarnate button should be Color.WHITE")
	
	# Test 4: Reincarnate button enabled -> should pulse/glow
	btn_reinc.disabled = false
	reinc_window._process(0.016)
	print("Enabled Reincarnate Btn Modulate:", btn_reinc.modulate)
	assert(btn_reinc.modulate.r >= 1.0 and btn_reinc.modulate.b >= 1.0, "Enabled reincarnate button should glow/modulate")
	
	# Test 5: Close window -> processing disabled
	var btn_home = hud.get_node("%HomeTabBtn") as Button
	btn_home.pressed.emit()
	assert(reinc_window.is_processing() == false, "Reincarnation window process should be disabled when closed")
	
	print("[PASS] All button glowing and pulsing behaviors verified successfully.")
	print("--- ALL VERIFICATIONS PASSED ---")
	quit(0)
