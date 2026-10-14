class_name BlacksmithWindow
extends BaseWindow
## Window controller for Blacksmith (鍛冶) feature.

const SLOT_SIZE := Vector2(64, 64)
const MAX_MATERIALS := 9

@onready var type_option_button: OptionButton = %TypeOptionButton
@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var material_grid: GridContainer = %MaterialGrid
@onready var preview_icon_container: CenterContainer = %PreviewIconContainer
@onready var btn_forge: Button = %ForgeButton
@onready var candidate_title_label: Label = %CandidateTitleLabel
@onready var skill_list_container: VBoxContainer = %SkillListContainer

# 選択中の装備タイプ: "main", "sub", "accessory"
var current_type: String = "main"

# 3×3投入枠データ: slot_index -> { "item": Dictionary, "inv_index": int }
var placed_materials: Dictionary = {}

var _preview_equipment_icon: EquipmentIcon = null
var _preview_timer: Timer = null
var _candidate_combinations: Array[Dictionary] = []
var _last_displayed_combination: Dictionary = {}
var _current_target_forge_count: int = 0


func _ready() -> void:
	super._ready()
	_setup_ui()
	GameData.equipment_changed.connect(_on_equipment_changed)
	GameData.inventory_updated.connect(_on_equipment_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			_on_equipment_changed()
		else:
			if _preview_timer and _preview_timer.is_inside_tree():
				_preview_timer.stop()
			if btn_forge:
				btn_forge.modulate = Color.WHITE


func _process(_delta: float) -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return

	# 合成ボタン: 押下可能な状態 (disabled == false) のときに転生トークン注入のように明滅
	if btn_forge:
		if not btn_forge.disabled:
			var t: float = float(Time.get_ticks_msec()) * 0.0022
			var pulse: float = 0.5 + 0.5 * sin(t)
			var glow: Color = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(1.5, 1.3, 1.8, 1.0), pulse)
			btn_forge.modulate = glow
		else:
			btn_forge.modulate = Color.WHITE


func _setup_ui() -> void:
	# 種類選択プルダウンの設定
	if type_option_button:
		type_option_button.clear()
		type_option_button.add_item("メイン", 0)
		type_option_button.add_item("サブ", 1)
		type_option_button.add_item("アクセサリー", 2)
		type_option_button.item_selected.connect(_on_type_selected)

	# プレビューアイコンの初期化（初期状態はダミーアイコン: ??? / ? / コモン / +0なし）
	if preview_icon_container:
		var eq_icon_scene := preload("res://scenes/ui/equipment_icon.tscn")
		_preview_equipment_icon = eq_icon_scene.instantiate() as EquipmentIcon
		preview_icon_container.add_child(_preview_equipment_icon)
		_preview_equipment_icon.update_item({
			"show_question": true,
			"level_str": "Lv???",
			"rarity": "コモン",
			"forge_count": 0
		})

	# ルーレット演出用タイマー（1秒に約2回 = 0.5秒間隔で同期）
	_preview_timer = Timer.new()
	_preview_timer.wait_time = 0.5
	_preview_timer.autostart = false
	_preview_timer.one_shot = false
	_preview_timer.timeout.connect(_on_roulette_tick)
	add_child(_preview_timer)

	# 3×3素材投入枠の生成
	_init_material_slots()

	# 合成ボタン
	if btn_forge:
		btn_forge.pressed.connect(_on_forge_pressed)
		_style_forge_button()

	# 初期描画
	update_all()


