extends BaseWindow
## Window for configuring automations (Auto Ascension, Auto Base Upgrade Buying).

@onready var auto_ascend_card: PanelContainer = %AutoAscendCard
@onready var auto_ascend_unlock_label: Label = %AutoAscendUnlockLabel
@onready var auto_ascend_content: VBoxContainer = %AutoAscendContent
@onready var auto_ascend_toggle: CheckButton = %AutoAscendToggle
@onready var auto_ascend_level_spin: SpinBox = %AutoAscendLevelSpin
@onready var auto_ascend_wait_spin: SpinBox = %AutoAscendWaitSpin
@onready var auto_ascend_status_label: Label = %AutoAscendStatusLabel

@onready var auto_buying_card: PanelContainer = %AutoBuyingCard
@onready var auto_buying_unlock_label: Label = %AutoBuyingUnlockLabel
@onready var auto_buying_content: VBoxContainer = %AutoBuyingContent
@onready var auto_buying_toggle: CheckButton = %AutoBuyingToggle

# Level modifier buttons
@onready var btn_lvl_minus_100: Button = %BtnLvlMinus100
@onready var btn_lvl_minus_10: Button = %BtnLvlMinus10
@onready var btn_lvl_plus_10: Button = %BtnLvlPlus10
@onready var btn_lvl_plus_100: Button = %BtnLvlPlus100

# Wait time preset buttons
@onready var btn_wait_0: Button = %BtnWait0
@onready var btn_wait_30: Button = %BtnWait30
@onready var btn_wait_60: Button = %BtnWait60
@onready var btn_wait_180: Button = %BtnWait180
@onready var btn_wait_300: Button = %BtnWait300

var _is_updating_ui: bool = false


func _ready() -> void:
	super._ready()

	# Connect signals from GameData
	if GameData:
		GameData.auto_settings_changed.connect(_on_game_data_auto_settings_changed)
		GameData.auto_ascend_timer_updated.connect(_on_auto_ascend_timer_updated)
		GameData.upgrades_changed.connect(_update_status_display)
		GameData.skill_upgraded.connect(func(_id, _lvl): _update_unlock_states())

	# Connect UI inputs
	if auto_ascend_toggle:
		auto_ascend_toggle.toggled.connect(_on_auto_ascend_toggle_changed)
	if auto_ascend_level_spin:
		auto_ascend_level_spin.value_changed.connect(_on_level_spin_changed)
	if auto_ascend_wait_spin:
		auto_ascend_wait_spin.value_changed.connect(_on_wait_spin_changed)

	if auto_buying_toggle:
		auto_buying_toggle.toggled.connect(_on_auto_buying_toggle_changed)

	# Level quick buttons
	if btn_lvl_minus_100:
		btn_lvl_minus_100.pressed.connect(func(): _adjust_level(-100))
	if btn_lvl_minus_10:
		btn_lvl_minus_10.pressed.connect(func(): _adjust_level(-10))
	if btn_lvl_plus_10:
		btn_lvl_plus_10.pressed.connect(func(): _adjust_level(10))
	if btn_lvl_plus_100:
		btn_lvl_plus_100.pressed.connect(func(): _adjust_level(100))

	# Wait preset buttons
	if btn_wait_0:
		btn_wait_0.pressed.connect(func(): _set_wait_preset(0.0))
	if btn_wait_30:
		btn_wait_30.pressed.connect(func(): _set_wait_preset(30.0))
	if btn_wait_60:
		btn_wait_60.pressed.connect(func(): _set_wait_preset(60.0))
	if btn_wait_180:
		btn_wait_180.pressed.connect(func(): _set_wait_preset(180.0))
	if btn_wait_300:
		btn_wait_300.pressed.connect(func(): _set_wait_preset(300.0))

	sync_from_data()


func sync_from_data() -> void:
	if not GameData:
		return
	_is_updating_ui = true

	_update_unlock_states()

	if auto_ascend_toggle:
		auto_ascend_toggle.button_pressed = GameData.auto_ascend_enabled
	if auto_ascend_level_spin:
		auto_ascend_level_spin.value = GameData.auto_ascend_min_total_level
	if auto_ascend_wait_spin:
		auto_ascend_wait_spin.value = GameData.auto_ascend_wait_seconds

	if auto_buying_toggle:
		auto_buying_toggle.button_pressed = GameData.auto_status_buying_enabled

	_is_updating_ui = false
	_update_status_display()


