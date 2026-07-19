extends Node
## Global game data singleton (Autoload).
## Manages currencies, statistics, and game state.

# --- Currency ---
var gold: int = 10000
var tokens: int = 10000

# --- Statistics ---
var total_bounces: int = 0
var corner_hits: int = 0

# --- Upgrade Levels ---
var logo_count: int = 100
var speed_level: int = 100
var boost_level: int = 100
var size_level: int = 100
var ascension_level: int = 100
var skill_levels: Dictionary = {} # { "skill_id": level_int }

# --- Cumulative Skill Levels ---
var total_gold_boost_level: int = 0
var total_gold_cooltime_boost_level: int = 0
var total_get_gold_over_time_boost_level: int = 0
var total_gold_crit_boost_level: int = 0
var total_gold_direct_boost_level: int = 0
var total_token_boost_level: int = 0
var total_token_cooltime_boost_level: int = 0
var total_get_token_over_time_boost_level: int = 0
var total_token_crit_boost_level: int = 0
var total_token_direct_boost_level: int = 0

# --- Critical and Direct Hit Parameters ---
var gold_critical_parameter: float = 1.0
var gold_direct_hit_parameter: float = 1.0
var token_critical_parameter: float = 1.0
var token_direct_hit_parameter: float = 1.0

# --- Cached Multipliers (invalidated on skill upgrade) ---
var _cached_gold_skill_mult: float = 1.0
var _cached_token_skill_mult: float = 1.0
var _cached_gold_over_time_boost_mult: float = 1.0
var _cached_token_over_time_boost_mult: float = 1.0
var _cached_ascension_mult: float = 1.0

# --- Equipment ---
var inventories: Dictionary = {
	"main": [],
	"sub": [],
	"accessory": []
}
var equipped_items: Dictionary = {
	"main": null,
	"sub": null,
	"accessory_1": null,
	"accessory_2": null,
	"accessory_3": null,
	"accessory_4": null
}
const MAX_TYPE_INVENTORY_SIZE: int = 50

# --- Signals ---
signal gold_changed(new_amount: int)
signal tokens_changed(new_amount: int)
signal stats_changed()
signal corner_hit_occurred()
signal upgrades_changed()
signal logo_spawn_requested()
signal logo_reset_requested()
signal skill_upgraded(skill_id: String, new_level: int)
signal equipment_changed()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func add_tokens(amount: int) -> void:
	tokens += amount
	tokens_changed.emit(tokens)


func record_bounce(is_corner: bool) -> void:
	total_bounces += 1
	if is_corner:
		corner_hits += 1
		corner_hit_occurred.emit()
	stats_changed.emit()


# --- Upgrade Logic ---

func get_logo_upgrade_cost() -> int:
	return int(100 * pow(2.0, logo_count - 1))


func get_speed_upgrade_cost() -> int:
	return int(10 + speed_level * 15)


func get_boost_upgrade_cost() -> int:
	return int(20 + boost_level * 25)


func get_ascension_multiplier() -> float:
	return 1.0 + ascension_level * 2.0


func can_ascend() -> bool:
	return gold >= 1000


func buy_logo_upgrade() -> bool:
	var cost := get_logo_upgrade_cost()
	if gold >= cost:
		gold -= cost
		gold_changed.emit(gold)
		logo_count += 1
		upgrades_changed.emit()
		logo_spawn_requested.emit()
		return true
	return false


func buy_speed_upgrade() -> bool:
	var cost := get_speed_upgrade_cost()
	if gold >= cost:
		gold -= cost
		gold_changed.emit(gold)
		speed_level += 1
		upgrades_changed.emit()
		return true
	return false


func buy_boost_upgrade() -> bool:
	var cost := get_boost_upgrade_cost()
	if gold >= cost:
		gold -= cost
		gold_changed.emit(gold)
		boost_level += 1
		upgrades_changed.emit()
		return true
	return false


func buy_size_upgrade() -> bool:
	var cost := get_size_upgrade_cost()
	if gold >= cost:
		gold -= cost
		gold_changed.emit(gold)
		size_level += 1
		upgrades_changed.emit()
		return true
	return false


func get_size_upgrade_cost() -> int:
	return int(15 + size_level * 20)


