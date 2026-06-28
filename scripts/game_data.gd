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
var logo_count: int = 1
var speed_level: int = 0
var boost_level: int = 0
var ascension_level: int = 0
var skill_levels: Dictionary = {} # { "skill_id": level_int }

# --- Cumulative Skill Levels ---
var total_gold_boost_level: int = 0
var total_gold_cooltime_boost_level: int = 0
var total_get_gold_over_time_boost_level: int = 0
var total_gold_crit_boost_level: int = 0
var total_gold_direct_boost_level: int = 0

# --- Critical and Direct Hit Parameters ---
var gold_critical_parameter: float = 1.0
var gold_direct_hit_parameter: float = 1.0
var token_critical_parameter: float = 1.0
var token_direct_hit_parameter: float = 1.0

# --- Signals ---
signal gold_changed(new_amount: int)
signal tokens_changed(new_amount: int)
signal stats_changed()
signal corner_hit_occurred()
signal upgrades_changed()
signal logo_spawn_requested()
signal logo_reset_requested()
signal skill_upgraded(skill_id: String, new_level: int)


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


func perform_ascension() -> bool:
	if can_ascend():
		gold = 0
		# Do not reset tokens or skill_levels on ascension
		logo_count = 1 + get_skill_level("extra_logo")
		speed_level = 0
		boost_level = 0
		ascension_level += 1
		
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
	return token_critical_parameter


func get_token_direct_hit_parameter() -> float:
	return token_direct_hit_parameter


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
