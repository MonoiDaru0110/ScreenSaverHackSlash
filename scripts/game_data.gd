extends Node
## Global game data singleton (Autoload).
## Manages currencies, statistics, and game state.

# --- Currency ---
var gold: float = 10000.0
var tokens: float = 10000.0
var stars: int = 0
var infused_tokens: float = 0.0
var is_infusing_tokens: bool = false
var star_level: int = 0
var base_star_threshold: float = 1000.0


static func add_commas(int_str: String) -> String:
	var prefix := ""
	var s := int_str
	if s.begins_with("-"):
		prefix = "-"
		s = s.substr(1)
	var res := ""
	var n := s.length()
	for i in range(n):
		if i > 0 and (n - i) % 3 == 0:
			res += ","
		res += s[i]
	return prefix + res


func format_num(val: float) -> String:
	var abs_v := absf(val)
	if abs_v == 0.0:
		return "0"

	var sign_str := "-" if val < 0.0 else ""

	# 1. 絶対値が1以上
	if abs_v >= 1.0:
		var rounded_v := roundf(abs_v)
		if rounded_v < 1e10:
			# 1e10までは整数で3桁カンマ区切り表記する
			var int_str := "%d" % int(rounded_v)
			return "%s%s" % [sign_str, add_commas(int_str)]
		else:
			# 1e10以降は1e10などの簡易表示を行う
			var exp_val := floori(log(abs_v) / log(10.0))
			var mantissa := abs_v / pow(10.0, float(exp_val))
			if mantissa >= 9.995:
				mantissa = 1.0
				exp_val += 1
			var m_str := "%.2f" % mantissa
			if m_str.contains("."):
				m_str = m_str.rstrip("0").rstrip(".")
			return "%s%se%d" % [sign_str, m_str, exp_val]

	# 2. 絶対値が1未満
	if abs_v >= 1e-2:
		# 1e-2までは2桁まで表示した少数で表示(0.90,0.023など)
		var exp_val := floori(log(abs_v) / log(10.0))
		var decimals := -exp_val + 1
		var factor := pow(10.0, float(decimals))
		var rounded: float = roundf(abs_v * factor) / factor
		if rounded >= 1.0:
			return "%s1" % sign_str
		var new_exp := floori(log(rounded) / log(10.0))
		var new_decimals := -new_exp + 1
		return ("%s%." + str(new_decimals) + "f") % [sign_str, rounded]
	else:
		# それより小さい数値は指数表記する
		var exp_val := floori(log(abs_v) / log(10.0))
		var mantissa := abs_v / pow(10.0, float(exp_val))
		if mantissa >= 9.995:
			mantissa = 1.0
			exp_val += 1
		var m_str := "%.2f" % mantissa
		if m_str.contains("."):
			m_str = m_str.rstrip("0").rstrip(".")
		return "%s%se%d" % [sign_str, m_str, exp_val]
var reincarnation_level: int = 0
var pending_reincarnation_upgrades: Dictionary = {} # 特殊スキル予約 { "upgrade_id": level_int }
var active_reincarnation_upgrades: Dictionary = {}  # 特殊スキル適用済み { "upgrade_id": level_int }
var unlocked_reincarnation_skills: Dictionary = {"tree_node_root": true} # 転生スキルツリー解放状況 { "skill_id": true }
var stars_spent_in_current_cycle: int = 0 # 現サイクルで消費したスター数

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
var auto_unlock_skill_order: Array[String] = []
var skill_max_levels: Dictionary = {} # { "skill_id": max_level_int }
var permanently_unlocked_skills: Dictionary = {} # { "skill_id": true }

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

# --- Special Skill Settings & Definitions ---
var special_skill_drop_chance: float = 0.03 # 基本確率 3%
var special_skill_color: Color = Color(0.85, 0.45, 1.0, 1.0) # ソフトコーディング用カラー (紫/アストラル系)

# --- Accumulation Special Skill ---
var accumulation_rank: int = 0
var accumulation_bounces_in_rank: int = 0
signal accumulation_changed(ranked_up: bool)