func get_logo_size_multiplier() -> float:
	return clampf(1.0 + size_level * 0.1, 0.5, 3.0)


func perform_ascension() -> bool:
	if can_ascend():
		gold = 0
		# Do not reset tokens or skill_levels on ascension
		ascension_level += 1
		logo_count = 1 + ascension_level + get_skill_level("extra_logo")
		speed_level = 0
		boost_level = 0
		size_level = 0
		
		gold_changed.emit(gold)
		upgrades_changed.emit()
		logo_reset_requested.emit()
		return true
	return false


func get_skill_level(skill_id: String) -> int:
	return skill_levels.get(skill_id, 0)


func get_gold_critical_parameter() -> float:
	return gold_critical_parameter * pow(1.1, total_gold_crit_boost_level)


func get_gold_direct_hit_parameter() -> float:
	return gold_direct_hit_parameter * pow(1.1, total_gold_direct_boost_level)


func get_token_critical_parameter() -> float:
	return token_critical_parameter * pow(1.1, total_token_crit_boost_level)


func get_token_direct_hit_parameter() -> float:
	return token_direct_hit_parameter * pow(1.1, total_token_direct_boost_level)


func get_gold_crit_chance() -> float:
	var x = get_gold_critical_parameter()
	return 1.0 / (1.0 + exp(-1.0 * (x - 4.0)))


func get_gold_crit_multiplier() -> float:
	var x = get_gold_critical_parameter()
	return 1.5 + 0.015 * x


func get_gold_direct_chance() -> float:
	var x = get_gold_direct_hit_parameter()
	return 0.2 + 0.8 / (1.0 + exp(-1.0 * (x - 3.0)))


func get_gold_direct_multiplier() -> float:
	var x = get_gold_direct_hit_parameter()
	return 1.2 + 0.01 * x


func get_token_crit_chance() -> float:
	var x = get_token_critical_parameter()
	return 1.0 / (1.0 + exp(-1.0 * (x - 4.0)))


func get_token_crit_multiplier() -> float:
	var x = get_token_critical_parameter()
	return 1.5 + 0.015 * x


func get_token_direct_chance() -> float:
	var x = get_token_direct_hit_parameter()
	return 0.2 + 0.8 / (1.0 + exp(-1.0 * (x - 3.0)))


func get_token_direct_multiplier() -> float:
	var x = get_token_direct_hit_parameter()
	return 1.2 + 0.01 * x


func _ready() -> void:
	_recalculate_all_cumulative_levels()
	_recalculate_cached_multipliers()


func _recalculate_all_cumulative_levels() -> void:
	total_gold_boost_level = _recalculate_total_level("gold_boost_")
	total_gold_cooltime_boost_level = _recalculate_total_level("gold_cooltime_boost_")
	total_get_gold_over_time_boost_level = _recalculate_total_level("get_gold_over_time_boost_")
	total_gold_crit_boost_level = _recalculate_total_level("gold_critical_hit_boost_")
	total_gold_direct_boost_level = _recalculate_total_level("gold_direct_hit_boost_")
	total_token_boost_level = _recalculate_total_level("token_boost_")
	total_token_cooltime_boost_level = _recalculate_total_level("token_cooltime_boost_")
	total_get_token_over_time_boost_level = _recalculate_total_level("get_token_over_time_boost_")
	total_token_crit_boost_level = _recalculate_total_level("token_critical_hit_boost_")
	total_token_direct_boost_level = _recalculate_total_level("token_direct_hit_boost_")
	_recalculate_cached_multipliers()


func _recalculate_cached_multipliers() -> void:
	_cached_gold_skill_mult = pow(1.1, total_gold_boost_level)
	_cached_token_skill_mult = pow(1.1, total_token_boost_level)
	_cached_gold_over_time_boost_mult = pow(1.1, total_get_gold_over_time_boost_level)
	_cached_token_over_time_boost_mult = pow(1.1, total_get_token_over_time_boost_level)
	_cached_ascension_mult = get_ascension_multiplier()


func _recalculate_total_level(prefix: String) -> int:
	var total := 0
	var prefix_len := prefix.length()
	for id in skill_levels:
		if id.begins_with(prefix):
			var suffix: String = id.substr(prefix_len)
			if suffix.is_valid_int() and suffix.to_int() > 0:
				total += skill_levels[id]
	return total


