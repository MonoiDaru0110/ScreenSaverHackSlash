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

func generate_random_equipment() -> Dictionary:
	var types := ["main", "sub", "accessory"]
	var type: String = types[randi() % types.size()]
	var name := ""
	
	var prefix := ""
	var base := ""
	
	if type == "main":
		var main_prefixes := ["錆びた", "鋼鉄の", "魔力の", "勇者の", "伝説の", "暗黒の", "輝く"]
		var main_bases := ["ソード", "ブレード", "カタナ", "レイピア", "大剣"]
		prefix = main_prefixes[randi() % main_prefixes.size()]
		base = main_bases[randi() % main_bases.size()]
	elif type == "sub":
		var sub_prefixes := ["壊れた", "鉄の", "守護の", "ルーンの", "聖なる", "要塞の", "重厚な"]
		var sub_bases := ["シールド", "タワーシールド", "バックラー", "魔導書", "オーブ"]
		prefix = sub_prefixes[randi() % sub_prefixes.size()]
		base = sub_bases[randi() % sub_bases.size()]
	else:
		var acc_prefixes := ["古びた", "幸運の", "魔導の", "疾風の", "王家の", "守りの", "天使の"]
		var acc_bases := ["リング", "アミュレット", "ネックレス", "ブレスレット", "ブローチ"]
		prefix = acc_prefixes[randi() % acc_prefixes.size()]
		base = acc_bases[randi() % acc_bases.size()]
		
	name = prefix + base
	var id := "eq_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 1000)
	
	return {
		"id": id,
		"name": name,
		"type": type
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
	# Find item in inventories
	var found_item: Dictionary = {}
	for type in inventories:
		for item in inventories[type]:
			if item.get("id") == item_id:
				found_item = item
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
		
	# If already equipped in another slot, unequip it first
	for key in equipped_items:
		var eq = equipped_items[key]
		if eq != null and eq.get("id") == item_id:
			equipped_items[key] = null
			
	# Equip it
	equipped_items[slot_key] = found_item
	equipment_changed.emit()
	return true


func unequip_item(slot_key: String) -> void:
	if equipped_items.get(slot_key) != null:
		equipped_items[slot_key] = null
		equipment_changed.emit()


func is_item_equipped(item_id: String) -> String:
	for slot_key in equipped_items:
		var eq = equipped_items[slot_key]
		if eq != null and eq.get("id") == item_id:
			return slot_key
	return ""
