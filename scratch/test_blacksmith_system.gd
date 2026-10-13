extends Node

func _ready() -> void:
	print("--- Starting Blacksmith System Tests ---")
	
	# 1. 装備生成テスト
	var eq1 := GameData.generate_random_equipment()
	assert(eq1.has("forge_count"), "eq1 must have forge_count")
	assert(eq1["forge_count"] == 0, "Initial forge_count must be 0")
	print("✓ Test 1: Initial equipment has forge_count = 0")
	
	# 2. プレビュー計算テスト
	var test_mat1 := {
		"id": "test_1",
		"name": "テストの剣A",
		"type": "main",
		"icon": "res://images/equip_icon/equip_main_1.png",
		"level": 10,
		"rarity": "コモン",
		"forge_count": 0,
		"equip_skill": [
			{ "id": "corner_trick", "name": "ミラクルバウンド", "level": 2, "is_special": false },
			{ "id": "saving", "name": "節約術", "level": 1, "is_special": false }
		]
	}
	var test_mat2 := {
		"id": "test_2",
		"name": "テストの剣B",
		"type": "main",
		"icon": "res://images/equip_icon/equip_main_2.png",
		"level": 30,
		"rarity": "アンコモン",
		"forge_count": 0,
		"equip_skill": [
			{ "id": "saving", "name": "節約術", "level": 3, "is_special": false },
			{ "id": "gold_rush", "name": "ゴールドラッシュ", "level": 4, "is_special": false }
		]
	}
	
	var preview_empty := GameData.calculate_forge_preview([])
	assert(not preview_empty["can_forge"], "Empty materials cannot be forged")
	
	var preview_single := GameData.calculate_forge_preview([test_mat1])
	assert(not preview_single["can_forge"], "Single material cannot be forged")
	
	var preview_two := GameData.calculate_forge_preview([test_mat1, test_mat2])
	assert(preview_two["can_forge"], "Two valid materials can be forged")
	assert(preview_two["forge_count"] == 1, "Target forge count should be 1")
	
	# スキル合算確認: corner_trick Lv2, saving Lv(1+3=4), gold_rush Lv4
	var skills: Array = preview_two["skills"]
	assert(skills.size() == 3, "Total unique skills should be 3")
	var saving_skill: Dictionary = {}
	for sk in skills:
		if sk["id"] == "saving":
			saving_skill = sk
			break
	assert(saving_skill["level"] == 4, "Saving skill level should be 1 + 3 = 4")
	print("✓ Test 2: Preview correctly aggregates skills (saving Lv4)")
	
	# 3. 鍛冶合成実行テスト
	# インベントリにアイテムをセット
	GameData._ensure_inventory_sizes()
	GameData.inventories["main"][2] = test_mat1
	GameData.inventories["main"][7] = test_mat2
	
	var forged_item := GameData.forge_equipment("main", [7, 2])
	assert(not forged_item.is_empty(), "Forged item should not be empty")
	assert(forged_item["forge_count"] == 1, "Forged item forge_count must be 1")
	assert(forged_item["type"] == "main", "Forged item type must be main")
	assert(forged_item["level"] == 10 or forged_item["level"] == 30, "Forged item level must be one of materials (10 or 30)")
	
	# 最上・最左（インデックス最小 = 2）に完成品が配置され、7は消滅
	assert(GameData.inventories["main"][2] != null, "Index 2 must contain forged item")
	assert(GameData.inventories["main"][2]["id"] == forged_item["id"], "Index 2 item ID must match forged item")
	assert(GameData.inventories["main"][7] == null, "Index 7 must be cleared (null)")
	print("✓ Test 3: Forging places result at min index (2) and clears other materials (7)")
	
	# 4. 鍛冶ウィンドウのインスタンス化・初期化テスト
	var blacksmith_scene := preload("res://scenes/ui/blacksmith_window.tscn")
	var bs_instance = blacksmith_scene.instantiate() as BlacksmithWindow
	add_child(bs_instance)
	assert(bs_instance != null, "blacksmith_window.tscn must instantiate successfully")
	assert(bs_instance.inventory_grid.get_child_count() == 50, "Inventory grid should have 50 slots")
	assert(bs_instance.material_grid.get_child_count() == 9, "Material grid should have 9 slots")
	print("✓ Test 4: blacksmith_window.tscn instantiated and populated 50 inv slots & 9 material slots")
	
	# 5. 素材配置テスト (place_material & remove_material)
	var place_ok := bs_instance.place_material(0, 2)
	assert(place_ok == true, "Placing material from index 2 should succeed")
	assert(bs_instance.placed_materials.has(0), "Slot 0 should have material")
	
	# 重複配置拒否テスト
	var place_dup := bs_instance.place_material(1, 2)
	assert(place_dup == false, "Placing duplicate material from index 2 should fail")
	
	# 取り出しテスト
	bs_instance.remove_material(0)
	assert(not bs_instance.placed_materials.has(0), "Slot 0 should be empty after removal")
	print("✓ Test 5: place_material and remove_material work as expected")
	
	# 6. HUD シーンのインスタンス化テスト
	var hud_scene := preload("res://scenes/ui/hud.tscn")
	var hud_instance = hud_scene.instantiate()
	add_child(hud_instance)
	assert(hud_instance != null, "hud.tscn must instantiate successfully")
	print("✓ Test 6: hud.tscn instantiated successfully")
	
	print("--- All Blacksmith Tests Passed Successfully! ---")
	get_tree().quit(0)