func _update_cumulative_levels(skill_id: String) -> void:
	if skill_id.begins_with("gold_boost_"):
		var suffix: String = skill_id.substr(11)
		if suffix.is_valid_int() and suffix.to_int() > 0:
			total_gold_boost_level = _recalculate_total_level("gold_boost_")
	elif skill_id.begins_with("gold_cooltime_boost_"):
		var suffix: String = skill_id.substr(20) # "gold_cooltime_boost_".length() = 20
		if suffix.is_valid_int() and suffix.to_int() > 0:
			total_gold_cooltime_boost_level = _recalculate_total_level("gold_cooltime_boost_")
	elif skill_id.begins_with("get_gold_over_time_boost_"):
		var suffix: String = skill_id.substr(25) # "get_gold_over_time_boost_".length() = 25
		if suffix.is_valid_int() and suffix.to_int() > 0:
			total_get_gold_over_time_boost_level = _recalculate_total_level("get_gold_over_time_boost_")
	elif skill_id.begins_with("gold_critical_hit_boost_"):
		var suffix: String = skill_id.substr(24) # "gold_critical_hit_boost_".length() = 24
		if suffix.is_valid_int() and suffix.to_int() > 0:
			total_gold_crit_boost_level = _recalculate_total_level("gold_critical_hit_boost_")
	elif skill_id.begins_with("gold_direct_hit_boost_"):
		var suffix: String = skill_id.substr(22) # "gold_direct_hit_boost_".length() = 22
		if suffix.is_valid_int() and suffix.to_int() > 0:
			total_gold_direct_boost_level = _recalculate_total_level("gold_direct_hit_boost_")
	elif skill_id.begins_with("token_boost_"):
		var suffix: String = skill_id.substr(12) # "token_boost_".length() = 12
		if suffix.is_valid_int() and suffix.to_int() > 0:
			total_token_boost_level = _recalculate_total_level("token_boost_")
	elif skill_id.begins_with("token_cooltime_boost_"):
		var suffix: String = skill_id.substr(21) # "token_cooltime_boost_".length() = 21
		if suffix.is_valid_int() and suffix.to_int() > 0:
			total_token_cooltime_boost_level = _recalculate_total_level("token_cooltime_boost_")
	elif skill_id.begins_with("get_token_over_time_boost_"):
		var suffix: String = skill_id.substr(26) # "get_token_over_time_boost_".length() = 26
		if suffix.is_valid_int() and suffix.to_int() > 0:
			total_get_token_over_time_boost_level = _recalculate_total_level("get_token_over_time_boost_")
	elif skill_id.begins_with("token_critical_hit_boost_"):
		var suffix: String = skill_id.substr(25) # "token_critical_hit_boost_".length() = 25
		if suffix.is_valid_int() and suffix.to_int() > 0:
			total_token_crit_boost_level = _recalculate_total_level("token_critical_hit_boost_")
	elif skill_id.begins_with("token_direct_hit_boost_"):
		var suffix: String = skill_id.substr(23) # "token_direct_hit_boost_".length() = 23
		if suffix.is_valid_int() and suffix.to_int() > 0:
			total_token_direct_boost_level = _recalculate_total_level("token_direct_hit_boost_")
	_recalculate_cached_multipliers()


func buy_skill_upgrade(skill_id: String, cost: int, max_level: int) -> bool:
	if tokens >= cost:
		var current_lvl = get_skill_level(skill_id)
		if current_lvl < max_level:
			tokens -= cost
			skill_levels[skill_id] = current_lvl + 1
			
			# Apply immediate passive effect for extra logo
			if skill_id == "extra_logo":
				logo_count += 1
				logo_spawn_requested.emit()
				
			# Update cumulative skill levels
			_update_cumulative_levels(skill_id)
				
			tokens_changed.emit(tokens)
			skill_upgraded.emit(skill_id, skill_levels[skill_id])
			upgrades_changed.emit() # Recalculate speeds/etc.
			return true
	return false


# --- Equipment Logic ---