func _update_unlock_states() -> void:
	if not GameData:
		return

	# 1. Auto Ascension unlock check
	var is_ascend_unlocked := GameData.get_skill_level("auto_ascension") > 0
	if auto_ascend_unlock_label:
		auto_ascend_unlock_label.visible = not is_ascend_unlocked
	if auto_ascend_content:
		auto_ascend_content.visible = is_ascend_unlocked

	# 2. Auto Buying unlock check
	var is_buying_unlocked := GameData.get_skill_level("auto_status_buying") > 0
	if auto_buying_unlock_label:
		auto_buying_unlock_label.visible = not is_buying_unlocked
	if auto_buying_content:
		auto_buying_content.visible = is_buying_unlocked


func _on_auto_ascend_toggle_changed(enabled: bool) -> void:
	if _is_updating_ui or not GameData:
		return
	GameData.set_auto_ascend_settings(
		enabled,
		int(auto_ascend_level_spin.value),
		float(auto_ascend_wait_spin.value)
	)
	_update_status_display()


func _on_level_spin_changed(val: float) -> void:
	if _is_updating_ui or not GameData:
		return
	GameData.set_auto_ascend_settings(
		auto_ascend_toggle.button_pressed,
		int(val),
		float(auto_ascend_wait_spin.value)
	)
	_update_status_display()


func _on_wait_spin_changed(val: float) -> void:
	if _is_updating_ui or not GameData:
		return
	GameData.set_auto_ascend_settings(
		auto_ascend_toggle.button_pressed,
		int(auto_ascend_level_spin.value),
		float(val)
	)
	_update_status_display()


func _adjust_level(diff: int) -> void:
	if auto_ascend_level_spin:
		var new_val = clampi(int(auto_ascend_level_spin.value) + diff, 100, 99999999)
		auto_ascend_level_spin.value = new_val


func _set_wait_preset(sec: float) -> void:
	if auto_ascend_wait_spin:
		auto_ascend_wait_spin.value = sec


func _on_auto_buying_toggle_changed(enabled: bool) -> void:
	if _is_updating_ui or not GameData:
		return
	GameData.set_auto_status_buying_enabled(enabled)


func _on_game_data_auto_settings_changed() -> void:
	sync_from_data()


func _on_auto_ascend_timer_updated(current_timer: float, wait_seconds: float) -> void:
	_update_timer_label(current_timer, wait_seconds)


func _update_status_display() -> void:
	if not GameData:
		return
	_update_timer_label(GameData.get_auto_ascend_timer(), GameData.auto_ascend_wait_seconds)


func _update_timer_label(current_timer: float, wait_seconds: float) -> void:
	if not auto_ascend_status_label or not GameData:
		return

	if GameData.get_skill_level("auto_ascension") <= 0:
		auto_ascend_status_label.text = ""
		return

	if not GameData.auto_ascend_enabled:
		auto_ascend_status_label.text = "⏸️ 自動アセンション: オフ"
		auto_ascend_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1.0))
		return

	var current_total := GameData.get_base_upgrade_total_level()
	var target_total := GameData.auto_ascend_min_total_level

	if current_total < target_total:
		auto_ascend_status_label.text = "📊 レベル条件判定中: 合計Lv %d / %d (あと %d Lv)" % [
			current_total,
			target_total,
			target_total - current_total
		]
		auto_ascend_status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 1.0))
	else:
		if wait_seconds <= 0.0:
			auto_ascend_status_label.text = "⚡ 条件達成 (即時アセンション対象)"
			auto_ascend_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
		else:
			var remaining := maxf(0.0, wait_seconds - current_timer)
			auto_ascend_status_label.text = "⏳ 稼ぎキープ中: 残り %.1f秒 / %.0f秒 (経過: %.1fs)" % [
				remaining,
				wait_seconds,
				current_timer
			]
			auto_ascend_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
