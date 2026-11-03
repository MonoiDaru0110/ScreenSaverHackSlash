class_name InfuserWindow
extends BaseWindow
## 注入器（Infuser）ウィンドウコントローラー
## ロゴの壁衝突によって発生するCP（衝突エネルギー）を各スロットへ注入・分配し、
## 各種キネティックおよびハクスラ能力を永続育成する。

# --- UI References ---
@onready var hub_panel: PanelContainer = %HubPanel
@onready var hub_water_canvas: Control = %HubWaterCanvas
@onready var cps_label: Label = %CpsLabel
@onready var total_cp_label: Label = %TotalCpLabel
@onready var total_bounces_label: Label = %TotalBouncesLabel
@onready var pop_container: Control = %PopContainer
@onready var pipe_canvas: Control = %PipeCanvas
@onready var left_slots_column: VBoxContainer = %LeftSlotsColumn
@onready var right_slots_column: VBoxContainer = %RightSlotsColumn
@onready var center_pipe_area: Control = %CenterPipeArea

const LEFT_SLOT_KEYS: Array[String] = [
	"speed_infusion",
	"crit_infusion",
	"harvest_infusion"
]

const RIGHT_SLOT_KEYS: Array[String] = [
	"treasure_infusion",
	"corner_infusion",
	"efficiency_infusion"
]

# スロットごとのUIノードキャッシュ
var _slot_cards: Dictionary = {} # { "slot_id": CardNodesDictionary }
var _active_editing_slot_id: String = ""

# 更新タイマー
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1

# ポップアップ管理（波の防止と一定寿命）
var _active_pops: Array[Node] = []
var _pending_cp_amount: float = 0.0
var _pending_is_corner: bool = false
var _pop_cooldown: float = 0.0
const MIN_POP_INTERVAL: float = 0.12 # 出現の波を防ぐ最小間隔
const MAX_ACTIVE_POPS: int = 5 # 同時出現数の上限
const POP_LIFETIME: float = 1.2 # 各ポップアップの一定寿命（秒）


func _ready() -> void:
	super._ready()
	_create_slot_cards()
	_update_all_ui()

	if hub_water_canvas:
		hub_water_canvas.draw.connect(_on_hub_water_draw)
	if pipe_canvas:
		pipe_canvas.draw.connect(_on_pipe_canvas_draw)

	GameData.infuser_cp_gained.connect(_on_cp_gained)
	GameData.infuser_updated.connect(_on_infuser_updated)
	GameData.infuser_leveled_up.connect(_on_leveled_up)
	GameData.stats_changed.connect(_on_stats_changed)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# 他のエリアをクリックした際に入力内容を反映して入力モードを終了
	if event is InputEventMouseButton and event.pressed:
		if not _active_editing_slot_id.is_empty() and _slot_cards.has(_active_editing_slot_id):
			var nodes: Dictionary = _slot_cards[_active_editing_slot_id]
			var weight_container: Control = nodes.get("weight_container")
			if is_instance_valid(weight_container):
				var mb: InputEventMouseButton = event as InputEventMouseButton
				if not weight_container.get_global_rect().has_point(mb.global_position):
					_commit_weight_edit(_active_editing_slot_id)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_refresh_runtime_values()

	# ポップアップ出現の波を平滑化
	if _pop_cooldown > 0.0:
		_pop_cooldown -= delta
	elif _pending_cp_amount > 0.0:
		_spawn_cp_popup(_pending_cp_amount, _pending_is_corner)
		_pending_cp_amount = 0.0
		_pending_is_corner = false
		_pop_cooldown = MIN_POP_INTERVAL

	if hub_water_canvas:
		hub_water_canvas.queue_redraw()
	if pipe_canvas:
		pipe_canvas.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			_update_all_ui()
		else:
			if not _active_editing_slot_id.is_empty():
				_commit_weight_edit(_active_editing_slot_id)


func _commit_weight_edit(slot_id: String) -> void:
	if not _slot_cards.has(slot_id):
		return
	var nodes: Dictionary = _slot_cards[slot_id]
	var weight_edit: LineEdit = nodes.get("weight_edit")
	if not is_instance_valid(weight_edit):
		return

	var raw_text := weight_edit.text.strip_edges()
	var val := clampi(int(raw_text), 0, 100) if raw_text.is_valid_int() else GameData.get_infuser_slot_weight(slot_id)
	GameData.set_infuser_slot_weight(slot_id, val)
	weight_edit.text = str(val)

	var empty_sb: StyleBoxEmpty = nodes.get("empty_sb")
	if empty_sb:
		weight_edit.add_theme_stylebox_override("normal", empty_sb)
	weight_edit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	weight_edit.release_focus()
	weight_edit.deselect()

	var is_active: bool = (val > 0)
	weight_edit.add_theme_color_override("font_color", Color(0.28, 0.94, 0.80, 1.0) if is_active else Color(0.55, 0.70, 0.65, 0.7))

	if _active_editing_slot_id == slot_id:
		_active_editing_slot_id = ""


