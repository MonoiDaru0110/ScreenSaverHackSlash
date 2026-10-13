extends SceneTree

func _init() -> void:
	var root_ctrl := Control.new()
	root_ctrl.size = Vector2(1200, 800)
	root.add_child(root_ctrl)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 100)
	scroll.size = Vector2(700, 100)
	root_ctrl.add_child(scroll)
	
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Do NOT expand vertically so it can scroll naturally:
	center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(center)
	
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(580, 0)
	center.add_child(vbox)
	
	for i in range(20):
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		var lbl1 := Label.new()
		lbl1.text = "◆ Skill %d Lv.1" % i
		lbl1.custom_minimum_size = Vector2(220, 0)
		var lbl2 := Label.new()
		lbl2.text = "Description of the skill %d" % i
		lbl2.custom_minimum_size = Vector2(340, 0)
		hbox.add_child(lbl1)
		hbox.add_child(lbl2)
		vbox.add_child(hbox)
	
	await process_frame
	await process_frame
	
	print("CenterContainer size: ", center.size, " pos: ", center.position)
	print("ScrollContainer v_scroll_bar max: ", scroll.get_v_scroll_bar().max_value)
	assert(scroll.get_v_scroll_bar().max_value > 100, "ScrollContainer should be scrollable vertically!")
	print("VBox global X: ", vbox.global_position.x)
	assert(abs(vbox.position.x - 60) < 5, "VBox should still be centered horizontally!")
	print("SCROLLING AND CENTERING TEST PASSED!")
	quit(0)
