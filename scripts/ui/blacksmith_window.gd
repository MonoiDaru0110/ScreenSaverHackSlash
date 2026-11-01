class_name BlacksmithWindow
extends BaseWindow
## Window controller for Blacksmith (鍛冶) feature.

const SLOT_SIZE := Vector2(64, 64)
const MAX_MATERIALS := 9

@onready var type_option_button: OptionButton = %TypeOptionButton
@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var material_grid: GridContainer = %MaterialGrid
@onready var right_frame: PanelContainer = %RightFrame
@onready var result_section: VBoxContainer = %ResultSection
@onready var result_top_spacer: Control = %ResultTopSpacer
@onready var preview_tooltip: EquipmentTooltip = %PreviewTooltip
@onready var btn_forge: Button = %ForgeButton

# 選択中の装備タイプ: "main", "sub", "accessory"
var current_type: String = "main"

# 3×3投入枠データ: slot_index -> { "item": Dictionary, "inv_index": int }
var placed_materials: Dictionary = {}

var _current_target_forge_count: int = 0
var _is_forging: bool = false
var _is_showing_result: bool = false
var _hidden_inv_index: int = -1


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
			_is_forging = false
			_is_showing_result = false
			_hidden_inv_index = -1
			if btn_forge:
				btn_forge.modulate = Color.WHITE


func _process(_delta: float) -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return

	# 合成ボタン: 押下可能な状態 (disabled == false) のときに転生トークン注入のように明滅
	if btn_forge:
		if not btn_forge.disabled and not _is_forging:
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

	# プレビューカードの初期化（初期状態はダミー表示）
	if preview_tooltip:
		preview_tooltip.setup({
			"name": "完成予想",
			"show_question": true,
			"level_str": "Lv???",
			"rarity": "コモン",
			"forge_count": 0,
			"placeholder_message": "素材をセットしてください"
		})

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

	btn_forge.focus_mode = Control.FOCUS_NONE
	btn_forge.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_forge.add_theme_stylebox_override("normal", style_normal)
	btn_forge.add_theme_stylebox_override("hover", style_hover)
	btn_forge.add_theme_stylebox_override("pressed", style_pressed)
	btn_forge.add_theme_stylebox_override("disabled", style_disabled)


func _on_type_selected(index: int) -> void:
	if _is_forging:
		return
	match index:
		0:
			current_type = "main"
		1:
			current_type = "sub"
		2:
			current_type = "accessory"
	# 種類が変更された場合、投入中の素材と結果表示はクリアする
	_is_showing_result = false
	_hidden_inv_index = -1
	placed_materials.clear()
	update_all()


func update_all() -> void:
	_update_inventory_grid()
	_update_material_slots()
	_update_preview_and_candidates()


func _on_equipment_changed() -> void:
	if not is_visible_in_tree() or _is_forging:
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
		_is_showing_result = false
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
			var is_hidden := (i == _hidden_inv_index)
			slot_node.update_slot(current_type, i, item_data, is_placed, is_hidden)


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
	if _is_forging:
		return false

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

	_is_showing_result = false
	placed_materials[slot_idx] = {
		"item": item_to_place,
		"inv_index": inv_idx
	}

	update_all()
	return true


