extends Node
## Global game data singleton (Autoload).
## Manages currencies, statistics, and game state.

# --- Currency ---
var gold: int = 10000
var tokens: int = 0

# --- Statistics ---
var total_bounces: int = 0
var corner_hits: int = 0

# --- Upgrade Levels ---
var logo_count: int = 1
var speed_level: int = 0
var boost_level: int = 0
var ascension_level: int = 0
var skill_levels: Dictionary = {} # { "skill_id": level_int }

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
				
			tokens_changed.emit(tokens)
			skill_upgraded.emit(skill_id, skill_levels[skill_id])
			upgrades_changed.emit() # Recalculate speeds/etc.
			return true
	return false