var special_skill_defs: Dictionary = {
	"spec_diversity": {
		"id": "spec_diversity",
		"name": "多様性",
		"desc_template": "装備レア度3種以上で%s倍、6種で%s倍",
		"has_custom_ui": true,
		"ui_title": "多様性"
	},
	"spec_accumulation": {
		"id": "spec_accumulation",
		"name": "累積",
		"desc_template": "ゴールド、トークン入手量×2^(レベル) 一定回数衝突するごとにさらに倍率+2^(レベル)",
		"has_custom_ui": true,
		"ui_title": "累積"
	},
	"spec_aura": {
		"id": "spec_aura",
		"name": "星輝のオーラ",
		"desc_template": "転生後、自動でオーラを発動しゴールド・トークン獲得を常時アシスト",
		"has_custom_ui": true,
		"ui_title": "星輝のオーラ"
	},
	"spec_warp": {
		"id": "spec_warp",
		"name": "時空の歪み",
		"desc_template": "壁バウンス時の基本速度と加速能力を永続的に底上げ",
		"has_custom_ui": true,
		"ui_title": "時空の歪み"
	},
	"spec_resonance": {
		"id": "spec_resonance",
		"name": "クリティカル共鳴",
		"desc_template": "ダイレクトヒット時のトークン・装備ドロップ率を倍増",
		"has_custom_ui": true,
		"ui_title": "クリティカル共鳴"
	}
}


func init_skill_tree_auto_unlock_order() -> void:
	auto_unlock_skill_order.clear()
	skill_max_levels.clear()
	
	var json_path := "res://data/skills.json"
	if not FileAccess.file_exists(json_path):
		printerr("スキルデータファイルが見つかりません: ", json_path)
		return
	
	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		printerr("スキルデータファイルのオープンに失敗しました: ", json_path)
		return
		
	var text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(text) != OK:
		printerr("スキルデータファイルのJSONパースに失敗しました")
		return
		
	var data: Variant = json.get_data()
	if not data is Dictionary or not data.has("skills"):
		printerr("スキルデータのフォーマットが不正です")
		return
		
	var skills: Dictionary = data["skills"]
	var children_map: Dictionary = {}
	var root_skill_id: String = ""
	
	for skill_id: String in skills:
		children_map[skill_id] = []
		var s: Dictionary = skills[skill_id]
		skill_max_levels[skill_id] = int(s.get("max_level", 5))
	
	for skill_id: String in skills:
		var s: Dictionary = skills[skill_id]
		var prereqs: Array = s.get("prerequisites", [])
		if prereqs.is_empty():
			root_skill_id = skill_id
		else:
			for p in prereqs:
				var parent_id: String = str(p)
				if children_map.has(parent_id):
					(children_map[parent_id] as Array).append(skill_id)
				else:
					children_map[parent_id] = [skill_id]
					
	if root_skill_id.is_empty():
		printerr("前提スキルが0個のルートスキルが見つかりません")
		return
		
	# BFS でルートスキルからの最短経路距離（ホップ数）を計算
	var dist: Dictionary = {}
	dist[root_skill_id] = 0
	var queue: Array[String] = [root_skill_id]
	
	while not queue.is_empty():
		var curr: String = queue.pop_front()
		var d: int = dist[curr]
		var next_nodes: Array = children_map.get(curr, [])
		for nxt: String in next_nodes:
			if not dist.has(nxt):
				dist[nxt] = d + 1
				queue.append(nxt)
				
	# 全スキルを 最短距離昇順、同距離なら skill_id 辞書順昇順 でソート
	var all_skills: Array = skills.keys()
	all_skills.sort_custom(func(a: String, b: String) -> bool:
		var d_a: int = dist.get(a, 999999)
		var d_b: int = dist.get(b, 999999)
		if d_a != d_b:
			return d_a < d_b
		return a < b
	)
	
	for sk: String in all_skills:
		auto_unlock_skill_order.append(sk)


