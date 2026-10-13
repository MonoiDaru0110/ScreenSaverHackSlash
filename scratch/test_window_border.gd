extends SceneTree

func _init() -> void:
	print("Testing Window Border Overlay...")
	var base_wnd_scene: PackedScene = load("res://scenes/ui/challenge_window.tscn")
	var wnd = base_wnd_scene.instantiate() as BaseWindow
	root.add_child(wnd)
	
	# Check nodes
	await process_frame
	print("Window size: ", wnd.size)
	assert(wnd.size.x >= 1200 and wnd.size.y >= 861, "Window size should match minimum")
	
	var overlay = wnd.get_node_or_null("WindowBorderOverlay") as Panel
	print("Overlay node: ", overlay)
	
	print("WINDOW BORDER SCRIPT INITIALIZED SUCCESSFULLY")
	quit(0)
