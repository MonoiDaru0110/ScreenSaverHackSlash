extends Node
## Global game data singleton (Autoload).
## Manages currencies, statistics, and game state.

# --- Currency ---
var gold: float = 0.0
var tokens: float = 0.0
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
var pending_reincarnation_skills: Dictionary = {}   # 転生ツリースキル予約 { "skill_id": true }
var active_reincarnation_skills: Dictionary = {"tree_node_root": true} # 転生ツリースキル適用済み { "skill_id": true }
var unlocked_reincarnation_skills: Dictionary = active_reincarnation_skills # 互換用参照
var stars_spent_in_current_cycle: int = 0 # 現サイクルで消費したスター数

# --- Statistics ---
var total_bounces: int = 0
var corner_hits: int = 0
var total_play_time: float = 0.0

# --- Corner Assist Debug & Status ---
var assist_time_threshold: float = 180.0
var assist_max_angle_deg: float = 5.0
var last_assist_result: String = "未判定"
var last_assist_triggered: bool = false

# --- Upgrade Levels ---
var logo_count: int = 1
var speed_level: int = 1
var boost_level: int = 1
var size_level: int = 1
var ascension_level: int = 0
var skill_levels: Dictionary = {"root_node": 1} # { "skill_id": level_int }
var auto_unlock_skill_order: Array[String] = []
var skill_max_levels: Dictionary = {} # { "skill_id": max_level_int }
var skill_tree_defs: Dictionary = {} # { "skill_id": { ... } }
var permanently_unlocked_skills: Dictionary = {"root_node": true} # { "skill_id": true }
var debug_free_skill_cost: bool = false # テスト用: スキルツリーのコスト無視解放フラグ

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
var total_equip_skill_boost_level: int = 0
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
var _cached_gold_amp_mult: float = 1.0
var _cached_token_amp_mult: float = 1.0

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
const BASE_INVENTORY_SIZE: int = 20
const MAX_TYPE_INVENTORY_SIZE: int = 50


func get_max_inventory_size() -> int:
	var sz := BASE_INVENTORY_SIZE
	if get_skill_level("inventory_expand_1") > 0:
		sz += 10
	if get_skill_level("inventory_expand_2") > 0:
		sz += 10
	if get_skill_level("inventory_expand_3") > 0:
		sz += 10
	return sz

# --- Special Skill Settings & Definitions ---
var special_skill_drop_chance: float = 0.03 # 基本確率 3%
var special_skill_color: Color = Color(0.85, 0.45, 1.0, 1.0) # ソフトコーディング用カラー (紫/アストラル系)

# --- Accumulation Special Skill ---
var accumulation_rank: int = 0
var accumulation_bounces_in_rank: int = 0
signal accumulation_changed(ranked_up: bool)

# --- Trinity Special Skill ---
var trinity_sacrificed_stat: String = "none" # "none", "size", "speed", "boost"
signal trinity_changed

# --- Gamble Special Skill ---
const GAMBLE_INTERVAL: float = 300.0 # 5分 (300秒)
var gamble_timer: float = 300.0
var gamble_current_slot: int = 0
var gamble_current_multiplier: float = 1.0
var _prev_gamble_level: int = 0
var gamble_should_spin_on_ui_ready: bool = false
signal gamble_changed(multiplier: float, slot: int, animated: bool)
signal gamble_timer_updated(remaining_seconds: float)

