extends SceneTree

func _init() -> void:
	print("=== Running Window Customization Tests ===")
	var hud_scene = load("res://scenes/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	
	# Wait for ready
	var skill_wnd = hud.get_node("%SkillTreeWindow") as BaseWindow
	var inv_wnd = hud.get_node("%InventoryWindow") as BaseWindow
	var reinc_wnd = hud.get_node("%ReincarnationWindow") as BaseWindow
	var filter_wnd = hud.get_node("%EquipmentFilterWindow") as BaseWindow
	
	assert(skill_wnd != null, "SkillTreeWindow should exist")
	assert(inv_wnd != null, "InventoryWindow should exist")
	assert(reinc_wnd != null, "ReincarnationWindow should exist")
	assert(filter_wnd != null, "EquipmentFilterWindow should exist")
	
	print("[1] Checking Titles and Emojis...")
	print("  SkillTreeWindow title: ", skill_wnd.get_title_label().text)
	assert(skill_wnd.get_title_label().text == "永続スキルツリー", "SkillTree title mismatch")
	assert(not "🌳" in skill_wnd.get_title_label().text, "SkillTree title must not have tree emoji")
	
	print("  InventoryWindow title: ", inv_wnd.get_title_label().text)
	assert(inv_wnd.get_title_label().text == "インベントリ (0 / 50)", "Inventory title mismatch")
	assert(not "🎒" in inv_wnd.get_title_label().text, "Inventory title must not have bag emoji")
	
	print("  ReincarnationWindow title: ", reinc_wnd.get_title_label().text)
	assert(reinc_wnd.get_title_label().text == "転生", "Reincarnation title mismatch")
	assert(not "⚛️" in reinc_wnd.get_title_label().text, "Reincarnation title must not have atom emoji")
	
	print("  EquipmentFilterWindow title: ", filter_wnd.get_title_label().text)
	assert(filter_wnd.get_title_label().text == "装備入手フィルター", "Filter title mismatch")
	assert(not "⚙️" in filter_wnd.get_title_label().text, "Filter title must not have gear emoji")
	
	print("[2] Checking Distinct Header Colors & Opacity (Alpha == 1.0)...")
	var skill_header_style = skill_wnd.get_node("WindowVBox/HeaderPanel").get_theme_stylebox("panel") as StyleBoxFlat
	var inv_header_style = inv_wnd.get_node("WindowVBox/HeaderPanel").get_theme_stylebox("panel") as StyleBoxFlat
	var reinc_header_style = reinc_wnd.get_node("WindowVBox/HeaderPanel").get_theme_stylebox("panel") as StyleBoxFlat
	var filter_header_style = filter_wnd.get_node("WindowVBox/HeaderPanel").get_theme_stylebox("panel") as StyleBoxFlat
	
	print("  SkillTree header color: ", skill_header_style.bg_color)
	print("  Inventory header color: ", inv_header_style.bg_color)
	print("  Reincarnation header color: ", reinc_header_style.bg_color)
	print("  Filter header color: ", filter_header_style.bg_color)
	
	assert(is_equal_approx(skill_header_style.bg_color.a, 1.0), "SkillTree header must be fully opaque")
	assert(is_equal_approx(inv_header_style.bg_color.a, 1.0), "Inventory header must be fully opaque")
	assert(is_equal_approx(reinc_header_style.bg_color.a, 1.0), "Reincarnation header must be fully opaque")
	assert(is_equal_approx(filter_header_style.bg_color.a, 1.0), "Filter header must be fully opaque")
	
	# Check body styles opacity
	var skill_body_style = skill_wnd.get_node("WindowVBox/BodyPanel").get_theme_stylebox("panel") as StyleBoxFlat
	var inv_body_style = inv_wnd.get_node("WindowVBox/BodyPanel").get_theme_stylebox("panel") as StyleBoxFlat
	assert(is_equal_approx(skill_body_style.bg_color.a, 1.0), "SkillTree body must be fully opaque")
	assert(is_equal_approx(inv_body_style.bg_color.a, 1.0), "Inventory body must be fully opaque")
	
	# Verify SkillTree is Green and Inventory is Navy Blue (Not identical!)
	assert(skill_header_style.bg_color != inv_header_style.bg_color, "SkillTree and Inventory MUST have distinct colors!")
	assert(skill_header_style.bg_color.g > skill_header_style.bg_color.b, "SkillTree must be green-tinted")
	assert(inv_header_style.bg_color.b > inv_header_style.bg_color.g, "Inventory must be blue-tinted")
	
	print("[3] Checking CloseButton Sizing and Mark Font Size...")
	for wnd in [skill_wnd, inv_wnd, reinc_wnd, filter_wnd]:
		var close_btn = wnd.get_close_button()
		assert(close_btn != null, "Window must have close button")
		print("  %s CloseBtn size: %s" % [wnd.name, str(close_btn.custom_minimum_size)])
		assert(close_btn.custom_minimum_size.x >= wnd.header_height, "Close button must reach separator line")
		assert(close_btn.custom_minimum_size.x == close_btn.custom_minimum_size.y, "Close button must be square")
		var mark_lbl = close_btn.get_node("%MarkLabel") as Label
		assert(mark_lbl != null, "Close button must have MarkLabel")
		var font_sz = mark_lbl.get_theme_font_size("font_size")
		print("  %s Mark font size: %d" % [wnd.name, font_sz])
		assert(font_sz >= int(close_btn.custom_minimum_size.x * 0.9), "Mark font size should be large")

	print("=== All Window Customization Tests Passed Successfully! ===")
	quit()