func _create_slot_cards() -> void:
	_slot_cards.clear()

	if left_slots_column:
		for child in left_slots_column.get_children():
			child.queue_free()
		for slot_id in LEFT_SLOT_KEYS:
			if GameData.INFUSER_SLOTS.has(slot_id):
				var card := _build_slot_card(slot_id, true)
				left_slots_column.add_child(card)

	if right_slots_column:
		for child in right_slots_column.get_children():
			child.queue_free()
		for slot_id in RIGHT_SLOT_KEYS:
			if GameData.INFUSER_SLOTS.has(slot_id):
				var card := _build_slot_card(slot_id, false)
				right_slots_column.add_child(card)


func _build_slot_card(slot_id: String, _is_left: bool) -> PanelContainer:
	var def: Dictionary = GameData.INFUSER_SLOTS[slot_id]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 140)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# カード外枠
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.14, 0.20, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.25, 0.92, 0.78, 0.95)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.shadow_color = Color(0.12, 0.80, 0.66, 0.35)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2.ZERO
	panel_style.content_margin_left = 0.0
	panel_style.content_margin_top = 0.0
	panel_style.content_margin_right = 0.0
	panel_style.content_margin_bottom = 0.0
	panel.add_theme_stylebox_override("panel", panel_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(main_vbox)

	# --- 上部セクション（左右分割タイトルバー） ---
	var header_panel := PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 48)
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	header_style.border_width_left = 2
	header_style.border_width_top = 2
	header_style.border_width_right = 2
	header_style.border_width_bottom = 0
	header_style.border_color = Color(0.25, 0.92, 0.78, 0.95)
	header_style.corner_radius_top_left = 6
	header_style.corner_radius_top_right = 6
	header_style.content_margin_left = 12.0
	header_style.content_margin_right = 0.0
	header_style.content_margin_top = 0.0
	header_style.content_margin_bottom = 0.0
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_hbox.add_theme_constant_override("separation", 0)
	header_panel.add_child(top_hbox)

	# 左側: タイトル表示エリア（セパレートされた左側エリアに中央揃えで配置、白文字）
	var left_area := CenterContainer.new()
	left_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(left_area)

	var title_lbl := Label.new()
	title_lbl.text = str(def.get("name", ""))
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_area.add_child(title_lbl)

	# 縦セパレータ（上部バー全体を途切れずに貫通する細線）
	var v_sep := ColorRect.new()
	v_sep.custom_minimum_size = Vector2(1, 0)
	v_sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_sep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v_sep.color = Color(0.20, 0.85, 0.72, 0.75)
	top_hbox.add_child(v_sep)

	# 右側: 重み入力エリア（ホバーで淡く発光、クリックで入力モードへ移行、入力時の位置・フォントサイズと完全一致）
	var weight_container := PanelContainer.new()
	weight_container.custom_minimum_size = Vector2(85, 0)
	weight_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cont_empty_sb := StyleBoxEmpty.new()
	weight_container.add_theme_stylebox_override("panel", cont_empty_sb)
	top_hbox.add_child(weight_container)

	var empty_sb := StyleBoxEmpty.new()

	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = Color(0.20, 0.60, 0.50, 0.25)
	hover_sb.corner_radius_top_left = 0
	hover_sb.corner_radius_top_right = 5
	hover_sb.corner_radius_bottom_right = 0
	hover_sb.corner_radius_bottom_left = 0

	# 単一の LineEdit で通常表示・ホバー表示・入力時表示をすべて担うことで、位置ズレやフォント差を完全解消
	var weight_edit := LineEdit.new()
	weight_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weight_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weight_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	weight_edit.max_length = 3
	weight_edit.text = str(GameData.get_infuser_slot_weight(slot_id))
	weight_edit.context_menu_enabled = false
	weight_edit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	weight_edit.add_theme_stylebox_override("normal", empty_sb)
	weight_edit.add_theme_stylebox_override("focus", empty_sb)
	weight_edit.add_theme_stylebox_override("read_only", empty_sb)
	weight_edit.add_theme_font_size_override("font_size", 20)
	weight_edit.add_theme_color_override("font_color", Color(0.28, 0.94, 0.80, 1.0))
	weight_edit.add_theme_color_override("selection_color", Color(0.20, 0.60, 0.50, 0.45))
	weight_edit.add_theme_color_override("caret_color", Color(0.35, 0.98, 0.82, 1.0))
	weight_container.add_child(weight_edit)

	# --- 水平セパレータ（1pxに細線化） ---
	var h_sep := ColorRect.new()
	h_sep.custom_minimum_size = Vector2(0, 1)
	h_sep.color = Color(0.20, 0.85, 0.72, 0.75)
	main_vbox.add_child(h_sep)

	# --- 下部ボディセクション ---
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 16)
	body_margin.add_theme_constant_override("margin_right", 16)
	body_margin.add_theme_constant_override("margin_top", 4)
	body_margin.add_theme_constant_override("margin_bottom", 6)
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(body_margin)

	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 0)
	body_margin.add_child(body_vbox)

	# --- 上部: 効果テキスト部（上端に詰める） ---
	var effect_vbox := VBoxContainer.new()
	effect_vbox.add_theme_constant_override("separation", 2)
	effect_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	body_vbox.add_child(effect_vbox)

	var cur_val_lbl := Label.new()
	cur_val_lbl.text = "-"
	cur_val_lbl.add_theme_font_size_override("font_size", 19)
	cur_val_lbl.add_theme_color_override("font_color", Color(0.35, 0.96, 0.75, 1.0))
	effect_vbox.add_child(cur_val_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(def.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.60, 0.78, 0.74, 0.95))
	effect_vbox.add_child(desc_lbl)

	# --- 中間: 伸縮スペーサー（空きスペースを広げて上下端へ押し出す） ---
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_vbox.add_child(spacer)

	# --- 下部グループ: 進捗バー ＋ 流量/進捗テキスト（下端に詰める） ---
	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.add_theme_constant_override("separation", 4)
	bottom_vbox.alignment = BoxContainer.ALIGNMENT_END
	body_vbox.add_child(bottom_vbox)

	# 上段: プログレスバー
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 0.0

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.07, 0.10, 0.14, 1.0)
	bar_bg.border_width_left = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_right = 1
	bar_bg.border_width_bottom = 1
	bar_bg.border_color = Color(0.12, 0.42, 0.36, 0.7)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_right = 4
	bar_bg.corner_radius_bottom_left = 4
	bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.10, 0.76, 0.60, 1.0)
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_right = 4
	bar_fill.corner_radius_bottom_left = 4
	bar.add_theme_stylebox_override("fill", bar_fill)
	bottom_vbox.add_child(bar)

	# 下段: 流量 / 進捗（右詰）
	var rate_prog_hbox := HBoxContainer.new()
	rate_prog_hbox.add_theme_constant_override("separation", 8)
	bottom_vbox.add_child(rate_prog_hbox)

	var rate_lbl := Label.new()
	rate_lbl.text = "流量: 0 CP/s (0%)"
	rate_lbl.add_theme_font_size_override("font_size", 12)
	rate_lbl.add_theme_color_override("font_color", Color(0.48, 0.88, 0.76, 1.0))
	rate_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rate_prog_hbox.add_child(rate_lbl)

	var prog_lbl := Label.new()
	prog_lbl.text = "0 / 0 CP (あと --秒)"
	prog_lbl.add_theme_font_size_override("font_size", 12)
	prog_lbl.add_theme_color_override("font_color", Color(0.72, 0.86, 0.82, 1.0))
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rate_prog_hbox.add_child(prog_lbl)

	# イベント接続（ホバーで淡く変化、クリックで全選択＆入力開始、Enterや外側クリックで確定）
	weight_edit.mouse_entered.connect(func():
		if _active_editing_slot_id != slot_id:
			weight_edit.add_theme_stylebox_override("normal", hover_sb)
	)
	weight_edit.mouse_exited.connect(func():
		if _active_editing_slot_id != slot_id:
			weight_edit.add_theme_stylebox_override("normal", empty_sb)
	)

	weight_edit.focus_entered.connect(func():
		if not _active_editing_slot_id.is_empty() and _active_editing_slot_id != slot_id:
			_commit_weight_edit(_active_editing_slot_id)
		_active_editing_slot_id = slot_id
		weight_edit.add_theme_stylebox_override("normal", empty_sb)
		weight_edit.mouse_default_cursor_shape = Control.CURSOR_IBEAM
		weight_edit.call_deferred("select_all")
	)

	weight_edit.text_submitted.connect(func(_new_text: String):
		_commit_weight_edit(slot_id)
	)
	weight_edit.focus_exited.connect(func():
		_commit_weight_edit(slot_id)
	)

	# ノード参照キャッシュ
	_slot_cards[slot_id] = {
		"panel": panel,
		"panel_style": panel_style,
		"header_style": header_style,
		"h_sep": h_sep,
		"v_sep": v_sep,
		"weight_container": weight_container,
		"weight_edit": weight_edit,
		"empty_sb": empty_sb,
		"hover_sb": hover_sb,
		"cur_val_lbl": cur_val_lbl,
		"desc_lbl": desc_lbl,
		"bar": bar,
		"rate_lbl": rate_lbl,
		"prog_lbl": prog_lbl
	}

	return panel


