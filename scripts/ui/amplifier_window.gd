class_name AmplifierWindow
extends BaseWindow
## 融合ウィンドウ (Fusion Window)
## UIノードはすべて scenes/ui/amplifier_window.tscn 内に静的に配置されており、
## インスペクタ・エディタ上から直接編集可能。

var _ui_timer: Timer = null
var _shake_timer: float = 0.0

@export_group("Card & Text Colors")
@export var card_bg_affordable: Color = Color(0.18, 0.42, 0.78, 1.0)
@export var card_bg_normal: Color = Color(0.10, 0.15, 0.24, 1.0)
@export var card_border_color: Color = Color(0.05, 0.06, 0.09, 1.0)
@export var cost_text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var cost_color_unaffordable: Color = Color.RED

# --- ゴールドセクション参照 (%UniqueName) ---
@onready var _gold_total_label: Label = get_node_or_null("%GoldTotalLabel")
@onready var _gold_base_btn: Button = get_node_or_null("%GoldBaseBtn")
@onready var _gold_base_val_lbl: Label = get_node_or_null("%GoldBaseValLabel")
@onready var _gold_base_cost_lbl: Label = get_node_or_null("%GoldBaseCostLabel")
@onready var _gold_seal_cost_lbl: Label = get_node_or_null("%GoldSealCostLabel")

@onready var _gold_mult_btn: Button = get_node_or_null("%GoldMultBtn")
@onready var _gold_mult_val_lbl: Label = get_node_or_null("%GoldMultValLabel")
@onready var _gold_mult_cost_lbl: Label = get_node_or_null("%GoldMultCostLabel")

@onready var _gold_mult_b_btn: Button = get_node_or_null("%GoldMultBBtn")
@onready var _gold_mult_b_val_lbl: Label = get_node_or_null("%GoldMultBValLabel")
@onready var _gold_mult_b_cost_lbl: Label = get_node_or_null("%GoldMultBCostLabel")

@onready var _gold_pow_btn: Button = get_node_or_null("%GoldPowBtn")
@onready var _gold_pow_val_lbl: Label = get_node_or_null("%GoldPowValLabel")
@onready var _gold_pow_cost_lbl: Label = get_node_or_null("%GoldPowCostLabel")

# --- トークンセクション参照 (%UniqueName) ---
@onready var _token_total_label: Label = get_node_or_null("%TokenTotalLabel")
@onready var _token_base_btn: Button = get_node_or_null("%TokenBaseBtn")
@onready var _token_base_val_lbl: Label = get_node_or_null("%TokenBaseValLabel")
@onready var _token_base_cost_lbl: Label = get_node_or_null("%TokenBaseCostLabel")
@onready var _token_seal_cost_lbl: Label = get_node_or_null("%TokenSealCostLabel")

@onready var _token_mult_btn: Button = get_node_or_null("%TokenMultBtn")
@onready var _token_mult_val_lbl: Label = get_node_or_null("%TokenMultValLabel")
@onready var _token_mult_cost_lbl: Label = get_node_or_null("%TokenMultCostLabel")

@onready var _token_mult_b_btn: Button = get_node_or_null("%TokenMultBBtn")
@onready var _token_mult_b_val_lbl: Label = get_node_or_null("%TokenMultBValLabel")
@onready var _token_mult_b_cost_lbl: Label = get_node_or_null("%TokenMultBCostLabel")

@onready var _token_pow_btn: Button = get_node_or_null("%TokenPowBtn")
@onready var _token_pow_val_lbl: Label = get_node_or_null("%TokenPowValLabel")
@onready var _token_pow_cost_lbl: Label = get_node_or_null("%TokenPowCostLabel")