func _style_forge_button() -> void:
	if not btn_forge:
		return
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.7, 0.25, 0.1, 1) # 鍛冶の炎色・赤橙
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.95, 0.45, 0.2, 1)
	style_normal.set_corner_radius_all(6)

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.85, 0.35, 0.15, 1)
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(1.0, 0.6, 0.3, 1)
	style_hover.set_corner_radius_all(6)

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.5, 0.15, 0.05, 1)
	style_pressed.border_width_left = 2
	style_pressed.border_width_top = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_bottom = 2
	style_pressed.border_color = Color(0.8, 0.3, 0.1, 1)
	style_pressed.set_corner_radius_all(6)

	var style_disabled := StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.18, 0.12, 0.12, 0.8)
	style_disabled.border_width_left = 1
	style_disabled.border_width_top = 1
	style_disabled.border_width_right = 1
	style_disabled.border_width_bottom = 1
	style_disabled.border_color = Color(0.3, 0.2, 0.2, 0.8)
	style_disabled.set_corner_radius_all(6)

	btn_forge.add_theme_stylebox_override("normal", style_normal)
	btn_forge.add_theme_stylebox_override("hover", style_hover)
	btn_forge.add_theme_stylebox_override("pressed", style_pressed)
	btn_forge.add_theme_stylebox_override("disabled", style_disabled)


func _on_type_selected(index: int) -> void:
	match index:
		0:
			current_type = "main"
		1:
			current_type = "sub"
		2:
			current_type = "accessory"
	# 種類が変更された場合、投入中の素材はクリアする
	placed_materials.clear()
	_last_displayed_combination.clear()
	update_all()


func update_all() -> void:
	_update_inventory_grid()
	_update_material_slots()
	_update_preview_and_candidates()


func _on_equipment_changed() -> void:
	if not is_visible_in_tree():
		return
	# 投入中の素材がインベントリから消えていたり変化していないか検証
	var inv: Array = GameData.inventories.get(current_type, [])
	var keys_to_remove: Array[int] = []
	var item_modified: bool = false
	for slot_idx in placed_materials:
		var entry: Dictionary = placed_materials[slot_idx]
		var inv_idx: int = entry.get("inv_index", -1)
		if inv_idx < 0 or inv_idx >= inv.size() or inv[inv_idx] == null:
			keys_to_remove.append(slot_idx)
		else:
			var curr_item = inv[inv_idx]
			if curr_item.get("id") != entry["item"].get("id"):
				keys_to_remove.append(slot_idx)
			elif curr_item != entry["item"]:
				entry["item"] = curr_item
				item_modified = true

	for k in keys_to_remove:
		placed_materials.erase(k)

	_update_inventory_grid()

	# 素材枠や結果プレビューは、投入中の素材に実際に変動があった場合のみ再更新する
	# （新たな装備をドロップ入手した等の通常のインベントリ更新ではプレビュー・ルーレットをリセット・再発火させない）
	if not keys_to_remove.is_empty() or item_modified:
		_update_material_slots()
		_update_preview_and_candidates()


# --- 左側: 5×10 インベントリグリッド ---

func _update_inventory_grid() -> void:
	if not inventory_grid:
		return

	var inv: Array = GameData.inventories.get(current_type, [])
	var placed_inv_indices := get_placed_inventory_indices()

	# 枠数が50未満なら生成
	if inventory_grid.get_child_count() < GameData.MAX_TYPE_INVENTORY_SIZE:
		for child in inventory_grid.get_children():
			inventory_grid.remove_child(child)
			child.queue_free()
		for i in range(GameData.MAX_TYPE_INVENTORY_SIZE):
			var slot_node := BlacksmithInventorySlot.new()
			slot_node.setup(self, current_type, i)
			inventory_grid.add_child(slot_node)

	for i in range(GameData.MAX_TYPE_INVENTORY_SIZE):
		var slot_node = inventory_grid.get_child(i) as BlacksmithInventorySlot
		if slot_node:
			var item_data = inv[i] if i < inv.size() else null
			var is_placed := placed_inv_indices.has(i)
			slot_node.update_slot(current_type, i, item_data, is_placed)


func get_placed_inventory_indices() -> Array[int]:
	var result: Array[int] = []
	for slot_idx in placed_materials:
		result.append(placed_materials[slot_idx]["inv_index"])
	return result