## 素材投入枠からアイテムを取り出す
func remove_material(slot_idx: int) -> void:
	if _is_forging:
		return

	if placed_materials.has(slot_idx):
		_is_showing_result = false
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
	if _is_forging or _is_showing_result:
		return

	var materials: Array = []
	for slot_idx in placed_materials:
		materials.append(placed_materials[slot_idx]["item"])

	var preview := GameData.calculate_forge_preview(materials)
	var can_forge: bool = preview.get("can_forge", false)

	if btn_forge:
		btn_forge.disabled = not can_forge
		if btn_forge.disabled:
			btn_forge.modulate = Color.WHITE

	if materials.is_empty():
		_current_target_forge_count = 0

		if preview_tooltip:
			preview_tooltip.setup({
				"name": "完成予想",
				"rarity": "コモン",
				"rarity_bbcode": "",
				"level_str": "Lv???",
				"forge_count": 0,
				"show_question": true,
				"placeholder_message": "素材をセットしてください"
			})
	elif materials.size() == 1:
		var single_mat: Dictionary = materials[0]
		var single_lvl: int = single_mat.get("level", 1)
		var single_rar: String = single_mat.get("rarity", "コモン")
		_current_target_forge_count = single_mat.get("forge_count", 0) + 1

		var col: Color = GameData.get_rarity_color(single_rar)
		var rarity_bbcode := "[color=#%s]%s[/color]" % [col.to_html(false), single_rar]

		if preview_tooltip:
			preview_tooltip.setup({
				"name": "完成予想",
				"icon": single_mat.get("icon", ""),
				"rarity": single_rar,
				"rarity_bbcode": rarity_bbcode,
				"level_str": "Lv.%d" % single_lvl,
				"forge_count": _current_target_forge_count,
				"show_question": true,
				"placeholder_message": "もう1つ以上の素材をセットしてください"
			})
	else:
		var min_lvl: int = preview.get("min_level", 10)
		var max_lvl: int = preview.get("max_level", 10)
		var level_str := ""
		if min_lvl == max_lvl:
			level_str = "Lv.%d" % min_lvl
		else:
			level_str = "Lv.%d 〜 Lv.%d" % [min_lvl, max_lvl]

		var r_range: Array = preview.get("possible_rarity_range", [1, 1])
		var rarity_names := ["コモン", "アンコモン", "レア", "エピック", "レジェンド", "ミシック"]
		var min_idx: int = clampi(r_range[0], 1, rarity_names.size())
		var max_idx: int = clampi(r_range[1], 1, rarity_names.size())
		var min_r: String = rarity_names[min_idx - 1]
		var max_r: String = rarity_names[max_idx - 1]
		var min_col: Color = GameData.get_rarity_color(min_r)
		var max_col: Color = GameData.get_rarity_color(max_r)
		var rarity_bbcode := ""
		if min_idx == max_idx:
			rarity_bbcode = "[color=#%s]%s[/color]" % [min_col.to_html(false), min_r]
		else:
			rarity_bbcode = "[color=#%s]%s[/color] [color=#a09ab0]〜[/color] [color=#%s]%s[/color]" % [min_col.to_html(false), min_r, max_col.to_html(false), max_r]

		_current_target_forge_count = preview.get("forge_count", 1)
		var icon_path: String = materials[0].get("icon", "")

		if preview_tooltip:
			preview_tooltip.setup({
				"name": "完成予想",
				"icon": icon_path,
				"rarity": max_r,
				"rarity_bbcode": rarity_bbcode,
				"level_str": level_str,
				"forge_count": _current_target_forge_count,
				"show_question": true,
				"equip_skill": preview.get("skills", [])
			})

	_adjust_result_position.call_deferred()


func _adjust_result_position() -> void:
	if not result_top_spacer or not result_section or not preview_tooltip or not right_frame:
		return

	# いったん最大スキル高さ制限を解除しデフォルト余白で計測
	preview_tooltip.set_max_skill_height(0.0)
	result_top_spacer.custom_minimum_size.y = 36.0

	await get_tree().process_frame
	if not is_inside_tree() or not is_visible_in_tree():
		return

	var available_h: float = right_frame.size.y
	if available_h <= 0.0:
		available_h = 740.0

	# コンテンツ全体の高さ（プレビューカード単体）
	var content_h: float = preview_tooltip.size.y
	var default_top: float = 36.0
	var bottom_margin: float = 12.0
	var max_bottom: float = available_h - bottom_margin

	if default_top + content_h <= max_bottom:
		# 下限に収まる場合：上端を9マスグリッド（36px）と揃える
		result_top_spacer.custom_minimum_size.y = default_top
		preview_tooltip.set_max_skill_height(0.0)
	else:
		# 下限を超える場合：上端揃えの制限を撤廃して上にせり上げる
		var needed_top: float = max_bottom - content_h
		if needed_top >= 0.0:
			result_top_spacer.custom_minimum_size.y = needed_top
			preview_tooltip.set_max_skill_height(0.0)
		else:
			# さらに上に伸びすぎた場合：上端を0でクランプし、ツールチップ内をスクロール可能にしてウィンドウへの干渉を防ぐ
			result_top_spacer.custom_minimum_size.y = 0.0
			var max_tooltip_h: float = maxi(100, int(available_h - bottom_margin))
			var max_skill_h: float = maxi(60, int(max_tooltip_h - 130))
			preview_tooltip.set_max_skill_height(max_skill_h)