func apply_auto_unlocked_skills() -> void:
	if auto_unlock_skill_order.is_empty():
		init_skill_tree_auto_unlock_order()
		
	var target_count: int = get_auto_unlocked_skill_count()
	var unlock_count: int = mini(target_count, auto_unlock_skill_order.size())
	
	var any_changed: bool = false
	for i in range(unlock_count):
		var sk_id: String = auto_unlock_skill_order[i]
		permanently_unlocked_skills[sk_id] = true
		var max_lvl: int = skill_max_levels.get(sk_id, 5)
		if skill_levels.get(sk_id, 0) < max_lvl:
			skill_levels[sk_id] = max_lvl
			any_changed = true
			skill_upgraded.emit(sk_id, max_lvl)
			
	if any_changed:
		_recalculate_all_cumulative_levels()
		_recalculate_cached_multipliers()
		equipment_changed.emit()
		upgrades_changed.emit()


func is_skill_permanently_unlocked(skill_id: String) -> bool:
	return permanently_unlocked_skills.get(skill_id, false)


func get_equipped_unique_rarities() -> Array[String]:
	var result: Array[String] = []
	for slot_key in equipped_items:
		if not is_slot_unlocked(slot_key):
			continue
		var item = equipped_items[slot_key]
		if item != null and item is Dictionary and not item.is_empty():
			var r: String = item.get("rarity", "コモン")
			if not result.has(r):
				result.append(r)
	return result


func get_special_skill_active_level(skill_id: String) -> int:
	return active_reincarnation_upgrades.get(skill_id, 0)


func get_special_skill_total_level(skill_id: String) -> int:
	var total_lvl := get_special_skill_active_level(skill_id)
	for slot_key in equipped_items:
		if not is_slot_unlocked(slot_key):
			continue
		var item = equipped_items[slot_key]
		if item != null and item is Dictionary and not item.is_empty():
			var skills: Array = item.get("equip_skill", [])
			for sk in skills:
				if sk is Dictionary and sk.get("id", "") == skill_id:
					total_lvl += int(sk.get("level", 1))
	return total_lvl


func get_diversity_multiplier() -> float:
	var total_lvl := get_special_skill_total_level("spec_diversity")
	if total_lvl <= 0:
		return 1.0

	var unique_rarity_count := get_equipped_unique_rarities().size()
	if unique_rarity_count >= 6:
		return pow(50.0, float(total_lvl))
	elif unique_rarity_count >= 3:
		return pow(25.0, float(total_lvl))
	return 1.0


func get_accumulation_req_bounces(rank: int) -> int:
	# ランクアップに必要な衝突回数は 2^(n+2)
	# n=0: 4, n=1: 8, n=2: 16, n=3: 32, ...
	return int(round(pow(2.0, float(rank + 2))))


func get_accumulation_multiplier() -> float:
	var m: int = get_special_skill_total_level("spec_accumulation")
	if m <= 0:
		return 1.0
	var n: int = accumulation_rank
	# (n + 1) * 2^m
	return float(n + 1) * pow(2.0, float(m))


func record_accumulation_bounce() -> void:
	var m: int = get_special_skill_total_level("spec_accumulation")
	if m <= 0:
		return
	
	accumulation_bounces_in_rank += 1
	var req := get_accumulation_req_bounces(accumulation_rank)
	var ranked_up := false
	while accumulation_bounces_in_rank >= req:
		accumulation_bounces_in_rank -= req
		accumulation_rank += 1
		ranked_up = true
		req = get_accumulation_req_bounces(accumulation_rank)
	
	if ranked_up:
		_recalculate_cached_multipliers()
	accumulation_changed.emit(ranked_up)


const EQUIP_SKILLS_PATH = "res://data/equipment_skills.json"
var equipment_skill_defs: Dictionary = {}
var equipped_skill_levels: Dictionary = {}
var _cached_equipped_skill_totals: Dictionary = {}
var _cached_equipment_skill_keys: Array = []


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
			_cached_equipment_skill_keys = equipment_skill_defs.keys()
	file.close()


func _recalculate_equipped_skill_levels() -> void:
	equipped_skill_levels.clear()
	_cached_equipped_skill_totals.clear()
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

	for sk_id in equipped_skill_levels:
		var lvl: int = equipped_skill_levels[sk_id]
		var def: Dictionary = equipment_skill_defs.get(sk_id, {})
		var unit_val: float = float(def.get("unit_value", 0.0))
		_cached_equipped_skill_totals[sk_id] = unit_val * float(lvl)

	_recalculate_cached_multipliers()