# --- 右側: 3×3 素材投入枠 ---

func _init_material_slots() -> void:
	if not material_grid:
		return
	for child in material_grid.get_children():
		material_grid.remove_child(child)
		child.queue_free()

	for i in range(MAX_MATERIALS):
		var mat_slot := ForgeMaterialSlot.new()
		mat_slot.setup(self, i)
		material_grid.add_child(mat_slot)


func _update_material_slots() -> void:
	if not material_grid:
		return
	for i in range(MAX_MATERIALS):
		var mat_slot = material_grid.get_child(i) as ForgeMaterialSlot
		if mat_slot:
			var entry = placed_materials.get(i, null)
			mat_slot.update_display(entry)


## 素材投入枠へアイテムを配置する
func place_material(slot_idx: int, inv_idx: int) -> bool:
	var inv: Array = GameData.inventories.get(current_type, [])
	if inv_idx < 0 or inv_idx >= inv.size() or inv[inv_idx] == null:
		return false

	var item_to_place: Dictionary = inv[inv_idx]
	if item_to_place.get("type", "") != current_type:
		return false

	# 既にいずれかの3×3スロットに同じインベントリ位置のアイテムが入っているかチェック
	for s in placed_materials:
		if placed_materials[s]["inv_index"] == inv_idx and s != slot_idx:
			return false

	# 鍛冶回数の一致チェック
	var target_forge_count: int = item_to_place.get("forge_count", 0)
	for s in placed_materials:
		if s == slot_idx:
			continue
		var existing_fc: int = placed_materials[s]["item"].get("forge_count", 0)
		if existing_fc != target_forge_count:
			return false

	placed_materials[slot_idx] = {
		"item": item_to_place,
		"inv_index": inv_idx
	}

	update_all()
	return true


## 素材投入枠からアイテムを取り出す
func remove_material(slot_idx: int) -> void:
	if placed_materials.has(slot_idx):
		placed_materials.erase(slot_idx)
		update_all()


## 空いている最初の投入スロットインデックスを取得
func get_first_empty_material_slot() -> int:
	for i in range(MAX_MATERIALS):
		if not placed_materials.has(i):
			return i
	return -1


# --- プレビュー＆候補スキル一覧 ---