# --- Switch Special Skill ---
var switch_sacrificed_type: String = "none" # "none", "gold", "token"
signal switch_changed

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
	"spec_trinity": {
		"id": "spec_trinity",
		"name": "トリニティ",
		"desc_template": "基礎強化1つを無効化し、他2つのレベル×%s倍",
		"has_custom_ui": true,
		"ui_title": "トリニティ"
	},
	"spec_switch": {
		"id": "spec_switch",
		"name": "スイッチ",
		"desc_template": "ゴールド、トークンのいずれかを無効化し、他方の入手量×%s倍",
		"has_custom_ui": true,
		"ui_title": "スイッチ"
	},
	"spec_gamble": {
		"id": "spec_gamble",
		"name": "ギャンブル",
		"desc_template": "ルーレットによってゴールド・トークン入手量がランダムに乗算(1倍~%s倍) 5分ごとにリセット",
		"has_custom_ui": true,
		"ui_title": "ギャンブル"
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
	skill_tree_defs = skills
	var children_map: Dictionary = {}
	var root_skill_id: String = ""
	
	for skill_id: String in skills:
		children_map[skill_id] = []
		var s: Dictionary = skills[skill_id]
		skill_max_levels[skill_id] = 1
	
	for skill_id: String in skills:
		var s: Dictionary = skills[skill_id]
		var prereqs: Array = s.get("prerequisites", [])
		if skill_id == "root_node":
			root_skill_id = "root_node"
		elif prereqs.is_empty() and root_skill_id.is_empty():
			root_skill_id = skill_id
		
		for p in prereqs:
			var parent_id: String = str(p)
			if children_map.has(parent_id):
				(children_map[parent_id] as Array).append(skill_id)
			else:
				children_map[parent_id] = [skill_id]
					
	if root_skill_id.is_empty():
		if skills.has("root_node"):
			root_skill_id = "root_node"
		else:
			printerr("前提スキルが0個のルートスキルが見つかりません")
			return

	# 開始時のルートノードを初期解放済みに設定
	skill_levels["root_node"] = 1
	permanently_unlocked_skills["root_node"] = true
	if not root_skill_id.is_empty():
		skill_levels[root_skill_id] = 1
		permanently_unlocked_skills[root_skill_id] = true

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
	if is_challenge_active("c1"):
		return total_lvl
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


func get_trinity_multiplier() -> float:
	var n: int = get_special_skill_total_level("spec_trinity")
	if n <= 0:
		return 1.0
	# 2 + 0.2 * (n - 1)
	return 2.0 + 0.2 * float(n - 1)


func is_trinity_active() -> bool:
	return get_special_skill_total_level("spec_trinity") > 0 and trinity_sacrificed_stat != "none"


func set_trinity_sacrificed_stat(stat: String) -> void:
	if trinity_sacrificed_stat == stat:
		# 無効化されている項目のボタンをもう一回押すとどれも選択されていない状態に戻る
		trinity_sacrificed_stat = "none"
	else:
		trinity_sacrificed_stat = stat
	
	_recalculate_cached_multipliers()
	trinity_changed.emit()
	upgrades_changed.emit()


func get_effective_size_level() -> int:
	if is_challenge_active("c2"):
		return 1
	if not is_trinity_active():
		return size_level
	if trinity_sacrificed_stat == "size":
		return 0
	return int(round(float(size_level) * get_trinity_multiplier()))


func get_effective_speed_level() -> int:
	if is_challenge_active("c2"):
		return 1
	if not is_trinity_active():
		return speed_level
	if trinity_sacrificed_stat == "speed":
		return 0
	return int(round(float(speed_level) * get_trinity_multiplier()))


func get_effective_boost_level() -> int:
	if is_challenge_active("c2"):
		return 1
	if not is_trinity_active():
		return boost_level
	if trinity_sacrificed_stat == "boost":
		return 0
	return int(round(float(boost_level) * get_trinity_multiplier()))


func get_trinity_stat_diff(stat_type: String) -> int:
	if not is_trinity_active():
		return 0
	match stat_type:
		"size":
			return get_effective_size_level() - size_level
		"speed":
			return get_effective_speed_level() - speed_level
		"boost":
			return get_effective_boost_level() - boost_level
	return 0


# --- Gamble Special Skill Operations ---

func get_gamble_base_multiplier() -> int:
	var lvl := get_special_skill_total_level("spec_gamble")
	if lvl <= 0:
		return 1
	return lvl + 1


func get_gamble_slot_multiplier(slot_idx: int) -> float:
	var n := float(get_gamble_base_multiplier())
	return pow(n, float(slot_idx))


func get_gamble_multiplier() -> float:
	if get_special_skill_total_level("spec_gamble") <= 0:
		return 1.0
	return gamble_current_multiplier


func roll_gamble(animated: bool = true) -> void:
	var lvl := get_special_skill_total_level("spec_gamble")
	if lvl <= 0:
		gamble_current_slot = 0
		gamble_current_multiplier = 1.0
		gamble_timer = GAMBLE_INTERVAL
		gamble_should_spin_on_ui_ready = false
		return

	# 再抽選 (0〜4 の 5スロット)
	gamble_current_slot = randi() % 5
	gamble_current_multiplier = get_gamble_slot_multiplier(gamble_current_slot)
	# 再抽選が行われた際に、そのタイミングを問わずタイマーを5分にリセット
	gamble_timer = GAMBLE_INTERVAL
	if animated:
		gamble_should_spin_on_ui_ready = true
	_recalculate_cached_multipliers()
	gamble_changed.emit(gamble_current_multiplier, gamble_current_slot, animated)


func check_gamble_activation() -> void:
	var lvl := get_special_skill_total_level("spec_gamble")
	if lvl > 0 and _prev_gamble_level == 0:
		# スキルレベルが0の状態から正の値になったときのみ再抽選・回転！
		_prev_gamble_level = lvl
		roll_gamble(true)
	elif lvl > 0 and lvl != _prev_gamble_level:
		# レベルが変わっただけの場合は再抽選しない！
		# （現在のスロットの倍率のみ新レベルで更新、タイマーやスロットは維持）
		_prev_gamble_level = lvl
		gamble_current_multiplier = get_gamble_slot_multiplier(gamble_current_slot)
		gamble_changed.emit(gamble_current_multiplier, gamble_current_slot, false)
	elif lvl == 0:
		_prev_gamble_level = 0
		gamble_current_slot = 0
		gamble_current_multiplier = 1.0
		gamble_should_spin_on_ui_ready = false


# --- Switch Special Skill Operations ---

func get_switch_multiplier() -> float:
	var lvl := get_special_skill_total_level("spec_switch")
	if lvl <= 0:
		return 1.0
	return pow(2.0, float(lvl))


func is_switch_active() -> bool:
	return get_special_skill_total_level("spec_switch") > 0 and switch_sacrificed_type != "none"


func is_switch_gold_disabled() -> bool:
	return is_switch_active() and switch_sacrificed_type == "gold"


func is_switch_token_disabled() -> bool:
	return is_switch_active() and switch_sacrificed_type == "token"


func set_switch_target(target_type: String) -> void:
	if switch_sacrificed_type != target_type:
		switch_sacrificed_type = target_type
		_recalculate_cached_multipliers()
		switch_changed.emit()
		upgrades_changed.emit()


func reset_switch() -> void:
	if switch_sacrificed_type != "none":
		switch_sacrificed_type = "none"
		_recalculate_cached_multipliers()
		switch_changed.emit()
		upgrades_changed.emit()


func toggle_switch(target_type: String) -> void:
	if switch_sacrificed_type == target_type:
		switch_sacrificed_type = "none"
	else:
		switch_sacrificed_type = target_type
	_recalculate_cached_multipliers()
	switch_changed.emit()
	upgrades_changed.emit()


func get_switch_gold_multiplier() -> float:
	if not is_switch_active():
		return 1.0
	if switch_sacrificed_type == "gold":
		return 0.0
	elif switch_sacrificed_type == "token":
		return get_switch_multiplier()
	return 1.0


func get_switch_token_multiplier() -> float:
	if not is_switch_active():
		return 1.0
	if switch_sacrificed_type == "token":
		return 0.0
	elif switch_sacrificed_type == "gold":
		return get_switch_multiplier()
	return 1.0




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
	if is_challenge_active("c1"):
		return 0.0
	return _cached_equipped_skill_totals.get(skill_id, 0.0)


func get_equipped_saving_cost_multiplier() -> float:
	if is_challenge_active("c1"):
		return 1.0
	var lvl: int = equipped_skill_levels.get("gold_cost", 0) + equipped_skill_levels.get("saving", 0)
	if lvl <= 0:
		return 1.0
	var unit_val: float = float(equipment_skill_defs.get("gold_cost", {}).get("unit_value", 0.99))
	return pow(unit_val, float(lvl))


func get_equipped_token_saving_cost_multiplier() -> float:
	if is_challenge_active("c1"):
		return 1.0
	var lvl: int = equipped_skill_levels.get("token_cost", 0) + equipped_skill_levels.get("token_saving", 0)
	if lvl <= 0:
		return 1.0
	var unit_val: float = float(equipment_skill_defs.get("token_cost", {}).get("unit_value", 0.99))
	return pow(unit_val, float(lvl))


func is_slot_unlocked(slot_key: String) -> bool:
	if slot_key == "main" or slot_key == "sub" or slot_key == "accessory_1":
		return true
	elif slot_key == "accessory_2":
		return is_reincarnation_skill_active("handing_over_accessory_2") or total_accessory_slot_unlock_level >= 1
	elif slot_key == "accessory_3":
		return is_reincarnation_skill_active("handing_over_accessory_3") or total_accessory_slot_unlock_level >= 2
	elif slot_key == "accessory_4":
		return is_reincarnation_skill_active("handing_over_accessory_4") or total_accessory_slot_unlock_level >= 3
	return unlocked_slots.get(slot_key, false)


func set_slot_unlocked(slot_key: String, unlocked: bool) -> void:
	unlocked_slots[slot_key] = unlocked
	equipment_changed.emit()


func is_window_unlocked(window_id: String) -> bool:
	match window_id:
		"skill_tree":
			return true
		"equipment":
			return get_skill_level("equip_drop_unlock") > 0
		"challenge":
			return is_challenge_unlocked()
		"blacksmith":
			return get_skill_level("blacksmith_unlock") > 0
		"amplifier":
			return get_skill_level("amplifier_unlock") > 0
	return false

# --- Signals ---
signal gold_changed(new_amount: float)
signal tokens_changed(new_amount: float)
signal stars_changed(new_amount: int)
signal infusion_changed()
signal stats_changed()
signal corner_hit_occurred()
signal upgrades_changed()
signal logo_spawn_requested()
signal logo_reset_requested()
signal skill_upgraded(skill_id: String, new_level: int)
signal debug_free_skill_cost_changed(enabled: bool)
signal equipment_changed()
signal inventory_updated()
signal reincarnation_performed()
signal game_saved(success: bool)
signal game_loaded(success: bool)
signal game_reset()


func add_gold(amount: float) -> void:
	var final_amount := amount * get_challenge_gold_multiplier()
	gold += final_amount
	gold_changed.emit(gold)
	if is_challenge_active():
		record_challenge_progress("gold", final_amount)


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
	var final_amount := amount * get_challenge_token_multiplier()
	if is_challenge_active():
		record_challenge_progress("token", final_amount)
	if is_infusing_tokens:
		infused_tokens += final_amount
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
		# 注入量の変化は軽量シグナルで通知する
		# (upgrades_changed は全ロゴ・HUD・転生ウィンドウの再計算を誘発し、角ヒット毎に発火すると非常に重いため)
		infusion_changed.emit()
	else:
		tokens += final_amount
		tokens_changed.emit(tokens)


func reserve_reincarnation_upgrade(upgrade_id: String, star_cost: int) -> bool:
	if use_stars(star_cost):
		var current_lvl = pending_reincarnation_upgrades.get(upgrade_id, 0)
		pending_reincarnation_upgrades[upgrade_id] = current_lvl + 1
		stars_spent_in_current_cycle += star_cost
		upgrades_changed.emit()
		return true
	return false


func is_reincarnation_skill_active(skill_id: String) -> bool:
	return active_reincarnation_skills.get(skill_id, false)


func is_reincarnation_skill_pending(skill_id: String) -> bool:
	return pending_reincarnation_skills.get(skill_id, false)


func is_reincarnation_skill_purchased(skill_id: String) -> bool:
	return is_reincarnation_skill_active(skill_id) or is_reincarnation_skill_pending(skill_id)


func is_reincarnation_skill_unlocked(skill_id: String) -> bool:
	return is_reincarnation_skill_active(skill_id)


func unlock_reincarnation_skill(skill_id: String, star_cost: int) -> bool:
	if is_reincarnation_skill_purchased(skill_id):
		return false
	if star_cost == 0 or use_stars(star_cost):
		pending_reincarnation_skills[skill_id] = true
		stars_spent_in_current_cycle += star_cost
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

	# 予約されていた転生ツリースキルを解禁（アクティベート）
	for skill_id in pending_reincarnation_skills:
		active_reincarnation_skills[skill_id] = true
	pending_reincarnation_skills.clear()

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

	# 3. 装備引き継ぎ & リセット処理
	var slot_to_skill := {
		"main": "handing_over_main_equip",
		"sub": "handing_over_sub_equip",
		"accessory_1": "handing_over_accessory_1",
		"accessory_2": "handing_over_accessory_2",
		"accessory_3": "handing_over_accessory_3",
		"accessory_4": "handing_over_accessory_4",
	}

	for slot_key in slot_to_skill:
		var s_id: String = slot_to_skill[slot_key]
		if not is_reincarnation_skill_active(s_id):
			equipped_items[slot_key] = null

	for type in ["main", "sub", "accessory"]:
		inventories[type] = []
		for i in range(MAX_TYPE_INVENTORY_SIZE):
			inventories[type].append(null)

	_recalculate_equipped_skill_levels()
	equipment_changed.emit()
	inventory_updated.emit()

	# 4. トークンによるスキルをリセット
	# skill_levels.clear()
	# _recalculate_all_cumulative_levels()

	# 5. 特殊スキル「累積」のリセット
	accumulation_rank = 0
	accumulation_bounces_in_rank = 0
	accumulation_changed.emit(false)

	# 6. 特殊スキル「トリニティ」のリセット
	trinity_sacrificed_stat = "none"
	trinity_changed.emit()

	# 7. 特殊スキル「ギャンブル」のリセット
	gamble_timer = GAMBLE_INTERVAL
	gamble_current_slot = 0
	gamble_current_multiplier = 1.0
	_prev_gamble_level = 0
	gamble_should_spin_on_ui_ready = false
	gamble_changed.emit(1.0, 0, false)

	# 8. 特殊スキル「スイッチ」のリセット
	switch_sacrificed_type = "none"
	switch_changed.emit()

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
	var tree_boost := 0.25 if is_reincarnation_skill_purchased("tree_node_mult") else 0.0
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


func _calc_arithmetic_cost(base_init: float, step: float, current_level: int, count: int, saving_mult: float) -> float:
	if count <= 0:
		return 0.0
	var a0 := (base_init + float(current_level) * step) * saving_mult
	if count == 1:
		return a0
	var d := step * saving_mult
	return float(count) * a0 + d * float(count * (count - 1)) * 0.5


func _calc_arithmetic_max_count(base_init: float, step: float, current_level: int, currency: float, saving_mult: float) -> int:
	var a0 := (base_init + float(current_level) * step) * saving_mult
	if currency < a0:
		return 0
	var d := step * saving_mult
	var n := 0
	if is_zero_approx(d):
		n = int(currency / a0)
	else:
		var b := a0 - d * 0.5
		var disc := b * b + 2.0 * d * currency
		if disc >= 0.0:
			n = int(floor((-b + sqrt(disc)) / d))
	var actual_cost := _calc_arithmetic_cost(base_init, step, current_level, n, saving_mult)
	if actual_cost > currency and n > 0:
		n -= 1
	elif n >= 0:
		var next_cost := _calc_arithmetic_cost(base_init, step, current_level, n + 1, saving_mult)
		if next_cost <= currency:
			n += 1
	return maxi(0, n)


func _calc_base_geometric_cost(base_init: float, ratio: float, current_level: int, count: int, saving_mult: float) -> float:
	if count <= 0:
		return 0.0
	var r := ratio
	var start_lvl := maxi(1, current_level)
	var first_cost := base_init * pow(r, float(start_lvl - 1)) * saving_mult
	if count == 1:
		return first_cost
	if absf(r - 1.0) < 0.0001:
		return first_cost * float(count)
	return first_cost * (pow(r, float(count)) - 1.0) / (r - 1.0)


func _calc_base_geometric_max_count(base_init: float, ratio: float, current_level: int, currency: float, saving_mult: float) -> int:
	if currency <= 0.0:
		return 0
	var r := ratio
	var start_lvl := maxi(1, current_level)
	var first_cost := base_init * pow(r, float(start_lvl - 1)) * saving_mult
	if currency < first_cost:
		return 0
	if absf(r - 1.0) < 0.0001:
		return int(currency / first_cost)

	var val := 1.0 + currency * (r - 1.0) / first_cost
	if val <= 0.0:
		return 0
	var n := int(floor(log(val) / log(r)))
	n = maxi(0, n)

	var actual_cost := _calc_base_geometric_cost(base_init, r, current_level, n, saving_mult)
	if actual_cost > currency and n > 0:
		n -= 1
	else:
		var next_cost := _calc_base_geometric_cost(base_init, r, current_level, n + 1, saving_mult)
		if next_cost <= currency:
			n += 1
	return maxi(0, n)


func get_ascension_cost_multiplier() -> float:
	# アセンションレベルごとに基本強化のコストが1.3倍
	return pow(1.3, float(ascension_level))


func get_speed_upgrade_cost(count: int = 1) -> float:
	return _calc_base_geometric_cost(10.0 * get_ascension_cost_multiplier(), 1.15, speed_level, count, get_equipped_saving_cost_multiplier())


func get_speed_upgrade_max_count() -> int:
	return _calc_base_geometric_max_count(10.0 * get_ascension_cost_multiplier(), 1.15, speed_level, gold, get_equipped_saving_cost_multiplier())


func get_boost_upgrade_cost(count: int = 1) -> float:
	return _calc_base_geometric_cost(20.0 * get_ascension_cost_multiplier(), 1.15, boost_level, count, get_equipped_saving_cost_multiplier())


func get_boost_upgrade_max_count() -> int:
	return _calc_base_geometric_max_count(20.0 * get_ascension_cost_multiplier(), 1.15, boost_level, gold, get_equipped_saving_cost_multiplier())


func get_size_upgrade_cost(count: int = 1) -> float:
	return _calc_base_geometric_cost(15.0 * get_ascension_cost_multiplier(), 1.15, size_level, count, get_equipped_saving_cost_multiplier())


func get_size_upgrade_max_count() -> int:
	return _calc_base_geometric_max_count(15.0 * get_ascension_cost_multiplier(), 1.15, size_level, gold, get_equipped_saving_cost_multiplier())


func get_ascension_multiplier() -> float:
	if is_challenge_active("c4"):
		return 1.0
	# アセンションボーナス計算式: (前回の倍率 * 1.05) + 1.0 (Lv0: 1.0, Lv1: 2.05, Lv2: 3.1525...)
	# 一般項: 21.0 * pow(1.05, ascension_level) - 20.0
	if ascension_level <= 0:
		return 1.0
	return 21.0 * pow(1.05, float(ascension_level)) - 20.0


func get_base_upgrade_total_level() -> int:
	return speed_level + boost_level + size_level


func can_ascend() -> bool:
	# 基本強化が合計レベル100まで到達すると可能
	return get_base_upgrade_total_level() >= 100


## アセンションレベルに応じた追加ロゴ数
## 1個ごとに必要アセンション回数が1増える (0->1, 2->3, 5->6...)
func get_ascension_extra_logo_count(asc_lvl: int = -1) -> int:
	var a := ascension_level if asc_lvl < 0 else asc_lvl
	if a <= 0:
		return 0
	return int(floor((-1.0 + sqrt(1.0 + 8.0 * float(a))) / 2.0))


## 次のロゴ追加までの残りアセンション回数
func get_ascension_logos_next_remaining() -> int:
	var current_k := get_ascension_extra_logo_count()
	var next_k := current_k + 1
	var next_threshold := int(round(float(next_k * (next_k + 1)) * 0.5))
	return maxi(1, next_threshold - ascension_level)


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


func buy_speed_upgrade(count: int = 1) -> bool:
	if count <= 0:
		return false
	var cost := get_speed_upgrade_cost(count)
	if gold >= cost:
		gold -= cost
		gold_changed.emit(gold)
		speed_level += count
		upgrades_changed.emit()
		return true
	return false


func buy_boost_upgrade(count: int = 1) -> bool:
	if count <= 0:
		return false
	var cost := get_boost_upgrade_cost(count)
	if gold >= cost:
		gold -= cost
		gold_changed.emit(gold)
		boost_level += count
		upgrades_changed.emit()
		return true
	return false


func buy_size_upgrade(count: int = 1) -> bool:
	if count <= 0:
		return false
	var cost := get_size_upgrade_cost(count)
	if gold >= cost:
		gold -= cost
		gold_changed.emit(gold)
		size_level += count
		upgrades_changed.emit()
		return true
	return false





func get_logo_size_multiplier() -> float:
	# 枠内ギリギリの追加可能限界 C (画面1662x1080に対してロゴ200x100。横幅限界 1662/200 = 8.31倍。マージン考慮で 8.25倍 -> C = 7.25)
	var max_C := 7.25
	var half_C := max_C * 0.5
	
	# 基礎強化レベル A (size_level) による収束寄与
	var level_A := float(get_effective_size_level())
	var contrib_A := half_C * (1.0 - exp(-0.02 * level_A))
	
	# 装備スキルレベル B (size_factor / size_boost) による収束寄与
	var level_B := get_equipped_skill_total_val("size_factor") + get_equipped_skill_total_val("size_boost")
	var contrib_B := half_C * (1.0 - exp(-0.03 * level_B))
	
	return 1.0 + contrib_A + contrib_B


func get_corner_conversion_chance() -> float:
	var n := int(get_equipped_skill_total_val("corner_trick"))
	if n <= 0:
		return 0.0
	return 1.0 - pow(0.99, float(n))


func perform_ascension() -> bool:
	if can_ascend():
		# 所持ゴールドはリセットしない
		ascension_level += 1
		logo_count = 1 + get_ascension_extra_logo_count() + get_skill_level("extra_logo")
		speed_level = 1
		boost_level = 1
		size_level = 1
		
		_recalculate_cached_multipliers()
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
	if is_challenge_active("c5"):
		return {"multiplier": 1.0, "is_crit": false, "weight": 0}
	var equip_crit_rate := get_equipped_skill_total_val("crit_rate")
	var equip_crit_yield := get_equipped_skill_total_val("crit_yield")
	var chance_percent := 5.0 * crit_factor + equip_crit_rate
	if chance_percent <= 0.0:
		return {"multiplier": 1.0, "is_crit": false, "weight": 0}
	
	var n := int(floor(chance_percent / 100.0))
	var m := chance_percent - float(n * 100)
	
	var weight := n
	if randf() * 100.0 < m:
		weight += 1
		
	if weight <= 0:
		return {"multiplier": 1.0, "is_crit": false, "weight": 0}
		
	var base_crit_bonus := 0.05 * crit_factor + equip_crit_yield * 0.01
	var mult := (1.0 + float(weight) * base_crit_bonus) * get_challenge_crit_multiplier()
	return {"multiplier": mult, "is_crit": true, "weight": weight}


func roll_gold_critical() -> Dictionary:
	return calculate_crit_result(get_gold_critical_parameter())


func roll_token_critical() -> Dictionary:
	return calculate_crit_result(get_token_critical_parameter())


func calculate_direct_result(direct_factor: float) -> Dictionary:
	if is_challenge_active("c6"):
		return {"multiplier": 1.0, "is_direct": false}
	var equip_direct_rate := get_equipped_skill_total_val("direct_rate")
	var equip_direct_yield := get_equipped_skill_total_val("direct_yield")
	var chance_percent := minf(100.0, 5.0 * direct_factor + equip_direct_rate)
	if chance_percent <= 0.0:
		return {"multiplier": 1.0, "is_direct": false}
	
	var is_direct := (randf() * 100.0) < chance_percent
	if not is_direct:
		return {"multiplier": 1.0, "is_direct": false}
		
	var base_direct_bonus := 0.01 * pow(direct_factor, 2.0) + equip_direct_yield * 0.01
	var mult := (1.0 + base_direct_bonus) * get_challenge_direct_multiplier()
	return {"multiplier": mult, "is_direct": true}


func roll_gold_direct() -> Dictionary:
	return calculate_direct_result(get_gold_direct_hit_parameter())


func roll_token_direct() -> Dictionary:
	return calculate_direct_result(get_token_direct_hit_parameter())


func _ready() -> void:
	init_skill_tree_auto_unlock_order()
	apply_auto_unlocked_skills()
	_load_equipment_skill_defs()
	_load_challenge_defs()
	_ensure_inventory_sizes()
	_recalculate_all_cumulative_levels()
	_recalculate_equipped_skill_levels()
	_recalculate_cached_multipliers()
	equipment_changed.connect(_on_equipment_changed_internal)

	if has_save_data():
		load_game()


func _process(delta: float) -> void:
	total_play_time += delta
	_amp_cache_timer += delta
	if _amp_cache_timer >= 0.1:
		_amp_cache_timer = 0.0
		update_amplifier_cache()

	if get_special_skill_total_level("spec_gamble") > 0:
		gamble_timer -= delta
		if gamble_timer <= 0.0:
			roll_gamble(true)
		else:
			gamble_timer_updated.emit(gamble_timer)

	if not active_challenge_id.is_empty():
		challenge_time_left -= delta
		if challenge_time_left <= 0.0:
			challenge_time_left = 0.0
			fail_challenge()
		else:
			challenge_progress_updated.emit(challenge_current_val, challenge_target_val, challenge_time_left)


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
	var max_sz := get_max_inventory_size()
	for i in range(mini(arr.size(), max_sz)):
		if arr[i] != null:
			count += 1
	return count


# --- Skill Tree Equipment Bonus Calculations ---

func _parse_skill_int_bonus(skill_id: String, fallback: int) -> int:
	if not skill_tree_defs.has(skill_id):
		return fallback
	var desc: String = skill_tree_defs[skill_id].get("description", "")
	var regex := RegEx.new()
	if regex.compile("\\+(\\d+)") == OK:
		var result := regex.search(desc)
		if result:
			return result.get_string(1).to_int()
	return fallback


func _parse_skill_percent_bonus(skill_id: String, fallback: float) -> float:
	if not skill_tree_defs.has(skill_id):
		return fallback
	var desc: String = skill_tree_defs[skill_id].get("description", "")
	var regex := RegEx.new()
	if regex.compile("(\\d+)(?:%|％)") == OK:
		var result := regex.search(desc)
		if result:
			return float(result.get_string(1)) * 0.01
	return fallback


func get_tree_equip_drop_probability_bonus() -> float:
	var bonus := 0.0
	for i in range(1, 100):
		var s_id := "equip_drop_probability_boost_%d" % i
		if not skill_tree_defs.has(s_id) and i > 5:
			break
		if get_skill_level(s_id) > 0:
			var default_val := float(i) * 0.01
			bonus += _parse_skill_percent_bonus(s_id, default_val)
	return bonus


func get_tree_equip_drop_level_bonus() -> int:
	var bonus := 0
	for i in range(1, 100):
		var s_id := "equip_drop_level_boost_%d" % i
		if not skill_tree_defs.has(s_id) and i > 5:
			break
		if get_skill_level(s_id) > 0:
			var default_val := i * 10
			bonus += _parse_skill_int_bonus(s_id, default_val)
	return bonus


func get_total_equip_drop_rarity_boost() -> int:
	var boost := 0
	for i in range(1, 100):
		var s_id := "equip_drop_rarity_boost_%d" % i
		if not skill_tree_defs.has(s_id) and i > 5:
			break
		if get_skill_level(s_id) > 0:
			var default_val := i
			boost += _parse_skill_int_bonus(s_id, default_val)
	return boost


func get_tree_equip_skill_level_bonus() -> int:
	var bonus := 0
	for i in range(1, 100):
		var s_id := "equip_skill_boost_%d" % i
		if not skill_tree_defs.has(s_id) and i > 5:
			break
		if get_skill_level(s_id) > 0:
			var default_val := i
			bonus += _parse_skill_int_bonus(s_id, default_val)
	return bonus


func calculate_corner_hit_gold() -> Dictionary:
	var mult := _cached_ascension_mult
	var gold_skill_mult := _cached_gold_skill_mult * _cached_gold_amp_mult
	var normal_base_gold := (20.0 + float(get_effective_boost_level())) * mult * gold_skill_mult
	var base_gold := normal_base_gold * 100.0

	var gold_crit := roll_gold_critical()
	var gold_direct := roll_gold_direct()
	var gold_mult: float = gold_crit.multiplier * gold_direct.multiplier
	var gold_amount := base_gold * gold_mult

	if is_challenge_active("c7"):
		gold_amount = 0.0
	else:
		gold_amount *= get_challenge_corner_gold_multiplier()

	return {
		"amount": gold_amount,
		"crit": gold_crit,
		"direct": gold_direct
	}


func get_corner_hit_gold_amount() -> float:
	return calculate_corner_hit_gold()["amount"]


func get_corner_hit_token_amount() -> float:
	if is_challenge_active("c7"):
		return 0.0
	var mult := _cached_ascension_mult
	var token_skill_mult := _cached_token_skill_mult * _cached_token_amp_mult
	var base_tokens := float(get_effective_boost_level()) * mult * token_skill_mult
	var token_luck_level := get_skill_level("token_luck")
	if token_luck_level > 0 and randf() < float(token_luck_level) * 0.3:
		base_tokens += 1.0
	return base_tokens


func discard_equipment_rewards() -> Dictionary:
	var res := { "gold": 0.0, "tokens": 0.0 }
	if get_skill_level("get_gold_when_discarding") > 0:
		res["gold"] += get_corner_hit_gold_amount()
	if get_skill_level("get_token_when_discarding") > 0:
		res["tokens"] += get_corner_hit_token_amount()
	return res


func discard_inventory_item(type: String, index: int) -> bool:
	_ensure_inventory_sizes()
	if not inventories.has(type):
		return false
	var arr: Array = inventories[type]
	if index < 0 or index >= get_max_inventory_size():
		return false
	var item = arr[index]
	if item == null or not item is Dictionary or item.is_empty():
		return false
	if is_item_equipped(item.get("id", "")) != "":
		return false
	arr[index] = null
	var rewards := discard_equipment_rewards()
	if rewards["gold"] > 0.0:
		add_gold(rewards["gold"])
	if rewards["tokens"] > 0.0:
		add_tokens(rewards["tokens"])
	equipment_changed.emit()
	inventory_updated.emit()
	return true


func discard_multiple_inventory_items(items_to_discard: Array) -> Dictionary:
	_ensure_inventory_sizes()
	var total_rewards := { "gold": 0.0, "tokens": 0.0 }
	var discarded_count := 0
	
	for entry in items_to_discard:
		if not entry is Dictionary:
			continue
		var type: String = entry.get("type", "")
		var item_id: String = entry.get("id", "")
		if not inventories.has(type):
			continue
		if is_item_equipped(item_id) != "":
			continue
			
		var arr: Array = inventories[type]
		for i in range(arr.size()):
			var it = arr[i]
			if it != null and it is Dictionary and it.get("id", "") == item_id:
				arr[i] = null
				discarded_count += 1
				var single_reward := discard_equipment_rewards()
				total_rewards["gold"] += single_reward["gold"]
				total_rewards["tokens"] += single_reward["tokens"]
				break
				
	if discarded_count > 0:
		if total_rewards["gold"] > 0.0:
			add_gold(total_rewards["gold"])
		if total_rewards["tokens"] > 0.0:
			add_tokens(total_rewards["tokens"])
		equipment_changed.emit()
		inventory_updated.emit()
		
	return total_rewards


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
	total_equip_skill_boost_level = _recalculate_total_level("equip_skill_boost_")
	total_accessory_slot_unlock_level = _recalculate_total_level("accessory_slot_unlock_")
	_recalculate_cached_multipliers()


func _recalculate_cached_multipliers() -> void:
	check_gamble_activation()
	var gold_equip_mult := 1.0 + (get_equipped_skill_total_val("gold_gain") + get_equipped_skill_total_val("gold_boost")) * 0.01
	var token_equip_mult := 1.0 + (get_equipped_skill_total_val("token_gain") + get_equipped_skill_total_val("token_boost")) * 0.01
	var div_mult := get_diversity_multiplier()
	var accum_mult := get_accumulation_multiplier()
	var reinc_mult := get_reincarnation_multiplier()
	var gamble_mult := get_gamble_multiplier()
	var switch_gold_mult := get_switch_gold_multiplier()
	var switch_token_mult := get_switch_token_multiplier()

	# スキルツリーによる倍率
	var tree_gold_mult := 1.0
	var tree_token_mult := 1.0

	# 購入オプション拡張: 入手ゴールド/トークン×150倍
	if get_skill_level("buying_expand") > 0:
		tree_gold_mult *= 150.0
		tree_token_mult *= 150.0

	# 角ヒット時装備強化: 入手ゴールド/トークン5倍
	if get_skill_level("equip_corner_enhance") > 0:
		tree_gold_mult *= 5.0
		tree_token_mult *= 5.0

	# チャレンジクリアボーナス関連スキル
	var cleared_ch_count := 0 if is_challenge_active("c8") else get_cleared_challenge_count()
	if get_skill_level("challange_gold_bonus") > 0 and cleared_ch_count > 0:
		tree_gold_mult *= (1.0 + 0.1 * float(cleared_ch_count))
	if get_skill_level("challange_token_bonus") > 0 and cleared_ch_count > 0:
		tree_token_mult *= (1.0 + 0.1 * float(cleared_ch_count))
	if get_skill_level("challange_max_level_bonus") > 0 and not is_challenge_active("c8"):
		var max_lvl_ch_count := get_max_level_challenge_count()
		if max_lvl_ch_count > 0:
			var max_lvl_mult := pow(2.0, float(max_lvl_ch_count))
			tree_gold_mult *= max_lvl_mult
			tree_token_mult *= max_lvl_mult

	_cached_gold_skill_mult = pow(1.1, total_gold_boost_level) * gold_equip_mult * div_mult * accum_mult * reinc_mult * gamble_mult * switch_gold_mult * tree_gold_mult
	_cached_token_skill_mult = pow(1.1, total_token_boost_level) * token_equip_mult * div_mult * accum_mult * reinc_mult * gamble_mult * switch_token_mult * tree_token_mult
	_cached_gold_over_time_boost_mult = pow(1.1, total_get_gold_over_time_boost_level) * accum_mult * reinc_mult * gamble_mult * switch_gold_mult * tree_gold_mult
	_cached_token_over_time_boost_mult = pow(1.1, total_get_token_over_time_boost_level) * accum_mult * reinc_mult * gamble_mult * switch_token_mult * tree_token_mult
	_cached_ascension_mult = get_ascension_multiplier()
	update_amplifier_cache()


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
	elif _check_and_update_cumulative(skill_id, "equip_skill_boost_"):
		total_equip_skill_boost_level = _recalculate_total_level("equip_skill_boost_")
	elif _check_and_update_cumulative(skill_id, "accessory_slot_unlock_"):
		total_accessory_slot_unlock_level = _recalculate_total_level("accessory_slot_unlock_")
		equipment_changed.emit()
	_recalculate_cached_multipliers()


func toggle_debug_free_skill_cost() -> bool:
	debug_free_skill_cost = !debug_free_skill_cost
	debug_free_skill_cost_changed.emit(debug_free_skill_cost)
	return debug_free_skill_cost


func buy_skill_upgrade(skill_id: String, cost: float, is_unlimited: bool = false, force_free: bool = false) -> bool:
	var is_free := debug_free_skill_cost or force_free
	if is_free or tokens >= cost:
		var current_lvl = get_skill_level(skill_id)
		if is_unlimited or current_lvl == 0:
			if not is_free:
				tokens -= cost
			skill_levels[skill_id] = current_lvl + 1
			
			# Apply immediate passive effect for extra logo
			if skill_id == "extra_logo":
				logo_count += 1
				logo_spawn_requested.emit()
				
			# Update cumulative skill levels
			_update_cumulative_levels(skill_id)
			
			if skill_id.begins_with("inventory_expand_"):
				_ensure_inventory_sizes()
				inventory_updated.emit()
				equipment_changed.emit()
			elif skill_id == "equip_drop_unlock" or skill_id == "equip_drop_filter_unlock":
				equipment_changed.emit()
				
			if not is_free:
				tokens_changed.emit(tokens)
			skill_upgraded.emit(skill_id, skill_levels[skill_id])
			upgrades_changed.emit() # Recalculate speeds/etc.
			return true
	return false


# --- Equipment Logic ---
var _item_obtain_counter: int = 0

func get_next_item_obtain_order() -> int:
	_item_obtain_counter += 1
	return _item_obtain_counter


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



func format_equipment_skill_desc(sk_id: String, s_level: int, is_special: bool = false) -> String:
	if is_special or special_skill_defs.has(sk_id):
		var spec_def: Dictionary = special_skill_defs.get(sk_id, {})
		var desc_tmpl: String = spec_def.get("desc_template", "%s")
		if sk_id == "spec_diversity":
			var m25 := pow(25.0, float(s_level))
			var m50 := pow(50.0, float(s_level))
			return desc_tmpl % [format_num(m25), format_num(m50)]
		elif sk_id == "spec_accumulation":
			var base_mult := int(pow(2.0, float(s_level)))
			var s_val := format_num(float(base_mult))
			return "ゴールド、トークン入手量×%s 一定回数衝突するごとにさらに倍率+%s" % [s_val, s_val]
		elif sk_id == "spec_trinity":
			var mult_val := 2.0 + 0.2 * float(s_level - 1)
			return "基礎強化1つを無効化し、他2つのレベル×%.1f倍" % mult_val
		elif sk_id == "spec_gamble":
			var n := s_level + 1
			var max_m := int(pow(float(n), 4.0))
			return "ルーレットによってゴールド・トークン入手量がランダムに乗算(1倍~%s倍) 5分ごとにリセット" % format_num(float(max_m))
		elif sk_id == "spec_switch":
			var mult_val := int(pow(2.0, float(s_level)))
			return "ゴールド、トークンのいずれかを無効化し、他方の入手量×%s倍" % format_num(float(mult_val))
		elif "%d" in desc_tmpl:
			return desc_tmpl % s_level
		return desc_tmpl
	else:
		var sk_def: Dictionary = equipment_skill_defs.get(sk_id, {})
		var unit_val: float = float(sk_def.get("unit_value", 1.0))
		var desc_tmpl: String = sk_def.get("desc_template", "%s")
		var is_pow: bool = (sk_id == "gold_cost" or sk_id == "token_cost" or sk_id == "saving" or sk_id == "token_saving")
		var total_val: float = pow(unit_val, float(s_level)) if is_pow else unit_val * float(s_level)
		
		if sk_id == "corner_trick":
			var chance_percent := int((1.0 - pow(0.99, float(s_level))) * 100.0)
			return desc_tmpl % chance_percent
		elif "%.2f" in desc_tmpl:
			return desc_tmpl % total_val
		elif "%.1f" in desc_tmpl or "%f" in desc_tmpl:
			return desc_tmpl.replace("%f", "%.1f") % total_val
		elif "%d" in desc_tmpl:
			return desc_tmpl % int(round(total_val))
		return desc_tmpl


func generate_random_equipment(is_corner: bool = false) -> Dictionary:
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
	var tree_level_bonus := float(get_tree_equip_drop_level_bonus())
	var reinc_level_bonus := float(get_base_equip_level_bonus())
	var raw_level := (base_asc * rand_factor) + tree_level_bonus + reinc_level_bonus
	var level := maxi(10, int(round(raw_level / 10.0)) * 10)
	
	# 乱数幅 (0.9 ~ 1.1) の3分割判定 (Low: 0.90~0.9667, Medium: 0.9667~1.0333, High: 1.0333~1.10)
	var tier := "low"
	if rand_factor >= 0.9 + (0.2 * 2.0 / 3.0):
		tier = "high"
	elif rand_factor >= 0.9 + (0.2 / 3.0):
		tier = "medium"
	else:
		tier = "low"
	
	# Generate random rarity using Gaussian (Normal) Distribution model
	# Index x: 0:コモン, 1:アンコモン, 2:レア, 3:エピック, 4:レジェンド, 5:ミシック
	var rarity_level := get_total_equip_drop_rarity_boost() + int(get_equipped_skill_total_val("drop_rarity") + get_equipped_skill_total_val("drop_luck"))
	if is_corner and get_skill_level("equip_corner_enhance") > 0:
		rarity_level += 1

	var is_mythic_unlocked := get_skill_level("mythic_unlock") > 0
	var max_rarity_idx := 5 if is_mythic_unlocked else 4
	var max_mu := 5.0 if is_mythic_unlocked else 4.0

	var L := float(rarity_level)
	var mu := minf(max_mu, 0.05 * L)
	var threshold_L := 100.0 if is_mythic_unlocked else 80.0
	var extra_L := maxf(0.0, L - threshold_L)
	var sigma := 0.01 + 1.09 * exp(-0.02 * extra_L)

	var num_rarities := max_rarity_idx + 1
	var weights: Array[float] = []
	weights.resize(num_rarities)
	var total_w := 0.0
	for x in range(num_rarities):
		var diff := float(x) - mu
		var w := exp(- (diff * diff) / (2.0 * sigma * sigma))
		weights[x] = w
		total_w += w

	var roll := randf() * total_w
	var accumulated_w := 0.0
	var rarity_names := ["コモン", "アンコモン", "レア", "エピック", "レジェンド", "ミシック"]
	var rarity: String = "コモン"
	for x in range(num_rarities):
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

	# 特殊スキルの付与判定 (スキル解放時のみ, 基本確率: 3%, 1装備につき最大1つ)
	var can_have_special: bool = get_skill_level("equip_special_skill_unlock") > 0
	var has_special: bool = can_have_special and (randf() < special_skill_drop_chance) and not special_skill_defs.is_empty()
	var normal_skill_count: int = maxi(0, num_skills - 1 if has_special else num_skills)

	# 利用可能なオプション効果（スキル）のキーをシャッフル
	var skill_keys := _cached_equipment_skill_keys.duplicate()
	if skill_keys.is_empty():
		skill_keys = equipment_skill_defs.keys()
	skill_keys.shuffle()
	
	# スキルレベル配分 (平均 = 装備レベル/10 + 洗練レベル*0.1)
	var refinement_total := get_equipped_skill_total_val("drop_skill_level") + get_equipped_skill_total_val("refinement")
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

	# スキルツリーおよび角ヒットボーナス加算
	var skill_level_bonus := get_tree_equip_skill_level_bonus()
	if is_corner and get_skill_level("equip_corner_enhance") > 0:
		skill_level_bonus += 1

	var item_skills: Array[Dictionary] = []
	for i in range(min(normal_skill_count, skill_keys.size())):
		var sk_id: String = skill_keys[i]
		var sk_def: Dictionary = equipment_skill_defs.get(sk_id, {})
		var sk_name: String = sk_def.get("name", "")
		var s_level: int = final_skill_levels[i] + skill_level_bonus
		var formatted_desc := format_equipment_skill_desc(sk_id, s_level, false)
				
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
		var formatted_desc := format_equipment_skill_desc(spec_id, spec_lvl, true)

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
		"level_tier": tier,
		"rand_factor": rand_factor,
		"rarity": rarity,
		"equip_skill": item_skills,
		"forge_count": 0,
		"obtain_order": get_next_item_obtain_order()
	}