func get_equipped_skill_total_val(skill_id: String) -> float:
	return _cached_equipped_skill_totals.get(skill_id, 0.0)


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
signal gold_changed(new_amount: float)
signal tokens_changed(new_amount: float)
signal stars_changed(new_amount: int)
signal stats_changed()
signal corner_hit_occurred()
signal upgrades_changed()
signal logo_spawn_requested()
signal logo_reset_requested()
signal skill_upgraded(skill_id: String, new_level: int)
signal equipment_changed()
signal inventory_updated()
signal reincarnation_performed()


func add_gold(amount: float) -> void:
	gold += amount
	gold_changed.emit(gold)


func add_stars(amount: int) -> void:
	stars += amount
	stars_changed.emit(stars)


func use_stars(amount: int) -> bool:
	if stars >= amount:
		stars -= amount
		stars_changed.emit(stars)
		return true
	return false


func get_next_star_cost() -> float:
	# 1スター上がるごとに必要トークン量が2倍 (1,000 * 2^star_level)
	return base_star_threshold * pow(2.0, float(star_level))


func toggle_token_infusion() -> bool:
	is_infusing_tokens = !is_infusing_tokens
	upgrades_changed.emit()
	return is_infusing_tokens


func add_tokens(amount: float) -> void:
	if amount <= 0.0:
		return
	if is_infusing_tokens:
		infused_tokens += amount
		var cost = get_next_star_cost()
		var star_gained := false
		while infused_tokens >= cost and cost > 0.0:
			infused_tokens -= cost
			stars += 1
			star_level += 1
			star_gained = true
			cost = get_next_star_cost()
		if star_gained:
			stars_changed.emit(stars)
		upgrades_changed.emit()
	else:
		tokens += amount
		tokens_changed.emit(tokens)


func reserve_reincarnation_upgrade(upgrade_id: String, star_cost: int) -> bool:
	if use_stars(star_cost):
		var current_lvl = pending_reincarnation_upgrades.get(upgrade_id, 0)
		pending_reincarnation_upgrades[upgrade_id] = current_lvl + 1
		stars_spent_in_current_cycle += star_cost
		upgrades_changed.emit()
		return true
	return false


func is_reincarnation_skill_unlocked(skill_id: String) -> bool:
	return unlocked_reincarnation_skills.get(skill_id, false)


func unlock_reincarnation_skill(skill_id: String, star_cost: int) -> bool:
	if is_reincarnation_skill_unlocked(skill_id):
		return false
	if star_cost == 0 or use_stars(star_cost):
		unlocked_reincarnation_skills[skill_id] = true
		stars_spent_in_current_cycle += star_cost
		_recalculate_cached_multipliers()
		if skill_id == "tree_node_auto_skills":
			apply_auto_unlocked_skills()
		upgrades_changed.emit()
		return true
	return false


func has_spent_stars_in_current_cycle() -> bool:
	return stars_spent_in_current_cycle > 0


func execute_reincarnation() -> void:
	# 予約されていた強化を解禁（アクティベート）
	for id in pending_reincarnation_upgrades:
		var current_active = active_reincarnation_upgrades.get(id, 0)
		active_reincarnation_upgrades[id] = current_active + pending_reincarnation_upgrades[id]
	pending_reincarnation_upgrades.clear()

	stars_spent_in_current_cycle = 0
	reincarnation_level += 1
	is_infusing_tokens = false

	# --- 転生時のリセット要素（※一時的にすべて無効化） ---
	# 1. トークン、ゴールドを0に
	# tokens = 0.0
	# tokens_changed.emit(0.0)
	# gold = 0.0
	# gold_changed.emit(0.0)

	# 2. 右枠のステータス強化リセット
	# size_level = 0
	# speed_level = 0
	# boost_level = 0
	# ascension_level = 0
	# logo_count = 1
	# logo_reset_requested.emit()

	# 3. 所持装備を装備欄含めてすべて未所持の状態にリセット
	# equipped_items = {
	# 	"main": null,
	# 	"sub": null,
	# 	"accessory_1": null,
	# 	"accessory_2": null,
	# 	"accessory_3": null,
	# 	"accessory_4": null
	# }
	# for type in ["main", "sub", "accessory"]:
	# 	inventories[type] = []
	# 	for i in range(MAX_TYPE_INVENTORY_SIZE):
	# 		inventories[type].append(null)
	# _recalculate_equipped_skill_levels()
	# equipment_changed.emit()
	# inventory_updated.emit()

	# 4. トークンによるスキルをリセット
	# skill_levels.clear()
	# _recalculate_all_cumulative_levels()

	# 5. 特殊スキル「累積」のリセット
	accumulation_rank = 0
	accumulation_bounces_in_rank = 0
	accumulation_changed.emit(false)

	# 転生ボーナスによるスキルの自動解放を適用
	apply_auto_unlocked_skills()

	# 倍率キャッシュ等の再計算
	_recalculate_cached_multipliers()

	reincarnation_performed.emit()
	upgrades_changed.emit()