# --- 合成ボタン押下時 ＆ 演出 ---

func _on_forge_pressed() -> void:
	if _is_forging:
		return

	var mat_indices: Array[int] = []
	for slot_idx in placed_materials:
		mat_indices.append(placed_materials[slot_idx]["inv_index"])

	if mat_indices.size() < 2:
		return

	_is_forging = true
	_is_showing_result = false

	if btn_forge:
		btn_forge.release_focus()
		btn_forge.disabled = true
		btn_forge.modulate = Color.WHITE

	# 合成後の配置先インデックス（最小インデックス）を特定
	var target_inv_idx: int = mat_indices[0]
	for idx in mat_indices:
		if idx < target_inv_idx:
			target_inv_idx = idx

	# 合成実行（内部的にはこの瞬間に装備が消滅し、target_inv_idx に新装備が配置される）
	var result_item := GameData.forge_equipment(current_type, mat_indices)
	if result_item.is_empty():
		_is_forging = false
		_hidden_inv_index = -1
		update_all()
		return

	# 配置された新装備は演出完了まで不可視＆操作不可にする
	_hidden_inv_index = target_inv_idx

	# 素材スロットをクリアしてインベントリ表示を更新（新アイテムは不可視）
	placed_materials.clear()
	_update_inventory_grid()
	_update_material_slots()

	# 演出開始
	await _play_forge_success_animation(result_item, target_inv_idx)