## 鍛冶の事前プレビュー情報（合算スキル候補リスト、レア度抽選確率、レベル候補など）を計算する純粋関数
func calculate_forge_preview(materials: Array) -> Dictionary:
	if materials.is_empty():
		return {
			"can_forge": false,
			"reason": "素材がありません",
			"skills": [],
			"rarity_probs": {},
			"forge_count": 0,
			"levels": []
		}

	var first_type: String = materials[0].get("type", "")
	var first_forge_count: int = materials[0].get("forge_count", 0)

	for mat in materials:
		if mat == null or not mat is Dictionary:
			return { "can_forge": false, "reason": "無効な素材が含まれています", "skills": [], "rarity_probs": {}, "forge_count": 0, "levels": [] }
		if mat.get("type", "") != first_type:
			return { "can_forge": false, "reason": "装備の種類が一致していません", "skills": [], "rarity_probs": {}, "forge_count": 0, "levels": [] }
		if mat.get("forge_count", 0) != first_forge_count:
			return { "can_forge": false, "reason": "鍛冶回数が一致していません", "skills": [], "rarity_probs": {}, "forge_count": 0, "levels": [] }

	# スキルの合算
	var aggregated_map: Dictionary = {}
	var levels: Array[int] = []

	for mat in materials:
		levels.append(int(mat.get("level", 10)))
		var m_skills = mat.get("equip_skill", [])
		for sk in m_skills:
			var sk_id: String = sk.get("id", "")
			if sk_id == "":
				continue
			var sk_lvl: int = int(sk.get("level", 1))
			if aggregated_map.has(sk_id):
				aggregated_map[sk_id]["level"] += sk_lvl
			else:
				var is_spec: bool = sk.get("is_special", false) or special_skill_defs.has(sk_id)
				var sk_name: String = sk.get("name", "")
				if sk_name == "":
					if is_spec:
						sk_name = special_skill_defs.get(sk_id, {}).get("name", sk_id)
					else:
						sk_name = equipment_skill_defs.get(sk_id, {}).get("name", sk_id)
				aggregated_map[sk_id] = {
					"id": sk_id,
					"name": sk_name,
					"level": sk_lvl,
					"is_special": is_spec,
					"has_custom_ui": sk.get("has_custom_ui", false),
					"ui_title": sk.get("ui_title", "")
				}

	# スキルを「通常スキル（Lv降順） → 特殊スキル（Lv降順）」でソート
	var normal_skills: Array[Dictionary] = []
	var special_skills: Array[Dictionary] = []
	for sk_id in aggregated_map:
		var sk_entry: Dictionary = aggregated_map[sk_id]
		sk_entry["desc"] = format_equipment_skill_desc(sk_id, sk_entry["level"], sk_entry["is_special"])
		if sk_entry["is_special"]:
			special_skills.append(sk_entry)
		else:
			normal_skills.append(sk_entry)

	normal_skills.sort_custom(func(a, b): return a["level"] > b["level"])
	special_skills.sort_custom(func(a, b): return a["level"] > b["level"])

	var all_skills: Array[Dictionary] = []
	all_skills.append_array(normal_skills)
	all_skills.append_array(special_skills)

	# レア度抽選確率の算出
	# 1~5個: nからn-2の3種 (1のときはコモンのみ、2のときはコモンとアンコモン)
	# 6個以上: 4~6に対応したレア度が等確率 (エピック, レジェンド, ミシック) ※ミシック未解放時はレジェンドまで
	var is_mythic_unlocked := get_skill_level("mythic_unlock") > 0
	var max_allowed_r := 6 if is_mythic_unlocked else 5
	var n: int = all_skills.size()
	var rarity_names := ["コモン", "アンコモン", "レア", "エピック", "レジェンド", "ミシック"]
	var rarity_probs: Dictionary = {}
	var min_r: int = 1
	var max_r: int = 1

	if n <= 0:
		pass
	elif n <= 5:
		min_r = maxi(1, n - 2)
		max_r = mini(n, max_allowed_r)
		var count: float = float(max_r - min_r + 1)
		for r_idx in range(min_r, max_r + 1):
			var r_name: String = rarity_names[r_idx - 1]
			rarity_probs[r_name] = 1.0 / count
	else:
		min_r = 4
		max_r = max_allowed_r
		var count: float = float(max_r - min_r + 1)
		for r_idx in range(min_r, max_r + 1):
			var r_name: String = rarity_names[r_idx - 1]
			rarity_probs[r_name] = 1.0 / count

	return {
		"can_forge": materials.size() >= 2 and materials.size() <= 9,
		"reason": "" if materials.size() >= 2 else "素材が2つ以上必要です",
		"skills": all_skills,
		"rarity_probs": rarity_probs,
		"possible_rarity_range": [min_r, max_r],
		"forge_count": first_forge_count + 1,
		"levels": levels,
		"item_type": first_type
	}