func _ready() -> void:
	header_color = Color(0.18, 0.42, 0.78, 1.0)
	separator_color = Color(0.0, 0.0, 0.0, 1.0)
	super._ready()

	# ボタン押下シグナル接続
	if _gold_base_btn:
		_gold_base_btn.pressed.connect(func(): GameData.buy_amp_gold_base_unlock())
	if _gold_mult_btn:
		_gold_mult_btn.pressed.connect(func(): GameData.buy_amp_gold_mult())
	if _gold_mult_b_btn:
		_gold_mult_b_btn.pressed.connect(func(): GameData.buy_amp_gold_mult_b())
	if _gold_pow_btn:
		_gold_pow_btn.pressed.connect(func(): GameData.buy_amp_gold_pow())

	if _token_base_btn:
		_token_base_btn.pressed.connect(func(): GameData.buy_amp_token_base_unlock())
	if _token_mult_btn:
		_token_mult_btn.pressed.connect(func(): GameData.buy_amp_token_mult())
	if _token_mult_b_btn:
		_token_mult_b_btn.pressed.connect(func(): GameData.buy_amp_token_mult_b())
	if _token_pow_btn:
		_token_pow_btn.pressed.connect(func(): GameData.buy_amp_token_pow())

	GameData.amplifier_changed.connect(update_all)
	GameData.reincarnation_performed.connect(update_all)

	# ウィンドウ表示中のみ0.1秒ごとに数値を更新するスロットリングタイマー
	_ui_timer = Timer.new()
	_ui_timer.wait_time = 0.1
	_ui_timer.autostart = true
	_ui_timer.timeout.connect(_on_ui_timer_timeout)
	add_child(_ui_timer)

	update_all()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_shake_timer += delta

	var gold_sealed := not GameData.amp_gold_base_unlocked
	var gold_can_unlock := GameData.tokens >= GameData.AMP_GOLD_BASE_UNLOCK_COST
	_update_sealed_button_shake(_gold_base_btn, gold_sealed, gold_can_unlock, 0.0)

	var token_sealed := not GameData.amp_token_base_unlocked
	var token_can_unlock := GameData.gold >= GameData.AMP_TOKEN_BASE_UNLOCK_COST
	_update_sealed_button_shake(_token_base_btn, token_sealed, token_can_unlock, 1.35)


func _update_sealed_button_shake(btn: Button, is_sealed: bool, can_unlock: bool, phase_offset: float) -> void:
	if not btn:
		return

	var t: float = _shake_timer + phase_offset

	# 1. 常時の高周波微振動（ピキピキとした微細な揺れ）
	var base_freq := 42.0
	var jx := sin(t * base_freq) * 0.45 + sin(t * 73.0) * 0.25
	var jy := cos(t * (base_freq * 1.15)) * 0.45 + cos(t * 61.0) * 0.25
	var jrot := sin(t * 33.0) * 0.005

	# 2. 定期的な脈動・軋み（2.2秒周期でガタガタッと身悶えするバースト）
	var cycle_time := fmod(t, 2.2)
	var spasm := 0.0
	if cycle_time < 0.45:
		var norm := cycle_time / 0.45
		spasm = sin(norm * PI)

	var rattle_freq := 30.0
	var sx := sin(t * rattle_freq) * 2.2 * spasm
	var sy := cos(t * (rattle_freq * 0.85)) * 1.5 * spasm
	var srot := sin(t * (rattle_freq * 0.7)) * 0.024 * spasm # 約 1.37度

	# 解放後も躍動的な振動を継続
	var boost := 1.25 if (can_unlock or not is_sealed) else 1.0

	btn.position = Vector2((jx + sx) * boost, (jy + sy) * boost)
	btn.rotation = (jrot + srot) * boost


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			update_all()


func _on_ui_timer_timeout() -> void:
	if is_visible_in_tree():
		update_all()


func _format_decimal_val(val: float) -> String:
	if val >= 1e10:
		return GameData.format_num(val)
	return "%.2f" % val


