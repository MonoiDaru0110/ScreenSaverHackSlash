class_name AutoAscendCard
extends AutomationCardBase
## Card for Auto Ascension automation settings with dropdown condition criteria.

const TOTAL_LEVEL_OPTIONS: Array[int] = [100, 150, 250, 500, 1000]
const STAT_LEVEL_OPTIONS: Array[int] = [0, 20, 50, 100, 200]
const WAIT_TIME_OPTIONS: Array[float] = [0.0, 30.0, 60.0, 120.0, 300.0]

@onready var unlock_label: Label = %AutoAscendUnlockLabel
@onready var content_vbox: VBoxContainer = %AutoAscendContent
@onready var main_toggle: CheckBox = %MainToggle
@onready var disable_challenge_check: CheckBox = %DisableDuringChallengeCheck

@onready var total_level_opt: OptionButton = %TotalLevelOpt
@onready var size_level_opt: OptionButton = %SizeLevelOpt
@onready var speed_level_opt: OptionButton = %SpeedLevelOpt
@onready var boost_level_opt: OptionButton = %BoostLevelOpt
@onready var wait_time_opt: OptionButton = %WaitTimeOpt

@onready var status_label: Label = %AutoAscendStatusLabel

var _is_updating_ui: bool = false


func _ready() -> void:
	super._ready()

	# 緑色のチェックマークアイコンを適用
	AutomationCardBase.setup_green_checkbox(main_toggle)
	if disable_challenge_check:
		AutomationCardBase.setup_green_checkbox(disable_challenge_check)

	_setup_options()

	if GameData:
		GameData.auto_settings_changed.connect(_on_settings_changed)
		GameData.auto_ascend_timer_updated.connect(_on_timer_updated)
		GameData.upgrades_changed.connect(_update_status_display)
		GameData.skill_upgraded.connect(func(_id, _lvl): _update_unlock_state())

	if main_toggle:
		main_toggle.toggled.connect(_on_condition_changed)
	if disable_challenge_check:
		disable_challenge_check.toggled.connect(_on_condition_changed)
	if total_level_opt:
		total_level_opt.item_selected.connect(_on_condition_changed)
	if size_level_opt:
		size_level_opt.item_selected.connect(_on_condition_changed)
	if speed_level_opt:
		speed_level_opt.item_selected.connect(_on_condition_changed)
	if boost_level_opt:
		boost_level_opt.item_selected.connect(_on_condition_changed)
	if wait_time_opt:
		wait_time_opt.item_selected.connect(_on_condition_changed)

	sync_from_data()


func _setup_options() -> void:
	if total_level_opt and total_level_opt.item_count == 0:
		for val in TOTAL_LEVEL_OPTIONS:
			total_level_opt.add_item(str(val))

	if size_level_opt and size_level_opt.item_count == 0:
		for val in STAT_LEVEL_OPTIONS:
			size_level_opt.add_item(str(val))

	if speed_level_opt and speed_level_opt.item_count == 0:
		for val in STAT_LEVEL_OPTIONS:
			speed_level_opt.add_item(str(val))

	if boost_level_opt and boost_level_opt.item_count == 0:
		for val in STAT_LEVEL_OPTIONS:
			boost_level_opt.add_item(str(val))

	if wait_time_opt and wait_time_opt.item_count == 0:
		for val in WAIT_TIME_OPTIONS:
			wait_time_opt.add_item(str(int(val)))


func sync_from_data() -> void:
	if not GameData:
		return
	_is_updating_ui = true
	_update_unlock_state()

	if main_toggle:
		main_toggle.button_pressed = GameData.auto_ascend_enabled
	if disable_challenge_check:
		disable_challenge_check.button_pressed = GameData.auto_ascend_disable_during_challenge

	_select_option_closest(total_level_opt, TOTAL_LEVEL_OPTIONS, GameData.auto_ascend_min_total_level)
	_select_option_closest(size_level_opt, STAT_LEVEL_OPTIONS, GameData.auto_ascend_min_size_level)
	_select_option_closest(speed_level_opt, STAT_LEVEL_OPTIONS, GameData.auto_ascend_min_speed_level)
	_select_option_closest(boost_level_opt, STAT_LEVEL_OPTIONS, GameData.auto_ascend_min_boost_level)
	_select_option_closest_float(wait_time_opt, WAIT_TIME_OPTIONS, GameData.auto_ascend_wait_seconds)

	_is_updating_ui = false
	_update_status_display()


func _select_option_closest(opt: OptionButton, options: Array[int], target_val: int) -> void:
	if not opt:
		return
	var best_idx := 0
	var best_diff := 99999999
	for i in range(options.size()):
		var diff := absi(options[i] - target_val)
		if diff < best_diff:
			best_diff = diff
			best_idx = i
	opt.selected = best_idx


