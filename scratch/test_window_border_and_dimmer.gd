extends SceneTree

func _init() -> void:
	print("--- Running test_window_border_and_dimmer.gd ---")
	
	# 1. Test BaseWindow border overlay
	print("Testing BaseWindow border overlay...")
	var base_scene: PackedScene = load("res://scenes/ui/challenge_window.tscn")
	var wnd = base_scene.instantiate() as BaseWindow
	root.add_child(wnd)
	
	await process_frame
	var overlay = wnd.get_node_or_null("WindowBorderOverlay") as Panel
	assert(overlay != null, "WindowBorderOverlay should exist on BaseWindow")
	assert(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Overlay should ignore mouse input")
	
	var style = overlay.get_theme_stylebox("panel") as StyleBoxFlat
	assert(style != null, "Overlay should have StyleBoxFlat")
	assert(style.draw_center == false, "Overlay StyleBoxFlat draw_center should be false")
	assert(style.border_width_left == 1 and style.border_width_top == 1, "Border width should be 1")
	assert(style.corner_radius_top_left == 6 and style.corner_radius_bottom_right == 6, "Corner radius should be 6")
	assert(style.border_color == Color(0, 0, 0, 1), "Border color should be black")
	print(" BaseWindow border overlay verified successfully!")
	wnd.queue_free()
	
	# 2. Test HUD with WindowDimmer and Reincarnation Dummy Windows
	print("Testing HUD with WindowDimmer and Reincarnation dummy windows...")
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	
	await process_frame
	
	# Check WindowDimmer
	var dimmer = hud.get_node_or_null("%WindowDimmer") as ColorRect
	assert(dimmer != null, "WindowDimmer should exist in HUD")
	assert(dimmer.z_index == 5, "WindowDimmer z_index should be 5")
	assert(dimmer.size.x == 1664, "WindowDimmer width should be 1664 (excluding right sidebar)")
	assert(dimmer.size.y == 1080, "WindowDimmer height should be 1080")
	assert(dimmer.visible == false, "WindowDimmer should initially be invisible")
	print(" WindowDimmer node verified!")
	
	# Check Reincarnation dummy windows
	var reinc_tree_wnd = hud.get_node_or_null("%ReincTreeWindow")
	var reinc_ability_wnd = hud.get_node_or_null("%ReincAbilityWindow")
	assert(reinc_tree_wnd != null, "ReincTreeWindow should exist in HUD")
	assert(reinc_ability_wnd != null, "ReincAbilityWindow should exist in HUD")
	assert(reinc_tree_wnd.z_index == 10, "ReincTreeWindow z_index should be 10")
	assert(reinc_ability_wnd.z_index == 10, "ReincAbilityWindow z_index should be 10")
	print(" Reincarnation dummy windows verified!")
	
	# Check opening an inventory window triggers dimmer
	print("Testing opening inventory window triggers dimmer...")
	hud.open_inventory()
	await process_frame
	assert(dimmer.visible == true, "Dimmer should become visible when inventory is open")
	
	# Check closing inventory window closes dimmer
	hud.close_inventory()
	# Wait for fade out
	for i in range(15):
		await process_frame
	assert(dimmer.visible == false, "Dimmer should become invisible when all subbar windows close")
	print(" Home subbar dimmer trigger verified!")
	
	# Check reincarnation dummy window triggers dimmer
	print("Testing opening reinc tree window triggers dimmer...")
	hud.open_reinc_tree()
	await process_frame
	assert(reinc_tree_wnd.visible == true, "ReincTreeWindow should be visible")
	assert(dimmer.visible == true, "Dimmer should be visible when reinc tree is open")
	
	# Check clicking dimmer closes all subbar windows
	print("Testing clicking dimmer closes open windows...")
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	hud._on_window_dimmer_gui_input(click_event)
	await process_frame
	assert(reinc_tree_wnd.visible == false, "ReincTreeWindow should close when dimmer is clicked")
	
	for i in range(15):
		await process_frame
	assert(dimmer.visible == false, "Dimmer should hide after windows close")
	print(" Dimmer click close verified!")
	
	print("=== ALL TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