## 鍛冶合成を実行する
func forge_equipment(type: String, material_inv_indices: Array[int]) -> Dictionary:
	_ensure_inventory_sizes()
	if not inventories.has(type):
		return {}
	var inv_arr: Array = inventories[type]
	if material_inv_indices.size() < 2 or material_inv_indices.size() > 9:
		return {}

	# 重複インデックスの除去と検証
	var unique_indices: Array[int] = []
	var material_items: Array[Dictionary] = []
	for idx in material_inv_indices:
		if idx < 0 or idx >= MAX_TYPE_INVENTORY_SIZE:
			return {}
		if unique_indices.has(idx):
			continue
		unique_indices.append(idx)
		var it = inv_arr[idx]
		if it == null or not it is Dictionary or it.is_empty():
			return {}
		material_items.append(it)

	if material_items.size() < 2:
		return {}

	# プレビュー計算で妥当性検証
	var preview := calculate_forge_preview(material_items)
	if not preview.get("can_forge", false):
		return {}

	var forge_count: int = preview["forge_count"]
	var levels: Array = preview["levels"]
	var chosen_level: int = levels[randi() % levels.size()]
	var all_candidate_skills: Array = preview["skills"].duplicate(true)

	# レア度の決定
	var r_range: Array = preview.get("possible_rarity_range", [1, 1])
	var rolled_r_idx: int = randi_range(r_range[0], r_range[1])
	var rarity_names := ["コモン", "アンコモン", "レア", "エピック", "レジェンド", "ミシック"]
	var chosen_rarity: String = rarity_names[rolled_r_idx - 1]

	# 決定されたレア度枠数に応じたスキル選出
	var num_slots: int = rolled_r_idx
	var select_count: int = mini(num_slots, all_candidate_skills.size())
	all_candidate_skills.shuffle()
	var selected_skills := all_candidate_skills.slice(0, select_count)

	# スキルを「通常スキル（Lv降順） → 特殊スキル（Lv降順）」でソート
	var normal_list: Array[Dictionary] = []
	var special_list: Array[Dictionary] = []
	for sk in selected_skills:
		sk["desc"] = format_equipment_skill_desc(sk["id"], sk["level"], sk.get("is_special", false))
		if sk.get("is_special", false):
			special_list.append(sk)
		else:
			normal_list.append(sk)

	normal_list.sort_custom(func(a, b): return a["level"] > b["level"])
	special_list.sort_custom(func(a, b): return a["level"] > b["level"])

	var final_skills: Array[Dictionary] = []
	final_skills.append_array(normal_list)
	final_skills.append_array(special_list)

	# ベースアイテム（素材の中からランダムに選択）
	var base_item: Dictionary = material_items[randi() % material_items.size()]
	var new_id := "eq_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 1000)

	var new_item := {
		"id": new_id,
		"name": base_item.get("name", "装備"),
		"type": type,
		"icon": base_item.get("icon", ""),
		"level": chosen_level,
		"level_tier": base_item.get("level_tier", "medium"),
		"rand_factor": base_item.get("rand_factor", 1.0),
		"rarity": chosen_rarity,
		"equip_skill": final_skills,
		"forge_count": forge_count,
		"obtain_order": get_next_item_obtain_order()
	}

	# インベントリ配置: 素材の中でインデックス最小の位置に新アイテムを配置し、残りは消滅
	var min_idx: int = unique_indices[0]
	for idx in unique_indices:
		if idx < min_idx:
			min_idx = idx

	for idx in unique_indices:
		inv_arr[idx] = null

	inv_arr[min_idx] = new_item
	equipment_changed.emit()

	return new_item