func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"コモン":
			return Color.from_hsv(0.0, 0.0, 0.75)      # Light Muted Gray
		"アンコモン":
			return Color.from_hsv(0.333, 0.85, 0.9)    # Bright Green (Hue ~120)
		"レア":
			return Color.from_hsv(0.583, 0.85, 0.9)    # Bright Blue (Hue ~210)
		"エピック":
			return Color.from_hsv(0.778, 0.85, 0.9)    # Bright Purple (Hue ~280)
		"レジェンド":
			return Color.from_hsv(0.097, 0.85, 0.9)    # Bright Orange (Hue ~35)
		"ミシック":
			return Color.from_hsv(0.0, 0.85, 0.9)      # Bright Red (Hue 0)
		_:
			return Color(1.0, 1.0, 1.0)


func get_rarity_bg_path(rarity: String) -> String:
	match rarity:
		"コモン":
			return "res://images/equip_bg/equip_bg_common.png"
		"アンコモン":
			return "res://images/equip_bg/equip_bg_uncommon.png"
		"レア":
			return "res://images/equip_bg/equip_bg_rare.png"
		"エピック":
			return "res://images/equip_bg/equip_bg_epic.png"
		"レジェンド":
			return "res://images/equip_bg/equip_bg_legend.png"
		"ミシック":
			return "res://images/equip_bg/equip_bg_mythic.png"
		_:
			return "res://images/equip_bg/equip_bg_common.png"



func generate_random_equipment() -> Dictionary:
	var types: Array[String] = ["main", "sub", "accessory"]
	var type: String = types[randi() % types.size()]
	var name := ""
	
	var prefix := ""
	var base := ""
	
	if type == "main":
		var main_prefixes: Array[String] = ["錆びた", "鋼鉄の", "魔力の", "勇者の", "伝説の", "暗黒の", "輝く"]
		var main_bases: Array[String] = ["ソード", "ブレード", "カタナ", "レイピア", "大剣"]
		prefix = main_prefixes[randi() % main_prefixes.size()]
		base = main_bases[randi() % main_bases.size()]
	elif type == "sub":
		var sub_prefixes: Array[String] = ["壊れた", "鉄の", "守護の", "ルーンの", "聖なる", "要塞の", "重厚な"]
		var sub_bases: Array[String] = ["シールド", "タワーシールド", "バックラー", "魔導書", "オーブ"]
		prefix = sub_prefixes[randi() % sub_prefixes.size()]
		base = sub_bases[randi() % sub_bases.size()]
	else:
		var acc_prefixes: Array[String] = ["古びた", "幸運の", "魔導の", "疾風の", "王家の", "守りの", "天使の"]
		var acc_bases: Array[String] = ["リング", "アミュレット", "ネックレス", "ブレスレット", "ブローチ"]
		prefix = acc_prefixes[randi() % acc_prefixes.size()]
		base = acc_bases[randi() % acc_bases.size()]
		
	name = prefix + base
	var id := "eq_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 1000)
	
	# Generate random icon path (1 or 2)
	var icon_num := (randi() % 2) + 1
	var icon_path := "res://images/equip_icon/equip_%s_%d.png" % [type, icon_num]
	
	# Generate random level (1 to 100)
	var level := randi_range(1, 100)
	
	# Generate random rarity
	var rarities: Array[String] = ["コモン", "アンコモン", "レア", "エピック", "レジェンド", "ミシック"]
	var rarity: String = rarities[randi() % rarities.size()]
	
	return {
		"id": id,
		"name": name,
		"type": type,
		"icon": icon_path,
		"level": level,
		"rarity": rarity
	}


func roll_equipment_drop(is_corner: bool) -> Dictionary:
	var drop_chance := 1.0
	if is_corner:
		drop_chance = 0.15
		
	if randf() < drop_chance:
		var item := generate_random_equipment()
		var type = item.get("type", "")
		var inv: Array = inventories.get(type, [])
		if inv.size() < MAX_TYPE_INVENTORY_SIZE:
			inv.append(item)
			equipment_changed.emit()
			return item
	return {}