func get_base_equip_level_bonus() -> int:
	var bonus := 5 if is_reincarnation_skill_unlocked("tree_node_equip_lvl") else 0
	return bonus + (reincarnation_level * 10)


func get_pending_base_equip_level_bonus() -> int:
	var bonus := 5 if is_reincarnation_skill_unlocked("tree_node_equip_lvl") else 0
	return bonus + ((reincarnation_level + 1) * 10)


func get_auto_unlocked_skill_count() -> int:
	var bonus := 2 if is_reincarnation_skill_unlocked("tree_node_auto_skills") else 0
	return bonus + (reincarnation_level * 5)


func get_pending_auto_unlocked_skill_count() -> int:
	var bonus := 2 if is_reincarnation_skill_unlocked("tree_node_auto_skills") else 0
	return bonus + ((reincarnation_level + 1) * 5)


func get_reincarnation_multiplier() -> float:
	var star_boost = active_reincarnation_upgrades.get("upgrade_star_boost", 0)
	var tree_boost := 0.25 if is_reincarnation_skill_unlocked("tree_node_mult") else 0.0
	return (1.0 + (star_boost * 0.5) + tree_boost) * pow(1.1, float(reincarnation_level))


func get_pending_reincarnation_multiplier() -> float:
	var star_boost = active_reincarnation_upgrades.get("upgrade_star_boost", 0) + pending_reincarnation_upgrades.get("upgrade_star_boost", 0)
	var tree_boost := 0.25 if is_reincarnation_skill_unlocked("tree_node_mult") else 0.0
	return (1.0 + (star_boost * 0.5) + tree_boost) * pow(1.1, float(reincarnation_level + 1))


func use_tokens(amount: float) -> bool:
	if tokens >= amount:
		tokens -= amount
		tokens_changed.emit(tokens)
		return true
	return false


func use_gold(amount: float) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false


func record_bounce(is_corner: bool) -> void:
	total_bounces += 1
	if is_corner:
		corner_hits += 1
		corner_hit_occurred.emit()
	stats_changed.emit()


# --- Upgrade Logic ---

func get_logo_upgrade_cost() -> float:
	var base := 100.0 * pow(2.0, float(logo_count - 1))
	return base * get_equipped_saving_cost_multiplier()


func get_speed_upgrade_cost() -> float:
	var base := 10.0 + float(speed_level) * 15.0
	return base * get_equipped_saving_cost_multiplier()


func get_boost_upgrade_cost() -> float:
	var base := 20.0 + float(boost_level) * 25.0
	return base * get_equipped_saving_cost_multiplier()


func get_size_upgrade_cost() -> float:
	var base := 15.0 + float(size_level) * 20.0
	return base * get_equipped_saving_cost_multiplier()


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
	init_skill_tree_auto_unlock_order()
	apply_auto_unlocked_skills()
	_load_equipment_skill_defs()
	_ensure_inventory_sizes()
	_recalculate_all_cumulative_levels()
	_recalculate_equipped_skill_levels()
	_recalculate_cached_multipliers()
	equipment_changed.connect(_on_equipment_changed_internal)


