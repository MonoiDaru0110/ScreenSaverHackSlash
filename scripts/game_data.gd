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
var total_equip_drop_probability_boost_level: int = 0
var total_equip_drop_rarity_boost_level: int = 0
var total_equip_drop_level_boost_level: int = 0
var total_accessory_slot_unlock_level: int = 0

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
var unlocked_slots: Dictionary = {
	"main": true,
	"sub": true,
	"accessory_1": true,
	"accessory_2": false,
	"accessory_3": false,
	"accessory_4": false
}
const MAX_TYPE_INVENTORY_SIZE: int = 50

const EQUIP_SKILLS_PATH = "res://data/equipment_skills.json"
var equipment_skill_defs: Dictionary = {}
var equipped_skill_levels: Dictionary = {}


func _load_equipment_skill_defs() -> void:
	if not FileAccess.file_exists(EQUIP_SKILLS_PATH):
		return
	var file := FileAccess.open(EQUIP_SKILLS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		if data is Dictionary and data.has("equipment_skills"):
			equipment_skill_defs = data["equipment_skills"]
	file.close()


func _recalculate_equipped_skill_levels() -> void:
	equipped_skill_levels.clear()
	for slot_key in equipped_items:
		if not is_slot_unlocked(slot_key):
			continue
		var item = equipped_items[slot_key]
		if item != null and item is Dictionary and not item.is_empty():
			var item_skills: Array = item.get("equip_skill", [])
			for sk in item_skills:
				if sk is Dictionary:
					var id_val: String = sk.get("id", "")
					if id_val.is_empty():
						var name_val: String = sk.get("name", "")
						for k in equipment_skill_defs:
							if equipment_skill_defs[k].get("name", "") == name_val:
								id_val = k
								break
					var lvl: int = int(sk.get("level", 1))
					if not id_val.is_empty():
						equipped_skill_levels[id_val] = equipped_skill_levels.get(id_val, 0) + lvl
	_recalculate_cached_multipliers()


func get_equipped_skill_total_val(skill_id: String) -> float:
	var lvl: int = equipped_skill_levels.get(skill_id, 0)
	if lvl <= 0:
		return 0.0
	var def: Dictionary = equipment_skill_defs.get(skill_id, {})
	var unit_val: float = float(def.get("unit_value", 0.0))
	return unit_val * lvl


func get_equipped_saving_cost_multiplier() -> float:
	var lvl: int = equipped_skill_levels.get("saving", 0)
	if lvl <= 0:
		return 1.0
	var unit_val: float = float(equipment_skill_defs.get("saving", {}).get("unit_value", 0.99))
	return pow(unit_val, lvl)


func get_equipped_token_saving_cost_multiplier() -> float:
	var lvl: int = equipped_skill_levels.get("token_saving", 0)
	if lvl <= 0:
		return 1.0
	var unit_val: float = float(equipment_skill_defs.get("token_saving", {}).get("unit_value", 0.99))
	return pow(unit_val, lvl)


func is_slot_unlocked(slot_key: String) -> bool:
	if slot_key == "main" or slot_key == "sub" or slot_key == "accessory_1":
		return true
	elif slot_key == "accessory_2":
		return total_accessory_slot_unlock_level >= 1
	elif slot_key == "accessory_3":
		return total_accessory_slot_unlock_level >= 2
	elif slot_key == "accessory_4":
		return total_accessory_slot_unlock_level >= 3
	return unlocked_slots.get(slot_key, false)


func set_slot_unlocked(slot_key: String, unlocked: bool) -> void:
	unlocked_slots[slot_key] = unlocked
	equipment_changed.emit()

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
	var base := int(100 * pow(2.0, logo_count - 1))
	return int(base * get_equipped_saving_cost_multiplier())


func get_speed_upgrade_cost() -> int:
	var base := int(10 + speed_level * 15)
	return int(base * get_equipped_saving_cost_multiplier())


func get_boost_upgrade_cost() -> int:
	var base := int(20 + boost_level * 25)
	return int(base * get_equipped_saving_cost_multiplier())


func get_size_upgrade_cost() -> int:
	var base := int(15 + size_level * 20)
	return int(base * get_equipped_saving_cost_multiplier())


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





func get_logo_size_multiplier() -> float:
	# 枠内ギリギリの追加可能限界 C (画面1662x1080に対してロゴ200x100。横幅限界 1662/200 = 8.31倍。マージン考慮で 8.25倍 -> C = 7.25)
	var max_C := 7.25
	var half_C := max_C * 0.5
	
	# 基礎強化レベル A (size_level) による収束寄与
	var level_A := float(size_level)
	var contrib_A := half_C * (1.0 - exp(-0.02 * level_A))
	
	# 装備スキルレベル B (size_boost) による収束寄与
	var level_B := get_equipped_skill_total_val("size_boost")
	var contrib_B := half_C * (1.0 - exp(-0.03 * level_B))
	
	return 1.0 + contrib_A + contrib_B


func get_corner_conversion_chance() -> float:
	var n := int(get_equipped_skill_total_val("corner_trick"))
	if n <= 0:
		return 0.0
	return 1.0 - pow(0.99, float(n))


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
	return gold_critical_parameter + float(total_gold_crit_boost_level) + get_equipped_skill_total_val("crit_boost")


func get_gold_direct_hit_parameter() -> float:
	return gold_direct_hit_parameter + float(total_gold_direct_boost_level) + get_equipped_skill_total_val("direct_boost")


func get_token_critical_parameter() -> float:
	return token_critical_parameter + float(total_token_crit_boost_level) + get_equipped_skill_total_val("crit_boost")


func get_token_direct_hit_parameter() -> float:
	return token_direct_hit_parameter + float(total_token_direct_boost_level) + get_equipped_skill_total_val("direct_boost")


func calculate_crit_result(crit_factor: float) -> Dictionary:
	if crit_factor <= 0.0:
		return {"multiplier": 1.0, "is_crit": false, "weight": 0}
	
	var chance_percent := 5.0 * crit_factor
	var n := int(floor(chance_percent / 100.0))
	var m := chance_percent - float(n * 100)
	
	var weight := n
	if randf() * 100.0 < m:
		weight += 1
		
	if weight <= 0:
		return {"multiplier": 1.0, "is_crit": false, "weight": 0}
		
	var base_crit_bonus := 0.05 * crit_factor
	var mult := 1.0 + float(weight) * base_crit_bonus
	return {"multiplier": mult, "is_crit": true, "weight": weight}


func roll_gold_critical() -> Dictionary:
	return calculate_crit_result(get_gold_critical_parameter())


func roll_token_critical() -> Dictionary:
	return calculate_crit_result(get_token_critical_parameter())


func calculate_direct_result(direct_factor: float) -> Dictionary:
	if direct_factor <= 0.0:
		return {"multiplier": 1.0, "is_direct": false}
	
	var chance_percent := minf(100.0, 5.0 * direct_factor)
	var is_direct := (randf() * 100.0) < chance_percent
	
	if not is_direct:
		return {"multiplier": 1.0, "is_direct": false}
		
	var base_direct_bonus := 0.01 * pow(direct_factor, 2.0)
	var mult := 1.0 + base_direct_bonus
	return {"multiplier": mult, "is_direct": true}


func roll_gold_direct() -> Dictionary:
	return calculate_direct_result(get_gold_direct_hit_parameter())


func roll_token_direct() -> Dictionary:
	return calculate_direct_result(get_token_direct_hit_parameter())


func _ready() -> void:
	_load_equipment_skill_defs()
	_ensure_inventory_sizes()
	_recalculate_all_cumulative_levels()
	_recalculate_equipped_skill_levels()
	_recalculate_cached_multipliers()
	equipment_changed.connect(_on_equipment_changed_internal)


func _on_equipment_changed_internal() -> void:
	_recalculate_equipped_skill_levels()
	upgrades_changed.emit()


func _ensure_inventory_sizes() -> void:
	for type in ["main", "sub", "accessory"]:
		if not inventories.has(type) or not inventories[type] is Array:
			inventories[type] = []
		var arr: Array = inventories[type]
		while arr.size() < MAX_TYPE_INVENTORY_SIZE:
			arr.append(null)


func get_inventory_count(type: String) -> int:
	_ensure_inventory_sizes()
	var count := 0
	var arr: Array = inventories.get(type, [])
	for item in arr:
		if item != null:
			count += 1
	return count


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
	total_equip_drop_probability_boost_level = _recalculate_total_level("equip_drop_probability_boost_")
	total_equip_drop_rarity_boost_level = _recalculate_total_level("equip_drop_rarity_boost_")
	total_equip_drop_level_boost_level = _recalculate_total_level("equip_drop_level_boost_")
	total_accessory_slot_unlock_level = _recalculate_total_level("accessory_slot_unlock_")
	_recalculate_cached_multipliers()


func _recalculate_cached_multipliers() -> void:
	var gold_equip_mult := 1.0 + get_equipped_skill_total_val("gold_boost") * 0.01
	var token_equip_mult := 1.0 + get_equipped_skill_total_val("token_boost") * 0.01
	_cached_gold_skill_mult = pow(1.1, total_gold_boost_level) * gold_equip_mult
	_cached_token_skill_mult = pow(1.1, total_token_boost_level) * token_equip_mult
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


func _check_and_update_cumulative(skill_id: String, prefix: String) -> bool:
	if skill_id.begins_with(prefix):
		var suffix: String = skill_id.substr(prefix.length())
		if suffix.is_valid_int() and suffix.to_int() > 0:
			return true
	return false


func _update_cumulative_levels(skill_id: String) -> void:
	if _check_and_update_cumulative(skill_id, "gold_boost_"):
		total_gold_boost_level = _recalculate_total_level("gold_boost_")
	elif _check_and_update_cumulative(skill_id, "gold_cooltime_boost_"):
		total_gold_cooltime_boost_level = _recalculate_total_level("gold_cooltime_boost_")
	elif _check_and_update_cumulative(skill_id, "get_gold_over_time_boost_"):
		total_get_gold_over_time_boost_level = _recalculate_total_level("get_gold_over_time_boost_")
	elif _check_and_update_cumulative(skill_id, "gold_critical_hit_boost_"):
		total_gold_crit_boost_level = _recalculate_total_level("gold_critical_hit_boost_")
	elif _check_and_update_cumulative(skill_id, "gold_direct_hit_boost_"):
		total_gold_direct_boost_level = _recalculate_total_level("gold_direct_hit_boost_")
	elif _check_and_update_cumulative(skill_id, "token_boost_"):
		total_token_boost_level = _recalculate_total_level("token_boost_")
	elif _check_and_update_cumulative(skill_id, "token_cooltime_boost_"):
		total_token_cooltime_boost_level = _recalculate_total_level("token_cooltime_boost_")
	elif _check_and_update_cumulative(skill_id, "get_token_over_time_boost_"):
		total_get_token_over_time_boost_level = _recalculate_total_level("get_token_over_time_boost_")
	elif _check_and_update_cumulative(skill_id, "token_critical_hit_boost_"):
		total_token_crit_boost_level = _recalculate_total_level("token_critical_hit_boost_")
	elif _check_and_update_cumulative(skill_id, "token_direct_hit_boost_"):
		total_token_direct_boost_level = _recalculate_total_level("token_direct_hit_boost_")
	elif _check_and_update_cumulative(skill_id, "equip_drop_probability_boost_"):
		total_equip_drop_probability_boost_level = _recalculate_total_level("equip_drop_probability_boost_")
	elif _check_and_update_cumulative(skill_id, "equip_drop_rarity_boost_"):
		total_equip_drop_rarity_boost_level = _recalculate_total_level("equip_drop_rarity_boost_")
	elif _check_and_update_cumulative(skill_id, "equip_drop_level_boost_"):
		total_equip_drop_level_boost_level = _recalculate_total_level("equip_drop_level_boost_")
	elif _check_and_update_cumulative(skill_id, "accessory_slot_unlock_"):
		total_accessory_slot_unlock_level = _recalculate_total_level("accessory_slot_unlock_")
		equipment_changed.emit()
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
	
	# Generate level: 10の倍数補正 (アセンション*乱数0.9~1.1 + ツリー補正+10/lvl)
	var base_asc := float(maxi(1, ascension_level))
	var rand_factor := randf_range(0.9, 1.1)
	var tree_level_bonus := float(total_equip_drop_level_boost_level * 10)
	var raw_level := (base_asc * rand_factor) + tree_level_bonus
	var level := maxi(10, int(round(raw_level / 10.0)) * 10)
	
	# Generate random rarity using Gaussian (Normal) Distribution model
	# Index x: 0:コモン, 1:アンコモン, 2:レア, 3:エピック, 4:レジェンド, 5:ミシック
	var rarity_level := total_equip_drop_rarity_boost_level + int(get_equipped_skill_total_val("drop_luck"))
	var L := float(rarity_level)
	var mu := minf(5.0, 0.05 * L)
	# muが5.0に達する(L > 100)までは広いばらつき sigma=1.10 を維持し、
	# ミシック到達以降に標準偏差が収束してミシック100%確定へ向かう
	var extra_L := maxf(0.0, L - 100.0)
	var sigma := 0.01 + 1.09 * exp(-0.02 * extra_L)

	var weights: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var total_w := 0.0
	for x in range(6):
		var diff := float(x) - mu
		var w := exp(- (diff * diff) / (2.0 * sigma * sigma))
		weights[x] = w
		total_w += w

	var roll := randf() * total_w
	var accumulated_w := 0.0
	var rarity_names := ["コモン", "アンコモン", "レア", "エピック", "レジェンド", "ミシック"]
	var rarity: String = "コモン"
	for x in range(6):
		accumulated_w += weights[x]
		if roll <= accumulated_w:
			rarity = rarity_names[x]
			break
	
	# レア度に応じたスキル付与数
	var num_skills := 1
	match rarity:
		"コモン":
			num_skills = 1
		"アンコモン":
			num_skills = 2
		"レア":
			num_skills = 3
		"エピック":
			num_skills = 4
		"レジェンド":
			num_skills = 5
		"ミシック":
			num_skills = 6

	# 利用可能なオプション効果（スキル）のキーをシャッフル
	var skill_keys := equipment_skill_defs.keys()
	skill_keys.shuffle()
	
	# スキルレベル配分 (平均 = 装備レベル/10 + 洗練レベル*0.1)
	var refinement_total := get_equipped_skill_total_val("refinement")
	var target_avg_skill_level := (float(level) / 10.0) + refinement_total
	
	var float_skill_levels: Array[float] = []
	for i in range(num_skills):
		float_skill_levels.append(target_avg_skill_level)
		
	# 総和保存型の3割幅 (±30%) 分散
	if num_skills >= 2:
		for i in range(num_skills / 2):
			var idx1 := i
			var idx2 := num_skills - 1 - i
			var max_disp := target_avg_skill_level * 0.3
			var disp := randf_range(-max_disp, max_disp)
			float_skill_levels[idx1] += disp
			float_skill_levels[idx2] -= disp
			
	# 小数点確率還元を適用して整数レベル化（最低1）
	var final_skill_levels: Array[int] = []
	for s_val in float_skill_levels:
		var int_part := int(s_val)
		var frac_part := s_val - float(int_part)
		if randf() < frac_part:
			int_part += 1
		final_skill_levels.append(maxi(1, int_part))
		
	# スキルレベルが大きい順（降順）にソート
	final_skill_levels.sort_custom(func(a, b): return a > b)

	var item_skills: Array[Dictionary] = []
	for i in range(min(num_skills, skill_keys.size())):
		var sk_id: String = skill_keys[i]
		var sk_def: Dictionary = equipment_skill_defs.get(sk_id, {})
		var sk_name: String = sk_def.get("name", "")
		var unit_val: float = float(sk_def.get("unit_value", 1.0))
		var desc_tmpl: String = sk_def.get("desc_template", "%s")
		
		var s_level: int = final_skill_levels[i]
		var total_val = unit_val * s_level
		if sk_id == "saving" or sk_id == "token_saving":
			total_val = pow(unit_val, float(s_level))
		
		# 説明文フォーマットの生成
		var formatted_desc := desc_tmpl
		if sk_id == "corner_trick":
			var chance_percent := int((1.0 - pow(0.99, float(s_level))) * 100.0)
			formatted_desc = desc_tmpl % chance_percent
		elif "%" in desc_tmpl:
			var tmpl := desc_tmpl.replace("%f", "%.1f")
			if "%.2f" in tmpl or "%.1f" in tmpl:
				formatted_desc = tmpl % float(total_val)
			else:
				formatted_desc = tmpl % int(total_val)
				
		item_skills.append({
			"id": sk_id,
			"name": sk_name,
			"level": s_level,
			"desc": formatted_desc
		})
	
	return {
		"id": id,
		"name": name,
		"type": type,
		"icon": icon_path,
		"level": level,
		"rarity": rarity,
		"equip_skill": item_skills
	}


func roll_equipment_drop(is_corner: bool) -> Dictionary:
	# 装備ドロップ解放スキルが未習得の場合はドロップしない
	if get_skill_level("equip_drop_unlock") <= 0:
		return {}
		
	# 累積ドロップ率係数 L (スキルツリーレベル + 装備スキル「大漁」レベル)
	var L := float(total_equip_drop_probability_boost_level) + get_equipped_skill_total_val("drop_rate_boost")
	
	# 分数関数(反比例)漸近収束モデル: P(L) = 1.0 - (1.0 - P_base) / (1.0 + 0.03 * L)
	var base_drop_chance := 0.15 if is_corner else 0.02
	var drop_chance := 1.0 - (1.0 - base_drop_chance) / (1.0 + 0.03 * L)
		
	if randf() < drop_chance:
		var item := generate_random_equipment()
		var type = item.get("type", "")
		_ensure_inventory_sizes()
		var inv: Array = inventories.get(type, [])
		
		# 最初の空きスロット (null) を探す
		var empty_index := -1
		for i in range(inv.size()):
			if inv[i] == null:
				empty_index = i
				break
				
		if empty_index != -1:
			inv[empty_index] = item
			equipment_changed.emit()
			return item
		else:
			# インベントリ満タン時: インベントリには追加せず、売却金を追加して通知用データを返す
			var sell_price := 100
			add_gold(sell_price)
			item["is_sold"] = true
			item["sell_price"] = sell_price
			return item
	return {}


func equip_item_by_id(item_id: String, slot_key: String) -> bool:
	if not is_slot_unlocked(slot_key):
		return false
		
	_ensure_inventory_sizes()
	# 1. 装備中アイテム間でのスロット付け替え
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
		
		if slot_key == "main" and item_type_a != "main":
			return false
		elif slot_key == "sub" and item_type_a != "sub":
			return false
		elif slot_key.begins_with("accessory_") and item_type_a != "accessory":
			return false
			
		var item_b = equipped_items.get(slot_key)
		equipped_items[slot_key] = item_a
		equipped_items[from_slot_key] = item_b
		equipment_changed.emit()
		return true

	# 2. インベントリからの装備
	var found_type: String = ""
	var found_index: int = -1
	var found_item: Dictionary = {}
	
	for type in inventories:
		var arr: Array = inventories[type]
		for i in range(arr.size()):
			var element = arr[i]
			if element != null and element is Dictionary and element.get("id") == item_id:
				found_item = element
				found_type = type
				found_index = i
				break
		if not found_item.is_empty():
			break
			
	if found_item.is_empty():
		return false
		
	var item_type: String = found_item.get("type", "")
	if slot_key == "main" and item_type != "main":
		return false
	elif slot_key == "sub" and item_type != "sub":
		return false
	elif slot_key.begins_with("accessory_") and item_type != "accessory":
		return false
		
	var old_equipped = equipped_items.get(slot_key)
	
	# インベントリの found_index 位置を old_equipped (または null) に入れ替える（位置保存）
	inventories[found_type][found_index] = old_equipped
				
	equipped_items[slot_key] = found_item
	equipment_changed.emit()
	return true


func unequip_item(slot_key: String) -> void:
	unequip_item_to_index(slot_key, -1)


func unequip_item_to_index(slot_key: String, target_index: int) -> void:
	_ensure_inventory_sizes()
	var old_equipped = equipped_items.get(slot_key)
	if old_equipped == null or old_equipped.is_empty():
		return
		
	var item_type: String = old_equipped.get("type", "")
	if not inventories.has(item_type):
		return
		
	var arr: Array = inventories[item_type]
	
	# target_index が有効範囲内の場合
	if target_index >= 0 and target_index < MAX_TYPE_INVENTORY_SIZE:
		var target_inv_item = arr[target_index]
		if target_inv_item == null:
			arr[target_index] = old_equipped
			equipped_items[slot_key] = null
			equipment_changed.emit()
			return
		else:
			# 既にアイテムが存在する場合、同じタイプなら装備スロットとスワップ
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
				
	# target_index が無効かスワップ不可だった場合、最初の空きスロット (null) を探す
	var empty_index := -1
	for i in range(MAX_TYPE_INVENTORY_SIZE):
		if arr[i] == null:
			empty_index = i
			break
			
	if empty_index != -1:
		arr[empty_index] = old_equipped
		equipped_items[slot_key] = null
		equipment_changed.emit()


func swap_inventory_items(type: String, index_a: int, index_b: int) -> void:
	_ensure_inventory_sizes()
	if not inventories.has(type):
		return
	var arr: Array = inventories[type]
	if index_a < 0 or index_a >= MAX_TYPE_INVENTORY_SIZE:
		return
	if index_b < 0 or index_b >= MAX_TYPE_INVENTORY_SIZE:
		return
	if index_a == index_b:
		return
		
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