func _apply_box_style(btn: Button, can_afford: bool, is_unlocked_max: bool = false, _is_gold_cost: bool = false) -> void:
	if not btn:
		return
	var bg_col := card_bg_normal
	var border_col := card_border_color

	if is_unlocked_max:
		bg_col = card_bg_affordable
	elif can_afford:
		bg_col = card_bg_affordable
	else:
		bg_col = card_bg_normal

	var st_normal := StyleBoxFlat.new()
	st_normal.bg_color = bg_col
	st_normal.border_width_left = 2
	st_normal.border_width_top = 2
	st_normal.border_width_right = 2
	st_normal.border_width_bottom = 2
	st_normal.border_color = border_col
	st_normal.set_corner_radius_all(8)
	st_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	st_normal.shadow_size = 2
	st_normal.shadow_offset = Vector2(0, 1)

	var st_hover := st_normal.duplicate() as StyleBoxFlat
	if can_afford and not is_unlocked_max:
		st_hover.bg_color = bg_col.lightened(0.10)
		st_hover.shadow_size = 3
		st_hover.shadow_offset = Vector2(0, 2)

	var st_pressed := st_normal.duplicate() as StyleBoxFlat
	if can_afford and not is_unlocked_max:
		st_pressed.bg_color = bg_col.darkened(0.10)

	var st_disabled := st_normal.duplicate() as StyleBoxFlat

	btn.add_theme_stylebox_override("normal", st_normal)
	btn.add_theme_stylebox_override("hover", st_hover)
	btn.add_theme_stylebox_override("pressed", st_pressed)
	btn.add_theme_stylebox_override("disabled", st_disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func update_all() -> void:
	if not _gold_total_label:
		return

	var gold := GameData.gold
	var tokens := GameData.tokens

	# --- 1. ゴールド倍率セクションの更新 (コストはすべてトークン💎) ---
	var g_base := GameData.get_amp_gold_base_val()
	var g_mult := GameData.get_amp_gold_mult_val()
	var g_mult_b := GameData.get_amp_gold_mult_b_val()
	var g_pow := GameData.get_amp_gold_pow_val()
	var g_total := GameData.get_amp_gold_total_mult()

	_gold_total_label.text = "x%s" % GameData.format_num(g_total)

	# ゴールド ボーナス (解放前: 鎖で封印 + 上にコスト / 解放後: 現在のカードスタイル、下枠にlog表記)
	var g_vbox := _gold_base_btn.get_node_or_null("VBox") as Control if _gold_base_btn else null
	var g_seal := _gold_base_btn.get_node_or_null("SealOverlay") as Control if _gold_base_btn else null
	if GameData.amp_gold_base_unlocked:
		if g_vbox:
			g_vbox.visible = true
		if g_seal:
			g_seal.visible = false
		_gold_base_val_lbl.text = _format_decimal_val(g_base)
		_gold_base_val_lbl.add_theme_font_size_override("font_size", 21)
		_gold_base_cost_lbl.text = "＝ log₁₀(💎 %s)" % GameData.format_num(tokens)
		_gold_base_cost_lbl.add_theme_color_override("font_color", cost_text_color)
		_gold_base_btn.disabled = true
		_apply_box_style(_gold_base_btn, false, true, false)
	else:
		var unlock_cost := GameData.AMP_GOLD_BASE_UNLOCK_COST
		var can_unlock := tokens >= unlock_cost
		if g_vbox:
			g_vbox.visible = false
		if g_seal:
			g_seal.visible = true
		if _gold_seal_cost_lbl:
			_gold_seal_cost_lbl.text = "コスト: 💎 %s" % GameData.format_num(unlock_cost)
			_gold_seal_cost_lbl.add_theme_color_override("font_color", cost_text_color if can_unlock else cost_color_unaffordable)
		_gold_base_btn.disabled = not can_unlock
		_apply_box_style(_gold_base_btn, can_unlock, false, false)

	# ゴールド 倍率α - トークン消費
	var g_mult_cost := GameData.get_amp_gold_mult_cost()
	var can_g_mult := tokens >= g_mult_cost
	_gold_mult_val_lbl.text = _format_decimal_val(g_mult)
	_gold_mult_cost_lbl.text = "コスト: 💎 %s" % GameData.format_num(g_mult_cost)
	_gold_mult_cost_lbl.add_theme_color_override("font_color", cost_text_color if can_g_mult else cost_color_unaffordable)
	_gold_mult_btn.disabled = not can_g_mult
	_apply_box_style(_gold_mult_btn, can_g_mult, false, false)

	# ゴールド 倍率β - トークン消費
	if _gold_mult_b_btn and _gold_mult_b_val_lbl and _gold_mult_b_cost_lbl:
		var g_mult_b_cost := GameData.get_amp_gold_mult_b_cost()
		var can_g_mult_b := tokens >= g_mult_b_cost
		_gold_mult_b_val_lbl.text = _format_decimal_val(g_mult_b)
		_gold_mult_b_cost_lbl.text = "コスト: 💎 %s" % GameData.format_num(g_mult_b_cost)
		_gold_mult_b_cost_lbl.add_theme_color_override("font_color", cost_text_color if can_g_mult_b else cost_color_unaffordable)
		_gold_mult_b_btn.disabled = not can_g_mult_b
		_apply_box_style(_gold_mult_b_btn, can_g_mult_b, false, false)

	# ゴールド パワー - トークン消費
	var g_pow_cost := GameData.get_amp_gold_pow_cost()
	var can_g_pow := tokens >= g_pow_cost
	_gold_pow_val_lbl.text = _format_decimal_val(g_pow)
	_gold_pow_cost_lbl.text = "コスト: 💎 %s" % GameData.format_num(g_pow_cost)
	_gold_pow_cost_lbl.add_theme_color_override("font_color", cost_text_color if can_g_pow else cost_color_unaffordable)
	_gold_pow_btn.disabled = not can_g_pow
	_apply_box_style(_gold_pow_btn, can_g_pow, false, false)

	# --- 2. トークン倍率セクションの更新 (コストはすべてゴールド🪙) ---
	var t_base := GameData.get_amp_token_base_val()
	var t_mult := GameData.get_amp_token_mult_val()
	var t_mult_b := GameData.get_amp_token_mult_b_val()
	var t_pow := GameData.get_amp_token_pow_val()
	var t_total := GameData.get_amp_token_total_mult()

	_token_total_label.text = "x%s" % GameData.format_num(t_total)

	# トークン ボーナス (解放前: 鎖で封印 + 上にコスト / 解放後: 現在のカードスタイル、下枠にlog表記)
	var t_vbox := _token_base_btn.get_node_or_null("VBox") as Control if _token_base_btn else null
	var t_seal := _token_base_btn.get_node_or_null("SealOverlay") as Control if _token_base_btn else null
	if GameData.amp_token_base_unlocked:
		if t_vbox:
			t_vbox.visible = true
		if t_seal:
			t_seal.visible = false
		_token_base_val_lbl.text = _format_decimal_val(t_base)
		_token_base_val_lbl.add_theme_font_size_override("font_size", 21)
		_token_base_cost_lbl.text = "＝ log₁₀(🪙 %s)" % GameData.format_num(gold)
		_token_base_cost_lbl.add_theme_color_override("font_color", cost_text_color)
		_token_base_btn.disabled = true
		_apply_box_style(_token_base_btn, false, true, true)
	else:
		var unlock_cost := GameData.AMP_TOKEN_BASE_UNLOCK_COST
		var can_unlock := gold >= unlock_cost
		if t_vbox:
			t_vbox.visible = false
		if t_seal:
			t_seal.visible = true
		if _token_seal_cost_lbl:
			_token_seal_cost_lbl.text = "コスト: 🪙 %s" % GameData.format_num(unlock_cost)
			_token_seal_cost_lbl.add_theme_color_override("font_color", cost_text_color if can_unlock else cost_color_unaffordable)
		_token_base_btn.disabled = not can_unlock
		_apply_box_style(_token_base_btn, can_unlock, false, true)

	# トークン 倍率α - ゴールド消費
	var t_mult_cost := GameData.get_amp_token_mult_cost()
	var can_t_mult := gold >= t_mult_cost
	_token_mult_val_lbl.text = _format_decimal_val(t_mult)
	_token_mult_cost_lbl.text = "コスト: 🪙 %s" % GameData.format_num(t_mult_cost)
	_token_mult_cost_lbl.add_theme_color_override("font_color", cost_text_color if can_t_mult else cost_color_unaffordable)
	_token_mult_btn.disabled = not can_t_mult
	_apply_box_style(_token_mult_btn, can_t_mult, false, true)

	# トークン 倍率β - ゴールド消費
	if _token_mult_b_btn and _token_mult_b_val_lbl and _token_mult_b_cost_lbl:
		var t_mult_b_cost := GameData.get_amp_token_mult_b_cost()
		var can_t_mult_b := gold >= t_mult_b_cost
		_token_mult_b_val_lbl.text = _format_decimal_val(t_mult_b)
		_token_mult_b_cost_lbl.text = "コスト: 🪙 %s" % GameData.format_num(t_mult_b_cost)
		_token_mult_b_cost_lbl.add_theme_color_override("font_color", cost_text_color if can_t_mult_b else cost_color_unaffordable)
		_token_mult_b_btn.disabled = not can_t_mult_b
		_apply_box_style(_token_mult_b_btn, can_t_mult_b, false, true)

	# トークン パワー - ゴールド消費
	var t_pow_cost := GameData.get_amp_token_pow_cost()
	var can_t_pow := gold >= t_pow_cost
	_token_pow_val_lbl.text = _format_decimal_val(t_pow)
	_token_pow_cost_lbl.text = "コスト: 🪙 %s" % GameData.format_num(t_pow_cost)
	_token_pow_cost_lbl.add_theme_color_override("font_color", cost_text_color if can_t_pow else cost_color_unaffordable)
	_token_pow_btn.disabled = not can_t_pow
	_apply_box_style(_token_pow_btn, can_t_pow, false, true)