func _update_slot_card(slot_id: String) -> void:
	if not _slot_cards.has(slot_id):
		return
	var nodes: Dictionary = _slot_cards[slot_id]
	var lvl: int = GameData.get_infuser_level(slot_id)
	var prog: float = GameData.get_infuser_progress(slot_id)
	var cost: float = GameData.get_infuser_slot_cost(slot_id, lvl)
	var w: int = GameData.get_infuser_slot_weight(slot_id)
	var is_active: bool = (w > 0)

	# 重み表示の同期（入力中以外の場合に値を反映し、アクティブ状態のフォント色を適用）
	var weight_edit: LineEdit = nodes.get("weight_edit")
	if weight_edit:
		if not weight_edit.has_focus() and int(weight_edit.text) != w:
			weight_edit.text = str(w)
		if _active_editing_slot_id != slot_id:
			weight_edit.add_theme_color_override("font_color", Color(0.28, 0.94, 0.80, 1.0) if is_active else Color(0.55, 0.70, 0.65, 0.7))
		else:
			weight_edit.add_theme_color_override("font_color", Color(0.28, 0.94, 0.80, 1.0))

	# 現在効果テキスト（末尾にレベルを統合）
	var cur_val_lbl: Label = nodes["cur_val_lbl"]
	cur_val_lbl.text = "%s (Lv. %s)" % [_format_current_effect(slot_id, lvl), GameData.format_num(float(lvl))]

	# プログレスバー
	var bar: ProgressBar = nodes["bar"]
	bar.max_value = cost
	bar.value = clampf(prog, 0.0, cost)

	# 停止中のカードは少し半透明にし、発光枠を減光して休止状態を明示
	var panel: PanelContainer = nodes["panel"]
	panel.modulate.a = 1.0 if is_active else 0.65
	var panel_style: StyleBoxFlat = nodes.get("panel_style")
	var header_style: StyleBoxFlat = nodes.get("header_style")
	var h_sep: ColorRect = nodes.get("h_sep")
	var v_sep: ColorRect = nodes.get("v_sep")
	if panel_style and header_style:
		if is_active:
			panel_style.border_color = Color(0.25, 0.92, 0.78, 0.95)
			panel_style.shadow_color = Color(0.12, 0.80, 0.66, 0.35)
			panel_style.shadow_size = 8
			header_style.border_color = Color(0.25, 0.92, 0.78, 0.95)
			if h_sep:
				h_sep.color = Color(0.20, 0.85, 0.72, 0.75)
			if v_sep:
				v_sep.color = Color(0.20, 0.85, 0.72, 0.75)
		else:
			panel_style.border_color = Color(0.10, 0.28, 0.25, 0.6)
			panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
			panel_style.shadow_size = 0
			header_style.border_color = Color(0.10, 0.28, 0.25, 0.6)
			if h_sep:
				h_sep.color = Color(0.10, 0.28, 0.25, 0.5)
			if v_sep:
				v_sep.color = Color(0.10, 0.28, 0.25, 0.5)

	# 流量と進捗の更新
	_update_slot_runtime_text(slot_id, nodes, lvl, prog, cost, w, is_active)