# --- Equipment Filtering Logic ---
var equipment_filter_settings: Dictionary = {
	"level_tiers": {
		"low": true,
		"medium": true,
		"high": true
	},
	"rarities": {
		"コモン": true,
		"アンコモン": true,
		"レア": true,
		"エピック": true,
		"レジェンド": true,
		"ミシック": true
	},
	"normal_skills": {},
	"normal_skill_mode": "OR",
	"special_skill": ""
}
signal equipment_filter_changed


func reset_equipment_filter_settings() -> void:
	equipment_filter_settings = {
		"level_tiers": {
			"low": true,
			"medium": true,
			"high": true
		},
		"rarities": {
			"コモン": true,
			"アンコモン": true,
			"レア": true,
			"エピック": true,
			"レジェンド": true,
			"ミシック": true
		},
		"normal_skills": {},
		"normal_skill_mode": "OR",
		"special_skill": ""
	}
	equipment_filter_changed.emit()


func is_item_matched_filter(item: Dictionary) -> bool:
	if item.is_empty():
		return false
		
	# 1. Lv乱数帯判定
	var tier: String = item.get("level_tier", "low")
	var tier_settings: Dictionary = equipment_filter_settings.get("level_tiers", {})
	if not tier_settings.get(tier, true):
		return false
		
	# 2. レア度判定
	var rarity: String = item.get("rarity", "コモン")
	var rarity_settings: Dictionary = equipment_filter_settings.get("rarities", {})
	if not rarity_settings.get(rarity, true):
		return false
		
	# 3. 通常スキル判定
	var item_skills: Array = item.get("equip_skill", [])
	var item_normal_ids: Array[String] = []
	var item_special_id: String = ""
	
	for sk in item_skills:
		if sk is Dictionary:
			var sk_id: String = sk.get("id", "")
			if sk.get("is_special", false):
				item_special_id = sk_id
			else:
				item_normal_ids.append(sk_id)
				
	var normal_filters: Dictionary = equipment_filter_settings.get("normal_skills", {})
	var selected_normal_skills: Array[String] = []
	for sk_id in normal_filters:
		if normal_filters[sk_id]:
			selected_normal_skills.append(sk_id)
			
	if not selected_normal_skills.is_empty():
		var mode: String = equipment_filter_settings.get("normal_skill_mode", "OR")
		if mode == "AND":
			for req_id in selected_normal_skills:
				if req_id not in item_normal_ids:
					return false
		else: # "OR"
			var matched := false
			for req_id in selected_normal_skills:
				if req_id in item_normal_ids:
					matched = true
					break
			if not matched:
				return false
				
	# 4. 特殊スキル判定
	var target_special: String = equipment_filter_settings.get("special_skill", "")
	if not target_special.is_empty():
		if target_special == "__has_special__":
			if item_special_id.is_empty():
				return false
		elif target_special == "__no_special__":
			if not item_special_id.is_empty():
				return false
		else:
			if item_special_id != target_special:
				return false
			
	return true


# --- Inventory Filter & Sorting Logic ---
var inventory_filter_settings: Dictionary = {
	"main": {
		"sort_key": "rarity", # "rarity", "level", "obtain"
		"sort_order": "desc", # "desc", "asc"
		"rarities": {
			"コモン": true,
			"アンコモン": true,
			"レア": true,
			"エピック": true,
			"レジェンド": true,
			"ミシック": true
		},
		"normal_skills": {},
		"normal_skill_mode": "OR",
		"special_skill": ""
	},
	"sub": {
		"sort_key": "rarity",
		"sort_order": "desc",
		"rarities": {
			"コモン": true,
			"アンコモン": true,
			"レア": true,
			"エピック": true,
			"レジェンド": true,
			"ミシック": true
		},
		"normal_skills": {},
		"normal_skill_mode": "OR",
		"special_skill": ""
	},
	"accessory": {
		"sort_key": "rarity",
		"sort_order": "desc",
		"rarities": {
			"コモン": true,
			"アンコモン": true,
			"レア": true,
			"エピック": true,
			"レジェンド": true,
			"ミシック": true
		},
		"normal_skills": {},
		"normal_skill_mode": "OR",
		"special_skill": ""
	}
}
signal inventory_filter_changed(type: String)


func reset_inventory_filter_settings(type: String) -> void:
	if not inventory_filter_settings.has(type):
		return
	inventory_filter_settings[type] = {
		"sort_key": "rarity",
		"sort_order": "desc",
		"rarities": {
			"コモン": true,
			"アンコモン": true,
			"レア": true,
			"エピック": true,
			"レジェンド": true,
			"ミシック": true
		},
		"normal_skills": {},
		"normal_skill_mode": "OR",
		"special_skill": ""
	}
	inventory_filter_changed.emit(type)


func is_item_matched_inventory_filter(item: Dictionary, type: String) -> bool:
	if item.is_empty():
		return false
	var settings: Dictionary = inventory_filter_settings.get(type, {})
	if settings.is_empty():
		return true

	# 1. レア度判定
	var rarity: String = item.get("rarity", "コモン")
	var rarity_settings: Dictionary = settings.get("rarities", {})
	if not rarity_settings.get(rarity, true):
		return false

	# 2. 通常スキル判定
	var item_skills: Array = item.get("equip_skill", [])
	var item_normal_ids: Array[String] = []
	var item_special_id: String = ""

	for sk in item_skills:
		if sk is Dictionary:
			var sk_id: String = sk.get("id", "")
			if sk.get("is_special", false):
				item_special_id = sk_id
			else:
				item_normal_ids.append(sk_id)

	var normal_filters: Dictionary = settings.get("normal_skills", {})
	var selected_normal_skills: Array[String] = []
	for sk_id in normal_filters:
		if normal_filters[sk_id]:
			selected_normal_skills.append(sk_id)

	if not selected_normal_skills.is_empty():
		var mode: String = settings.get("normal_skill_mode", "OR")
		if mode == "AND":
			for req_id in selected_normal_skills:
				if req_id not in item_normal_ids:
					return false
		else: # "OR"
			var matched := false
			for req_id in selected_normal_skills:
				if req_id in item_normal_ids:
					matched = true
					break
			if not matched:
				return false

	# 3. 特殊スキル判定
	var target_special: String = settings.get("special_skill", "")
	if not target_special.is_empty():
		if target_special == "__has_special__":
			if item_special_id.is_empty():
				return false
		elif target_special == "__no_special__":
			if not item_special_id.is_empty():
				return false
		else:
			if item_special_id != target_special:
				return false

	return true


func _compare_items_for_sort(a: Dictionary, b: Dictionary, sort_key: String, sort_order: String) -> bool:
	var is_asc := (sort_order == "asc")
	var r_map := { "コモン": 0, "アンコモン": 1, "レア": 2, "エピック": 3, "レジェンド": 4, "ミシック": 5 }

	if sort_key == "rarity":
		var val_a: int = r_map.get(a.get("rarity", "コモン"), 0)
		var val_b: int = r_map.get(b.get("rarity", "コモン"), 0)
		if val_a != val_b:
			return (val_a < val_b) if is_asc else (val_a > val_b)
		var lvl_a: int = a.get("level", 0)
		var lvl_b: int = b.get("level", 0)
		if lvl_a != lvl_b:
			return lvl_a > lvl_b
		return int(a.get("obtain_order", 0)) > int(b.get("obtain_order", 0))

	elif sort_key == "level":
		var val_a: int = a.get("level", 0)
		var val_b: int = b.get("level", 0)
		if val_a != val_b:
			return (val_a < val_b) if is_asc else (val_a > val_b)
		var r_a: int = r_map.get(a.get("rarity", "コモン"), 0)
		var r_b: int = r_map.get(b.get("rarity", "コモン"), 0)
		if r_a != r_b:
			return r_a > r_b
		return int(a.get("obtain_order", 0)) > int(b.get("obtain_order", 0))

	else: # "obtain"
		var val_a: int = int(a.get("obtain_order", 0))
		var val_b: int = int(b.get("obtain_order", 0))
		if val_a != val_b:
			return (val_a < val_b) if is_asc else (val_a > val_b)
		return a.get("id", "") < b.get("id", "")


func sort_and_filter_inventory(type: String) -> void:
	if not inventories.has(type):
		return
	_ensure_inventory_sizes()
	var inv: Array = inventories[type]
	var settings: Dictionary = inventory_filter_settings.get(type, {})
	var sort_key: String = settings.get("sort_key", "rarity")
	var sort_order: String = settings.get("sort_order", "desc")

	var matched_items: Array[Dictionary] = []
	var unmatched_items: Array[Dictionary] = []

	for it in inv:
		if it != null and it is Dictionary and not it.is_empty():
			if is_item_matched_inventory_filter(it, type):
				matched_items.append(it)
			else:
				unmatched_items.append(it)

	matched_items.sort_custom(func(a, b): return _compare_items_for_sort(a, b, sort_key, sort_order))
	unmatched_items.sort_custom(func(a, b): return _compare_items_for_sort(a, b, sort_key, sort_order))

	var new_inv: Array = []
	for it in matched_items:
		new_inv.append(it)
	for it in unmatched_items:
		new_inv.append(it)

	while new_inv.size() < MAX_TYPE_INVENTORY_SIZE:
		new_inv.append(null)

	inventories[type] = new_inv
	inventory_updated.emit()
	equipment_changed.emit()


