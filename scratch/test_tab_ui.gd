extends SceneTree

func _init() -> void:
	print("--- Running Test for Maximized Mini Monitor ---")
	
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		printerr("FAILED: Could not load main.tscn")
		quit(1)
		return
	
	var main = main_scene.instantiate()
	root.add_child(main)
	
	var hud = main.get_node("HUD")
	var reinc_window = hud.get_node("%ReincarnationWindow")
	var mini_viewport = reinc_window.get_node("%MiniViewport") as SubViewport
	var mini_camera = reinc_window.get_node("%MiniCamera") as Camera2D
	
	assert(mini_viewport != null, "MiniViewport exists")
	assert(mini_viewport.size.x >= 350, "MiniViewport width should be >= 350 (got %d)" % mini_viewport.size.x)
	assert(mini_viewport.size.y >= 225, "MiniViewport height should be >= 225 (got %d)" % mini_viewport.size.y)
	print("[PASS] MiniViewport maximized size verified: %s" % mini_viewport.size)
	
	print("--- ALL VERIFICATIONS PASSED ---")
	quit(0)