func _update_slot_runtime_text(slot_id: String, nodes: Dictionary, _lvl: int, prog: float, cost: float, w: int, is_active: bool) -> void:
	var total_cps: float = GameData.get_infuser_cps()
	var total_weight: int = GameData.get_infuser_total_weight()

	var slot_cps := 0.0
	var pct := 0.0
	if is_active and total_weight > 0:
		pct = (float(w) / float(total_weight)) * 100.0
		slot_cps = total_cps * (float(w) / float(total_weight))

	var rate_lbl: Label = nodes["rate_lbl"]
	rate_lbl.text = "流量: %s CP/s (%.0f%%)" % [GameData.format_num(slot_cps), pct]

	var prog_lbl: Label = nodes["prog_lbl"]
	var remain_cp := maxf(0.0, cost - prog)
	var eta_str := "--"
	if slot_cps > 0.0:
		var sec := remain_cp / slot_cps
		if sec < 60.0:
			eta_str = "%.1f秒" % sec
		elif sec < 3600.0:
			eta_str = "%d分%d秒" % [int(sec) / 60, int(sec) % 60]
		else:
			eta_str = "%.1f時間" % (sec / 3600.0)

	prog_lbl.text = "%s / %s CP (あと %s)" % [
		GameData.format_num(prog),
		GameData.format_num(cost),
		eta_str
	]