func _update_preview_and_candidates() -> void:
	var materials: Array = []
	for slot_idx in placed_materials:
		materials.append(placed_materials[slot_idx]["item"])

	var preview := GameData.calculate_forge_preview(materials)
	var can_forge: bool = preview.get("can_forge", false)

	if btn_forge:
		btn_forge.disabled = not can_forge
		if btn_forge.disabled:
			btn_forge.modulate = Color.WHITE

	# 結果プレビューアイコン
	if materials.is_empty():
		if _preview_timer and _preview_timer.is_inside_tree():
			_preview_timer.stop()
		_candidate_combinations.clear()
		_last_displayed_combination.clear()
		_current_target_forge_count = 0

		if _preview_equipment_icon:
			_preview_equipment_icon.update_item({
				"show_question": true,
				"level_str": "Lv???",
				"rarity": "コモン",
				"forge_count": 0
			})
			_preview_equipment_icon.visible = true
	elif materials.size() == 1:
		var single_mat: Dictionary = materials[0]
		var single_lvl: int = single_mat.get("level", 1)
		var single_rar: String = single_mat.get("rarity", "コモン")
		var new_combs: Array[Dictionary] = [{"level": single_lvl, "rarity": single_rar}]
		_current_target_forge_count = single_mat.get("forge_count", 0) + 1

		if not _are_combinations_equal(_candidate_combinations, new_combs):
			_candidate_combinations = new_combs
			_last_displayed_combination = new_combs[0]
			if _preview_equipment_icon:
				_preview_equipment_icon.update_item({
					"show_question": true,
					"level": single_lvl,
					"rarity": single_rar,
					"forge_count": _current_target_forge_count
				})
				_preview_equipment_icon.visible = true

		if _preview_timer and _preview_timer.is_inside_tree() and not _preview_timer.is_stopped():
			_preview_timer.stop()
	else:
		var cand_levels: Array[int] = []
		for m in materials:
			var lvl: int = m.get("level", 1)
			if not cand_levels.has(lvl):
				cand_levels.append(lvl)

		var probs: Dictionary = preview.get("rarity_probs", {})
		var cand_rarities: Array[String] = []
		for r_name in probs.keys():
			cand_rarities.append(r_name)
		if cand_rarities.is_empty():
			cand_rarities.append("コモン")

		# レベル × レア度背景の全組み合わせを生成
		var new_combs: Array[Dictionary] = []
		for lvl in cand_levels:
			for rar in cand_rarities:
				new_combs.append({"level": lvl, "rarity": rar})
		_current_target_forge_count = preview.get("forge_count", 1)

		var combs_changed: bool = not _are_combinations_equal(_candidate_combinations, new_combs)
		if combs_changed:
			_candidate_combinations = new_combs
			_on_roulette_tick()

		if _candidate_combinations.size() > 1:
			if _preview_timer and _preview_timer.is_inside_tree() and _preview_timer.is_stopped():
				_preview_timer.start()
		else:
			if _preview_timer and _preview_timer.is_inside_tree() and not _preview_timer.is_stopped():
				_preview_timer.stop()

	# 候補スキル一覧リスト
	if candidate_title_label:
		candidate_title_label.text = "候補スキル一覧"
		candidate_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if skill_list_container:
		for child in skill_list_container.get_children():
			skill_list_container.remove_child(child)
			child.queue_free()

		var skills: Array = preview.get("skills", [])
		if skills.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = "素材が投入されると、合算された候補スキルが表示されます。"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.80, 0.9))
			empty_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			empty_lbl.add_theme_constant_override("shadow_offset_x", 1)
			empty_lbl.add_theme_constant_override("shadow_offset_y", 1)
			empty_lbl.add_theme_font_size_override("font_size", 18)
			skill_list_container.add_child(empty_lbl)
		else:
			for sk in skills:
				var row := _create_skill_candidate_row(sk)
				skill_list_container.add_child(row)


func _are_combinations_equal(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for item_a in a:
		var found := false
		for item_b in b:
			if item_a.get("level") == item_b.get("level") and item_a.get("rarity") == item_b.get("rarity"):
				found = true
				break
		if not found:
			return false
	return true


func _on_roulette_tick() -> void:
	if _candidate_combinations.is_empty():
		return

	var chosen: Dictionary = {}
	if _candidate_combinations.size() == 1:
		chosen = _candidate_combinations[0]
	else:
		# 同じ (レベル × レア度背景) の組み合わせが連続しないようにフィルタリング
		var options: Array[Dictionary] = []
		for comb in _candidate_combinations:
			if _last_displayed_combination.is_empty():
				options.append(comb)
			elif comb.get("level") != _last_displayed_combination.get("level") or comb.get("rarity") != _last_displayed_combination.get("rarity"):
				options.append(comb)

		if options.is_empty():
			options = _candidate_combinations

		chosen = options[randi() % options.size()]

	_last_displayed_combination = chosen

	if _preview_equipment_icon:
		_preview_equipment_icon.update_item({
			"show_question": true,
			"level": chosen.get("level", 1),
			"rarity": chosen.get("rarity", "コモン"),
			"forge_count": _current_target_forge_count
		})
		_preview_equipment_icon.visible = true


func _create_skill_candidate_row(sk: Dictionary) -> Control:
	var is_spec: bool = sk.get("is_special", false)

	var lbl := Label.new()
	var sk_name: String = sk.get("name", "")
	var sk_lvl: int = sk.get("level", 1)
	lbl.text = "◆ %s  Lv.%d" % [sk_name, sk_lvl]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	var desc: String = sk.get("desc", "")
	if not desc.is_empty():
		lbl.tooltip_text = desc
	if is_spec:
		lbl.add_theme_color_override("font_color", GameData.special_skill_color)
	else:
		lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 0.95))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_font_size_override("font_size", 20)

	return lbl