func _on_equipment_changed_internal() -> void:
	_recalculate_equipped_skill_levels()
	_recalculate_cached_multipliers()
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
	var div_mult := get_diversity_multiplier()
	var accum_mult := get_accumulation_multiplier()
	var reinc_mult := get_reincarnation_multiplier()
	_cached_gold_skill_mult = pow(1.1, total_gold_boost_level) * gold_equip_mult * div_mult * accum_mult * reinc_mult
	_cached_token_skill_mult = pow(1.1, total_token_boost_level) * token_equip_mult * div_mult * accum_mult * reinc_mult
	_cached_gold_over_time_boost_mult = pow(1.1, total_get_gold_over_time_boost_level) * accum_mult * reinc_mult
	_cached_token_over_time_boost_mult = pow(1.1, total_get_token_over_time_boost_level) * accum_mult * reinc_mult
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


func buy_skill_upgrade(skill_id: String, cost: float, max_level: int) -> bool:
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
	var reinc_level_bonus := float(get_base_equip_level_bonus())
	var raw_level := (base_asc * rand_factor) + tree_level_bonus + reinc_level_bonus
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

	# 特殊スキルの付与判定 (確立: 3%, 1装備につき最大1つ)
	var has_special: bool = (randf() < special_skill_drop_chance) and not special_skill_defs.is_empty()
	var normal_skill_count: int = maxi(0, num_skills - 1 if has_special else num_skills)

	# 利用可能なオプション効果（スキル）のキーをシャッフル
	var skill_keys := _cached_equipment_skill_keys.duplicate()
	if skill_keys.is_empty():
		skill_keys = equipment_skill_defs.keys()
	skill_keys.shuffle()
	
	# スキルレベル配分 (平均 = 装備レベル/10 + 洗練レベル*0.1)
	var refinement_total := get_equipped_skill_total_val("refinement")
	var target_avg_skill_level := (float(level) / 10.0) + refinement_total
	
	var float_skill_levels: Array[float] = []
	for i in range(normal_skill_count):
		float_skill_levels.append(target_avg_skill_level)
		
	# 総和保存型の3割幅 (±30%) 分散
	if normal_skill_count >= 2:
		for i in range(normal_skill_count / 2):
			var idx1 := i
			var idx2 := normal_skill_count - 1 - i
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
	final_skill_levels.sort_custom(_sort_descending_int)

	var item_skills: Array[Dictionary] = []
	for i in range(min(normal_skill_count, skill_keys.size())):
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
	
	# 特殊スキルが付与される場合、最後尾（最後）に1個追加
	if has_special:
		var spec_keys = special_skill_defs.keys()
		var spec_id: String = spec_keys[randi() % spec_keys.size()]
		var spec_def: Dictionary = special_skill_defs[spec_id]
		var spec_lvl: int = maxi(1, int(ceil(float(level) / 100.0)))
		var desc_tmpl: String = spec_def.get("desc_template", "%s")
		var formatted_desc: String = desc_tmpl
		if spec_id == "spec_diversity":
			var m25 := pow(25.0, float(spec_lvl))
			var m50 := pow(50.0, float(spec_lvl))
			var s25 := format_num(m25)
			var s50 := format_num(m50)
			formatted_desc = desc_tmpl % [s25, s50]
		elif spec_id == "spec_accumulation":
			var base_mult := int(pow(2.0, float(spec_lvl)))
			var s_val := format_num(float(base_mult))
			formatted_desc = "ゴールド、トークン入手量×%s 一定回数衝突するごとにさらに倍率+%s" % [s_val, s_val]
		elif "%d" in desc_tmpl:
			formatted_desc = desc_tmpl % spec_lvl

		item_skills.append({
			"id": spec_id,
			"name": spec_def.get("name", ""),
			"level": spec_lvl,
			"desc": formatted_desc,
			"is_special": true,
			"has_custom_ui": spec_def.get("has_custom_ui", false),
			"ui_title": spec_def.get("ui_title", "")
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
			inventory_updated.emit()
			return item
		else:
			# インベントリ満タン時: インベントリには追加せず、売却金を追加して通知用データを返す
			var sell_price: float = 100.0
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


static func _sort_descending_int(a: int, b: int) -> bool:
	return a > b