func _format_current_effect(slot_id: String, lvl: int) -> String:
	match slot_id:
		"speed_infusion":
			var spd := (GameData.get_infuser_speed_multiplier() - 1.0) * 100.0
			return "ロゴ速度 +%s%%" % GameData.format_num(spd)
		"treasure_infusion":
			var prob := GameData.get_infuser_equip_drop_prob_bonus()
			var eq_lvl := GameData.get_infuser_equip_level_bonus() * 10
			return "装備ドロップ率 +%s%% / 装備Lv +%d" % [GameData.format_num(prob), eq_lvl]
		"crit_infusion":
			var rate := GameData.get_infuser_crit_rate_bonus()
			var dmg := GameData.get_infuser_crit_damage_bonus()
			return "クリティカル率 +%s%% / 倍率 +%s%%" % [GameData.format_num(rate), GameData.format_num(dmg)]
		"corner_infusion":
			var mult := (GameData.get_infuser_corner_gold_mult() - 1.0) * 100.0
			return "角衝突報酬 +%s%%" % GameData.format_num(mult)
		"harvest_infusion":
			var gold_mult := (GameData.get_infuser_gold_multiplier() - 1.0) * 100.0
			return "衝突ゴールド・トークン +%s%%" % GameData.format_num(gold_mult)
		"efficiency_infusion":
			var eff := float(lvl) * 5.0
			return "1衝突あたりのCP獲得量 +%s%%" % GameData.format_num(eff)
	return ""


func _refresh_runtime_values() -> void:
	if cps_label:
		var cps := GameData.get_infuser_cps()
		cps_label.text = "総出力: %s CP/s" % GameData.format_num(cps)

	for slot_id in _slot_cards:
		var nodes: Dictionary = _slot_cards[slot_id]
		var lvl: int = GameData.get_infuser_level(slot_id)
		var prog: float = GameData.get_infuser_progress(slot_id)
		var cost: float = GameData.get_infuser_slot_cost(slot_id, lvl)
		var w: int = GameData.get_infuser_slot_weight(slot_id)
		var is_active: bool = (w > 0)
		_update_slot_runtime_text(slot_id, nodes, lvl, prog, cost, w, is_active)


func _update_hub_info() -> void:
	if cps_label:
		var cps := GameData.get_infuser_cps()
		cps_label.text = "総出力: %s CP/s" % GameData.format_num(cps)
	if total_cp_label:
		total_cp_label.text = "累計注入CP: %s" % GameData.format_num(GameData.infuser_total_cp)
	if total_bounces_label:
		total_bounces_label.text = "総衝突数: %s" % GameData.format_num(float(GameData.total_bounces))


func _update_all_ui() -> void:
	_update_hub_info()
	for slot_id in _slot_cards:
		_update_slot_card(slot_id)
	if pipe_canvas:
		pipe_canvas.queue_redraw()


# --- 演出: ポップアップ表示 ---
func _on_cp_gained(amount: float, is_corner: bool) -> void:
	if not is_visible_in_tree() or not pop_container:
		return

	# 即時進行バー反映
	for slot_id in _slot_cards:
		var nodes: Dictionary = _slot_cards[slot_id]
		var prog: float = GameData.get_infuser_progress(slot_id)
		var bar: ProgressBar = nodes["bar"]
		bar.value = prog

	# 出現に波が出来ないようにバッファリング＆レートリミット管理
	_pending_cp_amount += amount
	if is_corner:
		_pending_is_corner = true

	# クールダウンが経過しており上限数未満なら即座に出現
	if _pop_cooldown <= 0.0 and _active_pops.size() < MAX_ACTIVE_POPS:
		_spawn_cp_popup(_pending_cp_amount, _pending_is_corner)
		_pending_cp_amount = 0.0
		_pending_is_corner = false
		_pop_cooldown = MIN_POP_INTERVAL


