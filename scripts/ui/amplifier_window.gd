class_name AmplifierWindow
extends BaseWindow
## 融合ウィンドウ (Fusion Window)
## UIノードはすべて scenes/ui/amplifier_window.tscn 内に静的に配置されており、
## インスペクタ・エディタ上から直接編集可能。

var _ui_timer: Timer = null
var _shake_timer: float = 0.0

@export_group("Card & Text Colors")
@export var gold_card_bg_affordable: Color = Color(0.92, 0.68, 0.12, 1.0)
@export var gold_card_bg_normal: Color = Color(0.18, 0.15, 0.09, 1.0)
@export var token_card_bg_affordable: Color = Color(0.18, 0.42, 0.78, 1.0)
@export var token_card_bg_normal: Color = Color(0.10, 0.15, 0.24, 1.0)
@export var card_bg_affordable: Color = Color(0.18, 0.42, 0.78, 1.0)
@export var card_bg_normal: Color = Color(0.10, 0.15, 0.24, 1.0)
@export var card_border_color: Color = Color(0.05, 0.06, 0.09, 1.0)
@export var cost_text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var cost_color_unaffordable: Color = Color.RED

const BUY_MODES: Array[int] = [1, 5, 10, 100, -1] # -1 represents MAX

var _buy_mode_indices: Dictionary = {
	"gold_mult": 0,
	"gold_mult_b": 0,
	"gold_pow": 0,
	"token_mult": 0,
	"token_mult_b": 0,
	"token_pow": 0,
}

# --- ゴールドセクション参照 (%UniqueName) ---
@onready var _gold_total_label: Label = get_node_or_null("%GoldTotalLabel")
@onready var _gold_base_btn: Button = get_node_or_null("%GoldBaseBtn")
@onready var _gold_base_val_lbl: Label = get_node_or_null("%GoldBaseValLabel")
@onready var _gold_base_cost_lbl: Label = get_node_or_null("%GoldBaseCostLabel")
@onready var _gold_seal_cost_lbl: Label = get_node_or_null("%GoldSealCostLabel")

@onready var _gold_mult_btn: Button = get_node_or_null("%GoldMultBtn")
@onready var _gold_mult_val_lbl: Label = get_node_or_null("%GoldMultValLabel")
@onready var _gold_mult_cost_lbl: Label = get_node_or_null("%GoldMultCostLabel")
@onready var _gold_mult_mode_btn: Button = get_node_or_null("%GoldMultModeBtn")

@onready var _gold_mult_b_btn: Button = get_node_or_null("%GoldMultBBtn")
@onready var _gold_mult_b_val_lbl: Label = get_node_or_null("%GoldMultBValLabel")
@onready var _gold_mult_b_cost_lbl: Label = get_node_or_null("%GoldMultBCostLabel")
@onready var _gold_mult_b_mode_btn: Button = get_node_or_null("%GoldMultBModeBtn")

@onready var _gold_pow_btn: Button = get_node_or_null("%GoldPowBtn")
@onready var _gold_pow_val_lbl: Label = get_node_or_null("%GoldPowValLabel")
@onready var _gold_pow_cost_lbl: Label = get_node_or_null("%GoldPowCostLabel")
@onready var _gold_pow_mode_btn: Button = get_node_or_null("%GoldPowModeBtn")

# --- トークンセクション参照 (%UniqueName) ---
@onready var _token_total_label: Label = get_node_or_null("%TokenTotalLabel")
@onready var _token_base_btn: Button = get_node_or_null("%TokenBaseBtn")
@onready var _token_base_val_lbl: Label = get_node_or_null("%TokenBaseValLabel")
@onready var _token_base_cost_lbl: Label = get_node_or_null("%TokenBaseCostLabel")
@onready var _token_seal_cost_lbl: Label = get_node_or_null("%TokenSealCostLabel")

@onready var _token_mult_btn: Button = get_node_or_null("%TokenMultBtn")
@onready var _token_mult_val_lbl: Label = get_node_or_null("%TokenMultValLabel")
@onready var _token_mult_cost_lbl: Label = get_node_or_null("%TokenMultCostLabel")
@onready var _token_mult_mode_btn: Button = get_node_or_null("%TokenMultModeBtn")

@onready var _token_mult_b_btn: Button = get_node_or_null("%TokenMultBBtn")
@onready var _token_mult_b_val_lbl: Label = get_node_or_null("%TokenMultBValLabel")
@onready var _token_mult_b_cost_lbl: Label = get_node_or_null("%TokenMultBCostLabel")
@onready var _token_mult_b_mode_btn: Button = get_node_or_null("%TokenMultBModeBtn")

@onready var _token_pow_btn: Button = get_node_or_null("%TokenPowBtn")
@onready var _token_pow_val_lbl: Label = get_node_or_null("%TokenPowValLabel")
@onready var _token_pow_cost_lbl: Label = get_node_or_null("%TokenPowCostLabel")
@onready var _token_pow_mode_btn: Button = get_node_or_null("%TokenPowModeBtn")