func roll_equipment_drop(is_corner: bool) -> Dictionary:
	# 装備ドロップ解放スキルが未習得の場合はドロップしない
	if get_skill_level("equip_drop_unlock") <= 0:
		return {}
		
	# 累積ドロップ率係数 L (装備スキル「大漁」レベル)
	var L := get_equipped_skill_total_val("drop_rate_boost")
	
	# 分数関数(反比例)漸近収束モデル: P(L) = 1.0 - (1.0 - P_base) / (1.0 + 0.03 * L)
	var base_drop_chance := 0.15 if is_corner else 0.02
	base_drop_chance += get_tree_equip_drop_probability_bonus()
	base_drop_chance += get_challenge_drop_rate_bonus()
	var drop_chance := 1.0 - (1.0 - base_drop_chance) / (1.0 + 0.03 * L)
	# 装備スキル「装備ドロップ率」ボーナス (+1.2n%)
	var equip_drop_rate_bonus := get_equipped_skill_total_val("drop_rate") * 0.01
	drop_chance = minf(1.0, drop_chance + equip_drop_rate_bonus)
		
	if randf() < drop_chance:
		var item := generate_random_equipment(is_corner)
		
		# フィルタリング判定: フィルター解放済みかつ条件不一致の場合は自動廃棄
		var is_filter_unlocked := get_skill_level("equip_drop_filter_unlock") > 0
		if is_filter_unlocked and not is_item_matched_filter(item):
			var filter_rewards := discard_equipment_rewards()
			if filter_rewards["gold"] > 0.0:
				add_gold(filter_rewards["gold"])
			if filter_rewards["tokens"] > 0.0:
				add_tokens(filter_rewards["tokens"])
			item["is_discarded"] = true
			item["discard_gold"] = filter_rewards["gold"]
			item["discard_tokens"] = filter_rewards["tokens"]
			item["is_sold"] = true
			item["sell_price"] = filter_rewards["gold"]
			item["sell_tokens"] = filter_rewards["tokens"]
			return item

		var type = item.get("type", "")
		_ensure_inventory_sizes()
		var inv: Array = inventories.get(type, [])
		var max_sz := get_max_inventory_size()
		
		# 有効スロット範囲内で最初の空きスロット (null) を探す
		var empty_index := -1
		for i in range(mini(inv.size(), max_sz)):
			if inv[i] == null:
				empty_index = i
				break
				
		if empty_index != -1:
			inv[empty_index] = item
			inventory_updated.emit()
			return item
		else:
			# インベントリ満タン時: インベントリには追加せず、自動廃棄
			var full_rewards := discard_equipment_rewards()
			if full_rewards["gold"] > 0.0:
				add_gold(full_rewards["gold"])
			if full_rewards["tokens"] > 0.0:
				add_tokens(full_rewards["tokens"])
			item["is_discarded"] = true
			item["discard_gold"] = full_rewards["gold"]
			item["discard_tokens"] = full_rewards["tokens"]
			item["is_sold"] = true
			item["sell_price"] = full_rewards["gold"]
			item["sell_tokens"] = full_rewards["tokens"]
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


# --- Unified Close Button Design ---
var _close_btn_style_normal: StyleBoxFlat
var _close_btn_style_hover: StyleBoxFlat
var _close_btn_style_pressed: StyleBoxFlat