func _spawn_cp_popup(amount: float, is_corner: bool) -> void:
	if not pop_container or not is_visible_in_tree():
		return

	# 出現数上限管理（各ポップアップが一定の寿命を全うできるよう、上限超過時は間引く）
	if _active_pops.size() >= MAX_ACTIVE_POPS:
		return

	var lbl := Label.new()
	var text_str := "+%s CP" % GameData.format_num(amount)
	if is_corner:
		text_str = "CRITICAL " + text_str
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0)) # 金色
	else:
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.35, 0.96, 0.78, 1.0)) # ティールグリーン

	lbl.text = text_str
	pop_container.add_child(lbl)
	_active_pops.append(lbl)

	# 浮上＆フェードアウトアニメーション（下部から出現し、一定寿命をかけて上へ移動しながらフェードアウト）
	var offset_x := randf_range(-12.0, 12.0)
	var start_y := 75.0
	lbl.position = Vector2(offset_x, start_y)
	lbl.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	# 登場時フェードイン
	tw.tween_property(lbl, "modulate:a", 1.0, 0.12)
	# 上方向へスムーズに移動
	tw.tween_property(lbl, "position:y", start_y - 60.0, POP_LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 寿命後半で滑らかにフェードアウト
	tw.tween_property(lbl, "modulate:a", 0.0, 0.45).set_delay(POP_LIFETIME - 0.45)
	tw.chain().tween_callback(func():
		_active_pops.erase(lbl)
		if is_instance_valid(lbl):
			lbl.queue_free()
	)


func _on_infuser_updated() -> void:
	if is_visible_in_tree():
		_update_all_ui()


func _on_leveled_up(_slot_id: String, _new_lvl: int) -> void:
	if is_visible_in_tree():
		_update_all_ui()


func _on_stats_changed() -> void:
	if is_visible_in_tree():
		if total_bounces_label:
			total_bounces_label.text = "総衝突数: %s" % GameData.format_num(float(GameData.total_bounces))


func update_ui() -> void:
	_update_all_ui()


# ==============================================================================
# パイプ（管）描画システム
# ==============================================================================

func _on_pipe_canvas_draw() -> void:
	if not pipe_canvas or not is_instance_valid(hub_panel):
		return
	if not left_slots_column or not right_slots_column:
		return

	var canvas_inv := pipe_canvas.get_global_transform().affine_inverse()

	# ハブ底面の中心Xと底面Y（PipeCanvasローカル座標）
	var hub_rect: Rect2 = hub_panel.get_global_rect()
	var hub_bottom_global := Vector2(hub_rect.get_center().x, hub_rect.position.y + hub_rect.size.y)
	var hub_bottom_local := canvas_inv * hub_bottom_global
	var hub_center_x := hub_bottom_local.x
	var hub_bottom_y := hub_bottom_local.y

	# パスの水平オフセット（上側ほどハブ底面の外側、下側ほど中央寄り）
	# 左列・右列それぞれ3段: 0 (上: 速度/装備), 1 (中: 会心/角), 2 (下: 収穫/効率)
	var offsets: Array[float] = [70.0, 44.0, 18.0]
	var flow_time := float(Time.get_ticks_msec()) * 0.001

	# 左列の描画（ハブから下へ伸び、左へ水平に曲がってスロット右辺へ）
	_draw_side_pipes(LEFT_SLOT_KEYS, hub_center_x, hub_bottom_y, offsets, true, flow_time)

	# 右列の描画（ハブから下へ伸び、右へ水平に曲がってスロット左辺へ）
	_draw_side_pipes(RIGHT_SLOT_KEYS, hub_center_x, hub_bottom_y, offsets, false, flow_time)


func _draw_side_pipes(
	slot_ids: Array[String],
	hub_center_x: float,
	hub_bottom_y: float,
	offsets: Array[float],
	is_left: bool,
	flow_time: float
) -> void:
	var canvas_inv := pipe_canvas.get_global_transform().affine_inverse()

	for i in range(slot_ids.size()):
		var slot_id := slot_ids[i]
		if not _slot_cards.has(slot_id):
			continue
		var card_panel: PanelContainer = _slot_cards[slot_id]["panel"]
		if not is_instance_valid(card_panel):
			continue

		var card_rect := card_panel.get_global_rect()
		var card_min := canvas_inv * card_rect.position
		var card_max := canvas_inv * (card_rect.position + card_rect.size)

		# 接続点Y（カード上部から約35%付近の高さ）
		var connect_y := card_min.y + (card_max.y - card_min.y) * 0.35

		# 下降するX座標（上側ほど外側、下側ほど中央寄り）
		var offset_x := offsets[i] if i < offsets.size() else 18.0
		var drop_x := (hub_center_x - offset_x) if is_left else (hub_center_x + offset_x)

		# スロット側の接続点X（左列は右辺、右列は左辺）
		var slot_connect_x := card_max.x if is_left else card_min.x

		# 始点・角点・終点
		var p_start := Vector2(drop_x, hub_bottom_y)
		var p_corner := Vector2(drop_x, connect_y)
		var p_end := Vector2(slot_connect_x, connect_y)

		# パス形状（角丸L字）のポイントを生成
		var path_points := _build_rounded_l_path(p_start, p_corner, p_end, 10.0, is_left)
		if path_points.size() < 2:
			continue

		var is_active: bool = GameData.is_infuser_slot_active(slot_id)

		if is_active:
			# 外枠ベース管
			pipe_canvas.draw_polyline(path_points, Color(0.03, 0.22, 0.18, 0.85), 7.0, true)
			# グロー（発光管）
			pipe_canvas.draw_polyline(path_points, Color(0.10, 0.70, 0.56, 0.75), 3.5, true)
			# エナジーコア（明るいティール）
			pipe_canvas.draw_polyline(path_points, Color(0.45, 0.98, 0.82, 1.0), 1.6, true)

			# ハブ側ノズル
			pipe_canvas.draw_circle(p_start, 3.5, Color(0.12, 0.80, 0.66, 1.0))
			pipe_canvas.draw_circle(p_start, 1.5, Color.WHITE)

			# スロット側ノズル
			pipe_canvas.draw_circle(p_end, 3.5, Color(0.12, 0.80, 0.66, 1.0))
			pipe_canvas.draw_circle(p_end, 1.5, Color.WHITE)

			# パルス/エナジーフロー粒子
			var w_val: int = GameData.get_infuser_slot_weight(slot_id)
			var pulse_speed := 0.6 + minf(float(w_val) * 0.08, 1.2)
			_draw_flow_pulses(path_points, flow_time + float(i) * 0.25, pulse_speed)
		else:
			# 停止時（休止管）
			pipe_canvas.draw_polyline(path_points, Color(0.03, 0.12, 0.11, 0.6), 5.0, true)
			pipe_canvas.draw_polyline(path_points, Color(0.08, 0.28, 0.26, 0.45), 2.0, true)
			pipe_canvas.draw_circle(p_start, 2.5, Color(0.08, 0.26, 0.24, 0.5))
			pipe_canvas.draw_circle(p_end, 2.5, Color(0.08, 0.26, 0.24, 0.5))


func _build_rounded_l_path(start: Vector2, corner: Vector2, end: Vector2, radius: float, is_left: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(start)

	var r := minf(radius, minf(absf(corner.y - start.y) * 0.45, absf(end.x - corner.x) * 0.45))
	if r <= 2.0:
		pts.append(corner)
		pts.append(end)
		return pts

	# 下降して corner.y - r まで
	pts.append(Vector2(corner.x, corner.y - r))

	# 角丸（円弧補間）
	var arc_center := Vector2(corner.x - r if is_left else corner.x + r, corner.y - r)
	var start_angle := 0.0 if is_left else PI
	var sweep_angle := 0.5 * PI if is_left else -0.5 * PI
	var segs := 5
	for s in range(1, segs):
		var theta := start_angle + sweep_angle * (float(s) / float(segs))
		var pt := arc_center + Vector2(cos(theta), sin(theta)) * r
		pts.append(pt)

	pts.append(Vector2(corner.x - r if is_left else corner.x + r, corner.y))
	pts.append(end)
	return pts


func _draw_flow_pulses(points: PackedVector2Array, time_offset: float, speed: float = 0.7) -> void:
	if points.size() < 2:
		return

	var total_len := 0.0
	var seg_lens: Array[float] = []
	for k in range(points.size() - 1):
		var d := points[k].distance_to(points[k + 1])
		seg_lens.append(d)
		total_len += d

	if total_len <= 1.0:
		return

	var pulse_count := 2
	for p_idx in range(pulse_count):
		var phase: float = fmod(time_offset * speed + float(p_idx) / float(pulse_count), 1.0)
		var target_dist := phase * total_len

		var cur_d := 0.0
		var pulse_pos := points[0]
		for k in range(seg_lens.size()):
			var d_seg := seg_lens[k]
			if cur_d + d_seg >= target_dist:
				var t_seg := (target_dist - cur_d) / maxf(1.0, d_seg)
				pulse_pos = points[k].lerp(points[k + 1], t_seg)
				break
			cur_d += d_seg

		pipe_canvas.draw_circle(pulse_pos, 4.0, Color(0.20, 0.90, 0.75, 0.35))
		pipe_canvas.draw_circle(pulse_pos, 2.4, Color(0.50, 0.98, 0.85, 0.95))
		pipe_canvas.draw_circle(pulse_pos, 1.2, Color.WHITE)


func _on_hub_water_draw() -> void:
	if not is_instance_valid(hub_panel) or not is_instance_valid(hub_water_canvas):
		return

	var panel_size := hub_panel.size
	if panel_size.x <= 20.0 or panel_size.y <= 20.0:
		return

	# HubPanel 全体に描画されるようローカルオフセットを設定
	hub_water_canvas.draw_set_transform(-hub_water_canvas.position, 0.0, Vector2.ONE)

	var w := panel_size.x
	var h := panel_size.y
	var t := float(Time.get_ticks_msec()) / 1000.0

	var x_left := 2.0
	var x_right := w - 2.0
	var y_bottom := h - 2.0

	# 水面の基準高さをハブの中央付近に設定
	var base_y := h * 0.46

	# 大きくゆったりとした大波用のサンプリング点生成（細かさを排除し大まかなうねりに）
	var step := 12.0
	var num_pts := int(ceil((x_right - x_left) / step)) + 1
	var x_vals := PackedFloat32Array()
	x_vals.resize(num_pts)
	for i in range(num_pts):
		x_vals[i] = minf(x_left + float(i) * step, x_right)

	# --- 第1層: 奥側の大きなゆったりとしたうねり（極薄） ---
	var pts_back := PackedVector2Array()
	for i in range(num_pts):
		var x := x_vals[i]
		# 波長 約1000px と 約480px の大きなうねり
		var y := base_y - 4.0 + sin(x * 0.006 + t * 0.32) * 5.0 + cos(x * 0.013 - t * 0.22) * 2.2
		pts_back.append(Vector2(x, y))

	var poly_back := pts_back.duplicate()
	poly_back.append(Vector2(x_right, y_bottom - 6.0))
	poly_back.append(Vector2(x_right - 2.0, y_bottom - 2.0))
	poly_back.append(Vector2(x_right - 6.0, y_bottom))
	poly_back.append(Vector2(x_left + 6.0, y_bottom))
	poly_back.append(Vector2(x_left + 2.0, y_bottom - 2.0))
	poly_back.append(Vector2(x_left, y_bottom - 6.0))
	hub_water_canvas.draw_colored_polygon(poly_back, Color(0.04, 0.20, 0.17, 0.04))
	hub_water_canvas.draw_polyline(pts_back, Color(0.12, 0.55, 0.45, 0.07), 1.2, true)

	# --- 第2層: 手前の大きな主水面（極薄で文字可読性を優先） ---
	var pts_front := PackedVector2Array()
	for i in range(num_pts):
		var x := x_vals[i]
		# 波長 約700px と 約360px の大まかなうねり
		var y := base_y + 2.0 + sin(x * 0.009 + t * 0.42 + 1.8) * 6.0 + cos(x * 0.017 - t * 0.30) * 2.8
		pts_front.append(Vector2(x, y))

	var poly_front := pts_front.duplicate()
	poly_front.append(Vector2(x_right, y_bottom - 6.0))
	poly_front.append(Vector2(x_right - 2.0, y_bottom - 2.0))
	poly_front.append(Vector2(x_right - 6.0, y_bottom))
	poly_front.append(Vector2(x_left + 6.0, y_bottom))
	poly_front.append(Vector2(x_left + 2.0, y_bottom - 2.0))
	poly_front.append(Vector2(x_left, y_bottom - 6.0))
	hub_water_canvas.draw_colored_polygon(poly_front, Color(0.06, 0.30, 0.25, 0.06))

	# 水面ライン（文字の邪魔にならない淡い光筋）
	hub_water_canvas.draw_polyline(pts_front, Color(0.22, 0.85, 0.72, 0.15), 1.8, true)
	hub_water_canvas.draw_polyline(pts_front, Color(0.55, 0.95, 0.85, 0.22), 1.0, true)