func _ready() -> void:
	super._ready()

	# ボーナスボタン押下シグナル接続
	if _gold_base_btn:
		_gold_base_btn.pressed.connect(func(): GameData.buy_amp_gold_base_unlock())
	if _token_base_btn:
		_token_base_btn.pressed.connect(func(): GameData.buy_amp_token_base_unlock())

	# アップグレード購入ボタン押下シグナル接続
	if _gold_mult_btn:
		_gold_mult_btn.pressed.connect(func(): _buy_upgrade("gold_mult"))
	if _gold_mult_b_btn:
		_gold_mult_b_btn.pressed.connect(func(): _buy_upgrade("gold_mult_b"))
	if _gold_pow_btn:
		_gold_pow_btn.pressed.connect(func(): _buy_upgrade("gold_pow"))

	if _token_mult_btn:
		_token_mult_btn.pressed.connect(func(): _buy_upgrade("token_mult"))
	if _token_mult_b_btn:
		_token_mult_b_btn.pressed.connect(func(): _buy_upgrade("token_mult_b"))
	if _token_pow_btn:
		_token_pow_btn.pressed.connect(func(): _buy_upgrade("token_pow"))

	# モード切替ボタン押下シグナル接続
	if _gold_mult_mode_btn:
		_gold_mult_mode_btn.pressed.connect(func(): _cycle_buy_mode("gold_mult"))
	if _gold_mult_b_mode_btn:
		_gold_mult_b_mode_btn.pressed.connect(func(): _cycle_buy_mode("gold_mult_b"))
	if _gold_pow_mode_btn:
		_gold_pow_mode_btn.pressed.connect(func(): _cycle_buy_mode("gold_pow"))

	if _token_mult_mode_btn:
		_token_mult_mode_btn.pressed.connect(func(): _cycle_buy_mode("token_mult"))
	if _token_mult_b_mode_btn:
		_token_mult_b_mode_btn.pressed.connect(func(): _cycle_buy_mode("token_mult_b"))
	if _token_pow_mode_btn:
		_token_pow_mode_btn.pressed.connect(func(): _cycle_buy_mode("token_pow"))

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


func _apply_box_style(btn: Button, can_afford: bool, is_unlocked_max: bool = false, is_token_section: bool = false) -> void:
	if not btn:
		return
	var bg_col: Color
	if is_token_section:
		bg_col = token_card_bg_affordable if (can_afford or is_unlocked_max) else token_card_bg_normal
	else:
		bg_col = gold_card_bg_affordable if (can_afford or is_unlocked_max) else gold_card_bg_normal

	var border_col := card_border_color

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


func _apply_mode_btn_style(btn: Button, is_token_section: bool = false) -> void:
	if not btn:
		return
	var bg_col := token_card_bg_affordable if is_token_section else gold_card_bg_affordable
	var border_col := card_border_color

	var st_normal := StyleBoxFlat.new()
	st_normal.content_margin_left = 0.0
	st_normal.content_margin_top = 0.0
	st_normal.content_margin_right = 0.0
	st_normal.content_margin_bottom = 0.0
	st_normal.bg_color = bg_col
	st_normal.border_width_left = 2
	st_normal.border_width_top = 2
	st_normal.border_width_right = 2
	st_normal.border_width_bottom = 2
	st_normal.border_color = border_col
	st_normal.set_corner_radius_all(8)
	st_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	st_normal.shadow_size = 2
	st_normal.shadow_offset = Vector2(0, 1)

	var st_hover := st_normal.duplicate() as StyleBoxFlat
	st_hover.bg_color = bg_col.lightened(0.12)
	st_hover.shadow_size = 3

	var st_pressed := st_normal.duplicate() as StyleBoxFlat
	st_pressed.bg_color = bg_col.darkened(0.12)
	st_pressed.shadow_size = 1

	var st_disabled := st_normal.duplicate() as StyleBoxFlat

	btn.add_theme_stylebox_override("normal", st_normal)
	btn.add_theme_stylebox_override("hover", st_hover)
	btn.add_theme_stylebox_override("pressed", st_pressed)
	btn.add_theme_stylebox_override("disabled", st_disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# 親ボタンの disabled によるフォント色の減衰（グレーアウト）を防ぎ、常に明るい白を維持
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.92, 0.95, 1, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 1))
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.09, 1.0))


func _format_mode_text(mode: int) -> String:
	if mode == -1:
		return "最大"
	return str(mode)


func _cycle_buy_mode(key: String) -> void:
	if not _buy_mode_indices.has(key):
		return
	_buy_mode_indices[key] = (_buy_mode_indices[key] + 1) % BUY_MODES.size()
	update_all()