func _select_option_closest_float(opt: OptionButton, options: Array[float], target_val: float) -> void:
	if not opt:
		return
	var best_idx := 0
	var best_diff := 99999999.0
	for i in range(options.size()):
		var diff := absf(options[i] - target_val)
		if diff < best_diff:
			best_diff = diff
			best_idx = i
	opt.selected = best_idx


func _update_unlock_state() -> void:
	if not GameData:
		return
	var is_unlocked := GameData.get_skill_level("auto_ascension") > 0
	if unlock_label:
		unlock_label.visible = not is_unlocked
	if content_vbox:
		content_vbox.visible = is_unlocked


func _on_condition_changed(_extra: Variant = null) -> void:
	if _is_updating_ui or not GameData:
		return

	var enabled := main_toggle.button_pressed if main_toggle else true
	var disable_challenge := disable_challenge_check.button_pressed if disable_challenge_check else true
	var min_total := TOTAL_LEVEL_OPTIONS[clampi(total_level_opt.selected, 0, TOTAL_LEVEL_OPTIONS.size() - 1)] if total_level_opt else 100
	var min_size := STAT_LEVEL_OPTIONS[clampi(size_level_opt.selected, 0, STAT_LEVEL_OPTIONS.size() - 1)] if size_level_opt else 0
	var min_speed := STAT_LEVEL_OPTIONS[clampi(speed_level_opt.selected, 0, STAT_LEVEL_OPTIONS.size() - 1)] if speed_level_opt else 0
	var min_boost := STAT_LEVEL_OPTIONS[clampi(boost_level_opt.selected, 0, STAT_LEVEL_OPTIONS.size() - 1)] if boost_level_opt else 0
	var wait_sec := WAIT_TIME_OPTIONS[clampi(wait_time_opt.selected, 0, WAIT_TIME_OPTIONS.size() - 1)] if wait_time_opt else 0.0

	GameData.set_auto_ascend_all_conditions(
		enabled,
		disable_challenge,
		min_total,
		min_size,
		min_speed,
		min_boost,
		wait_sec
	)
	_update_status_display()


func _on_settings_changed() -> void:
	sync_from_data()


func _on_timer_updated(current_timer: float, wait_seconds: float) -> void:
	_update_timer_label(current_timer, wait_seconds)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_update_status_display()


func _update_status_display() -> void:
	if not GameData or not is_visible_in_tree():
		return
	_update_timer_label(GameData.get_auto_ascend_timer(), GameData.auto_ascend_wait_seconds)


func _update_timer_label(current_timer: float, wait_seconds: float) -> void:
	if not status_label or not GameData or not is_visible_in_tree():
		return

	if GameData.get_skill_level("auto_ascension") <= 0:
		status_label.text = ""
		return

	if not GameData.auto_ascend_enabled:
		status_label.text = "自動アセンション: オフ"
		status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1.0))
		return

	if GameData.auto_ascend_disable_during_challenge and GameData.is_challenge_active():
		status_label.text = "チャレンジ中 (自動アセンション一時停止)"
		status_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35, 1.0))
		return

	var is_met := GameData.is_auto_ascend_condition_met()
	if not is_met:
		var unmet_parts: Array[String] = []
		var cur_total := GameData.get_base_upgrade_total_level()
		if cur_total < GameData.auto_ascend_min_total_level:
			unmet_parts.append("合計Lv %d/%d" % [cur_total, GameData.auto_ascend_min_total_level])
		if GameData.auto_ascend_min_size_level > 0 and GameData.size_level < GameData.auto_ascend_min_size_level:
			unmet_parts.append("サイズLv %d/%d" % [GameData.size_level, GameData.auto_ascend_min_size_level])
		if GameData.auto_ascend_min_speed_level > 0 and GameData.speed_level < GameData.auto_ascend_min_speed_level:
			unmet_parts.append("速度Lv %d/%d" % [GameData.speed_level, GameData.auto_ascend_min_speed_level])
		if GameData.auto_ascend_min_boost_level > 0 and GameData.boost_level < GameData.auto_ascend_min_boost_level:
			unmet_parts.append("ブーストLv %d/%d" % [GameData.boost_level, GameData.auto_ascend_min_boost_level])

		var desc := ", ".join(unmet_parts)
		if desc.is_empty():
			status_label.text = "条件判定中 (基礎強化Lv合計100以上が必要)"
		else:
			status_label.text = "条件判定中: %s" % desc
		status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 1.0))
	else:
		if wait_seconds <= 0.0:
			status_label.text = "条件達成 (即時アセンション対象)"
			status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
		else:
			var remaining := maxf(0.0, wait_seconds - current_timer)
			status_label.text = "稼ぎキープ中: 残り %.1f秒 / %.0f秒 (経過: %.1fs)" % [
				remaining,
				wait_seconds,
				current_timer
			]
			status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