# --- 合成ボタン押下時 ---

func _on_forge_pressed() -> void:
	var mat_indices: Array[int] = []
	for slot_idx in placed_materials:
		mat_indices.append(placed_materials[slot_idx]["inv_index"])

	if mat_indices.size() < 2:
		return

	# 合成実行
	var result_item := GameData.forge_equipment(current_type, mat_indices)
	if not result_item.is_empty():
		placed_materials.clear()
		_last_displayed_combination.clear()
		update_all()
		# HUD等のログ表示またはポップアップがあれば発火
		var hud = get_tree().root.find_child("HUD", true, false)
		if hud and hud.has_method("show_equipment_drop_pop"):
			hud.show_equipment_drop_pop(result_item)


# ==============================================================================
# 内部クラス: 鍛冶用インベントリスロット (5×10)
# ==============================================================================
class BlacksmithInventorySlot extends Control:
	var parent_wnd: BlacksmithWindow = null
	var slot_type: String = ""
	var slot_index: int = -1
	var current_item_id: String = ""
	var child_item_ui: InventoryItemUI = null
	var child_empty_btn: Button = null
	var overlay_locked_panel: Panel = null

	func setup(p_wnd: BlacksmithWindow, p_type: String, p_index: int) -> void:
		parent_wnd = p_wnd
		slot_type = p_type
		slot_index = p_index
		custom_minimum_size = Vector2(64, 64)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func update_slot(p_type: String, p_index: int, item_data: Variant, is_placed_in_forge: bool) -> void:
		slot_type = p_type
		slot_index = p_index

		if item_data == null or not item_data is Dictionary or item_data.is_empty():
			if current_item_id == "" and child_empty_btn != null:
				return
			_clear_children()
			current_item_id = ""

			child_empty_btn = Button.new()
			child_empty_btn.custom_minimum_size = Vector2(64, 64)
			var style_empty := StyleBoxFlat.new()
			style_empty.bg_color = Color(0.05, 0.05, 0.08, 0.6)
			style_empty.border_width_left = 3
			style_empty.border_width_top = 3
			style_empty.border_width_right = 3
			style_empty.border_width_bottom = 3
			style_empty.border_color = Color(0.0, 0.0, 0.0, 1.0)
			style_empty.corner_radius_top_left = 6
			style_empty.corner_radius_top_right = 6
			style_empty.corner_radius_bottom_right = 6
			style_empty.corner_radius_bottom_left = 6
			child_empty_btn.add_theme_stylebox_override("normal", style_empty)
			child_empty_btn.add_theme_stylebox_override("hover", style_empty)
			child_empty_btn.add_theme_stylebox_override("pressed", style_empty)
			child_empty_btn.add_theme_stylebox_override("disabled", style_empty)
			add_child(child_empty_btn)
		else:
			var new_id: String = item_data.get("id", "")
			if current_item_id != new_id or child_item_ui == null:
				_clear_children()
				current_item_id = new_id

				var item_scene := preload("res://scenes/ui/inventory_item_ui.tscn")
				child_item_ui = item_scene.instantiate() as InventoryItemUI
				add_child(child_item_ui)
				child_item_ui.setup(item_data)
			else:
				child_item_ui.setup(item_data)

			# 3×3投入中なら半透明＆ロック
			if is_placed_in_forge:
				child_item_ui.modulate = Color(0.4, 0.4, 0.4, 0.5)
			else:
				child_item_ui.modulate = Color(1.0, 1.0, 1.0, 1.0)

	func _clear_children() -> void:
		for child in get_children():
			remove_child(child)
			child.queue_free()
		child_item_ui = null
		child_empty_btn = null

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not data is Dictionary:
			return false
		# 鍛冶投入枠（from_forge_slot）からの取り出しドロップも受け入れ可能
		if data.has("from_forge_slot"):
			return true
		return data.get("type", "") == slot_type

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not data is Dictionary:
			return
		if data.has("from_forge_slot"):
			var forge_slot: int = data.get("forge_slot", -1)
			if parent_wnd and forge_slot >= 0:
				parent_wnd.remove_material(forge_slot)
			return

		if data.has("item_index"):
			var from_index: int = data.get("item_index", -1)
			GameData.swap_inventory_items(slot_type, from_index, slot_index)
		elif data.has("from_slot"):
			var from_slot_key: String = data.get("slot_key", "")
			GameData.unequip_item_to_index(from_slot_key, slot_index)


