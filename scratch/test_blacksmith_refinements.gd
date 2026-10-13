extends Node

func _ready() -> void:
	print("--- Starting Blacksmith Refinements Unit Test ---")
	
	# Test 1: EquipmentIcon dummy display
	print("[Test 1] Testing EquipmentIcon dummy display...")
	var eq_icon_scene: PackedScene = preload("res://scenes/ui/equipment_icon.tscn")
	var icon_inst = eq_icon_scene.instantiate() as EquipmentIcon
	add_child(icon_inst)
	
	icon_inst.update_item({
		"show_question": true,
		"level_str": "Lv???",
		"rarity": "コモン",
		"forge_count": 0
	})
	
	assert(icon_inst.icon_rect.visible == false, "IconRect should be hidden when show_question is true")
	assert(icon_inst.question_label.visible == true, "QuestionLabel should be visible")
	assert(icon_inst.question_label.text == "?", "QuestionLabel text should be '?'")
	assert(icon_inst.level_label.text == "Lv???", "LevelLabel should display 'Lv???'")
	assert(icon_inst.forge_label.visible == false, "ForgeLabel should be hidden when forge_count is 0")
	print("  PASS: EquipmentIcon dummy display verified.")
	icon_inst.queue_free()
	
	# Test 2: BlacksmithWindow structure and initial state
	print("[Test 2] Testing BlacksmithWindow node structure...")
	var bs_scene: PackedScene = preload("res://scenes/ui/blacksmith_window.tscn")
	var bs_inst = bs_scene.instantiate() as BlacksmithWindow
	add_child(bs_inst)
	
	assert(bs_inst.type_option_button != null, "TypeOptionButton must exist")
	assert(bs_inst.type_option_button.item_count == 3, "TypeOptionButton should have 3 items")
	assert(bs_inst.get_node_or_null("%InventoryTitleLabel") == null, "InventoryTitleLabel must be deleted")
	assert(bs_inst.inventory_grid.columns == 5, "InventoryGrid should have 5 columns")
	assert(bs_inst.inventory_grid.get_theme_constant("h_separation") == 4, "h_separation should be 4")
	assert(bs_inst.inventory_grid.get_theme_constant("v_separation") == 4, "v_separation should be 4")
	
	# Check removed labels & unified right frame
	assert(bs_inst.get_node_or_null("%MaterialHeaderLabel") == null, "MaterialHeaderLabel should be deleted")
	assert(bs_inst.get_node_or_null("%ResultHeaderLabel") == null, "ResultHeaderLabel should be deleted")
	assert(bs_inst.get_node_or_null("%RarityProbLabel") == null, "RarityProbLabel should be deleted")
	assert(bs_inst.get_node_or_null("%RightFrame") != null, "RightFrame should exist")
	assert(bs_inst.get_node_or_null("%WorkbenchPanel") == null, "WorkbenchPanel should be deleted")
	assert(bs_inst.get_node_or_null("%CandidatePanel") == null, "CandidatePanel should be deleted")
	assert(bs_inst.candidate_title_label.text == "候補スキル一覧", "Candidate title should be strictly '候補スキル一覧'")
	assert(bs_inst.candidate_title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "CandidateTitleLabel must be centered")
	assert(bs_inst.candidate_title_label.get_theme_font_size("font_size") >= 20, "CandidateTitleLabel font size should be >= 20")
	assert(bs_inst.skill_list_container.get_parent() is ScrollContainer, "SkillListContainer must be direct child of ScrollContainer")
	assert(bs_inst.material_grid.get_parent().name == "MaterialFrame", "MaterialGrid should be inside MaterialFrame")
	
	# Check initial preview
	assert(bs_inst._preview_equipment_icon != null, "Preview equipment icon must exist")
	assert(bs_inst._preview_equipment_icon.question_label.visible == true, "Preview icon should show '?'")
	assert(bs_inst._preview_equipment_icon.level_label.text == "Lv???", "Preview level should be 'Lv???'")
	assert(bs_inst._preview_equipment_icon.forge_label.visible == false, "Preview forge label should be hidden")
	print("  PASS: BlacksmithWindow structure and initial dummy preview verified.")
	
	# Test 3: Material placing & roulette
	print("[Test 3] Testing Material placing and roulette...")
	# Setup test items in GameData
	GameData.inventories["main"] = [
		{
			"id": "test_m1", "type": "main", "name": "Sword A", "level": 10,
			"rarity": "コモン", "icon": "res://images/equip_icon/equip_main_1.png",
			"equip_skill": [{"id": "power", "name": "Power", "level": 1, "is_special": false, "desc": "ATK+1"}],
			"forge_count": 0
		},
		{
			"id": "test_m2", "type": "main", "name": "Sword B", "level": 20,
			"rarity": "アンコモン", "icon": "res://images/equip_icon/equip_main_2.png",
			"equip_skill": [{"id": "sharp", "name": "Sharp", "level": 2, "is_special": false, "desc": "Crit+2"}],
			"forge_count": 0
		}
	]
	bs_inst.update_all()
	
	# Place 1 material
	var place_ok1 = bs_inst.place_material(0, 0)
	assert(place_ok1, "Should successfully place material 0")
	assert(bs_inst._preview_timer.wait_time == 0.5, "Timer wait_time should be 0.5s (2 times per second)")
	assert(bs_inst._candidate_combinations.size() == 1, "Candidate combinations should have 1 combination")
	assert(bs_inst._candidate_combinations[0]["level"] == 10 and bs_inst._candidate_combinations[0]["rarity"] == "コモン")
	assert(bs_inst._current_target_forge_count == 1, "Target forge count should be 1 (+1)")
	
	# Place 2nd material
	var place_ok2 = bs_inst.place_material(1, 1)
	assert(place_ok2, "Should successfully place material 1")
	assert(bs_inst.btn_forge.disabled == false, "Forge button should be enabled with 2 materials")
	assert(bs_inst._candidate_combinations.size() > 1, "Should have multiple combinations")
	assert(bs_inst.skill_list_container.get_child_count() > 0, "Candidate skills should be populated")
	var first_row = bs_inst.skill_list_container.get_child(0) as Label
	assert(first_row != null, "Candidate skill rows must be Label without separate desc")
	assert(first_row.get_theme_font_size("font_size") >= 20, "Candidate skill name font size should be >= 20")
	assert(first_row.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Candidate skill must be centered")
	
	# Test roulette ticks: 50 consecutive ticks must never repeat the exact same (level, rarity) combination
	var prev_comb: Dictionary = {}
	for t in range(50):
		bs_inst._on_roulette_tick()
		var curr_comb = bs_inst._last_displayed_combination
		if not prev_comb.is_empty():
			var is_same: bool = (curr_comb["level"] == prev_comb["level"] and curr_comb["rarity"] == prev_comb["rarity"])
			assert(not is_same, "Consecutive combinations must not be identical on tick %d: %s vs %s" % [t, curr_comb, prev_comb])
		prev_comb = curr_comb
		assert(bs_inst._preview_equipment_icon.question_label.visible == true, "Roulette icon stays '?'")
		assert(bs_inst._preview_equipment_icon.forge_label.text == "+1", "Roulette forge count displays '+1'")
	print("  PASS: Material placing, 0.5s timer, non-border rows, and non-consecutive roulette combinations verified across 50 ticks.")
	
	# Test 4: Inventory loot drop does NOT trigger roulette tick or disrupt preview
	print("[Test 4] Testing equipment obtain / inventory_updated isolation...")
	var combo_before: Dictionary = bs_inst._last_displayed_combination.duplicate()
	# Simulate 10 new items dropping into empty slots 2 to 11
	for d in range(2, 12):
		GameData.inventories["main"].append({
			"id": "drop_%d" % d, "type": "main", "name": "Drop Sword %d" % d, "level": 5,
			"rarity": "コモン", "icon": "res://images/equip_icon/equip_main_1.png",
			"equip_skill": [], "forge_count": 0
		})
		GameData.inventory_updated.emit()
	
	# The displayed combination must NOT have changed from equipment loot drop!
	assert(bs_inst._last_displayed_combination["level"] == combo_before["level"], "Loot drops must NOT force roulette ticks")
	assert(bs_inst._last_displayed_combination["rarity"] == combo_before["rarity"], "Loot drops must NOT force roulette ticks")
	# Left inventory grid must have updated slot 2
	var slot2 = bs_inst.inventory_grid.get_child(2) as BlacksmithWindow.BlacksmithInventorySlot
	assert(slot2.child_item_ui != null, "Inventory slot 2 must reflect newly acquired loot item")
	assert(slot2.current_item_id == "drop_2", "Inventory slot 2 must have drop_2")
	print("  PASS: Equipment obtain / inventory_updated isolation verified.")
	
	# Test 5: Tooltip and Grid Overlay on ForgeMaterialSlot
	print("[Test 5] Testing Tooltip and Grid Overlay on ForgeMaterialSlot...")
	var mat_slot = bs_inst.material_grid.get_child(0) as BlacksmithWindow.ForgeMaterialSlot
	assert(mat_slot != null, "Material slot 0 must exist")
	assert(mat_slot.grid_overlay != null, "grid_overlay must exist")
	assert(mat_slot.grid_overlay.get_index() > mat_slot.icon_node.get_index(), "grid_overlay must be rendered above icon_node")
	var overlay_style = mat_slot.grid_overlay.get_theme_stylebox("panel") as StyleBoxFlat
	assert(overlay_style != null, "overlay_style must be StyleBoxFlat")
	assert(overlay_style.border_color.is_equal_approx(Color(0.65, 0.38, 0.18, 0.9)), "grid_overlay border_color must match preview frame color")
	assert(overlay_style.draw_center == false, "grid_overlay must have draw_center false")
	
	mat_slot._on_mouse_entered()
	assert(mat_slot._custom_tooltip != null, "Tooltip should be created on mouse_entered")
	mat_slot._on_mouse_exited()
	assert(mat_slot._custom_tooltip == null, "Tooltip should be freed on mouse_exited")
	print("  PASS: ForgeMaterialSlot tooltip and grid overlay verified.")
	
	# Test 6: Synthesis execution and reset to dummy
	print("[Test 6] Testing Synthesis and reset to dummy icon...")
	bs_inst._on_forge_pressed()
	assert(bs_inst.placed_materials.is_empty(), "Placed materials should be cleared after forge")
	assert(bs_inst._preview_equipment_icon.level_label.text == "Lv???", "Preview level must reset to 'Lv???'")
	assert(bs_inst._preview_equipment_icon.forge_label.visible == false, "Preview forge label must be hidden")
	assert(bs_inst.candidate_title_label.text == "候補スキル一覧", "CandidateTitleLabel stays '候補スキル一覧'")
	print("  PASS: Synthesis and reset to dummy icon verified.")
	
	# Test 7: Candidate skill vertical scrolling when overflowing
	print("[Test 7] Testing candidate skills vertical scrolling when overflowing...")
	var scroll = bs_inst.get_node("%SkillScroll") as ScrollContainer
	assert(scroll != null, "SkillScroll must exist")
	assert(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Horizontal scroll should be disabled")
	
	for i in range(20):
		var lbl = Label.new()
		lbl.text = "◆ Overflow Skill %d  Lv.1" % i
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 20)
		bs_inst.skill_list_container.add_child(lbl)
	
	await get_tree().process_frame
	await get_tree().process_frame
	var v_bar = scroll.get_v_scroll_bar()
	assert(v_bar.max_value > scroll.size.y, "VScrollBar max should exceed scroll height when many skills are added")
	scroll.scroll_vertical = 60
	await get_tree().process_frame
	assert(scroll.scroll_vertical == 60, "scroll_vertical should be scrollable to 60")
	print("  PASS: Candidate skills vertical scrolling verified.")
	
	bs_inst.queue_free()
	print("=== ALL TESTS PASSED! ===")
	get_tree().quit(0)