func _play_forge_success_animation(result_item: Dictionary, target_inv_idx: int) -> void:
	if not preview_tooltip or not right_frame:
		_hidden_inv_index = -1
		_is_forging = false
		_update_inventory_grid()
		return

	var orig_pos: Vector2 = preview_tooltip.position
	preview_tooltip.pivot_offset = preview_tooltip.size * 0.5

	# 1. 溜め・発光フェーズ（約0.42秒、白熱発光しながら小刻みに振動）
	var charge_tween := create_tween()
	charge_tween.tween_property(preview_tooltip, "modulate", Color(3.2, 2.7, 1.8, 1.0), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var elapsed := 0.0
	var shake_duration := 0.42
	while elapsed < shake_duration:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		elapsed += dt
		var shake_strength: float = lerpf(1.5, 4.5, elapsed / shake_duration)
		preview_tooltip.position = orig_pos + Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))

	preview_tooltip.position = orig_pos

	# 2. 光の放出フェーズ（フラッシュ ＆ ショックウェーブ ＆ パーティクルバースト）
	var card_center_global: Vector2 = preview_tooltip.global_position + preview_tooltip.size * 0.5
	var effect_center: Vector2 = card_center_global - right_frame.global_position
	var rar_str: String = result_item.get("rarity", "コモン")
	var rar_color: Color = GameData.get_rarity_color(rar_str)

	# フラッシュ（閃光ホワイトアウト）
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.88)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_frame.add_child(flash)

	var flash_tween := create_tween()
	flash_tween.tween_interval(0.04)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tween.tween_callback(flash.queue_free)

	# ショックウェーブリング
	var shockwave := ForgeShockwaveRing.new()
	shockwave.position = effect_center
	shockwave.ring_color = Color(1.0, 0.96, 0.85, 0.95)
	right_frame.add_child(shockwave)

	var sw_tween := create_tween().set_parallel(true)
	sw_tween.tween_property(shockwave, "radius", 260.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sw_tween.tween_property(shockwave, "width", 1.0, 0.42)
	sw_tween.tween_property(shockwave, "ring_color:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sw_tween.chain().tween_callback(shockwave.queue_free)

	# 星屑・火花パーティクル
	var particles := CPUParticles2D.new()
	particles.position = effect_center
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.amount = 45
	particles.lifetime = 0.65
	particles.spread = 180.0
	particles.gravity = Vector2(0, 140)
	particles.initial_velocity_min = 160.0
	particles.initial_velocity_max = 340.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.5
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.25, rar_color.lightened(0.25))
	grad.set_color(grad.get_point_count() - 1, Color(rar_color.r, rar_color.g, rar_color.b, 0.0))
	particles.color_ramp = grad
	right_frame.add_child(particles)
	particles.restart()

	# 3. 結果カードのセットアップ ＆ ポップイン
	var result_data := result_item.duplicate(true)
	result_data["is_result"] = true
	preview_tooltip.setup(result_data, "完成！")
	_adjust_result_position.call_deferred()

	preview_tooltip.scale = Vector2(0.85, 0.85)
	preview_tooltip.modulate = Color(2.5, 2.3, 1.8, 1.0)

	var pop_tween := create_tween().set_parallel(true)
	pop_tween.tween_property(preview_tooltip, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(preview_tooltip, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# パーティクルの後片付け
	get_tree().create_timer(0.65).timeout.connect(particles.queue_free)

	# 4. 合成演出終了後、約1秒の余韻時間
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or not is_visible_in_tree():
		_hidden_inv_index = -1
		_is_forging = false
		_is_showing_result = true
		_update_inventory_grid()
		return

	# 5. アイコンのインベントリへの飛行移動演出
	var tooltip_icon := preview_tooltip.get_node_or_null("%EquipmentIcon") as Control
	var start_pos: Vector2 = tooltip_icon.global_position if tooltip_icon else (preview_tooltip.global_position + Vector2(16, 16))

	var target_slot_node: Control = null
	if inventory_grid and target_inv_idx >= 0 and target_inv_idx < inventory_grid.get_child_count():
		target_slot_node = inventory_grid.get_child(target_inv_idx) as Control

	var end_pos: Vector2 = target_slot_node.global_position if target_slot_node else start_pos

	var flying_icon := preload("res://scenes/ui/equipment_icon.tscn").instantiate() as EquipmentIcon
	flying_icon.top_level = true
	flying_icon.z_index = 200
	flying_icon.global_position = start_pos
	flying_icon.update_item(result_item)
	add_child(flying_icon)

	var fly_dur := 0.35
	var fly_tween := create_tween()
	# X軸の移動（滑らかに）
	fly_tween.parallel().tween_property(flying_icon, "global_position:x", end_pos.x, fly_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Y軸の移動（自然なわずかな山なり）
	var peak_y: float = mini(start_pos.y, end_pos.y) - 20.0
	fly_tween.parallel().tween_property(flying_icon, "global_position:y", peak_y, fly_dur * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly_tween.chain().tween_property(flying_icon, "global_position:y", end_pos.y, fly_dur * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await fly_tween.finished
	flying_icon.queue_free()

	# 6. 着弾！ 不可視状態を解除し、通常状態に移行
	_hidden_inv_index = -1
	_update_inventory_grid()

	# 着弾演出: くどい大きなバウンスを廃止し、あっさりとした微小なリアクションに
	if is_instance_valid(target_slot_node):
		target_slot_node.pivot_offset = target_slot_node.size * 0.5
		var land_tween := create_tween()
		land_tween.tween_property(target_slot_node, "scale", Vector2(1.06, 1.06), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		land_tween.tween_property(target_slot_node, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# HUDのドロップ通知
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud and hud.has_method("show_equipment_drop_pop"):
		hud.show_equipment_drop_pop(result_item)

	_is_showing_result = true
	_is_forging = false


# ==============================================================================
# 内部クラス: ショックウェーブ描画リング
# ==============================================================================
class ForgeShockwaveRing extends Node2D:
	var radius: float = 10.0
	var ring_color: Color = Color(1.0, 0.95, 0.85, 0.95)
	var width: float = 6.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if radius > 0.0 and ring_color.a > 0.0:
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ring_color, width, true)


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

	func update_slot(p_type: String, p_index: int, item_data: Variant, is_placed_in_forge: bool, is_hidden: bool = false) -> void:
		slot_type = p_type
		slot_index = p_index

		if is_hidden or item_data == null or not item_data is Dictionary or item_data.is_empty():
			if current_item_id == "" and child_empty_btn != null and not is_hidden:
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
			child_empty_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_hidden else Control.MOUSE_FILTER_PASS
			child_empty_btn.disabled = is_hidden
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
		if parent_wnd and (parent_wnd._is_forging or parent_wnd._hidden_inv_index == slot_index):
			return false
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
		if parent_wnd and parent_wnd._is_forging:
			return false
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
			if parent_wnd and parent_wnd._is_forging:
				return
			if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
				# クリックで素材取り出し
				if placed_entry != null and parent_wnd:
					parent_wnd.remove_material(slot_index)

	func _get_drag_data(_at_position: Vector2) -> Variant:
		_remove_tooltip()
		if parent_wnd and parent_wnd._is_forging:
			return null
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