func _buy_upgrade(key: String) -> void:
	var mode: int = BUY_MODES[_buy_mode_indices.get(key, 0)]
	match key:
		"gold_mult":
			var count := GameData.get_amp_gold_mult_max_count() if mode == -1 else mode
			if count > 0:
				GameData.buy_amp_gold_mult(count)
		"gold_mult_b":
			var count := GameData.get_amp_gold_mult_b_max_count() if mode == -1 else mode
			if count > 0:
				GameData.buy_amp_gold_mult_b(count)
		"gold_pow":
			var count := GameData.get_amp_gold_pow_max_count() if mode == -1 else mode
			if count > 0:
				GameData.buy_amp_gold_pow(count)
		"token_mult":
			var count := GameData.get_amp_token_mult_max_count() if mode == -1 else mode
			if count > 0:
				GameData.buy_amp_token_mult(count)
		"token_mult_b":
			var count := GameData.get_amp_token_mult_b_max_count() if mode == -1 else mode
			if count > 0:
				GameData.buy_amp_token_mult_b(count)
		"token_pow":
			var count := GameData.get_amp_token_pow_max_count() if mode == -1 else mode
			if count > 0:
				GameData.buy_amp_token_pow(count)


func _update_upgrade_card(
	btn: Button,
	val_lbl: Label,
	cost_lbl: Label,
	mode_btn: Button,
	key: String,
	current_val: float,
	user_currency: float,
	currency_sym: String,
	cost_func: Callable,
	max_count_func: Callable,
	is_token_section: bool
) -> void:
	if not btn or not val_lbl or not cost_lbl:
		return

	var mode: int = BUY_MODES[_buy_mode_indices.get(key, 0)]
	if mode_btn:
		mode_btn.text = _format_mode_text(mode)

	var cost: float = 0.0
	var can_afford: bool = false

	if mode == -1: # MAX
		var max_cnt: int = max_count_func.call()
		if max_cnt > 0:
			cost = cost_func.call(max_cnt)
			can_afford = true
			cost_lbl.text = "コスト: %s %s (+%d)" % [currency_sym, GameData.format_num(cost), max_cnt]
		else:
			cost = cost_func.call(1)
			can_afford = false
			cost_lbl.text = "コスト: %s %s (+0)" % [currency_sym, GameData.format_num(cost)]
	else:
		cost = cost_func.call(mode)
		can_afford = user_currency >= cost
		cost_lbl.text = "コスト: %s %s" % [currency_sym, GameData.format_num(cost)]

	val_lbl.text = _format_decimal_val(current_val)
	cost_lbl.add_theme_color_override("font_color", cost_text_color if can_afford else cost_color_unaffordable)
	btn.disabled = not can_afford
	_apply_box_style(btn, can_afford, false, is_token_section)
	if mode_btn:
		_apply_mode_btn_style(mode_btn, is_token_section)


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

	# ゴールド 倍率α
	_update_upgrade_card(
		_gold_mult_btn, _gold_mult_val_lbl, _gold_mult_cost_lbl, _gold_mult_mode_btn,
		"gold_mult", g_mult, tokens, "💎",
		Callable(GameData, "get_amp_gold_mult_cost"),
		Callable(GameData, "get_amp_gold_mult_max_count"),
		false
	)

	# ゴールド 倍率β
	_update_upgrade_card(
		_gold_mult_b_btn, _gold_mult_b_val_lbl, _gold_mult_b_cost_lbl, _gold_mult_b_mode_btn,
		"gold_mult_b", g_mult_b, tokens, "💎",
		Callable(GameData, "get_amp_gold_mult_b_cost"),
		Callable(GameData, "get_amp_gold_mult_b_max_count"),
		false
	)

	# ゴールド パワー
	_update_upgrade_card(
		_gold_pow_btn, _gold_pow_val_lbl, _gold_pow_cost_lbl, _gold_pow_mode_btn,
		"gold_pow", g_pow, tokens, "💎",
		Callable(GameData, "get_amp_gold_pow_cost"),
		Callable(GameData, "get_amp_gold_pow_max_count"),
		false
	)

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

	# トークン 倍率α
	_update_upgrade_card(
		_token_mult_btn, _token_mult_val_lbl, _token_mult_cost_lbl, _token_mult_mode_btn,
		"token_mult", t_mult, gold, "🪙",
		Callable(GameData, "get_amp_token_mult_cost"),
		Callable(GameData, "get_amp_token_mult_max_count"),
		true
	)

	# トークン 倍率β
	_update_upgrade_card(
		_token_mult_b_btn, _token_mult_b_val_lbl, _token_mult_b_cost_lbl, _token_mult_b_mode_btn,
		"token_mult_b", t_mult_b, gold, "🪙",
		Callable(GameData, "get_amp_token_mult_b_cost"),
		Callable(GameData, "get_amp_token_mult_b_max_count"),
		true
	)

	# トークン パワー
	_update_upgrade_card(
		_token_pow_btn, _token_pow_val_lbl, _token_pow_cost_lbl, _token_pow_mode_btn,
		"token_pow", t_pow, gold, "🪙",
		Callable(GameData, "get_amp_token_pow_cost"),
		Callable(GameData, "get_amp_token_pow_max_count"),
		true
	)
