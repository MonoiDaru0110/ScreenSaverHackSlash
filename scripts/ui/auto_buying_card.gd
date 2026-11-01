class_name AutoBuyingCard
extends AutomationCardBase
## Card for Auto Base Upgrade Buying automation.

@onready var unlock_label: Label = %AutoBuyingUnlockLabel
@onready var content_vbox: VBoxContainer = %AutoBuyingContent
@onready var main_toggle: CheckBox = %MainToggle
@onready var size_check: CheckBox = %SizeCheck
@onready var speed_check: CheckBox = %SpeedCheck
@onready var boost_check: CheckBox = %BoostCheck

var _is_updating_ui: bool = false


func _ready() -> void:
	super._ready()

	# 緑色のチェックマークアイコンを全チェックボックスに適用
	AutomationCardBase.setup_green_checkbox(main_toggle)
	AutomationCardBase.setup_green_checkbox(size_check)
	AutomationCardBase.setup_green_checkbox(speed_check)
	AutomationCardBase.setup_green_checkbox(boost_check)

	if GameData:
		GameData.auto_settings_changed.connect(_on_settings_changed)
		GameData.skill_upgraded.connect(func(_id, _lvl): _update_unlock_state())

	if main_toggle:
		main_toggle.toggled.connect(_on_checkbox_changed)
	if size_check:
		size_check.toggled.connect(_on_checkbox_changed)
	if speed_check:
		speed_check.toggled.connect(_on_checkbox_changed)
	if boost_check:
		boost_check.toggled.connect(_on_checkbox_changed)

	sync_from_data()


func sync_from_data() -> void:
	if not GameData:
		return
	_is_updating_ui = true
	_update_unlock_state()
	if main_toggle:
		main_toggle.button_pressed = GameData.auto_status_buying_enabled
	if size_check:
		size_check.button_pressed = GameData.auto_buy_size_enabled
	if speed_check:
		speed_check.button_pressed = GameData.auto_buy_speed_enabled
	if boost_check:
		boost_check.button_pressed = GameData.auto_buy_boost_enabled
	_is_updating_ui = false


func _update_unlock_state() -> void:
	if not GameData:
		return
	var is_unlocked := GameData.get_skill_level("auto_status_buying") > 0
	if unlock_label:
		unlock_label.visible = not is_unlocked
	if content_vbox:
		content_vbox.visible = is_unlocked


func _on_checkbox_changed(_enabled: bool) -> void:
	if _is_updating_ui or not GameData:
		return
	GameData.set_auto_buying_settings(
		main_toggle.button_pressed if main_toggle else true,
		size_check.button_pressed if size_check else true,
		speed_check.button_pressed if speed_check else true,
		boost_check.button_pressed if boost_check else true
	)


func _on_settings_changed() -> void:
	sync_from_data()
