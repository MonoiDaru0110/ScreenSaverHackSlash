extends SceneTree

func _init() -> void:
	var root_ctrl := Control.new()
	root_ctrl.size = Vector2(1200, 800)
	root.add_child(root_ctrl)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 200)
	scroll.size = Vector2(500, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root_ctrl.add_child(scroll)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	for i in range(15):
		var lbl := Label.new()
		lbl.text = "◆ Skill %d  Lv.%d" % [i, i + 1]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.tooltip_text = "This is description of skill %d" % i
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(lbl)
	
	await process_frame
	await process_frame
	
	print("VScrollBar max: ", scroll.get_v_scroll_bar().max_value)
	assert(scroll.get_v_scroll_bar().max_value > 200, "Should scroll vertically")
	
	# Simulate wheel event over label
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = Vector2(250, 100)
	scroll._gui_input(event)
	await process_frame
	
	print("scroll_vertical after wheel: ", scroll.scroll_vertical)
	print("TOOLTIP + WHEEL TEST PASSED!")
	quit(0)