func equip_item_by_id(item_id: String, slot_key: String) -> bool:
	# 1. First, check if the item is currently equipped in another slot
	var from_slot_key: String = ""
	for key in equipped_items:
		var eq = equipped_items[key]
		if eq != null and eq.get("id") == item_id:
			from_slot_key = key
			break
			
	if from_slot_key != "":
		if from_slot_key == slot_key:
			return true
			
		var item_a: Dictionary = equipped_items[from_slot_key]
		var item_type_a: String = item_a.get("type", "")
		
		# Check type restriction for target slot_key
		if slot_key == "main" and item_type_a != "main":
			return false
		elif slot_key == "sub" and item_type_a != "sub":
			return false
		elif slot_key.begins_with("accessory_") and item_type_a != "accessory":
			return false
			
		# Swap equipped items between from_slot_key and slot_key
		var item_b = equipped_items.get(slot_key)
		equipped_items[slot_key] = item_a
		equipped_items[from_slot_key] = item_b
		equipment_changed.emit()
		return true

	# 2. Otherwise, find item in inventories
	var found_type: String = ""
	var found_index: int = -1
	var found_item: Dictionary = {}
	
	for type in inventories:
		var arr: Array = inventories[type]
		for i in range(arr.size()):
			if arr[i].get("id") == item_id:
				found_item = arr[i]
				found_type = type
				found_index = i
				break
		if not found_item.is_empty():
			break
			
	if found_item.is_empty():
		return false
		
	# Check type restrictions
	var item_type: String = found_item.get("type", "")
	if slot_key == "main" and item_type != "main":
		return false
	elif slot_key == "sub" and item_type != "sub":
		return false
	elif slot_key.begins_with("accessory_") and item_type != "accessory":
		return false
		
	# Get currently equipped item in target slot if any
	var old_equipped = equipped_items.get(slot_key)
	
	# Remove newly equipped item from inventory
	if found_index >= 0 and inventories.has(found_type):
		inventories[found_type].remove_at(found_index)
		
	# If there was an old item equipped, swap it back into inventory
	if old_equipped != null and not old_equipped.is_empty():
		if inventories.has(found_type):
			if found_index <= inventories[found_type].size():
				inventories[found_type].insert(found_index, old_equipped)
			else:
				inventories[found_type].append(old_equipped)
				
	# Set new equipped item
	equipped_items[slot_key] = found_item
	equipment_changed.emit()
	return true


func unequip_item(slot_key: String) -> void:
	unequip_item_to_index(slot_key, -1)


func unequip_item_to_index(slot_key: String, target_index: int) -> void:
	var old_equipped = equipped_items.get(slot_key)
	if old_equipped == null or old_equipped.is_empty():
		return
		
	var item_type: String = old_equipped.get("type", "")
	if not inventories.has(item_type):
		return
		
	var arr: Array = inventories[item_type]
	
	# If target_index points to an existing item in inventory, swap equipped item with inventory item if valid
	if target_index >= 0 and target_index < arr.size():
		var target_inv_item = arr[target_index]
		var target_type: String = target_inv_item.get("type", "")
		
		var can_equip := false
		if slot_key == "main" and target_type == "main":
			can_equip = true
		elif slot_key == "sub" and target_type == "sub":
			can_equip = true
		elif slot_key.begins_with("accessory_") and target_type == "accessory":
			can_equip = true
			
		if can_equip:
			arr[target_index] = old_equipped
			equipped_items[slot_key] = target_inv_item
			equipment_changed.emit()
			return
			
	if arr.size() >= MAX_TYPE_INVENTORY_SIZE:
		return # Inventory full
		
	if target_index >= 0 and target_index <= arr.size():
		arr.insert(target_index, old_equipped)
	else:
		arr.append(old_equipped)
		
	equipped_items[slot_key] = null
	equipment_changed.emit()


func swap_inventory_items(type: String, index_a: int, index_b: int) -> void:
	if not inventories.has(type):
		return
	var arr: Array = inventories[type]
	if index_a < 0 or index_a >= arr.size():
		return
		
	if index_b < 0:
		index_b = 0
	elif index_b >= arr.size():
		# If dropped on empty slot beyond array bounds, move to end
		var item = arr[index_a]
		arr.remove_at(index_a)
		arr.append(item)
		equipment_changed.emit()
		return
		
	if index_a == index_b:
		return
		
	# Swap elements inside inventory array
	var temp = arr[index_a]
	arr[index_a] = arr[index_b]
	arr[index_b] = temp
	equipment_changed.emit()


func is_item_equipped(item_id: String) -> String:
	for slot_key in equipped_items:
		var eq = equipped_items[slot_key]
		if eq != null and eq.get("id") == item_id:
			return slot_key
	return ""