func setup_close_button(btn: Button) -> void:
	if not btn:
		return
	if btn is CloseButton:
		return

		
	if _close_btn_style_normal == null:
		# 角が少しラウンドした正方形、境界は黒、内部はオレンジがかった少し彩度の低い赤
		_close_btn_style_normal = StyleBoxFlat.new()
		_close_btn_style_normal.bg_color = Color(0.78, 0.24, 0.18, 1.0)
		_close_btn_style_normal.border_width_left = 1
		_close_btn_style_normal.border_width_top = 1
		_close_btn_style_normal.border_width_right = 1
		_close_btn_style_normal.border_width_bottom = 1
		_close_btn_style_normal.border_color = Color(0.0, 0.0, 0.0, 1.0) # 境界は黒
		_close_btn_style_normal.corner_radius_top_left = 4
		_close_btn_style_normal.corner_radius_top_right = 6 # ウィンドウ右上角のラウンドに合わせる
		_close_btn_style_normal.corner_radius_bottom_right = 4
		_close_btn_style_normal.corner_radius_bottom_left = 6
		
		_close_btn_style_hover = StyleBoxFlat.new()
		_close_btn_style_hover.bg_color = Color(0.88, 0.32, 0.24, 1.0)
		_close_btn_style_hover.border_width_left = 1
		_close_btn_style_hover.border_width_top = 1
		_close_btn_style_hover.border_width_right = 1
		_close_btn_style_hover.border_width_bottom = 1
		_close_btn_style_hover.border_color = Color(0.0, 0.0, 0.0, 1.0)
		_close_btn_style_hover.corner_radius_top_left = 4
		_close_btn_style_hover.corner_radius_top_right = 6
		_close_btn_style_hover.corner_radius_bottom_right = 4
		_close_btn_style_hover.corner_radius_bottom_left = 6
		
		_close_btn_style_pressed = StyleBoxFlat.new()
		_close_btn_style_pressed.bg_color = Color(0.62, 0.18, 0.14, 1.0)
		_close_btn_style_pressed.border_width_left = 1
		_close_btn_style_pressed.border_width_top = 1
		_close_btn_style_pressed.border_width_right = 1
		_close_btn_style_pressed.border_width_bottom = 1
		_close_btn_style_pressed.border_color = Color(0.0, 0.0, 0.0, 1.0)
		_close_btn_style_pressed.corner_radius_top_left = 4
		_close_btn_style_pressed.corner_radius_top_right = 6
		_close_btn_style_pressed.corner_radius_bottom_right = 4
		_close_btn_style_pressed.corner_radius_bottom_left = 6

	if btn.custom_minimum_size == Vector2.ZERO or btn.custom_minimum_size == Vector2(60, 60):
		btn.custom_minimum_size = Vector2(64, 64)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _close_btn_style_normal)
	btn.add_theme_stylebox_override("hover", _close_btn_style_hover)
	btn.add_theme_stylebox_override("pressed", _close_btn_style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	# 中央に、ボタン内部のオレンジがかった赤色に少し近い黒で太めの×マーク
	var close_mark_color := Color(0.20, 0.05, 0.04, 1.0)
	btn.add_theme_color_override("font_color", close_mark_color)
	btn.add_theme_color_override("font_hover_color", Color(0.14, 0.03, 0.02, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.08, 0.01, 0.01, 1.0))
	var font_sz := int(round(btn.custom_minimum_size.y * 0.85))
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.text = "×"


# ==============================================================================
# チャレンジシステム (Challenge System)
# ==============================================================================

signal challenge_started(challenge_id: String)
signal challenge_progress_updated(current: float, target: float, time_left: float)
signal challenge_completed(challenge_id: String)
signal challenge_failed(challenge_id: String)
signal challenge_state_changed()

var active_challenge_id: String = ""
var challenge_time_left: float = 0.0
var challenge_duration: float = 60.0
var challenge_current_val: float = 0.0
var challenge_target_val: float = 0.0
var challenge_cleared: Dictionary = {} # { "c1": true, ... }

var CHALLENGE_DEFS: Dictionary = {
	"c1": {
		"id": "c1",
		"name": "装備無効",
		"icon": "🥋",
		"desc": "すべての装備効果・スキルが無効化される",
		"duration": 60.0,
		"target_type": "gold",
		"target_val": 5000.0,
		"reward_desc": "装備ドロップ率 +10%"
	},
	"c2": {
		"id": "c2",
		"name": "基礎強化無効",
		"icon": "🛑",
		"desc": "基本強化（速度・増加・サイズ）が無効化される",
		"duration": 30.0,
		"target_type": "gold",
		"target_val": 2500.0,
		"reward_desc": "基本ゴールド獲得量 +15%"
	},
	"c3": {
		"id": "c3",
		"name": "ロゴ数制限",
		"icon": "👤",
		"desc": "ロゴが1個に固定される",
		"duration": 60.0,
		"target_type": "gold",
		"target_val": 10000.0,
		"reward_desc": "ロゴ基本速度 +10%"
	},
	"c4": {
		"id": "c4",
		"name": "アセンションボーナス無効",
		"icon": "⚛️",
		"desc": "アセンションによる倍率ボーナスが無効化される",
		"duration": 60.0,
		"target_type": "gold",
		"target_val": 25000.0,
		"reward_desc": "アセンション獲得トークン +15%"
	},
	"c5": {
		"id": "c5",
		"name": "クリティカル無効",
		"icon": "⚡",
		"desc": "クリティカルヒットが発生しなくなる",
		"duration": 60.0,
		"target_type": "gold",
		"target_val": 50000.0,
		"reward_desc": "クリティカル倍率 +15%"
	},
	"c6": {
		"id": "c6",
		"name": "ダイレクトヒット無効",
		"icon": "🎯",
		"desc": "ダイレクトヒットが発生しなくなる",
		"duration": 60.0,
		"target_type": "gold",
		"target_val": 100000.0,
		"reward_desc": "ダイレクトヒット倍率 +15%"
	},
	"c7": {
		"id": "c7",
		"name": "角ヒット無効",
		"icon": "📐",
		"desc": "角ヒット時の獲得・ボーナスが無効化される",
		"duration": 60.0,
		"target_type": "gold",
		"target_val": 250000.0,
		"reward_desc": "角ヒットゴールド倍率 +25%"
	},
	"c8": {
		"id": "c8",
		"name": "チャレンジボーナス無効",
		"icon": "🏆",
		"desc": "チャレンジクリアによる恒久ボーナスが無効化される",
		"duration": 60.0,
		"target_type": "gold",
		"target_val": 500000.0,
		"reward_desc": "全トークン獲得量 +15%"
	}
}

const CHALLENGES_PATH = "res://data/challenges.json"
var challenge_cleared_levels: Dictionary = {} # { "c1": 1, ... }
var active_challenge_level: int = 1


func _load_challenge_defs() -> void:
	if not FileAccess.file_exists(CHALLENGES_PATH):
		return
	var file := FileAccess.open(CHALLENGES_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		if data is Dictionary and data.has("challenges"):
			CHALLENGE_DEFS = data["challenges"]
			# levels 定義からレベル1のプロパティをトップレベルにも反映（互換性確保）
			for ch_id in CHALLENGE_DEFS:
				var ch: Dictionary = CHALLENGE_DEFS[ch_id]
				var levels: Array = ch.get("levels", [])
				if levels.size() > 0 and levels[0] is Dictionary:
					var lv1: Dictionary = levels[0]
					if not ch.has("duration"): ch["duration"] = lv1.get("duration", 60.0)
					if not ch.has("target_type"): ch["target_type"] = lv1.get("target_type", "gold")
					if not ch.has("target_val"): ch["target_val"] = lv1.get("target_val", 1000.0)
					if not ch.has("reward_desc"): ch["reward_desc"] = lv1.get("reward_desc", "")
	file.close()


func is_challenge_unlocked() -> bool:
	return get_skill_level("challenge_unlock") > 0 or get_skill_level("challange_unlock") > 0


func is_challenge_item_unlocked(ch_id: String) -> bool:
	if not is_challenge_unlocked():
		return false

	match ch_id:
		"c1", "c2":
			return true # 初期解放（チャレンジ1, 2）
		"c3", "c4":
			return get_skill_level("new_challange_unlock_1") > 0 or get_skill_level("new_challenge_unlock_1") > 0
		"c5", "c6":
			return get_skill_level("new_challange_unlock_2") > 0 or get_skill_level("new_challenge_unlock_2") > 0
		"c7", "c8":
			return get_skill_level("new_challange_unlock_3") > 0 or get_skill_level("new_challenge_unlock_3") > 0
		_:
			return true


func get_challenge_level_cap() -> int:
	var cap := 2 # 初期値は1と2のみ解放
	if get_skill_level("challange_level_unlock_1") > 0:
		cap += 1 # Lv.3解放
	if get_skill_level("challange_level_unlock_2") > 0:
		cap += 1 # Lv.4解放
	if get_skill_level("challange_level_unlock_3") > 0:
		cap += 1 # Lv.5解放
	return cap


func get_challenge_time_multiplier() -> float:
	var mult := 1.0
	for i in range(1, 6):
		if get_skill_level("challange_time_extend_%d" % i) > 0:
			mult *= 1.2
	return mult


func get_challenge_norma_multiplier() -> float:
	var mult := 1.0
	for i in range(1, 6):
		if get_skill_level("challange_norma_onus_%d" % i) > 0:
			mult *= 0.8
	return mult


func get_challenge_cleared_level(ch_id: String) -> int:
	if challenge_cleared_levels.has(ch_id):
		return int(challenge_cleared_levels[ch_id])
	return 1 if challenge_cleared.get(ch_id, false) else 0


func get_challenge_def_max_level(ch_id: String) -> int:
	var def: Dictionary = CHALLENGE_DEFS.get(ch_id, {})
	var levels: Array = def.get("levels", [])
	return maxi(1, levels.size())


func get_challenge_max_level(ch_id: String) -> int:
	var def_max := get_challenge_def_max_level(ch_id)
	return mini(def_max, get_challenge_level_cap())


func get_challenge_target_level(ch_id: String) -> int:
	var cleared_lvl := get_challenge_cleared_level(ch_id)
	var max_lvl := get_challenge_max_level(ch_id)
	return mini(cleared_lvl + 1, max_lvl)


func get_challenge_level_def(ch_id: String, level: int = -1) -> Dictionary:
	var def: Dictionary = CHALLENGE_DEFS.get(ch_id, {})
	var levels: Array = def.get("levels", [])
	if levels.is_empty():
		return {
			"level": 1,
			"duration": def.get("duration", 60.0),
			"target_type": def.get("target_type", "gold"),
			"target_val": def.get("target_val", 1000.0),
			"reward_desc": def.get("reward_desc", "")
		}
	if level <= 0:
		level = get_challenge_target_level(ch_id)
	var idx := clampi(level - 1, 0, levels.size() - 1)
	return levels[idx]


func get_challenge_effective_duration(ch_id: String, level: int = -1) -> float:
	var lv_def := get_challenge_level_def(ch_id, level)
	var base_dur: float = float(lv_def.get("duration", 60.0))
	return base_dur * get_challenge_time_multiplier()


func get_challenge_effective_target_val(ch_id: String, level: int = -1) -> float:
	var lv_def := get_challenge_level_def(ch_id, level)
	var base_val: float = float(lv_def.get("target_val", 1000.0))
	return base_val * get_challenge_norma_multiplier()


func is_challenge_active(challenge_id: String = "") -> bool:
	if challenge_id.is_empty():
		return not active_challenge_id.is_empty()
	return active_challenge_id == challenge_id


func is_challenge_cleared(challenge_id: String) -> bool:
	return challenge_cleared.get(challenge_id, false)


func get_effective_logo_count() -> int:
	if is_challenge_active("c3"):
		return 1
	return logo_count


func start_challenge(challenge_id: String, target_level: int = -1) -> bool:
	if not is_challenge_unlocked():
		return false
	if not is_challenge_item_unlocked(challenge_id):
		return false
	if not CHALLENGE_DEFS.has(challenge_id):
		return false
	if not active_challenge_id.is_empty():
		cancel_challenge()

	var def: Dictionary = CHALLENGE_DEFS[challenge_id]
	if target_level <= 0:
		target_level = get_challenge_target_level(challenge_id)
	var max_allowed := get_challenge_max_level(challenge_id)
	target_level = clampi(target_level, 1, max_allowed)

	active_challenge_id = challenge_id
	active_challenge_level = target_level
	challenge_duration = get_challenge_effective_duration(challenge_id, target_level)
	challenge_time_left = challenge_duration
	challenge_current_val = 0.0
	challenge_target_val = get_challenge_effective_target_val(challenge_id, target_level)

	_recalculate_cached_multipliers()
	upgrades_changed.emit()
	if challenge_id == "c3":
		logo_reset_requested.emit()

	challenge_started.emit(challenge_id)
	challenge_state_changed.emit()
	challenge_progress_updated.emit(challenge_current_val, challenge_target_val, challenge_time_left)
	return true


func cancel_challenge() -> void:
	if active_challenge_id.is_empty():
		return
	var old_id := active_challenge_id
	active_challenge_id = ""
	challenge_time_left = 0.0
	challenge_current_val = 0.0

	_recalculate_cached_multipliers()
	upgrades_changed.emit()
	if old_id == "c3":
		logo_reset_requested.emit()

	challenge_state_changed.emit()


func fail_challenge() -> void:
	if active_challenge_id.is_empty():
		return
	var old_id := active_challenge_id
	cancel_challenge()
	challenge_failed.emit(old_id)


func complete_challenge() -> void:
	if active_challenge_id.is_empty():
		return
	var old_id := active_challenge_id
	var cleared_lvl := active_challenge_level
	challenge_cleared[old_id] = true
	var prev_cleared: int = challenge_cleared_levels.get(old_id, 0)
	if cleared_lvl > prev_cleared:
		challenge_cleared_levels[old_id] = cleared_lvl
	cancel_challenge()
	_recalculate_cached_multipliers()
	challenge_completed.emit(old_id)


func get_cleared_challenge_count() -> int:
	var count := 0
	for ch_id in challenge_cleared:
		if challenge_cleared[ch_id]:
			count += 1
	return count


func get_max_level_challenge_count() -> int:
	# 現状の全チャレンジクリア数をカウント（レベル制拡張時にも対応）
	return get_cleared_challenge_count()


func record_challenge_progress(currency_type: String, amount: float) -> void:
	if active_challenge_id.is_empty():
		return
	var lv_def: Dictionary = get_challenge_level_def(active_challenge_id, active_challenge_level)
	var expected_type: String = lv_def.get("target_type", "gold")
	if currency_type != expected_type:
		return

	challenge_current_val += amount
	challenge_progress_updated.emit(challenge_current_val, challenge_target_val, challenge_time_left)

	if challenge_current_val >= challenge_target_val:
		complete_challenge()


# --- チャレンジクリア恒久パッシブ効果 ---

func get_challenge_gold_multiplier() -> float:
	if is_challenge_active("c8"):
		return 1.0
	var mult: float = 1.0
	if is_challenge_cleared("c2"):
		mult *= 1.15 # c2クリア: 基本ゴールド +15%
	return mult


func get_challenge_speed_multiplier() -> float:
	if is_challenge_active("c8"):
		return 1.0
	var mult: float = 1.0
	if is_challenge_cleared("c3"):
		mult *= 1.10 # c3クリア: 速度 +10%
	return mult


func get_challenge_corner_gold_multiplier() -> float:
	if is_challenge_active("c8"):
		return 1.0
	var mult: float = 1.0
	if is_challenge_cleared("c7"):
		mult *= 1.25 # c7クリア: 角ヒットゴールド +25%
	return mult


func get_challenge_drop_rate_bonus() -> float:
	if is_challenge_active("c8"):
		return 0.0
	if is_challenge_cleared("c1"):
		return 0.10 # c1クリア: ドロップ率 +10%
	return 0.0


func get_challenge_ascension_token_multiplier() -> float:
	if is_challenge_active("c8"):
		return 1.0
	if is_challenge_cleared("c4"):
		return 1.15 # c4クリア: アセンショントークン +15%
	return 1.0


func get_challenge_crit_multiplier() -> float:
	if is_challenge_active("c8"):
		return 1.0
	if is_challenge_cleared("c5"):
		return 1.15 # c5クリア: クリティカル倍率 +15%
	return 1.0


func get_challenge_direct_multiplier() -> float:
	if is_challenge_active("c8"):
		return 1.0
	if is_challenge_cleared("c6"):
		return 1.15 # c6クリア: ダイレクトヒット倍率 +15%
	return 1.0


func get_challenge_token_multiplier() -> float:
	if is_challenge_active("c8"):
		return 1.0
	if is_challenge_cleared("c8"):
		return 1.15 # c8クリア: トークン獲得量 +15%
	return 1.0


# ==============================================================================
# 増幅装置システム (Amplifier System)
# ==============================================================================

signal amplifier_changed()

var _amp_cache_timer: float = 0.0

# ゴールド倍率: ボーナス * ( 倍率α * 倍率β ) ^ パワー
var amp_gold_base_unlocked: bool = false
var amp_gold_mult_level: int = 0 # 倍率α
var amp_gold_mult_b_level: int = 0 # 倍率β
var amp_gold_pow_level: int = 0

# トークン倍率: ボーナス * ( 倍率α * 倍率β ) ^ パワー
var amp_token_base_unlocked: bool = false
var amp_token_mult_level: int = 0 # 倍率α
var amp_token_mult_b_level: int = 0 # 倍率β
var amp_token_pow_level: int = 0

const AMP_GOLD_BASE_UNLOCK_COST: float = 100.0 # トークン消費
const AMP_TOKEN_BASE_UNLOCK_COST: float = 1000.0 # ゴールド消費


func get_amp_gold_base_val() -> float:
	if not amp_gold_base_unlocked:
		return 1.0
	if tokens <= 1.0:
		return 1.0
	return maxf(1.0, log(tokens) / log(10.0))


func get_amp_gold_mult_val() -> float:
	return 1.0 + float(amp_gold_mult_level) * 0.5


func get_amp_gold_mult_b_val() -> float:
	return 1.0 + float(amp_gold_mult_b_level) * 0.5


func get_amp_gold_pow_val() -> float:
	return 1.0 + float(amp_gold_pow_level) * 0.05


func get_amp_gold_total_mult() -> float:
	var base_v := get_amp_gold_base_val()
	var mult_a_v := get_amp_gold_mult_val()
	var mult_b_v := get_amp_gold_mult_b_val()
	var pow_v := get_amp_gold_pow_val()
	return base_v * pow(mult_a_v * mult_b_v, pow_v)


func get_amp_token_base_val() -> float:
	if not amp_token_base_unlocked:
		return 1.0
	if gold <= 1.0:
		return 1.0
	return maxf(1.0, log(gold) / log(10.0))


func get_amp_token_mult_val() -> float:
	return 1.0 + float(amp_token_mult_level) * 0.5


func get_amp_token_mult_b_val() -> float:
	return 1.0 + float(amp_token_mult_b_level) * 0.5


func get_amp_token_pow_val() -> float:
	return 1.0 + float(amp_token_pow_level) * 0.05


func get_amp_token_total_mult() -> float:
	var base_v := get_amp_token_base_val()
	var mult_a_v := get_amp_token_mult_val()
	var mult_b_v := get_amp_token_mult_b_val()
	var pow_v := get_amp_token_pow_val()
	return base_v * pow(mult_a_v * mult_b_v, pow_v)


func update_amplifier_cache() -> void:
	_cached_gold_amp_mult = get_amp_gold_total_mult()
	_cached_token_amp_mult = get_amp_token_total_mult()


func _calc_geometric_cost(base: float, growth: float, current_level: int, count: int, saving_mult: float) -> float:
	if count <= 0:
		return 0.0
	var first_cost := base * pow(growth, float(current_level)) * saving_mult
	if count == 1:
		return first_cost
	if is_equal_approx(growth, 1.0):
		return first_cost * float(count)
	return first_cost * (pow(growth, float(count)) - 1.0) / (growth - 1.0)


func _calc_geometric_max_count(base: float, growth: float, current_level: int, currency: float, saving_mult: float) -> int:
	var first_cost := base * pow(growth, float(current_level)) * saving_mult
	if currency < first_cost:
		return 0
	if is_equal_approx(growth, 1.0):
		return int(currency / first_cost)
	var term := 1.0 + currency * (growth - 1.0) / first_cost
	if term <= 1.0:
		return 0
	var n := int(floor(log(term) / log(growth)))
	var actual_cost := _calc_geometric_cost(base, growth, current_level, n, saving_mult)
	if actual_cost > currency and n > 0:
		n -= 1
	elif n >= 0:
		var next_cost := _calc_geometric_cost(base, growth, current_level, n + 1, saving_mult)
		if next_cost <= currency:
			n += 1
	return maxi(0, n)


func get_amp_gold_mult_cost(count: int = 1) -> float:
	return _calc_geometric_cost(20.0, 1.6, amp_gold_mult_level, count, get_equipped_token_saving_cost_multiplier())


func get_amp_gold_mult_max_count() -> int:
	return _calc_geometric_max_count(20.0, 1.6, amp_gold_mult_level, tokens, get_equipped_token_saving_cost_multiplier())


func get_amp_gold_mult_b_cost(count: int = 1) -> float:
	return _calc_geometric_cost(100.0, 1.8, amp_gold_mult_b_level, count, get_equipped_token_saving_cost_multiplier())


func get_amp_gold_mult_b_max_count() -> int:
	return _calc_geometric_max_count(100.0, 1.8, amp_gold_mult_b_level, tokens, get_equipped_token_saving_cost_multiplier())


func get_amp_gold_pow_cost(count: int = 1) -> float:
	return _calc_geometric_cost(500.0, 4.0, amp_gold_pow_level, count, get_equipped_token_saving_cost_multiplier())


func get_amp_gold_pow_max_count() -> int:
	return _calc_geometric_max_count(500.0, 4.0, amp_gold_pow_level, tokens, get_equipped_token_saving_cost_multiplier())


func get_amp_token_mult_cost(count: int = 1) -> float:
	return _calc_geometric_cost(100.0, 1.6, amp_token_mult_level, count, get_equipped_saving_cost_multiplier())


func get_amp_token_mult_max_count() -> int:
	return _calc_geometric_max_count(100.0, 1.6, amp_token_mult_level, gold, get_equipped_saving_cost_multiplier())


func get_amp_token_mult_b_cost(count: int = 1) -> float:
	return _calc_geometric_cost(500.0, 1.8, amp_token_mult_b_level, count, get_equipped_saving_cost_multiplier())


func get_amp_token_mult_b_max_count() -> int:
	return _calc_geometric_max_count(500.0, 1.8, amp_token_mult_b_level, gold, get_equipped_saving_cost_multiplier())


func get_amp_token_pow_cost(count: int = 1) -> float:
	return _calc_geometric_cost(5000.0, 4.0, amp_token_pow_level, count, get_equipped_saving_cost_multiplier())


func get_amp_token_pow_max_count() -> int:
	return _calc_geometric_max_count(5000.0, 4.0, amp_token_pow_level, gold, get_equipped_saving_cost_multiplier())


func buy_amp_gold_base_unlock() -> bool:
	if amp_gold_base_unlocked:
		return false
	if use_tokens(AMP_GOLD_BASE_UNLOCK_COST):
		amp_gold_base_unlocked = true
		update_amplifier_cache()
		amplifier_changed.emit()
		return true
	return false


func buy_amp_gold_mult(count: int = 1) -> bool:
	if count <= 0:
		return false
	var cost := get_amp_gold_mult_cost(count)
	if use_tokens(cost):
		amp_gold_mult_level += count
		update_amplifier_cache()
		amplifier_changed.emit()
		return true
	return false


func buy_amp_gold_mult_b(count: int = 1) -> bool:
	if count <= 0:
		return false
	var cost := get_amp_gold_mult_b_cost(count)
	if use_tokens(cost):
		amp_gold_mult_b_level += count
		update_amplifier_cache()
		amplifier_changed.emit()
		return true
	return false


func buy_amp_gold_pow(count: int = 1) -> bool:
	if count <= 0:
		return false
	var cost := get_amp_gold_pow_cost(count)
	if use_tokens(cost):
		amp_gold_pow_level += count
		update_amplifier_cache()
		amplifier_changed.emit()
		return true
	return false


func buy_amp_token_base_unlock() -> bool:
	if amp_token_base_unlocked:
		return false
	if use_gold(AMP_TOKEN_BASE_UNLOCK_COST):
		amp_token_base_unlocked = true
		update_amplifier_cache()
		amplifier_changed.emit()
		return true
	return false


func buy_amp_token_mult(count: int = 1) -> bool:
	if count <= 0:
		return false
	var cost := get_amp_token_mult_cost(count)
	if use_gold(cost):
		amp_token_mult_level += count
		update_amplifier_cache()
		amplifier_changed.emit()
		return true
	return false


func buy_amp_token_mult_b(count: int = 1) -> bool:
	if count <= 0:
		return false
	var cost := get_amp_token_mult_b_cost(count)
	if use_gold(cost):
		amp_token_mult_b_level += count
		update_amplifier_cache()
		amplifier_changed.emit()
		return true
	return false


func buy_amp_token_pow(count: int = 1) -> bool:
	if count <= 0:
		return false
	var cost := get_amp_token_pow_cost(count)
	if use_gold(cost):
		amp_token_pow_level += count
		update_amplifier_cache()
		amplifier_changed.emit()
		return true
	return false


# ==============================================================================
# セーブ＆ロード＆リセット機能 (Save / Load / Reset System)
# ==============================================================================

const SAVE_DATA_PATH = "user://save_data.json"


func has_save_data() -> bool:
	return FileAccess.file_exists(SAVE_DATA_PATH)


func save_game() -> bool:
	var save_dict: Dictionary = {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		# 通貨・統計
		"gold": gold,
		"tokens": tokens,
		"stars": stars,
		"infused_tokens": infused_tokens,
		"is_infusing_tokens": is_infusing_tokens,
		"star_level": star_level,
		"reincarnation_level": reincarnation_level,
		"stars_spent_in_current_cycle": stars_spent_in_current_cycle,
		"total_bounces": total_bounces,
		"corner_hits": corner_hits,
		"total_play_time": total_play_time,
		# 基礎強化
		"logo_count": logo_count,
		"speed_level": speed_level,
		"boost_level": boost_level,
		"size_level": size_level,
		"ascension_level": ascension_level,
		# スキルツリー・転生スキル
		"skill_levels": skill_levels,
		"permanently_unlocked_skills": permanently_unlocked_skills,
		"active_reincarnation_skills": active_reincarnation_skills,
		"pending_reincarnation_skills": pending_reincarnation_skills,
		"active_reincarnation_upgrades": active_reincarnation_upgrades,
		"pending_reincarnation_upgrades": pending_reincarnation_upgrades,
		# 特殊スキル状態
		"accumulation_rank": accumulation_rank,
		"accumulation_bounces_in_rank": accumulation_bounces_in_rank,
		"trinity_sacrificed_stat": trinity_sacrificed_stat,
		"gamble_current_slot": gamble_current_slot,
		"gamble_current_multiplier": gamble_current_multiplier,
		"switch_sacrificed_type": switch_sacrificed_type,
		# 装備 & インベントリ
		"equipped_items": equipped_items,
		"inventories": inventories,
		"unlocked_slots": unlocked_slots,
		# チャレンジ
		"challenge_cleared": challenge_cleared,
		"challenge_cleared_levels": challenge_cleared_levels,
		# 増幅器
		"amp_gold_base_unlocked": amp_gold_base_unlocked,
		"amp_gold_mult_level": amp_gold_mult_level,
		"amp_gold_mult_b_level": amp_gold_mult_b_level,
		"amp_gold_pow_level": amp_gold_pow_level,
		"amp_token_base_unlocked": amp_token_base_unlocked,
		"amp_token_mult_level": amp_token_mult_level,
		"amp_token_mult_b_level": amp_token_mult_b_level,
		"amp_token_pow_level": amp_token_pow_level
	}

	var json_str := JSON.stringify(save_dict, "\t")
	var file := FileAccess.open(SAVE_DATA_PATH, FileAccess.WRITE)
	if not file:
		printerr("セーブデータの保存に失敗しました: ", SAVE_DATA_PATH)
		game_saved.emit(false)
		return false

	file.store_string(json_str)
	file.close()
	print("セーブ完了: ", SAVE_DATA_PATH)
	game_saved.emit(true)
	return true


func load_game() -> bool:
	if not has_save_data():
		print("セーブデータが見つかりません: ", SAVE_DATA_PATH)
		game_loaded.emit(false)
		return false

	var file := FileAccess.open(SAVE_DATA_PATH, FileAccess.READ)
	if not file:
		printerr("セーブデータのオープンに失敗しました: ", SAVE_DATA_PATH)
		game_loaded.emit(false)
		return false

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		printerr("セーブデータのJSONパースに失敗しました: ", json.get_error_message())
		game_loaded.emit(false)
		return false

	var data: Variant = json.get_data()
	if not data is Dictionary:
		printerr("セーブデータが辞書形式ではありません")
		game_loaded.emit(false)
		return false

	# 1. 通貨・統計
	gold = float(data.get("gold", 0.0))
	tokens = float(data.get("tokens", 0.0))
	stars = int(data.get("stars", 0))
	infused_tokens = float(data.get("infused_tokens", 0.0))
	is_infusing_tokens = bool(data.get("is_infusing_tokens", false))
	star_level = int(data.get("star_level", 0))
	reincarnation_level = int(data.get("reincarnation_level", 0))
	stars_spent_in_current_cycle = int(data.get("stars_spent_in_current_cycle", 0))
	total_bounces = int(data.get("total_bounces", 0))
	corner_hits = int(data.get("corner_hits", 0))
	total_play_time = float(data.get("total_play_time", 0.0))

	# 2. 基礎強化
	logo_count = maxi(1, int(data.get("logo_count", 1)))
	speed_level = int(data.get("speed_level", 1))
	boost_level = int(data.get("boost_level", 1))
	size_level = int(data.get("size_level", 1))
	ascension_level = int(data.get("ascension_level", 0))

	# 3. スキルツリー・転生スキル（マスターデータと照合して安全にロード）
	var raw_skill_levels = data.get("skill_levels", {})
	if raw_skill_levels is Dictionary:
		skill_levels.clear()
		for sk_id in raw_skill_levels:
			var lvl: int = int(raw_skill_levels[sk_id])
			if skill_max_levels.has(sk_id):
				lvl = clampi(lvl, 0, skill_max_levels[sk_id])
			skill_levels[sk_id] = lvl
		if not skill_levels.has("root_node"):
			skill_levels["root_node"] = 1

	var raw_permanently = data.get("permanently_unlocked_skills", {})
	if raw_permanently is Dictionary:
		permanently_unlocked_skills = raw_permanently.duplicate()
		permanently_unlocked_skills["root_node"] = true

	var raw_active_reinc_skills = data.get("active_reincarnation_skills", {})
	if raw_active_reinc_skills is Dictionary:
		active_reincarnation_skills = raw_active_reinc_skills.duplicate()
		active_reincarnation_skills["tree_node_root"] = true

	var raw_pending_reinc_skills = data.get("pending_reincarnation_skills", {})
	if raw_pending_reinc_skills is Dictionary:
		pending_reincarnation_skills = raw_pending_reinc_skills.duplicate()

	var raw_active_reinc_upgrades = data.get("active_reincarnation_upgrades", {})
	if raw_active_reinc_upgrades is Dictionary:
		active_reincarnation_upgrades = raw_active_reinc_upgrades.duplicate()

	var raw_pending_reinc_upgrades = data.get("pending_reincarnation_upgrades", {})
	if raw_pending_reinc_upgrades is Dictionary:
		pending_reincarnation_upgrades = raw_pending_reinc_upgrades.duplicate()

	# 4. 特殊スキル
	accumulation_rank = int(data.get("accumulation_rank", 0))
	accumulation_bounces_in_rank = int(data.get("accumulation_bounces_in_rank", 0))
	trinity_sacrificed_stat = str(data.get("trinity_sacrificed_stat", "none"))
	gamble_current_slot = int(data.get("gamble_current_slot", 0))
	gamble_current_multiplier = float(data.get("gamble_current_multiplier", 1.0))
	switch_sacrificed_type = str(data.get("switch_sacrificed_type", "none"))

	# 5. 装備 & インベントリ
	var raw_eq = data.get("equipped_items", {})
	if raw_eq is Dictionary:
		equipped_items = raw_eq.duplicate(true)
	var raw_inv = data.get("inventories", {})
	if raw_inv is Dictionary:
		inventories = raw_inv.duplicate(true)
	var raw_slots = data.get("unlocked_slots", {})
	if raw_slots is Dictionary:
		unlocked_slots = raw_slots.duplicate(true)
	_ensure_inventory_sizes()

	# 6. チャレンジ
	var raw_cleared = data.get("challenge_cleared", {})
	if raw_cleared is Dictionary:
		challenge_cleared = raw_cleared.duplicate(true)
	var raw_cleared_lvls = data.get("challenge_cleared_levels", {})
	if raw_cleared_lvls is Dictionary:
		challenge_cleared_levels = raw_cleared_lvls.duplicate(true)

	# 7. 増幅器
	amp_gold_base_unlocked = bool(data.get("amp_gold_base_unlocked", false))
	amp_gold_mult_level = int(data.get("amp_gold_mult_level", 0))
	amp_gold_mult_b_level = int(data.get("amp_gold_mult_b_level", 0))
	amp_gold_pow_level = int(data.get("amp_gold_pow_level", 0))
	amp_token_base_unlocked = bool(data.get("amp_token_base_unlocked", false))
	amp_token_mult_level = int(data.get("amp_token_mult_level", 0))
	amp_token_mult_b_level = int(data.get("amp_token_mult_b_level", 0))
	amp_token_pow_level = int(data.get("amp_token_pow_level", 0))

	# 8. 各種キャッシュの再計算 & シグナル通知
	_recalculate_all_cumulative_levels()
	_recalculate_equipped_skill_levels()
	_recalculate_cached_multipliers()
	update_amplifier_cache()

	gold_changed.emit(gold)
	tokens_changed.emit(tokens)
	stars_changed.emit(stars)
	stats_changed.emit()
	upgrades_changed.emit()
	equipment_changed.emit()
	inventory_updated.emit()
	amplifier_changed.emit()
	challenge_state_changed.emit()
	logo_reset_requested.emit()

	print("ロード完了: ", SAVE_DATA_PATH)
	game_loaded.emit(true)
	return true


func delete_save_data() -> bool:
	if has_save_data():
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("save_data.json")
	reset_all_data()
	game_reset.emit()
	return true


func reset_all_data() -> void:
	gold = 0.0
	tokens = 0.0
	stars = 0
	infused_tokens = 0.0
	is_infusing_tokens = false
	star_level = 0
	reincarnation_level = 0
	stars_spent_in_current_cycle = 0
	total_bounces = 0
	corner_hits = 0
	total_play_time = 0.0

	logo_count = 1
	speed_level = 1
	boost_level = 1
	size_level = 1
	ascension_level = 0

	skill_levels = {"root_node": 1}
	permanently_unlocked_skills = {"root_node": true}
	active_reincarnation_skills = {"tree_node_root": true}
	pending_reincarnation_skills.clear()
	active_reincarnation_upgrades.clear()
	pending_reincarnation_upgrades.clear()

	accumulation_rank = 0
	accumulation_bounces_in_rank = 0
	trinity_sacrificed_stat = "none"
	gamble_current_slot = 0
	gamble_current_multiplier = 1.0
	switch_sacrificed_type = "none"

	for slot_key in equipped_items:
		equipped_items[slot_key] = null
	for type in ["main", "sub", "accessory"]:
		inventories[type] = []
	unlocked_slots = {
		"main": true,
		"sub": true,
		"accessory_1": true,
		"accessory_2": false,
		"accessory_3": false,
		"accessory_4": false
	}
	_ensure_inventory_sizes()

	challenge_cleared.clear()
	challenge_cleared_levels.clear()
	if not active_challenge_id.is_empty():
		cancel_challenge()

	amp_gold_base_unlocked = false
	amp_gold_mult_level = 0
	amp_gold_mult_b_level = 0
	amp_gold_pow_level = 0
	amp_token_base_unlocked = false
	amp_token_mult_level = 0
	amp_token_mult_b_level = 0
	amp_token_pow_level = 0

	apply_auto_unlocked_skills()
	_recalculate_all_cumulative_levels()
	_recalculate_equipped_skill_levels()
	_recalculate_cached_multipliers()
	update_amplifier_cache()

	gold_changed.emit(gold)
	tokens_changed.emit(tokens)
	stars_changed.emit(stars)
	stats_changed.emit()
	upgrades_changed.emit()
	equipment_changed.emit()
	inventory_updated.emit()
	amplifier_changed.emit()
	challenge_state_changed.emit()
	logo_reset_requested.emit()