# ==============================================================================
# 内部クラス: 3×3 素材投入スロット
# ==============================================================================
class ForgeMaterialSlot extends Control:
	var parent_wnd: BlacksmithWindow = null
	var slot_index: int = -1
	var placed_entry: Variant = null
	var slot_panel: Panel = null
	var icon_node: EquipmentIcon = null
	var grid_overlay: Panel = null
	var _custom_tooltip: EquipmentTooltip = null

	func setup(p_wnd: BlacksmithWindow, p_index: int) -> void:
		parent_wnd = p_wnd
		slot_index = p_index
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_STOP

		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		tree_exited.connect(_on_mouse_exited)
		set_process(false)

		# 1. スロット背景パネル（空スロット時の背景）
		slot_panel = Panel.new()
		slot_panel.custom_minimum_size = Vector2(64, 64)
		slot_panel.anchors_preset = Control.PRESET_FULL_RECT
		slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.04, 0.07, 0.95) # 合成プレビュー背景と同色
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.65, 0.38, 0.18, 0.9) # 合成プレビュー枠と同色
		style.set_corner_radius_all(6)
		slot_panel.add_theme_stylebox_override("panel", style)
		add_child(slot_panel)

		# 2. 装備アイテムアイコン
		var icon_scene := preload("res://scenes/ui/equipment_icon.tscn")
		icon_node = icon_scene.instantiate() as EquipmentIcon
		icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon_node)
		icon_node.update_item({})

		# 3. 前面グリッド枠（アイテム投入後でもグリッド枠線が上に表示される）
		grid_overlay = Panel.new()
		grid_overlay.custom_minimum_size = Vector2(64, 64)
		grid_overlay.anchors_preset = Control.PRESET_FULL_RECT
		grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var overlay_style := StyleBoxFlat.new()
		overlay_style.draw_center = false
		overlay_style.border_width_left = 2
		overlay_style.border_width_top = 2
		overlay_style.border_width_right = 2
		overlay_style.border_width_bottom = 2
		overlay_style.border_color = Color(0.65, 0.38, 0.18, 0.9) # 合成プレビュー枠と同色
		overlay_style.set_corner_radius_all(6)
		grid_overlay.add_theme_stylebox_override("panel", overlay_style)
		add_child(grid_overlay)

	func update_display(entry: Variant) -> void:
		placed_entry = entry
		if entry != null and entry is Dictionary:
			var it: Dictionary = entry.get("item", {})
			icon_node.update_item(it)
			icon_node.visible = true
		else:
			_remove_tooltip()
			icon_node.update_item({})
			icon_node.visible = false

	func _on_mouse_entered() -> void:
		if Engine.is_editor_hint():
			return
		if not is_visible_in_tree():
			return
		if placed_entry == null or not placed_entry is Dictionary:
			return
		var it: Dictionary = placed_entry.get("item", {})
		if it.is_empty():
			return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			return

		_remove_tooltip()

		var tooltip_scene := preload("res://scenes/ui/equipment_tooltip.tscn")
		_custom_tooltip = tooltip_scene.instantiate() as EquipmentTooltip

		var parent_node = get_parent()
		var canvas_layer: CanvasLayer = null
		while parent_node:
			if parent_node is CanvasLayer:
				canvas_layer = parent_node as CanvasLayer
				break
			parent_node = parent_node.get_parent()

		if canvas_layer:
			canvas_layer.add_child(_custom_tooltip)
		else:
			_custom_tooltip.top_level = true
			add_child(_custom_tooltip)

		_custom_tooltip.z_index = 50
		_custom_tooltip.z_as_relative = false
		_custom_tooltip.setup(it)
		_update_tooltip_position()
		set_process(true)

	func _on_mouse_exited() -> void:
		_remove_tooltip()

	func _remove_tooltip() -> void:
		if is_instance_valid(_custom_tooltip):
			_custom_tooltip.queue_free()
		_custom_tooltip = null
		set_process(false)

	func _update_tooltip_position() -> void:
		if not is_instance_valid(_custom_tooltip):
			return

		var mouse_pos = get_global_mouse_position()
		var offset = Vector2(15, 15)
		var target_pos = mouse_pos + offset

		var viewport_size = get_viewport().get_visible_rect().size
		var tooltip_size = _custom_tooltip.get_combined_minimum_size()

		if target_pos.x + tooltip_size.x > viewport_size.x:
			target_pos.x = mouse_pos.x - tooltip_size.x - 15
		if target_pos.y + tooltip_size.y > viewport_size.y:
			target_pos.y = mouse_pos.y - tooltip_size.y - 15

		_custom_tooltip.global_position = target_pos

	func _process(_delta: float) -> void:
		if not Engine.is_editor_hint():
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_remove_tooltip()
			else:
				_update_tooltip_position()

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not data is Dictionary:
			return false
		# 右側装備スロット(from_slot)からの直接ドラッグは禁止！
		if data.has("from_slot"):
			return false
		# 5×10インベントリからのドラッグであること
		if not data.has("from_inventory"):
			return false

		if not parent_wnd:
			return false

		# 装備タイプチェック
		var incoming_type: String = data.get("type", "")
		if incoming_type != parent_wnd.current_type:
			return false

		var incoming_inv_idx: int = data.get("item_index", -1)
		# 既に他の3×3スロットに入っているかチェック
		for s in parent_wnd.placed_materials:
			if s != slot_index and parent_wnd.placed_materials[s]["inv_index"] == incoming_inv_idx:
				return false

		# 鍛冶回数チェック
		var incoming_fc: int = data.get("forge_count", 0)
		for s in parent_wnd.placed_materials:
			if s == slot_index:
				continue
			var existing_fc: int = parent_wnd.placed_materials[s]["item"].get("forge_count", 0)
			if existing_fc != incoming_fc:
				return false

		return true

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not data is Dictionary:
			return
		var inv_idx: int = data.get("item_index", -1)
		if parent_wnd and inv_idx >= 0:
			parent_wnd.place_material(slot_index, inv_idx)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_remove_tooltip()
			if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
				# クリックで素材取り出し
				if placed_entry != null and parent_wnd:
					parent_wnd.remove_material(slot_index)

	func _get_drag_data(_at_position: Vector2) -> Variant:
		_remove_tooltip()
		if placed_entry == null or not parent_wnd:
			return null
		var it: Dictionary = placed_entry.get("item", {})
		if it.is_empty():
			return null

		var preview_root := Control.new()
		preview_root.z_index = 100
		var preview_icon := preload("res://scenes/ui/equipment_icon.tscn").instantiate() as EquipmentIcon
		preview_icon.position = -Vector2(32, 32)
		preview_root.add_child(preview_icon)
		preview_icon.update_item(it)
		set_drag_preview(preview_root)

		return {
			"from_forge_slot": true,
			"forge_slot": slot_index,
			"type": it.get("type", ""),
			"item_id": it.get("id", ""),
			"forge_count": it.get("forge_count", 0)
		}
