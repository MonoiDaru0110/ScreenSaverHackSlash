extends CanvasLayer
## Heads-up display showing gold, bounce count, and corner hit announcements.

@onready var gold_label: Label = $Sidebar/SidebarLayout/FooterBottomSection/CenterContainer/GoldLabel
@onready var token_label: Label = $Sidebar/SidebarLayout/FooterTopSection/CenterContainer/TokenLabel
@onready var bounce_label: Label = $BounceLabel
@onready var corner_label: Label = $CornerLabel
@onready var corner_announce: Label = $CornerAnnounce

@onready var btn_size: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton1
@onready var btn_speed: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton2
@onready var btn_boost: Button = $Sidebar/SidebarLayout/TopSection/MarginContainer/UpgradeList/UpgradeButton3
@onready var btn_ascend: Button = %UpgradeButton4
@onready var btn_buy_mode: Button = %SidebarBuyModeBtn

const BUY_MODES_DEFAULT: Array[int] = [1, 5, 10]
const BUY_MODES_EXPANDED: Array[int] = [1, 5, 10, 100, -1]
var _sidebar_buy_mode_idx: int = 0

func _get_available_buy_modes() -> Array[int]:
	if GameData.get_skill_level("buying_expand") > 0:
		return BUY_MODES_EXPANDED
	return BUY_MODES_DEFAULT

func _get_current_buy_mode() -> int:
	var modes := _get_available_buy_modes()
	if _sidebar_buy_mode_idx >= modes.size():
		_sidebar_buy_mode_idx = 0
	return modes[_sidebar_buy_mode_idx]

# Tab UI references
@onready var star_label: Label = %StarLabel
@onready var sidebar_star_progress_bar: ProgressBar = %SidebarStarProgressBar
@onready var btn_home_tab: Button = %HomeTabBtn
@onready var btn_reincarnation_tab: Button = %ReincarnationTabBtn
@onready var sub_nav_container: PanelContainer = %SubNavContainer
@onready var btn_equipment_tab: Button = %EquipmentTabBtn
@onready var btn_skill_tree_tab: Button = %SkillTreeTabBtn
@onready var btn_challenge_tab: Button = %ChallengeTabBtn
@onready var btn_blacksmith_tab: Button = %BlacksmithTabBtn
@onready var btn_amplifier_tab: Button = %AmplifierTabBtn
@onready var reinc_sub_nav_container: PanelContainer = %ReincarnationSubNavContainer
@onready var btn_reinc_tab_1: Button = %ReincDummyTabBtn1
@onready var btn_reinc_tab_2: Button = %ReincDummyTabBtn2
@onready var window_dimmer: ColorRect = %WindowDimmer
@onready var special_skill_ui_container: Control = get_node_or_null("../PlayArea/SpecialSkillUIContainer") if get_node_or_null("../PlayArea/SpecialSkillUIContainer") else get_node_or_null("%SpecialSkillUIContainer")
@onready var grid_equipment: GridContainer = %GridContainer
@onready var skill_tree_viewport: Control = %SkillTreeViewport
@onready var skill_tree_window: PanelContainer = %SkillTreeWindow
@onready var challenge_window: PanelContainer = %ChallengeWindow
@onready var blacksmith_window: PanelContainer = %BlacksmithWindow
@onready var amplifier_window: PanelContainer = %AmplifierWindow
@onready var reinc_tree_window: PanelContainer = %ReincTreeWindow
@onready var reinc_ability_window: PanelContainer = %ReincAbilityWindow
@onready var reincarnation_window: PanelContainer = %ReincarnationWindow
@onready var save_slot_window: SaveSlotWindow = %SaveSlotWindow
@onready var skill_tree_scroll: SkillTreeController = %SkillTreeScroll
@onready var btn_close_window: Button = %CloseWindowBtn
@onready var btn_toggle_skill_vis: Button = %ToggleSkillVisibilityBtn

# Inventory UI references
@onready var inventory_window: PanelContainer = %InventoryWindow
@onready var btn_close_inventory: Button = %CloseInventoryBtn
@onready var btn_equipment_filter: Button = %EquipmentFilterBtn
@onready var equipment_filter_window: PanelContainer = %EquipmentFilterWindow
@onready var inventory_filter_window: PanelContainer = %InventoryFilterWindow
@onready var inventory_dimmer: Panel = %InventoryDimmer
@onready var main_title_label: Label = %MainTitleLabel
@onready var sub_title_label: Label = %SubTitleLabel
@onready var accessory_title_label: Label = %AccessoryTitleLabel
@onready var main_grid: GridContainer = %MainGrid
@onready var sub_grid: GridContainer = %SubGrid
@onready var accessory_grid: GridContainer = %AccessoryGrid
@onready var btn_main_sort: Button = %MainSortBtn
@onready var btn_sub_sort: Button = %SubSortBtn
@onready var btn_accessory_sort: Button = %AccessorySortBtn
@onready var btn_main_filter: Button = %MainFilterBtn
@onready var btn_sub_filter: Button = %SubFilterBtn
@onready var btn_accessory_filter: Button = %AccessoryFilterBtn
@onready var equipment_log_container: VBoxContainer = get_node_or_null("../PlayArea/EquipmentLogContainer") if get_node_or_null("../PlayArea/EquipmentLogContainer") else get_node_or_null("%EquipmentLogContainer")

var _skill_tree_scene: PackedScene = preload("res://scenes/skills/skill_tree_data.tscn")
var _skill_tree_instance: Control

# Tab UI styling
var _tab_style_active: StyleBoxFlat
var _tab_style_active_hover: StyleBoxFlat
var _tab_style_active_pressed: StyleBoxFlat
var _tab_style_inactive: StyleBoxFlat
var _tab_style_inactive_hover: StyleBoxFlat
var _tab_style_inactive_pressed: StyleBoxFlat

var _subtab_style_active: StyleBoxFlat
var _subtab_style_active_hover: StyleBoxFlat
var _subtab_style_active_pressed: StyleBoxFlat
var _subtab_style_inactive: StyleBoxFlat
var _subtab_style_inactive_hover: StyleBoxFlat
var _subtab_style_inactive_pressed: StyleBoxFlat
var _subtab_style_locked: StyleBoxFlat

var _reinc_subtab_index: int = 0
var _is_skill_tree_open: bool = false
var _is_inventory_open: bool = false
var _is_challenge_open: bool = false
var _is_blacksmith_open: bool = false
var _is_amplifier_open: bool = false
var _is_reinc_tree_open: bool = false
var _is_reinc_ability_open: bool = false
var _is_reincarnation_open: bool = false
var _is_save_slot_open: bool = false
var _has_centered_on_startup: bool = false
var _slot_buttons: Dictionary = {}
var _corner_tween: Tween = null
var _last_corner_announce_ticks: int = 0
var _btn_debug_free_skill: Button = null

# Quick Save / Load / Reset UI references
@onready var quick_save_btn: Button = get_node_or_null("%QuickSaveBtn")
@onready var quick_load_btn: Button = get_node_or_null("%QuickLoadBtn")
@onready var quick_reset_btn: Button = get_node_or_null("%QuickResetBtn")
@onready var save_toast_label: Label = get_node_or_null("%SaveToastLabel")
@onready var reset_confirm_dialog: ConfirmationDialog = get_node_or_null("%ResetConfirmDialog")
var _save_toast_tween: Tween = null

# パフォーマンス最適化: アップグレードボタン更新のスロットリング
var _upgrade_buttons_dirty: bool = false
var _upgrade_update_timer: Timer = null

# インベントリ複数選択・廃棄システム
var _selected_inventory_items: Dictionary = {}
var _sell_overlay: Control = null
var _sell_popup: PanelContainer = null
var _sell_popup_button: Button = null
var _discard_pop_node: PanelContainer = null
var _discard_pop_tween: Tween = null

# チャレンジ進行中ミニウィンドウ（右下・通貨欄の左）
@onready var _challenge_mini_panel: PanelContainer = %ChallengeMiniWindow
@onready var _challenge_mini_title: Label = %ChallengeMiniTitle
@onready var _challenge_mini_time: Label = %ChallengeMiniTime
@onready var _challenge_mini_bar: ProgressBar = %ChallengeMiniBar
@onready var _challenge_mini_progress: Label = %ChallengeMiniProgress
var _chain_cross_overlay: ChainCrossOverlay = null

# パフォーマンス最適化: デバッグ表示 & ステータス更新スロットリング
@onready var _debug_label: Label = %DebugLabel
var _debug_timer: Timer = null
var _stats_dirty: bool = false
var _default_upgrade_btn_styles: Dictionary = {}
var _was_trinity_active: bool = false
var _last_drop_pop_ticks: int = 0

# パフォーマンス最適化: ボタン子ラベルのキャッシュ
@onready var _lbl_title_size: Label = btn_size.get_node_or_null("Content/TitleHBox/TitleLabel") if btn_size else null
@onready var _lbl_diff_size: Label = btn_size.get_node_or_null("Content/TitleHBox/DiffLabel") if btn_size else null
@onready var _lbl_cost_size: Label = btn_size.get_node_or_null("Content/CostLabel") if btn_size else null
@onready var _lbl_title_speed: Label = btn_speed.get_node_or_null("Content/TitleHBox/TitleLabel") if btn_speed else null
@onready var _lbl_diff_speed: Label = btn_speed.get_node_or_null("Content/TitleHBox/DiffLabel") if btn_speed else null
@onready var _lbl_cost_speed: Label = btn_speed.get_node_or_null("Content/CostLabel") if btn_speed else null
@onready var _lbl_title_boost: Label = btn_boost.get_node_or_null("Content/TitleHBox/TitleLabel") if btn_boost else null
@onready var _lbl_diff_boost: Label = btn_boost.get_node_or_null("Content/TitleHBox/DiffLabel") if btn_boost else null
@onready var _lbl_cost_boost: Label = btn_boost.get_node_or_null("Content/CostLabel") if btn_boost else null
@onready var _lbl_title_ascend: Label = btn_ascend.get_node_or_null("Content/TitleLabel") if btn_ascend else null
@onready var _lbl_diff_ascend: Label = btn_ascend.get_node_or_null("Content/DiffLabel") if btn_ascend else null
@onready var _lbl_progress_ascend: Label = btn_ascend.get_node_or_null("Content/ProgressLabel") if btn_ascend else null


func _ready() -> void:
	# Configure StyleBoxFlat for button states programmatically
	# to prevent Godot Editor from overwriting the .tscn scene file styles.
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.33, 0.15, 0.85, 1)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.45, 0.25, 0.92, 1)
	style_normal.corner_radius_top_left = 3
	style_normal.corner_radius_top_right = 3
	style_normal.corner_radius_bottom_right = 3
	style_normal.corner_radius_bottom_left = 3

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.42, 0.25, 0.92, 1)
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(0.55, 0.38, 0.98, 1)
	style_hover.corner_radius_top_left = 3
	style_hover.corner_radius_top_right = 3
	style_hover.corner_radius_bottom_right = 3
	style_hover.corner_radius_bottom_left = 3

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.22, 0.08, 0.6, 1)
	style_pressed.border_width_left = 2
	style_pressed.border_width_top = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_bottom = 2
	style_pressed.border_color = Color(0.32, 0.14, 0.75, 1)
	style_pressed.corner_radius_top_left = 3
	style_pressed.corner_radius_top_right = 3
	style_pressed.corner_radius_bottom_right = 3
	style_pressed.corner_radius_bottom_left = 3

	var style_disabled := StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.24, 0.14, 0.42, 1) # Closer to default with slightly higher brightness/saturation
	style_disabled.border_width_left = 2
	style_disabled.border_width_top = 2
	style_disabled.border_width_right = 2
	style_disabled.border_width_bottom = 2
	style_disabled.border_color = Color(0.28, 0.18, 0.48, 1)
	style_disabled.corner_radius_top_left = 3
	style_disabled.corner_radius_top_right = 3
	style_disabled.corner_radius_bottom_right = 3
	style_disabled.corner_radius_bottom_left = 3

	var style_focus := StyleBoxEmpty.new() # Removes focus outline border highlighting

	for btn in [btn_size, btn_speed, btn_boost]:
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("disabled", style_disabled)
		btn.add_theme_stylebox_override("focus", style_focus)

		_default_upgrade_btn_styles[btn] = {
			"normal": style_normal,
			"hover": style_hover,
			"pressed": style_pressed,
			"disabled": style_disabled
		}
		
		# Make font sizes slightly larger and align the coin emoji visually
		var title_node = btn.get_node_or_null("Content/TitleHBox/TitleLabel")
		if not title_node:
			title_node = btn.get_node_or_null("Content/TitleLabel")
		if title_node:
			title_node.add_theme_font_size_override("font_size", 18)
		var cost_node = btn.get_node_or_null("Content/CostLabel")
		if cost_node:
			cost_node.add_theme_font_size_override("font_size", 16)

	if btn_ascend:
		btn_ascend.add_theme_stylebox_override("focus", style_focus)
		_default_upgrade_btn_styles[btn_ascend] = {
			"normal": btn_ascend.get_theme_stylebox("normal"),
			"hover": btn_ascend.get_theme_stylebox("hover"),
			"pressed": btn_ascend.get_theme_stylebox("pressed"),
			"disabled": btn_ascend.get_theme_stylebox("disabled")
		}

	# Main Tab button styles setup (ホーム / 転生)
	# Inactive: base dark charcoal/navy
	_tab_style_inactive = StyleBoxFlat.new()
	_tab_style_inactive.bg_color = Color(0.12, 0.12, 0.20, 0.9)
	_tab_style_inactive.border_width_left = 1
	_tab_style_inactive.border_width_top = 1
	_tab_style_inactive.border_width_right = 1
	_tab_style_inactive.border_width_bottom = 1
	_tab_style_inactive.border_color = Color(0.24, 0.22, 0.38, 1)
	_tab_style_inactive.corner_radius_top_left = 6
	_tab_style_inactive.corner_radius_top_right = 6
	_tab_style_inactive.corner_radius_bottom_right = 6
	_tab_style_inactive.corner_radius_bottom_left = 6

	_tab_style_inactive_hover = StyleBoxFlat.new()
	_tab_style_inactive_hover.bg_color = Color(0.18, 0.18, 0.28, 0.95)
	_tab_style_inactive_hover.border_width_left = 1
	_tab_style_inactive_hover.border_width_top = 1
	_tab_style_inactive_hover.border_width_right = 1
	_tab_style_inactive_hover.border_width_bottom = 1
	_tab_style_inactive_hover.border_color = Color(0.36, 0.34, 0.52, 1)
	_tab_style_inactive_hover.corner_radius_top_left = 6
	_tab_style_inactive_hover.corner_radius_top_right = 6
	_tab_style_inactive_hover.corner_radius_bottom_right = 6
	_tab_style_inactive_hover.corner_radius_bottom_left = 6

	_tab_style_inactive_pressed = StyleBoxFlat.new()
	_tab_style_inactive_pressed.bg_color = Color(0.09, 0.09, 0.15, 1.0)
	_tab_style_inactive_pressed.border_width_left = 1
	_tab_style_inactive_pressed.border_width_top = 1
	_tab_style_inactive_pressed.border_width_right = 1
	_tab_style_inactive_pressed.border_width_bottom = 1
	_tab_style_inactive_pressed.border_color = Color(0.20, 0.18, 0.32, 1)
	_tab_style_inactive_pressed.corner_radius_top_left = 6
	_tab_style_inactive_pressed.corner_radius_top_right = 6
	_tab_style_inactive_pressed.corner_radius_bottom_right = 6
	_tab_style_inactive_pressed.corner_radius_bottom_left = 6

	# Active (Selected): Slightly lighter than base color (not vivid purple)
	_tab_style_active = StyleBoxFlat.new()
	_tab_style_active.bg_color = Color(0.24, 0.24, 0.36, 1.0)
	_tab_style_active.border_width_left = 2
	_tab_style_active.border_width_top = 2
	_tab_style_active.border_width_right = 2
	_tab_style_active.border_width_bottom = 2
	_tab_style_active.border_color = Color(0.50, 0.48, 0.70, 1)
	_tab_style_active.corner_radius_top_left = 6
	_tab_style_active.corner_radius_top_right = 6
	_tab_style_active.corner_radius_bottom_right = 6
	_tab_style_active.corner_radius_bottom_left = 6

	_tab_style_active_hover = StyleBoxFlat.new()
	_tab_style_active_hover.bg_color = Color(0.30, 0.30, 0.44, 1.0)
	_tab_style_active_hover.border_width_left = 2
	_tab_style_active_hover.border_width_top = 2
	_tab_style_active_hover.border_width_right = 2
	_tab_style_active_hover.border_width_bottom = 2
	_tab_style_active_hover.border_color = Color(0.60, 0.58, 0.82, 1)
	_tab_style_active_hover.corner_radius_top_left = 6
	_tab_style_active_hover.corner_radius_top_right = 6
	_tab_style_active_hover.corner_radius_bottom_right = 6
	_tab_style_active_hover.corner_radius_bottom_left = 6

	_tab_style_active_pressed = StyleBoxFlat.new()
	_tab_style_active_pressed.bg_color = Color(0.20, 0.20, 0.30, 1.0)
	_tab_style_active_pressed.border_width_left = 2
	_tab_style_active_pressed.border_width_top = 2
	_tab_style_active_pressed.border_width_right = 2
	_tab_style_active_pressed.border_width_bottom = 2
	_tab_style_active_pressed.border_color = Color(0.44, 0.42, 0.62, 1)
	_tab_style_active_pressed.corner_radius_top_left = 6
	_tab_style_active_pressed.corner_radius_top_right = 6
	_tab_style_active_pressed.corner_radius_bottom_right = 6
	_tab_style_active_pressed.corner_radius_bottom_left = 6

	# Sub Tab button styles setup (装備 / スキル / 転生サブバー)
	_subtab_style_inactive = StyleBoxFlat.new()
	_subtab_style_inactive.bg_color = Color(0.10, 0.10, 0.16, 0.85)
	_subtab_style_inactive.border_width_left = 1
	_subtab_style_inactive.border_width_top = 1
	_subtab_style_inactive.border_width_right = 1
	_subtab_style_inactive.border_width_bottom = 1
	_subtab_style_inactive.border_color = Color(0.20, 0.20, 0.32, 1)
	_subtab_style_inactive.corner_radius_top_left = 3
	_subtab_style_inactive.corner_radius_top_right = 3
	_subtab_style_inactive.corner_radius_bottom_right = 3
	_subtab_style_inactive.corner_radius_bottom_left = 3

	_subtab_style_inactive_hover = StyleBoxFlat.new()
	_subtab_style_inactive_hover.bg_color = Color(0.16, 0.16, 0.24, 0.95)
	_subtab_style_inactive_hover.border_width_left = 1
	_subtab_style_inactive_hover.border_width_top = 1
	_subtab_style_inactive_hover.border_width_right = 1
	_subtab_style_inactive_hover.border_width_bottom = 1
	_subtab_style_inactive_hover.border_color = Color(0.30, 0.30, 0.44, 1)
	_subtab_style_inactive_hover.corner_radius_top_left = 3
	_subtab_style_inactive_hover.corner_radius_top_right = 3
	_subtab_style_inactive_hover.corner_radius_bottom_right = 3
	_subtab_style_inactive_hover.corner_radius_bottom_left = 3

	_subtab_style_inactive_pressed = StyleBoxFlat.new()
	_subtab_style_inactive_pressed.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	_subtab_style_inactive_pressed.border_width_left = 1
	_subtab_style_inactive_pressed.border_width_top = 1
	_subtab_style_inactive_pressed.border_width_right = 1
	_subtab_style_inactive_pressed.border_width_bottom = 1
	_subtab_style_inactive_pressed.border_color = Color(0.16, 0.16, 0.24, 1)
	_subtab_style_inactive_pressed.corner_radius_top_left = 3
	_subtab_style_inactive_pressed.corner_radius_top_right = 3
	_subtab_style_inactive_pressed.corner_radius_bottom_right = 3
	_subtab_style_inactive_pressed.corner_radius_bottom_left = 3

	_subtab_style_active = StyleBoxFlat.new()
	_subtab_style_active.bg_color = Color(0.22, 0.22, 0.32, 1.0)
	_subtab_style_active.border_width_left = 2
	_subtab_style_active.border_width_top = 2
	_subtab_style_active.border_width_right = 2
	_subtab_style_active.border_width_bottom = 2
	_subtab_style_active.border_color = Color(0.44, 0.44, 0.64, 1)
	_subtab_style_active.corner_radius_top_left = 3
	_subtab_style_active.corner_radius_top_right = 3
	_subtab_style_active.corner_radius_bottom_right = 3
	_subtab_style_active.corner_radius_bottom_left = 3

	_subtab_style_active_hover = StyleBoxFlat.new()
	_subtab_style_active_hover.bg_color = Color(0.27, 0.27, 0.38, 1.0)
	_subtab_style_active_hover.border_width_left = 2
	_subtab_style_active_hover.border_width_top = 2
	_subtab_style_active_hover.border_width_right = 2
	_subtab_style_active_hover.border_width_bottom = 2
	_subtab_style_active_hover.border_color = Color(0.54, 0.54, 0.76, 1)
	_subtab_style_active_hover.corner_radius_top_left = 3
	_subtab_style_active_hover.corner_radius_top_right = 3
	_subtab_style_active_hover.corner_radius_bottom_right = 3
	_subtab_style_active_hover.corner_radius_bottom_left = 3

	_subtab_style_active_pressed = StyleBoxFlat.new()
	_subtab_style_active_pressed.bg_color = Color(0.18, 0.18, 0.26, 1.0)
	_subtab_style_active_pressed.border_width_left = 2
	_subtab_style_active_pressed.border_width_top = 2
	_subtab_style_active_pressed.border_width_right = 2
	_subtab_style_active_pressed.border_width_bottom = 2
	_subtab_style_active_pressed.border_color = Color(0.38, 0.38, 0.56, 1)
	_subtab_style_active_pressed.corner_radius_top_left = 3
	_subtab_style_active_pressed.corner_radius_top_right = 3
	_subtab_style_active_pressed.corner_radius_bottom_right = 3
	_subtab_style_active_pressed.corner_radius_bottom_left = 3

	# Sub Tab locked style
	_subtab_style_locked = StyleBoxFlat.new()
	_subtab_style_locked.bg_color = Color(0.06, 0.06, 0.09, 0.75)
	_subtab_style_locked.border_width_left = 1
	_subtab_style_locked.border_width_top = 1
	_subtab_style_locked.border_width_right = 1
	_subtab_style_locked.border_width_bottom = 1
	_subtab_style_locked.border_color = Color(0.18, 0.18, 0.24, 0.8)
	_subtab_style_locked.corner_radius_top_left = 3
	_subtab_style_locked.corner_radius_top_right = 3
	_subtab_style_locked.corner_radius_bottom_right = 3
	_subtab_style_locked.corner_radius_bottom_left = 3

	if btn_home_tab:
		btn_home_tab.add_theme_stylebox_override("focus", style_focus)
		btn_home_tab.pressed.connect(_on_home_tab_pressed)
	if btn_reincarnation_tab:
		btn_reincarnation_tab.add_theme_stylebox_override("focus", style_focus)
		btn_reincarnation_tab.pressed.connect(_on_reincarnation_tab_pressed)
	if btn_equipment_tab:
		btn_equipment_tab.add_theme_stylebox_override("focus", style_focus)
		btn_equipment_tab.pressed.connect(_on_equipment_tab_pressed)
	if btn_skill_tree_tab:
		btn_skill_tree_tab.add_theme_stylebox_override("focus", style_focus)
		btn_skill_tree_tab.pressed.connect(_on_skill_tree_tab_pressed)
	if btn_challenge_tab:
		btn_challenge_tab.add_theme_stylebox_override("focus", style_focus)
		btn_challenge_tab.pressed.connect(_on_challenge_tab_pressed)
	if btn_blacksmith_tab:
		btn_blacksmith_tab.add_theme_stylebox_override("focus", style_focus)
		btn_blacksmith_tab.pressed.connect(_on_blacksmith_tab_pressed)
	if btn_amplifier_tab:
		btn_amplifier_tab.add_theme_stylebox_override("focus", style_focus)
		btn_amplifier_tab.pressed.connect(_on_amplifier_tab_pressed)
	if btn_reinc_tab_1:
		btn_reinc_tab_1.add_theme_stylebox_override("focus", style_focus)
		btn_reinc_tab_1.pressed.connect(_on_reinc_tab_1_pressed)
	if btn_reinc_tab_2:
		btn_reinc_tab_2.add_theme_stylebox_override("focus", style_focus)
		btn_reinc_tab_2.pressed.connect(_on_reinc_tab_2_pressed)

	if quick_save_btn:
		quick_save_btn.pressed.connect(toggle_save_slot_window)
	if quick_load_btn:
		quick_load_btn.pressed.connect(toggle_save_slot_window)
	if quick_reset_btn:
		quick_reset_btn.pressed.connect(_on_quick_reset_pressed)
	if reset_confirm_dialog:
		reset_confirm_dialog.confirmed.connect(_on_reset_confirmed)

	_update_tab_button_styles()

	# Instantiate and add skill tree container to viewport
	_skill_tree_instance = _skill_tree_scene.instantiate()
	skill_tree_viewport.add_child(_skill_tree_instance)
	
	# Load skills dynamically from JSON
	_load_skills_from_json()

	GameData.gold_changed.connect(_on_gold_changed)
	GameData.tokens_changed.connect(_on_tokens_changed)
	GameData.stars_changed.connect(_on_stars_changed)
	GameData.stats_changed.connect(_on_stats_changed)
	GameData.corner_hit_occurred.connect(_on_corner_hit)
	GameData.upgrades_changed.connect(_on_upgrades_changed)
	GameData.trinity_changed.connect(_on_trinity_changed)
	GameData.infusion_changed.connect(_on_infusion_changed)

	_on_stars_changed(GameData.stars)
	_update_sidebar_star_progress()
	_update_special_skill_custom_ui()
	
	btn_size.pressed.connect(_on_size_pressed)
	btn_speed.pressed.connect(_on_speed_pressed)
	btn_boost.pressed.connect(_on_boost_pressed)
	btn_ascend.pressed.connect(_on_ascend_pressed)
	if btn_buy_mode:
		btn_buy_mode.pressed.connect(_on_buy_mode_pressed)
	GameData.setup_close_button(btn_close_window)
	btn_close_window.pressed.connect(close_skill_tree)
	if btn_toggle_skill_vis:
		btn_toggle_skill_vis.visible = false
	_setup_debug_free_skill_button()
	
	skill_tree_window.visible = false
	
	_init_slot_buttons()
	GameData.equipment_changed.connect(_on_equipment_changed)
	GameData.inventory_updated.connect(_on_inventory_updated)
	GameData.inventory_filter_changed.connect(func(_t): _update_inventory_ui())
	GameData.reincarnation_performed.connect(_on_reincarnation_performed)
	GameData.skill_upgraded.connect(_on_skill_upgraded)
	GameData.setup_close_button(btn_close_inventory)
	btn_close_inventory.pressed.connect(close_inventory)
	if btn_equipment_filter:
		btn_equipment_filter.focus_mode = Control.FOCUS_NONE
		btn_equipment_filter.add_theme_stylebox_override("normal", style_normal)
		btn_equipment_filter.add_theme_stylebox_override("hover", style_hover)
		btn_equipment_filter.add_theme_stylebox_override("pressed", style_pressed)
		btn_equipment_filter.add_theme_stylebox_override("focus", style_focus)
		btn_equipment_filter.pressed.connect(_on_equipment_filter_pressed)
	var style_gear_normal := StyleBoxFlat.new()
	style_gear_normal.bg_color = Color(0.16, 0.16, 0.24, 0.9)
	style_gear_normal.border_width_left = 1
	style_gear_normal.border_width_top = 1
	style_gear_normal.border_width_right = 1
	style_gear_normal.border_width_bottom = 1
	style_gear_normal.border_color = Color(0.32, 0.32, 0.44, 0.9)
	style_gear_normal.corner_radius_top_left = 4
	style_gear_normal.corner_radius_top_right = 4
	style_gear_normal.corner_radius_bottom_right = 4
	style_gear_normal.corner_radius_bottom_left = 4

	var style_gear_hover := StyleBoxFlat.new()
	style_gear_hover.bg_color = Color(0.24, 0.24, 0.36, 1.0)
	style_gear_hover.border_width_left = 1
	style_gear_hover.border_width_top = 1
	style_gear_hover.border_width_right = 1
	style_gear_hover.border_width_bottom = 1
	style_gear_hover.border_color = Color(0.55, 0.55, 0.72, 1.0)
	style_gear_hover.corner_radius_top_left = 4
	style_gear_hover.corner_radius_top_right = 4
	style_gear_hover.corner_radius_bottom_right = 4
	style_gear_hover.corner_radius_bottom_left = 4

	var style_gear_pressed := StyleBoxFlat.new()
	style_gear_pressed.bg_color = Color(0.10, 0.10, 0.16, 1.0)
	style_gear_pressed.border_width_left = 1
	style_gear_pressed.border_width_top = 1
	style_gear_pressed.border_width_right = 1
	style_gear_pressed.border_width_bottom = 1
	style_gear_pressed.border_color = Color(0.22, 0.22, 0.32, 1.0)
	style_gear_pressed.corner_radius_top_left = 4
	style_gear_pressed.corner_radius_top_right = 4
	style_gear_pressed.corner_radius_bottom_right = 4
	style_gear_pressed.corner_radius_bottom_left = 4

	for btn in [btn_main_filter, btn_sub_filter, btn_accessory_filter]:
		if btn:
			btn.custom_minimum_size = Vector2(28, 28)
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_stylebox_override("normal", style_gear_normal)
			btn.add_theme_stylebox_override("hover", style_gear_hover)
			btn.add_theme_stylebox_override("pressed", style_gear_pressed)
			btn.add_theme_stylebox_override("focus", style_focus)
			btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.tooltip_text = "インベントリ設定"

	for btn in [btn_main_sort, btn_sub_sort, btn_accessory_sort]:
		if btn:
			btn.custom_minimum_size = Vector2(28, 28)
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_stylebox_override("normal", style_gear_normal)
			btn.add_theme_stylebox_override("hover", style_gear_hover)
			btn.add_theme_stylebox_override("pressed", style_gear_pressed)
			btn.add_theme_stylebox_override("focus", style_focus)
			btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.tooltip_text = "並び替え"

	if btn_main_sort:
		btn_main_sort.pressed.connect(func(): GameData.sort_and_filter_inventory("main"))
	if btn_sub_sort:
		btn_sub_sort.pressed.connect(func(): GameData.sort_and_filter_inventory("sub"))
	if btn_accessory_sort:
		btn_accessory_sort.pressed.connect(func(): GameData.sort_and_filter_inventory("accessory"))

	if btn_main_filter:
		btn_main_filter.pressed.connect(func(): _open_inventory_filter("main"))
	if btn_sub_filter:
		btn_sub_filter.pressed.connect(func(): _open_inventory_filter("sub"))
	if btn_accessory_filter:
		btn_accessory_filter.pressed.connect(func(): _open_inventory_filter("accessory"))

	if inventory_dimmer:
		inventory_dimmer.visible = false
		inventory_dimmer.modulate.a = 0.0
		inventory_dimmer.gui_input.connect(_on_inventory_dimmer_gui_input)
	if inventory_filter_window:
		inventory_filter_window.visible = false
		if inventory_filter_window.has_signal("closed"):
			inventory_filter_window.closed.connect(_update_inventory_dimmer)
	if equipment_filter_window:
		equipment_filter_window.visible = false
		if equipment_filter_window.has_signal("closed"):
			equipment_filter_window.closed.connect(_update_inventory_dimmer)
	if challenge_window:
		if challenge_window.has_signal("closed"):
			challenge_window.closed.connect(close_challenge)
		challenge_window.visible = false
	if blacksmith_window:
		if blacksmith_window.has_signal("closed"):
			blacksmith_window.closed.connect(close_blacksmith)
		blacksmith_window.visible = false
	if amplifier_window:
		if amplifier_window.has_signal("closed"):
			amplifier_window.closed.connect(close_amplifier)
		amplifier_window.visible = false
	if reincarnation_window.has_signal("closed"):
		reincarnation_window.closed.connect(close_reincarnation)
	reincarnation_window.visible = false
	if reinc_tree_window:
		if reinc_tree_window.has_signal("closed"):
			reinc_tree_window.closed.connect(close_reinc_tree)
		reinc_tree_window.visible = false
	if reinc_ability_window:
		if reinc_ability_window.has_signal("closed"):
			reinc_ability_window.closed.connect(close_reinc_ability)
		reinc_ability_window.visible = false
	if save_slot_window:
		if save_slot_window.has_signal("closed"):
			save_slot_window.closed.connect(close_save_slot_window)
		if save_slot_window.has_signal("slot_saved"):
			save_slot_window.slot_saved.connect(_on_slot_saved)
		if save_slot_window.has_signal("slot_loaded"):
			save_slot_window.slot_loaded.connect(_on_slot_loaded)
		if save_slot_window.has_signal("slot_deleted"):
			save_slot_window.slot_deleted.connect(_on_slot_deleted)
		save_slot_window.visible = false
	if window_dimmer:
		window_dimmer.visible = false
		window_dimmer.modulate.a = 0.0
		window_dimmer.gui_input.connect(_on_window_dimmer_gui_input)

	# チャレンジ進行中ミニウィンドウ & 装備無効化オーバーレイのセットアップ
	_setup_challenge_mini_window()
	_setup_chain_cross_overlay()
	GameData.challenge_started.connect(_on_challenge_started_mini)
	GameData.challenge_progress_updated.connect(_on_challenge_progress_updated_mini)
	GameData.challenge_completed.connect(_on_challenge_ended_mini)
	GameData.challenge_failed.connect(_on_challenge_ended_mini)
	GameData.challenge_state_changed.connect(_update_challenge_mini_window)
	GameData.challenge_state_changed.connect(_update_chain_cross_overlay)
	_update_challenge_mini_window()
	_update_chain_cross_overlay()
	
	# アップグレードボタン更新スロットリングタイマーの初期化 (0.2秒間隔 = 5回/秒)
	_upgrade_update_timer = Timer.new()
	_upgrade_update_timer.wait_time = 0.2
	_upgrade_update_timer.one_shot = true
	_upgrade_update_timer.timeout.connect(_on_upgrade_update_timer)
	add_child(_upgrade_update_timer)
	
	# デバッグ更新タイマーのセットアップ
	_debug_timer = Timer.new()
	_debug_timer.wait_time = 0.1
	_debug_timer.autostart = true
	_debug_timer.timeout.connect(_update_debug_and_stats_info)
	add_child(_debug_timer)

	# Initialize equipment grid frames and adjust separation spacing
	_setup_grid_frames()
	

	
	close_inventory()
	_update_all()




func _on_gold_changed(_amount: float) -> void:
	_stats_dirty = true
	# アップグレードボタンの更新をスロットリング (0.2秒に1回に制限)
	if not _upgrade_buttons_dirty:
		_upgrade_buttons_dirty = true
		_upgrade_update_timer.start()


func _on_upgrade_update_timer() -> void:
	if _upgrade_buttons_dirty:
		_upgrade_buttons_dirty = false
		_update_upgrade_buttons()


func _on_tokens_changed(_amount: float) -> void:
	_stats_dirty = true


func _on_stats_changed() -> void:
	_stats_dirty = true


var _star_progress_dirty: bool = false


func _on_infusion_changed() -> void:
	# 注入中は角ヒット毎に発火するため、実際の更新は 0.1 秒タイマーでまとめて行う
	_star_progress_dirty = true


func _update_debug_and_stats_info() -> void:
	if _star_progress_dirty:
		_star_progress_dirty = false
		_update_sidebar_star_progress()

	if _stats_dirty:
		_stats_dirty = false
		gold_label.text = "🪙 " + _format_number(GameData.gold)
		token_label.text = "💎 " + _format_number(GameData.tokens)
		bounce_label.text = "Bounces: " + _format_number(GameData.total_bounces)
		corner_label.text = "★ Corners: " + _format_number(GameData.corner_hits)
		
	if _debug_label and _debug_label.visible:
		var fps := Engine.get_frames_per_second()
		var cpu_proc := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var cpu_phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var orphan_count := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

		_debug_label.text = "FPS: %d\nCPU Proc: %.2f ms\nPhysics: %.2f ms\nNodes: %d (Orphans: %d)\nLogos: %d" % [
			fps, cpu_proc, cpu_phys, node_count, orphan_count, GameData.logo_count
		]


func _on_upgrades_changed() -> void:
	_update_upgrade_buttons()
	_update_sidebar_star_progress()
	_update_special_skill_custom_ui()
	_update_tab_button_styles()


func _on_reincarnation_performed() -> void:
	_update_upgrade_buttons()
	_update_sidebar_star_progress()
	_update_slots_ui()
	_update_inventory_ui()
	_update_special_skill_custom_ui()
	_update_skill_nodes()
	if skill_tree_scroll:
		skill_tree_scroll.update_culling()


func _update_special_skill_custom_ui() -> void:
	if not special_skill_ui_container:
		return

	# 特殊スキルの収集:
	# 1. 転生画面で強化されている特殊スキル (GameData.special_skill_defs に定義があり total_level > 0)
	# 2. 装備中アイテムに付与されている特殊スキル
	var active_spec_skills: Array[Dictionary] = []
	var active_skill_ids: Dictionary = {}

	# 1. 転生解放済み特殊スキル
	for spec_id in GameData.special_skill_defs:
		var total_lvl := GameData.get_special_skill_total_level(spec_id)
		if total_lvl > 0:
			var def: Dictionary = GameData.special_skill_defs[spec_id].duplicate()
			def["level"] = total_lvl
			active_spec_skills.append(def)
			active_skill_ids[spec_id] = true

	# 2. 装備品に付与された特殊スキル（まだ追加されていないものやレベル更新）
	for slot_key in GameData.equipped_items:
		var item = GameData.equipped_items[slot_key]
		if item != null:
			var skills: Array = item.get("equip_skill", [])
			for sk in skills:
				if sk.get("is_special", false) and sk.get("has_custom_ui", false):
					var sk_id: String = sk.get("id", "")
					if not active_skill_ids.has(sk_id):
						var sk_entry: Dictionary = sk.duplicate()
						sk_entry["level"] = GameData.get_special_skill_total_level(sk_id)
						active_spec_skills.append(sk_entry)
						active_skill_ids[sk_id] = true

	if active_spec_skills.is_empty():
		for child in special_skill_ui_container.get_children():
			child.queue_free()
		special_skill_ui_container.visible = false
		return

	special_skill_ui_container.visible = true

	# 不要になった既存UI（active_skill_ids に含まれないもの）のみ破棄
	for child in special_skill_ui_container.get_children():
		var child_id: String = child.get_meta("skill_id", "")
		if child_id == "" or not active_skill_ids.has(child_id):
			child.queue_free()

	# 専用UIパネルの動的生成（完全指定位置に配置）
	const SPECIAL_SKILL_UI_MAP := {
		"spec_diversity": "res://scenes/ui/special_skills/diversity_skill_ui.tscn",
		"spec_accumulation": "res://scenes/ui/special_skills/accumulation_skill_ui.tscn",
		"spec_trinity": "res://scenes/ui/special_skills/trinity_skill_ui.tscn",
		"spec_switch": "res://scenes/ui/special_skills/switch_skill_ui.tscn",
		"spec_gamble": "res://scenes/ui/special_skills/gamble_skill_ui.tscn"
	}
	const SPECIAL_SKILL_POSITIONS := {
		"spec_diversity": Vector2(20.0, 20.0),
		"spec_accumulation": Vector2(20.0, 290.0),
		"spec_trinity": Vector2(20.0, 390.0),
		"spec_switch": Vector2(20.0, 620.0),
		"spec_gamble": Vector2(20.0, 735.0)
	}

	for sk in active_spec_skills:
		var sk_id: String = sk.get("id", "")

		# 既にノードが存在するか確認（破棄キューに入っていないもの）
		var existing_node: Node = null
		for child in special_skill_ui_container.get_children():
			if not child.is_queued_for_deletion() and child.get_meta("skill_id", "") == sk_id:
				existing_node = child
				break

		if existing_node != null:
			# 既存ノードがある場合は再利用（データ更新のみ行い、Tweenや描画状態を保持）
			if existing_node.has_method("set_skill_data"):
				existing_node.set_skill_data(sk)
			continue

		# 新規ノード作成
		if SPECIAL_SKILL_UI_MAP.has(sk_id) and ResourceLoader.exists(SPECIAL_SKILL_UI_MAP[sk_id]):
			var scene: PackedScene = load(SPECIAL_SKILL_UI_MAP[sk_id])
			var custom_ui = scene.instantiate()
			custom_ui.name = sk_id
			custom_ui.set_meta("skill_id", sk_id)
			if custom_ui.has_method("set_skill_data"):
				custom_ui.set_skill_data(sk)
			if SPECIAL_SKILL_POSITIONS.has(sk_id):
				custom_ui.position = SPECIAL_SKILL_POSITIONS[sk_id]
			special_skill_ui_container.add_child(custom_ui)
		else:
			# フォールバック表示（デフォルトミニカード）
			var panel = PanelContainer.new()
			panel.name = sk_id
			panel.set_meta("skill_id", sk_id)
			panel.custom_minimum_size = Vector2(150, 34)

			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.1, 0.25, 0.9)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = GameData.special_skill_color
			style.set_corner_radius_all(6)
			panel.add_theme_stylebox_override("panel", style)

			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 8)
			margin.add_theme_constant_override("margin_right", 8)
			panel.add_child(margin)

			var hbox = HBoxContainer.new()
			hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			margin.add_child(hbox)

			var title_lbl = Label.new()
			var ui_title: String = sk.get("ui_title", sk.get("name", "特殊スキル"))
			title_lbl.text = "%s Lv.%d" % [ui_title, sk.get("level", 1)]
			title_lbl.add_theme_color_override("font_color", GameData.special_skill_color)
			title_lbl.add_theme_font_size_override("font_size", 13)
			hbox.add_child(title_lbl)

			special_skill_ui_container.add_child(panel)


func _on_corner_hit() -> void:
	## Show announcement when a corner hit occurs.
	var current_ticks := Time.get_ticks_msec()
	if current_ticks - _last_corner_announce_ticks < 250:
		return
	_last_corner_announce_ticks = current_ticks

	# 既存のTweenをKillして連続ヒット時の文字消失バグを防止
	if is_instance_valid(_corner_tween) and _corner_tween.is_running():
		_corner_tween.kill()

	if corner_announce:
		corner_announce.visible = true
		corner_announce.modulate.a = 1.0
		corner_announce.scale = Vector2(1.0, 1.0)
		
		_corner_tween = create_tween()
		_corner_tween.set_parallel(true)
		# シンプルな拡大アニメーション（1.2倍）
		_corner_tween.tween_property(corner_announce, "scale", Vector2(1.2, 1.2), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_corner_tween.tween_property(corner_announce, "modulate:a", 0.0, 0.5).set_delay(0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _update_all() -> void:
	_on_gold_changed(GameData.gold)
	_on_tokens_changed(GameData.tokens)
	_on_stats_changed()
	_update_upgrade_buttons()


func _process(_delta: float) -> void:
	var is_c2 := GameData.is_base_stat_disabled_challenge_active()
	var is_c4 := GameData.is_ascension_disabled_challenge_active()
	var is_trinity := GameData.is_trinity_active()
	if is_c2 or is_trinity or is_c4:
		_was_trinity_active = true
		_apply_trinity_button_styles()
	elif _was_trinity_active:
		_was_trinity_active = false
		_restore_upgrade_button_styles()

	# アセンションボタン: 押せるとき (can_ascend() && !disabled) にスター画面の注入ボタンや鍛造ボタンのようにゆっくり明滅
	if btn_ascend:
		if not btn_ascend.disabled and GameData.can_ascend():
			var t: float = float(Time.get_ticks_msec()) * 0.0022
			var pulse: float = 0.5 + 0.5 * sin(t)
			var glow: Color = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(1.5, 1.3, 1.8, 1.0), pulse)
			btn_ascend.modulate = glow
		else:
			btn_ascend.modulate = Color.WHITE


func _on_trinity_changed() -> void:
	_update_upgrade_buttons()


func _apply_trinity_button_styles() -> void:
	var is_c2 := GameData.is_base_stat_disabled_challenge_active()
	var is_c4 := GameData.is_ascension_disabled_challenge_active()
	var active_stat := GameData.trinity_sacrificed_stat
	var time := Time.get_ticks_msec() * 0.001
	var pulse := 0.8 + 0.2 * sin(time * 3.5)
	var glow_gold := Color(1.0, 0.88, 0.28, 1.0) * pulse
	glow_gold.a = 1.0
	var glow_gold_hover := Color(1.0, 0.95, 0.45, 1.0)

	var red_border := Color(0.95, 0.25, 0.30, 0.95)
	var red_border_hover := Color(1.0, 0.35, 0.40, 1.0)

	var stat_btns := [
		{ "stat": "size", "btn": btn_size },
		{ "stat": "speed", "btn": btn_speed },
		{ "stat": "boost", "btn": btn_boost }
	]

	var is_trinity := GameData.is_trinity_active()

	for entry in stat_btns:
		var stat_id: String = entry["stat"]
		var btn: Button = entry["btn"]
		var defaults: Dictionary = _default_upgrade_btn_styles.get(btn, {})
		var states := ["normal", "hover", "pressed", "disabled"]

		if is_c2 or (is_trinity and active_stat == stat_id):
			# 赤枠 (基礎強化無効 または トリニティ生贄)
			for state_name in states:
				var def_style: StyleBoxFlat = defaults.get(state_name, null)
				var style := StyleBoxFlat.new()
				style.corner_radius_top_left = 3
				style.corner_radius_top_right = 3
				style.corner_radius_bottom_right = 3
				style.corner_radius_bottom_left = 3
				if def_style:
					style.bg_color = def_style.bg_color
				else:
					style.bg_color = Color(0.33, 0.15, 0.85, 1)

				style.border_color = red_border_hover if state_name == "hover" else red_border
				style.border_width_left = 2
				style.border_width_top = 2
				style.border_width_right = 2
				style.border_width_bottom = 2
				btn.add_theme_stylebox_override(state_name, style)
		elif is_trinity:
			# トリニティ強化枠 (黄色・金色)
			for state_name in states:
				var def_style: StyleBoxFlat = defaults.get(state_name, null)
				var style := StyleBoxFlat.new()
				style.corner_radius_top_left = 3
				style.corner_radius_top_right = 3
				style.corner_radius_bottom_right = 3
				style.corner_radius_bottom_left = 3
				if def_style:
					style.bg_color = def_style.bg_color
				else:
					style.bg_color = Color(0.33, 0.15, 0.85, 1)

				style.border_color = glow_gold_hover if state_name == "hover" else glow_gold
				style.border_width_left = 3
				style.border_width_top = 3
				style.border_width_right = 3
				style.border_width_bottom = 3
				btn.add_theme_stylebox_override(state_name, style)
		else:
			# トリニティも c2 も無効な場合 (c4 等のみ発動中) はデフォルトスタイルを維持
			if not defaults.is_empty():
				for state_name in states:
					if defaults.has(state_name) and defaults[state_name]:
						btn.add_theme_stylebox_override(state_name, defaults[state_name])

	if btn_ascend:
		var defaults_ascend: Dictionary = _default_upgrade_btn_styles.get(btn_ascend, {})
		var states := ["normal", "hover", "pressed", "disabled"]
		if is_c4:
			for state_name in states:
				var def_style = defaults_ascend.get(state_name, null)
				var style := StyleBoxFlat.new()
				style.corner_radius_top_left = 3
				style.corner_radius_top_right = 3
				style.corner_radius_bottom_right = 3
				style.corner_radius_bottom_left = 3
				if def_style is StyleBoxFlat:
					style.bg_color = def_style.bg_color
				else:
					style.bg_color = Color(0.24, 0.14, 0.42, 1)
				style.border_color = red_border_hover if state_name == "hover" else red_border
				style.border_width_left = 2
				style.border_width_top = 2
				style.border_width_right = 2
				style.border_width_bottom = 2
				btn_ascend.add_theme_stylebox_override(state_name, style)
		elif not defaults_ascend.is_empty():
			for state_name in states:
				if defaults_ascend.has(state_name) and defaults_ascend[state_name]:
					btn_ascend.add_theme_stylebox_override(state_name, defaults_ascend[state_name])


func _restore_upgrade_button_styles() -> void:
	for btn in [btn_size, btn_speed, btn_boost, btn_ascend]:
		if _default_upgrade_btn_styles.has(btn):
			var defaults: Dictionary = _default_upgrade_btn_styles[btn]
			for state_name in ["normal", "hover", "pressed", "disabled"]:
				if defaults.has(state_name) and defaults[state_name]:
					btn.add_theme_stylebox_override(state_name, defaults[state_name])



func _on_buy_mode_pressed() -> void:
	var modes := _get_available_buy_modes()
	_sidebar_buy_mode_idx = (_sidebar_buy_mode_idx + 1) % modes.size()
	_update_upgrade_buttons()


func _update_upgrade_buttons() -> void:
	if not _lbl_cost_size or not _lbl_cost_speed or not _lbl_cost_boost:
		return
	var gold := GameData.gold
	var is_trinity := GameData.is_trinity_active()
	var mode: int = _get_current_buy_mode()

	if btn_buy_mode:
		btn_buy_mode.text = "最大" if mode == -1 else str(mode)

	# --- Upgrade 1: Logo Size ---
	var cost_size: float = 0.0
	var size_ok: bool = false
	if mode == -1:
		var max_size_cnt := GameData.get_size_upgrade_max_count()
		if max_size_cnt > 0:
			cost_size = GameData.get_size_upgrade_cost(max_size_cnt)
			size_ok = true
			_lbl_cost_size.text = "🪙 " + _format_number(cost_size) + " (+%d)" % max_size_cnt
		else:
			cost_size = GameData.get_size_upgrade_cost(1)
			size_ok = false
			_lbl_cost_size.text = "🪙 " + _format_number(cost_size) + " (+0)"
	else:
		cost_size = GameData.get_size_upgrade_cost(mode)
		size_ok = gold >= cost_size
		_lbl_cost_size.text = "🪙 " + _format_number(cost_size)

	btn_size.disabled = !size_ok
	_lbl_title_size.text = "ロゴサイズ強化  Lv. %d" % GameData.size_level
	_lbl_title_size.add_theme_color_override("font_color", Color.WHITE if size_ok else Color(1, 1, 1, 0.4))
	_lbl_cost_size.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85) if size_ok else Color.RED)

	var is_c2 := GameData.is_base_stat_disabled_challenge_active()

	var size_diff := GameData.get_base_upgrade_stat_diff("size")
	if is_c2 or (is_trinity and GameData.trinity_sacrificed_stat == "size"):
		_lbl_diff_size.visible = true
		_lbl_diff_size.text = "[無効]"
		_lbl_diff_size.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0)) # 無効化: 赤色
	elif size_diff > 0:
		_lbl_diff_size.visible = true
		_lbl_diff_size.text = "[%+d]" % size_diff
		_lbl_diff_size.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0)) # 強化: 黄色
	else:
		_lbl_diff_size.visible = false
		_lbl_diff_size.text = ""

	# --- Upgrade 2: Speed ---
	var cost_speed: float = 0.0
	var speed_ok: bool = false
	if mode == -1:
		var max_speed_cnt := GameData.get_speed_upgrade_max_count()
		if max_speed_cnt > 0:
			cost_speed = GameData.get_speed_upgrade_cost(max_speed_cnt)
			speed_ok = true
			_lbl_cost_speed.text = "🪙 " + _format_number(cost_speed) + " (+%d)" % max_speed_cnt
		else:
			cost_speed = GameData.get_speed_upgrade_cost(1)
			speed_ok = false
			_lbl_cost_speed.text = "🪙 " + _format_number(cost_speed) + " (+0)"
	else:
		cost_speed = GameData.get_speed_upgrade_cost(mode)
		speed_ok = gold >= cost_speed
		_lbl_cost_speed.text = "🪙 " + _format_number(cost_speed)

	btn_speed.disabled = !speed_ok
	_lbl_title_speed.text = "速度強化  Lv. %d" % GameData.speed_level
	_lbl_title_speed.add_theme_color_override("font_color", Color.WHITE if speed_ok else Color(1, 1, 1, 0.4))
	_lbl_cost_speed.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85) if speed_ok else Color.RED)

	var speed_diff := GameData.get_base_upgrade_stat_diff("speed")
	if is_c2 or (is_trinity and GameData.trinity_sacrificed_stat == "speed"):
		_lbl_diff_speed.visible = true
		_lbl_diff_speed.text = "[無効]"
		_lbl_diff_speed.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0)) # 無効化: 赤色
	elif speed_diff > 0:
		_lbl_diff_speed.visible = true
		_lbl_diff_speed.text = "[%+d]" % speed_diff
		_lbl_diff_speed.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0)) # 強化: 黄色
	else:
		_lbl_diff_speed.visible = false
		_lbl_diff_speed.text = ""

	# --- Upgrade 3: Gold/Token Boost ---
	var cost_boost: float = 0.0
	var boost_ok: bool = false
	if mode == -1:
		var max_boost_cnt := GameData.get_boost_upgrade_max_count()
		if max_boost_cnt > 0:
			cost_boost = GameData.get_boost_upgrade_cost(max_boost_cnt)
			boost_ok = true
			_lbl_cost_boost.text = "🪙 " + _format_number(cost_boost) + " (+%d)" % max_boost_cnt
		else:
			cost_boost = GameData.get_boost_upgrade_cost(1)
			boost_ok = false
			_lbl_cost_boost.text = "🪙 " + _format_number(cost_boost) + " (+0)"
	else:
		cost_boost = GameData.get_boost_upgrade_cost(mode)
		boost_ok = gold >= cost_boost
		_lbl_cost_boost.text = "🪙 " + _format_number(cost_boost)

	btn_boost.disabled = !boost_ok
	_lbl_title_boost.text = "ゴールド・トークン増加  Lv. %d" % GameData.boost_level
	_lbl_title_boost.add_theme_color_override("font_color", Color.WHITE if boost_ok else Color(1, 1, 1, 0.4))
	_lbl_cost_boost.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85) if boost_ok else Color.RED)

	var boost_diff := GameData.get_base_upgrade_stat_diff("boost")
	if is_c2 or (is_trinity and GameData.trinity_sacrificed_stat == "boost"):
		_lbl_diff_boost.visible = true
		_lbl_diff_boost.text = "[無効]"
		_lbl_diff_boost.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0)) # 無効化: 赤色
	elif boost_diff > 0:
		_lbl_diff_boost.visible = true
		_lbl_diff_boost.text = "[%+d]" % boost_diff
		_lbl_diff_boost.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0)) # 強化: 黄色
	else:
		_lbl_diff_boost.visible = false
		_lbl_diff_boost.text = ""

	# --- Upgrade 4: Ascension ---
	var total_base_lvl := GameData.get_base_upgrade_total_level()
	var ascend_ok := GameData.can_ascend()
	btn_ascend.disabled = !ascend_ok
	var title_col := Color.WHITE if ascend_ok else Color(1, 1, 1, 0.4)

	if _lbl_progress_ascend:
		_lbl_title_ascend.text = "アセンション  Lv. %d" % GameData.ascension_level
		_lbl_title_ascend.add_theme_color_override("font_color", title_col)
		_lbl_progress_ascend.text = "(%d/100)" % mini(100, total_base_lvl)
		_lbl_progress_ascend.add_theme_color_override("font_color", title_col)
	else:
		_lbl_title_ascend.text = "アセンション  Lv. %d  (%d/100)" % [GameData.ascension_level, mini(100, total_base_lvl)]
		_lbl_title_ascend.add_theme_color_override("font_color", title_col)

	var remaining := GameData.get_ascension_logos_next_remaining()
	if remaining == 1:
		btn_ascend.tooltip_text = "ロゴ追加まであと 1 回（今回でロゴ+1！）"
	else:
		btn_ascend.tooltip_text = "ロゴ追加まであと %d 回" % remaining

	if _lbl_diff_ascend:
		var is_c4 := GameData.is_c4_active()
		var ascend_diff := GameData.get_ascension_stat_diff()
		if is_c4:
			_lbl_diff_ascend.visible = true
			_lbl_diff_ascend.text = "[無効]"
			_lbl_diff_ascend.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0)) # 無効化: 赤色
		elif ascend_diff > 0:
			_lbl_diff_ascend.visible = true
			_lbl_diff_ascend.text = "[%+d]" % ascend_diff
			_lbl_diff_ascend.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0)) # 強化: 黄色
		else:
			_lbl_diff_ascend.visible = false
			_lbl_diff_ascend.text = ""


func _on_speed_pressed() -> void:
	var mode := _get_current_buy_mode()
	var count := GameData.get_speed_upgrade_max_count() if mode == -1 else mode
	if count > 0:
		GameData.buy_speed_upgrade(count)


func _on_boost_pressed() -> void:
	var mode := _get_current_buy_mode()
	var count := GameData.get_boost_upgrade_max_count() if mode == -1 else mode
	if count > 0:
		GameData.buy_boost_upgrade(count)


func _on_size_pressed() -> void:
	var mode := _get_current_buy_mode()
	var count := GameData.get_size_upgrade_max_count() if mode == -1 else mode
	if count > 0:
		GameData.buy_size_upgrade(count)


func _on_ascend_pressed() -> void:
	GameData.perform_ascension()


## Formats a number for HUD displays (integers without decimal points, or scientific notation for >= 1e10).
func _format_number(n) -> String:
	var val := float(n)
	var abs_v := absf(val)
	if abs_v < 1.0:
		return "0"
	if abs_v < 1e10:
		var int_val := int(floorf(abs_v))
		var sign_str := "-" if val < 0.0 else ""
		return "%s%s" % [sign_str, GameData.add_commas(str(int_val))]
	return GameData.format_num(val)


func _on_stars_changed(new_amount: int) -> void:
	if star_label:
		star_label.text = "⚛️ %s" % _format_number(new_amount)
	_update_sidebar_star_progress()


func _update_sidebar_star_progress() -> void:
	if sidebar_star_progress_bar:
		var next_cost = GameData.get_next_star_cost()
		sidebar_star_progress_bar.max_value = next_cost
		sidebar_star_progress_bar.value = min(GameData.infused_tokens, next_cost)


func _apply_tab_style(btn: Button, is_active: bool, is_subtab: bool = false) -> void:
	if not btn:
		return
	if not is_subtab:
		if is_active:
			btn.add_theme_stylebox_override("normal", _tab_style_active)
			btn.add_theme_stylebox_override("hover", _tab_style_active_hover)
			btn.add_theme_stylebox_override("pressed", _tab_style_active_pressed)
		else:
			btn.add_theme_stylebox_override("normal", _tab_style_inactive)
			btn.add_theme_stylebox_override("hover", _tab_style_inactive_hover)
			btn.add_theme_stylebox_override("pressed", _tab_style_inactive_pressed)
	else:
		if is_active:
			btn.add_theme_stylebox_override("normal", _subtab_style_active)
			btn.add_theme_stylebox_override("hover", _subtab_style_active_hover)
			btn.add_theme_stylebox_override("pressed", _subtab_style_active_pressed)
		else:
			btn.add_theme_stylebox_override("normal", _subtab_style_inactive)
			btn.add_theme_stylebox_override("hover", _subtab_style_inactive_hover)
			btn.add_theme_stylebox_override("pressed", _subtab_style_inactive_pressed)


func _apply_subtab_button(btn: Button, is_active: bool, is_unlocked: bool, unlocked_text: String, locked_text: String) -> void:
	if not btn:
		return
	btn.visible = true
	if is_unlocked:
		btn.disabled = false
		btn.text = unlocked_text
		btn.tooltip_text = ""
		btn.remove_theme_color_override("font_disabled_color")
		_apply_tab_style(btn, is_active, true)
	else:
		btn.disabled = true
		btn.text = locked_text
		btn.tooltip_text = "🔒 スキルツリーで解放できます"
		btn.add_theme_stylebox_override("disabled", _subtab_style_locked)
		btn.add_theme_color_override("font_disabled_color", Color(0.40, 0.40, 0.48, 0.8))


func _update_tab_button_styles() -> void:
	# 大タブ（ホーム / 転生）のスタイル更新
	_apply_tab_style(btn_home_tab, not _is_reincarnation_open, false)
	_apply_tab_style(btn_reincarnation_tab, _is_reincarnation_open, false)
	
	# サブタブ（ホーム画面側ツールバー / 転生画面側ツールバー）の表示・非表示とスタイル更新
	if sub_nav_container:
		sub_nav_container.visible = not _is_reincarnation_open
	if reinc_sub_nav_container:
		reinc_sub_nav_container.visible = _is_reincarnation_open

	_apply_subtab_button(btn_skill_tree_tab, _is_skill_tree_open, true, "🌳 スキル", "🌳 スキル")
	_apply_subtab_button(btn_equipment_tab, _is_inventory_open, GameData.is_window_unlocked("equipment"), "🎒 装備", "🔒 装備")
	_apply_subtab_button(btn_challenge_tab, _is_challenge_open, GameData.is_window_unlocked("challenge"), "🏆 チャレンジ", "🔒 チャレンジ")
	_apply_subtab_button(btn_blacksmith_tab, _is_blacksmith_open, GameData.is_window_unlocked("blacksmith"), "🔨 鍛冶", "🔒 鍛冶")
	_apply_subtab_button(btn_amplifier_tab, _is_amplifier_open, GameData.is_window_unlocked("amplifier"), "⚡ 融合", "🔒 融合")

	_apply_tab_style(btn_reinc_tab_1, _is_reinc_tree_open, true)
	_apply_tab_style(btn_reinc_tab_2, _is_reinc_ability_open, true)


func _on_home_tab_pressed() -> void:
	if _is_reincarnation_open:
		close_reincarnation()


func _on_reincarnation_tab_pressed() -> void:
	if not _is_reincarnation_open:
		open_reincarnation()


func open_reincarnation() -> void:
	if _is_reincarnation_open:
		return
	_is_reincarnation_open = true
	
	# 転生画面表示時はホーム画面用のウィンドウを閉じる
	if _is_inventory_open:
		close_inventory()
	if _is_skill_tree_open:
		close_skill_tree()
	if _is_challenge_open:
		close_challenge()
	if _is_blacksmith_open:
		close_blacksmith()
	if _is_amplifier_open:
		close_amplifier()
	if _is_reinc_tree_open:
		close_reinc_tree()
	if _is_reinc_ability_open:
		close_reinc_ability()
	if _is_save_slot_open:
		close_save_slot_window()

	reincarnation_window.visible = true
	if reincarnation_window.has_method("update_ui"):
		reincarnation_window.update_ui()
	_update_tab_button_styles()


func close_reincarnation() -> void:
	if not _is_reincarnation_open:
		return
	_is_reincarnation_open = false
	if _is_reinc_tree_open:
		close_reinc_tree()
	if _is_reinc_ability_open:
		close_reinc_ability()
	reincarnation_window.visible = false
	_update_tab_button_styles()


func _on_equipment_tab_pressed() -> void:
	if not GameData.is_window_unlocked("equipment"):
		return
	if _is_reincarnation_open:
		close_reincarnation()
	if _is_skill_tree_open:
		close_skill_tree()
	if _is_challenge_open:
		close_challenge()
	if _is_blacksmith_open:
		close_blacksmith()
	if _is_amplifier_open:
		close_amplifier()
	if _is_reinc_tree_open:
		close_reinc_tree()
	if _is_reinc_ability_open:
		close_reinc_ability()
	if _is_save_slot_open:
		close_save_slot_window()
	
	if _is_inventory_open:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	if not GameData.is_window_unlocked("equipment"):
		return
	if _is_inventory_open:
		return
		
	_is_inventory_open = true
	inventory_window.visible = true
	_update_inventory_ui()
	_update_tab_button_styles()
	_update_window_dimmer()


func close_inventory() -> void:
	if not _is_inventory_open:
		return
		
	_is_inventory_open = false
	if inventory_filter_window:
		inventory_filter_window.visible = false
	if equipment_filter_window:
		equipment_filter_window.visible = false
	if inventory_dimmer:
		inventory_dimmer.visible = false
		inventory_dimmer.modulate.a = 0.0
	InventoryItemUI.drag_select_mode = -1
	_hide_sell_popup()
	_clear_inventory_selection()
	_clear_discard_pop()
	inventory_window.visible = false
	_update_tab_button_styles()
	_update_window_dimmer()


func _on_equipment_filter_pressed() -> void:
	if not equipment_filter_window:
		return
	if inventory_filter_window:
		inventory_filter_window.visible = false
	equipment_filter_window.visible = not equipment_filter_window.visible
	if equipment_filter_window.visible and equipment_filter_window.has_method("sync_from_data"):
		equipment_filter_window.sync_from_data()
	_update_inventory_dimmer()


func _open_inventory_filter(type: String) -> void:
	if not inventory_filter_window:
		return
	if equipment_filter_window:
		equipment_filter_window.visible = false
	if inventory_filter_window.visible and inventory_filter_window.target_type == type:
		inventory_filter_window.visible = false
	else:
		inventory_filter_window.open_for_type(type)
	_update_inventory_dimmer()


var _inv_dimmer_tween: Tween = null


func _update_inventory_dimmer() -> void:
	if not is_instance_valid(inventory_dimmer):
		return
	if is_instance_valid(_inv_dimmer_tween) and _inv_dimmer_tween.is_running():
		_inv_dimmer_tween.kill()

	var is_filter_open: bool = (
		(equipment_filter_window != null and equipment_filter_window.visible) or
		(inventory_filter_window != null and inventory_filter_window.visible)
	)

	if is_filter_open:
		inventory_dimmer.visible = true
		_inv_dimmer_tween = create_tween()
		_inv_dimmer_tween.tween_property(inventory_dimmer, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		if inventory_dimmer.visible:
			_inv_dimmer_tween = create_tween()
			_inv_dimmer_tween.tween_property(inventory_dimmer, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_inv_dimmer_tween.tween_callback(func():
				if is_instance_valid(inventory_dimmer):
					inventory_dimmer.visible = false
			)
		else:
			inventory_dimmer.modulate.a = 0.0


func _on_inventory_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if equipment_filter_window and equipment_filter_window.visible:
			equipment_filter_window.visible = false
		if inventory_filter_window and inventory_filter_window.visible:
			inventory_filter_window.visible = false
		_update_inventory_dimmer()


func _on_skill_tree_tab_pressed() -> void:
	if _is_reincarnation_open:
		close_reincarnation()
	if _is_inventory_open:
		close_inventory()
	if _is_challenge_open:
		close_challenge()
	if _is_blacksmith_open:
		close_blacksmith()
	if _is_amplifier_open:
		close_amplifier()
	if _is_reinc_tree_open:
		close_reinc_tree()
	if _is_reinc_ability_open:
		close_reinc_ability()
	if _is_save_slot_open:
		close_save_slot_window()
		
	if _is_skill_tree_open:
		close_skill_tree()
	else:
		open_skill_tree()


func open_skill_tree() -> void:
	if _is_skill_tree_open:
		return
	
	_is_skill_tree_open = true
	skill_tree_window.visible = true
	_update_skill_nodes()
	_update_tab_button_styles()
	_update_window_dimmer()
	
	# ゲーム起動時（初回オープン時）のみ中央位置合わせを行う
	if not _has_centered_on_startup:
		_has_centered_on_startup = true
		# サイズが完全に解決するまで最大10フレーム待つ
		for i in range(10):
			await get_tree().process_frame
			if skill_tree_window.size.x > 100 and skill_tree_scroll.size.x > 100:
				break
		# トランスフォームの整合性を確実にするためにもう1フレーム待つ
		await get_tree().process_frame
		if is_instance_valid(skill_tree_scroll):
			skill_tree_scroll.center_on_root(skill_tree_window)


func close_skill_tree() -> void:
	if not _is_skill_tree_open:
		return
	
	_is_skill_tree_open = false
	skill_tree_window.visible = false
	_update_tab_button_styles()
	_update_window_dimmer()


func _on_challenge_tab_pressed() -> void:
	if not GameData.is_window_unlocked("challenge"):
		return
	if _is_reincarnation_open:
		close_reincarnation()
	if _is_inventory_open:
		close_inventory()
	if _is_skill_tree_open:
		close_skill_tree()
	if _is_blacksmith_open:
		close_blacksmith()
	if _is_amplifier_open:
		close_amplifier()
	if _is_reinc_tree_open:
		close_reinc_tree()
	if _is_reinc_ability_open:
		close_reinc_ability()
	if _is_save_slot_open:
		close_save_slot_window()
		
	if _is_challenge_open:
		close_challenge()
	else:
		open_challenge()


func open_challenge() -> void:
	if not GameData.is_window_unlocked("challenge"):
		return
	if _is_challenge_open:
		return
	
	_is_challenge_open = true
	if challenge_window:
		challenge_window.visible = true
	_update_tab_button_styles()
	_update_window_dimmer()


func close_challenge() -> void:
	if not _is_challenge_open:
		return
	
	_is_challenge_open = false
	if challenge_window:
		challenge_window.visible = false
	_update_tab_button_styles()
	_update_window_dimmer()


func _on_blacksmith_tab_pressed() -> void:
	if not GameData.is_window_unlocked("blacksmith"):
		return
	if _is_reincarnation_open:
		close_reincarnation()
	if _is_inventory_open:
		close_inventory()
	if _is_skill_tree_open:
		close_skill_tree()
	if _is_challenge_open:
		close_challenge()
	if _is_amplifier_open:
		close_amplifier()
	if _is_reinc_tree_open:
		close_reinc_tree()
	if _is_reinc_ability_open:
		close_reinc_ability()
	if _is_save_slot_open:
		close_save_slot_window()
		
	if _is_blacksmith_open:
		close_blacksmith()
	else:
		open_blacksmith()


func open_blacksmith() -> void:
	if not GameData.is_window_unlocked("blacksmith"):
		return
	if _is_blacksmith_open:
		return
	
	_is_blacksmith_open = true
	if blacksmith_window:
		blacksmith_window.visible = true
		if blacksmith_window.has_method("update_all"):
			blacksmith_window.update_all()
	_update_tab_button_styles()
	_update_window_dimmer()


func close_blacksmith() -> void:
	if not _is_blacksmith_open:
		return
	
	_is_blacksmith_open = false
	if blacksmith_window:
		blacksmith_window.visible = false
	_update_tab_button_styles()
	_update_window_dimmer()


func _on_amplifier_tab_pressed() -> void:
	if not GameData.is_window_unlocked("amplifier"):
		return
	if _is_reincarnation_open:
		close_reincarnation()
	if _is_inventory_open:
		close_inventory()
	if _is_skill_tree_open:
		close_skill_tree()
	if _is_challenge_open:
		close_challenge()
	if _is_blacksmith_open:
		close_blacksmith()
	if _is_reinc_tree_open:
		close_reinc_tree()
	if _is_reinc_ability_open:
		close_reinc_ability()
	if _is_save_slot_open:
		close_save_slot_window()
		
	if _is_amplifier_open:
		close_amplifier()
	else:
		open_amplifier()


func open_amplifier() -> void:
	if not GameData.is_window_unlocked("amplifier"):
		return
	if _is_amplifier_open:
		return
	
	_is_amplifier_open = true
	if amplifier_window:
		amplifier_window.visible = true
		if amplifier_window.has_method("update_all"):
			amplifier_window.update_all()
	_update_tab_button_styles()
	_update_window_dimmer()


func close_amplifier() -> void:
	if not _is_amplifier_open:
		return
	
	_is_amplifier_open = false
	if amplifier_window:
		amplifier_window.visible = false
	_update_tab_button_styles()
	_update_window_dimmer()


func _on_reinc_tab_1_pressed() -> void:
	if _is_inventory_open:
		close_inventory()
	if _is_skill_tree_open:
		close_skill_tree()
	if _is_challenge_open:
		close_challenge()
	if _is_blacksmith_open:
		close_blacksmith()
	if _is_amplifier_open:
		close_amplifier()
	if _is_reinc_ability_open:
		close_reinc_ability()
	if _is_save_slot_open:
		close_save_slot_window()
	
	if _is_reinc_tree_open:
		close_reinc_tree()
	else:
		open_reinc_tree()


func open_reinc_tree() -> void:
	if _is_reinc_tree_open:
		return
	
	_is_reinc_tree_open = true
	_reinc_subtab_index = 0
	if reinc_tree_window:
		reinc_tree_window.visible = true
	_update_tab_button_styles()
	_update_window_dimmer()


func close_reinc_tree() -> void:
	if not _is_reinc_tree_open:
		return
	
	_is_reinc_tree_open = false
	if reinc_tree_window:
		reinc_tree_window.visible = false
	_update_tab_button_styles()
	_update_window_dimmer()


func _on_reinc_tab_2_pressed() -> void:
	if _is_inventory_open:
		close_inventory()
	if _is_skill_tree_open:
		close_skill_tree()
	if _is_challenge_open:
		close_challenge()
	if _is_blacksmith_open:
		close_blacksmith()
	if _is_amplifier_open:
		close_amplifier()
	if _is_reinc_tree_open:
		close_reinc_tree()
	if _is_save_slot_open:
		close_save_slot_window()
	
	if _is_reinc_ability_open:
		close_reinc_ability()
	else:
		open_reinc_ability()


func open_reinc_ability() -> void:
	if _is_reinc_ability_open:
		return
	
	_is_reinc_ability_open = true
	_reinc_subtab_index = 1
	if reinc_ability_window:
		reinc_ability_window.visible = true
	_update_tab_button_styles()
	_update_window_dimmer()


func close_reinc_ability() -> void:
	if not _is_reinc_ability_open:
		return
	
	_is_reinc_ability_open = false
	if reinc_ability_window:
		reinc_ability_window.visible = false
	_update_tab_button_styles()
	_update_window_dimmer()


func toggle_save_slot_window() -> void:
	if _is_save_slot_open:
		close_save_slot_window()
	else:
		open_save_slot_window()


func open_save_slot_window() -> void:
	if _is_save_slot_open:
		return
	_close_all_subbar_windows()
	_is_save_slot_open = true
	if save_slot_window:
		save_slot_window.visible = true
		if save_slot_window.has_method("refresh_slots"):
			save_slot_window.refresh_slots()
	_update_tab_button_styles()
	_update_window_dimmer()


func close_save_slot_window() -> void:
	if not _is_save_slot_open:
		return
	_is_save_slot_open = false
	if save_slot_window:
		save_slot_window.visible = false
	_update_tab_button_styles()
	_update_window_dimmer()


func _is_any_subbar_window_open() -> bool:
	return _is_inventory_open or _is_skill_tree_open or _is_challenge_open or _is_blacksmith_open or _is_amplifier_open or _is_reinc_tree_open or _is_reinc_ability_open or _is_save_slot_open


var _dimmer_tween: Tween = null


func _update_window_dimmer() -> void:
	if not is_instance_valid(window_dimmer):
		return
	if is_instance_valid(_dimmer_tween) and _dimmer_tween.is_running():
		_dimmer_tween.kill()
		
	var should_be_open := _is_any_subbar_window_open()
	if should_be_open:
		window_dimmer.visible = true
		_dimmer_tween = create_tween()
		_dimmer_tween.tween_property(window_dimmer, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		if window_dimmer.visible:
			_dimmer_tween = create_tween()
			_dimmer_tween.tween_property(window_dimmer, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_dimmer_tween.tween_callback(func():
				if not _is_any_subbar_window_open():
					window_dimmer.visible = false
			)
		else:
			window_dimmer.modulate.a = 0.0


func _on_window_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_all_subbar_windows()


func _close_all_subbar_windows() -> void:
	if _is_inventory_open:
		close_inventory()
	if _is_skill_tree_open:
		close_skill_tree()
	if _is_challenge_open:
		close_challenge()
	if _is_blacksmith_open:
		close_blacksmith()
	if _is_amplifier_open:
		close_amplifier()
	if _is_reinc_tree_open:
		close_reinc_tree()
	if _is_reinc_ability_open:
		close_reinc_ability()
	if _is_save_slot_open:
		close_save_slot_window()


func _setup_debug_free_skill_button() -> void:
	var header_controls = get_node_or_null("%HeaderControls")
	if not header_controls:
		return
		
	_btn_debug_free_skill = Button.new()
	_btn_debug_free_skill.name = "DebugFreeSkillBtn"
	_btn_debug_free_skill.custom_minimum_size = Vector2(160, 32)
	_btn_debug_free_skill.focus_mode = Control.FOCUS_NONE
	_btn_debug_free_skill.add_theme_font_size_override("font_size", 13)
	_btn_debug_free_skill.tooltip_text = "テスト用: スキルツリーの全スキルをコスト無視で解放可能にします\n(ShiftまたはCtrlを押しながらスキルをクリックすることでも即時解放可能)"
	_btn_debug_free_skill.pressed.connect(_on_debug_free_skill_button_pressed)
	header_controls.add_child(_btn_debug_free_skill)
	header_controls.move_child(_btn_debug_free_skill, 0)
	
	_update_debug_free_skill_button_style()
	GameData.debug_free_skill_cost_changed.connect(func(_enabled): _update_debug_free_skill_button_style())


func _on_debug_free_skill_button_pressed() -> void:
	GameData.toggle_debug_free_skill_cost()


func _update_debug_free_skill_button_style() -> void:
	if not is_instance_valid(_btn_debug_free_skill):
		return
	var is_on := GameData.debug_free_skill_cost
	_btn_debug_free_skill.text = "🧪 コスト無視: ON" if is_on else "🧪 コスト無視: OFF"
	
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	
	if is_on:
		style.bg_color = Color(0.18, 0.45, 0.28, 0.95)
		style.border_color = Color(0.40, 0.90, 0.55, 1.0)
		_btn_debug_free_skill.add_theme_color_override("font_color", Color(0.95, 1.0, 0.95))
	else:
		style.bg_color = Color(0.18, 0.18, 0.24, 0.8)
		style.border_color = Color(0.35, 0.35, 0.45, 0.8)
		_btn_debug_free_skill.add_theme_color_override("font_color", Color(0.70, 0.70, 0.78))
		
	_btn_debug_free_skill.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = hover_style.bg_color.lightened(0.15)
	_btn_debug_free_skill.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = pressed_style.bg_color.darkened(0.15)
	_btn_debug_free_skill.add_theme_stylebox_override("pressed", pressed_style)


func _on_skill_node_pressed(node: SkillNode) -> void:
	var is_debug_free := GameData.debug_free_skill_cost or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL)
	
	if not is_debug_free and not node.is_playable():
		return
		
	var current_lvl = GameData.get_skill_level(node.skill_id)
	if not node.is_unlimited and current_lvl > 0:
		return
	
	var cost = 0.0 if is_debug_free else node.get_upgrade_cost(current_lvl)
	if GameData.buy_skill_upgrade(node.skill_id, cost, node.is_unlimited, is_debug_free):
		_update_tab_button_styles()


func _on_skill_upgraded(skill_id: String, _new_level: int) -> void:
	_update_tab_button_styles()
	if skill_id == "buying_expand":
		_update_upgrade_buttons()
	if skill_id.begins_with("inventory_expand_") or skill_id == "equip_drop_unlock" or skill_id == "equip_drop_filter_unlock":
		_update_inventory_ui()
	if skill_tree_scroll:
		skill_tree_scroll.update_culling()


func _update_skill_nodes() -> void:
	if not _skill_tree_instance:
		return
	for child in _skill_tree_instance.get_children():
		if child is SkillNode:
			child._update_ui()


func _load_skills_from_json() -> void:
	if not _skill_tree_instance:
		return
		
	var json_path = "res://data/skills.json"
	if not FileAccess.file_exists(json_path):
		printerr("スキルデータファイルが見つかりません: ", json_path)
		return
		
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		printerr("スキルデータファイルのオープンに失敗しました: ", json_path)
		return
		
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(text) != OK:
		printerr("スキルデータファイルのJSONパースに失敗しました。")
		return
		
	var data = json.get_data()
	if not data is Dictionary or not data.has("skills"):
		printerr("スキルデータのフォーマットが不正です。")
		return
		
	var skills = data["skills"] as Dictionary
	var skill_node_scene = preload("res://scenes/skills/skill_node.tscn")
	var created_nodes: Array[SkillNode] = []
	
	# 1. すべてのノードをインスタンス化して追加
	for skill_id in skills:
		var s = skills[skill_id]
		var node = skill_node_scene.instantiate() as SkillNode
		node.skill_id = skill_id
		node.skill_name = s.get("name", "")
		node.icon_char = s.get("icon", "❓")
		node.description = s.get("description", "")
		node.is_unlimited = bool(s.get("is_unlimited", false))
		node.base_cost = float(s.get("base_cost", 1.0))
		node.cost_multiplier = float(s.get("cost_multiplier", 1.5))
		# パネル間の隙間を微調整（枠のさらなる太枠化に伴い、元の0.95倍から1.1倍に変更）して辺の長さを調整する
		node.position = Vector2(s.get("x", 0), s.get("y", 0)) * 1.1
		
		# prerequisites の変換 (Array -> Array[String])
		var prereqs_raw = s.get("prerequisites", [])
		var prereqs: Array[String] = []
		for p in prereqs_raw:
			prereqs.append(str(p))
		node.prerequisites = prereqs
		
		_skill_tree_instance.add_child(node)
		created_nodes.append(node)
		
	# 2. すべてのノードが追加された後、シグナルを接続し初期描画を行う
	for node in created_nodes:
		node.pressed.connect(_on_skill_node_pressed.bind(node))
		# 初期表示の更新（他ノードとの接続線を引く処理を含む）
		node.refresh()
		
	if skill_tree_scroll:
		skill_tree_scroll.invalidate_skill_node_cache()
		skill_tree_scroll.update_culling()


# --- Equipment UI Logic ---

func _init_slot_buttons() -> void:
	for child in grid_equipment.get_children():
		if child is SlotButton:
			_slot_buttons[child.slot_key] = child
	_update_slots_ui()


func _update_slots_ui() -> void:
	for slot_key in _slot_buttons:
		var btn = _slot_buttons[slot_key] as SlotButton
		var eq = GameData.equipped_items.get(slot_key)
		
		var slot_name := "(メインの装備スロット)"
		if slot_key == "sub":
			slot_name = "(サブの装備スロット)"
		elif slot_key.begins_with("accessory_"):
			var acc_num: String = slot_key.substr(10)
			slot_name = "(アクセサリースロット%s)" % acc_num
			
		btn.update_slot_ui(slot_name, eq)

	_update_special_skill_custom_ui()


func _update_inventory_ui() -> void:
	if not _is_inventory_open:
		return
		
	if btn_equipment_filter:
		btn_equipment_filter.visible = GameData.get_skill_level("equip_drop_filter_unlock") > 0
		
	var inv_main: Array = GameData.inventories.get("main", [])
	var inv_sub: Array = GameData.inventories.get("sub", [])
	var inv_acc: Array = GameData.inventories.get("accessory", [])
	
	var count_main = GameData.get_inventory_count("main")
	var count_sub = GameData.get_inventory_count("sub")
	var count_acc = GameData.get_inventory_count("accessory")
	var max_sz := GameData.get_max_inventory_size()
	
	main_title_label.text = "メイン (%d / %d)" % [count_main, max_sz]
	sub_title_label.text = "サブ (%d / %d)" % [count_sub, max_sz]
	accessory_title_label.text = "アクセサリー (%d / %d)" % [count_acc, max_sz]
	
	_update_grid_slots(main_grid, "main", inv_main)
	_update_grid_slots(sub_grid, "sub", inv_sub)
	_update_grid_slots(accessory_grid, "accessory", inv_acc)


class InventorySlotWrapper extends Control:
	var grid_type: String = ""
	var slot_index: int = -1
	var current_item_id: String = ""
	var child_item_ui: InventoryItemUI = null
	var child_empty_btn: InventoryEmptySlot = null
	
	func setup_slot(p_type: String, p_index: int) -> void:
		grid_type = p_type
		slot_index = p_index
		custom_minimum_size = Vector2(64, 64)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
	func update_slot_item(item_data: Variant) -> void:
		if item_data == null or not item_data is Dictionary or item_data.is_empty():
			if current_item_id == "" and child_empty_btn != null:
				return # 既に空き枠なら何も変更せず、ノードを維持する
				
			_clear_children()
			current_item_id = ""
			
			child_empty_btn = InventoryEmptySlot.new()
			child_empty_btn.grid_type = grid_type
			child_empty_btn.slot_index = slot_index
			child_empty_btn.custom_minimum_size = Vector2(64, 64)
			child_empty_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			child_empty_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			add_child(child_empty_btn)
			child_empty_btn.text = ""
			
			var style_empty = StyleBoxFlat.new()
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
		else:
			var new_id: String = item_data.get("id", "")
			if current_item_id == new_id and child_item_ui != null:
				# アイテムIDが同一の場合はノードの再作成をスキップし、ホバー・ツールチップ状態を完全に維持する
				child_item_ui._update_style()
				return
				
			_clear_children()
			current_item_id = new_id
			
			var item_scene := preload("res://scenes/ui/inventory_item_ui.tscn")
			child_item_ui = item_scene.instantiate() as InventoryItemUI
			add_child(child_item_ui)
			child_item_ui.setup(item_data)
			
	func _clear_children() -> void:
		for child in get_children():
			remove_child(child)
			child.queue_free()
		child_item_ui = null
		child_empty_btn = null


class InventoryEmptySlot extends Button:
	var grid_type: String = ""
	var slot_index: int = -1
	
	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not data is Dictionary:
			return false
		return data.get("type", "") == grid_type

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if data is Dictionary:
			if data.has("item_index"):
				var from_index: int = data.get("item_index", -1)
				GameData.swap_inventory_items(grid_type, from_index, slot_index)
			elif data.has("from_slot"):
				GameData.unequip_item_to_index(data.get("slot_key", ""), slot_index)


func _update_grid_slots(grid: GridContainer, grid_type: String, items: Array) -> void:
	var max_sz := GameData.get_max_inventory_size()
	if grid.get_child_count() != max_sz:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
		for i in range(max_sz):
			var wrapper := InventorySlotWrapper.new()
			wrapper.setup_slot(grid_type, i)
			grid.add_child(wrapper)
			
	for i in range(max_sz):
		var wrapper = grid.get_child(i) as InventorySlotWrapper
		var item_data = items[i] if i < items.size() else null
		if wrapper:
			wrapper.update_slot_item(item_data)
			if wrapper.child_item_ui and item_data != null and not item_data.is_empty():
				var is_matched: bool = GameData.is_item_matched_inventory_filter(item_data, grid_type)
				wrapper.child_item_ui.set_grayed_out(not is_matched)
				var it_id: String = item_data.get("id", "")
				wrapper.child_item_ui.set_selected(_selected_inventory_items.has(it_id))
				if not wrapper.child_item_ui.selection_toggled.is_connected(_on_inventory_item_selection_toggled):
					wrapper.child_item_ui.selection_toggled.connect(_on_inventory_item_selection_toggled)
				if not wrapper.child_item_ui.item_clicked.is_connected(_on_inventory_item_clicked):
					wrapper.child_item_ui.item_clicked.connect(_on_inventory_item_clicked)


func _on_equipment_changed() -> void:
	_update_slots_ui()
	_update_inventory_ui()


func _on_inventory_updated() -> void:
	if _is_inventory_open:
		_update_inventory_ui()


func show_equipment_drop_pop(item_data: Dictionary) -> void:
	var current_ticks := Time.get_ticks_msec()
	if current_ticks - _last_drop_pop_ticks < 100:
		return
	_last_drop_pop_ticks = current_ticks

	var item_name: String = item_data.get("name", "")
	var item_type: String = item_data.get("type", "")
	var item_icon: String = item_data.get("icon", "")
	var item_level: int = item_data.get("level", 1)
	var item_rarity: String = item_data.get("rarity", "コモン")
	
	var pop := PanelContainer.new()
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var rarity_color := GameData.get_rarity_color(item_rarity)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.8) # Slightly transparent black
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = rarity_color
	pop.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 6)
	pop.add_child(hbox)
	
	# Add texture icon if available
	if item_icon != "":
		var tex := load(item_icon)
		if tex:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.custom_minimum_size = Vector2(24, 24)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox.add_child(rect)
			
	var is_discarded: bool = item_data.get("is_discarded", false) or item_data.get("is_sold", false)
	var discard_gold: float = float(item_data.get("discard_gold", item_data.get("sell_price", 0.0)))
	var discard_tokens: float = float(item_data.get("discard_tokens", item_data.get("sell_tokens", 0.0)))
	
	var label := Label.new()
	if is_discarded:
		if discard_gold > 0.0 and discard_tokens > 0.0:
			label.text = "[%s] %s (Lv.%d) を入手 (廃棄🪙+%s/💎+%s)" % [item_rarity, item_name, item_level, _format_number(discard_gold), _format_number(discard_tokens)]
		elif discard_gold > 0.0:
			label.text = "[%s] %s (Lv.%d) を入手 (廃棄🪙+%s)" % [item_rarity, item_name, item_level, _format_number(discard_gold)]
		elif discard_tokens > 0.0:
			label.text = "[%s] %s (Lv.%d) を入手 (廃棄💎+%s)" % [item_rarity, item_name, item_level, _format_number(discard_tokens)]
		else:
			label.text = "[%s] %s (Lv.%d) を入手 (廃棄)" % [item_rarity, item_name, item_level]
	else:
		label.text = "[%s] %s (Lv.%d) を入手" % [item_rarity, item_name, item_level]
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", rarity_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(label)
	
	equipment_log_container.add_child(pop)
	
	# Animate popup (fade in, wait, fade out, then queue_free)
	pop.modulate.a = 0.0
	var tween := pop.create_tween()
	tween.tween_property(pop, "modulate:a", 1.0, 0.15)
	tween.tween_property(pop, "modulate:a", 0.0, 0.3).set_delay(3.0)
	tween.chain().tween_callback(pop.queue_free)


func _setup_grid_frames() -> void:
	# Define flat style for slot frames (distinct from main window BG)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.04, 0.04, 0.08, 0.9) # Very dark slot background
	frame_style.border_width_left = 1
	frame_style.border_width_top = 1
	frame_style.border_width_right = 1
	frame_style.border_width_bottom = 1
	frame_style.border_color = Color(0.15, 0.15, 0.22, 0.8) # Muted frame border
	frame_style.corner_radius_top_left = 6
	frame_style.corner_radius_top_right = 6
	frame_style.corner_radius_bottom_right = 6
	frame_style.corner_radius_bottom_left = 6
	frame_style.content_margin_left = 6
	frame_style.content_margin_top = 8
	frame_style.content_margin_right = 6
	frame_style.content_margin_bottom = 8
	
	var sections := [
		{"grid": main_grid, "header": get_node_or_null("%MainHeaderHBox")},
		{"grid": sub_grid, "header": get_node_or_null("%SubHeaderHBox")},
		{"grid": accessory_grid, "header": get_node_or_null("%AccessoryHeaderHBox")}
	]

	for item in sections:
		var grid: GridContainer = item["grid"]
		var header: Control = item["header"]
		if grid:
			grid.add_theme_constant_override("h_separation", 4)
			grid.add_theme_constant_override("v_separation", 4)
			grid.size_flags_vertical = Control.SIZE_FILL
			
			var parent = grid.get_parent()
			if parent:
				var index = grid.get_index()
				parent.remove_child(grid)
				
				var frame := PanelContainer.new()
				frame.name = grid.name + "Frame"
				frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				frame.add_theme_stylebox_override("panel", frame_style)
				
				frame.add_child(grid)
				parent.add_child(frame)
				parent.move_child(frame, index)
				
				if header:
					header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					header.custom_minimum_size.x = 350.0


func _on_toggle_skill_vis_pressed() -> void:
	if skill_tree_scroll:
		var filter_on := skill_tree_scroll.toggle_filter_unlocked_only()
		_update_toggle_skill_vis_button_text(filter_on)


func _update_toggle_skill_vis_button_text(filter_on: bool) -> void:
	if not btn_toggle_skill_vis:
		return
	if filter_on:
		btn_toggle_skill_vis.text = "🔒 表示: 開放可能のみ"
		btn_toggle_skill_vis.tooltip_text = "現在は前提スキルをすべて満たしているスキルのみ表示中\nクリックで全スキルを表示"
	else:
		btn_toggle_skill_vis.text = "👁️ 表示: 全スキル"
		btn_toggle_skill_vis.tooltip_text = "現在は全てのスキルを表示中\nクリックで前提開放スキルのみを表示"


# --- チャレンジ進捗確認用ミニウィンドウ (メイン画面右下・通貨欄の左) ---

func _setup_challenge_mini_window() -> void:
	if not _challenge_mini_panel:
		return

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.18, 0.95) # チャレンジウィンドウと同調するダークネイビー背景
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.22, 0.45, 0.78, 0.9) # チャレンジウィンドウと同調するブルー枠線
	panel_style.set_corner_radius_all(6)
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 6
	panel_style.shadow_offset = Vector2(0, 2)
	_challenge_mini_panel.add_theme_stylebox_override("panel", panel_style)

	if _challenge_mini_bar:
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.06, 0.08, 0.14, 0.9)
		bar_bg.border_width_left = 1
		bar_bg.border_width_top = 1
		bar_bg.border_width_right = 1
		bar_bg.border_width_bottom = 1
		bar_bg.border_color = Color(0.2, 0.32, 0.5, 0.7)
		bar_bg.set_corner_radius_all(3)
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.35, 0.6, 0.88, 1.0) # チャレンジウィンドウと同調するシアンブルーバー
		bar_fill.set_corner_radius_all(3)
		_challenge_mini_bar.add_theme_stylebox_override("background", bar_bg)
		_challenge_mini_bar.add_theme_stylebox_override("fill", bar_fill)

	if _challenge_mini_title:
		_challenge_mini_title.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0, 1.0))
	if _challenge_mini_progress:
		_challenge_mini_progress.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))


func _update_challenge_mini_window() -> void:
	if not _challenge_mini_panel:
		return
	var is_active := GameData.is_challenge_active()
	_challenge_mini_panel.visible = is_active
	if is_active:
		var def: Dictionary = GameData.CHALLENGE_DEFS.get(GameData.active_challenge_id, {})
		var num_str := GameData.active_challenge_id.replace("c", "")
		_challenge_mini_title.text = "挑戦中: #%s %s" % [num_str, def.get("name", "")]
		_update_challenge_mini_progress(GameData.challenge_current_val, GameData.challenge_target_val, GameData.challenge_time_left)
	_update_upgrade_buttons()


func _update_challenge_mini_progress(cur: float, target: float, time_left: float) -> void:
	if not _challenge_mini_panel or not _challenge_mini_panel.visible:
		return
	var def: Dictionary = GameData.CHALLENGE_DEFS.get(GameData.active_challenge_id, {})
	var cur_sym := "🪙" if def.get("target_type", "gold") == "gold" else "💎"
	var pct := 0.0 if target <= 0.0 else (cur / target) * 100.0

	_challenge_mini_time.text = "⏳ %.1fs" % maxf(0.0, time_left)
	if _challenge_mini_bar:
		_challenge_mini_bar.max_value = target
		_challenge_mini_bar.value = minf(cur, target)
	if _challenge_mini_progress:
		_challenge_mini_progress.text = "%s %s / %s (%.0f%%)" % [
			cur_sym,
			_format_number(cur),
			_format_number(target),
			pct
		]


func _on_challenge_started_mini(_challenge_id: String) -> void:
	_update_challenge_mini_window()
	_update_chain_cross_overlay()
	_update_upgrade_buttons()


func _on_challenge_progress_updated_mini(cur: float, target: float, time_left: float) -> void:
	_update_challenge_mini_progress(cur, target, time_left)


func _on_challenge_ended_mini(_challenge_id: String) -> void:
	_update_challenge_mini_window()
	_update_chain_cross_overlay()
	_update_upgrade_buttons()


# --- チャレンジ #1 装備無効化 鎖✕マークオーバーレイ ---

func _setup_chain_cross_overlay() -> void:
	if not grid_equipment:
		return
	var tab_content := grid_equipment.get_parent()
	if not tab_content:
		return

	if not _chain_cross_overlay:
		_chain_cross_overlay = ChainCrossOverlay.new()
		_chain_cross_overlay.name = "ChainCrossOverlay"
		_chain_cross_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_chain_cross_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chain_cross_overlay.z_index = 10
		tab_content.add_child(_chain_cross_overlay)

	_update_chain_cross_overlay()


func _update_chain_cross_overlay() -> void:
	if not _chain_cross_overlay:
		return
	var is_c1 := GameData.is_equip_disabled_challenge_active()
	_chain_cross_overlay.visible = is_c1
	if is_c1:
		_chain_cross_overlay.queue_redraw()


# ==============================================================================
# インベントリ複数選択・廃棄システム (Inventory Multi-Selection & Discard System)
# ==============================================================================

func _ensure_sell_popup() -> void:
	if _sell_overlay != null:
		return

	_sell_overlay = Control.new()
	_sell_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_sell_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sell_overlay.z_index = 80
	_sell_overlay.visible = false
	_sell_overlay.gui_input.connect(_on_sell_overlay_gui_input)
	add_child(_sell_overlay)

	_sell_popup = PanelContainer.new()
	_sell_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var pop_style := StyleBoxFlat.new()
	pop_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	pop_style.border_width_left = 2
	pop_style.border_width_top = 2
	pop_style.border_width_right = 2
	pop_style.border_width_bottom = 2
	pop_style.border_color = Color(1.0, 0.85, 0.2, 1.0)
	pop_style.corner_radius_top_left = 8
	pop_style.corner_radius_top_right = 8
	pop_style.corner_radius_bottom_right = 8
	pop_style.corner_radius_bottom_left = 8
	pop_style.content_margin_left = 8
	pop_style.content_margin_right = 8
	pop_style.content_margin_top = 6
	pop_style.content_margin_bottom = 6
	_sell_popup.add_theme_stylebox_override("panel", pop_style)
	_sell_overlay.add_child(_sell_popup)

	_sell_popup_button = Button.new()
	_sell_popup_button.custom_minimum_size = Vector2(120, 38)
	_sell_popup_button.focus_mode = Control.FOCUS_NONE

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.82, 0.22, 0.16, 1.0)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.border_width_left = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color(0.95, 0.45, 0.35, 1.0)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.92, 0.32, 0.24, 1.0)
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.border_width_left = 1
	btn_hover.border_width_top = 1
	btn_hover.border_width_right = 1
	btn_hover.border_width_bottom = 1
	btn_hover.border_color = Color(1.0, 0.65, 0.55, 1.0)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.68, 0.15, 0.10, 1.0)
	btn_pressed.corner_radius_top_left = 6
	btn_pressed.corner_radius_top_right = 6
	btn_pressed.corner_radius_bottom_right = 6
	btn_pressed.corner_radius_bottom_left = 6

	_sell_popup_button.add_theme_stylebox_override("normal", btn_normal)
	_sell_popup_button.add_theme_stylebox_override("hover", btn_hover)
	_sell_popup_button.add_theme_stylebox_override("pressed", btn_pressed)
	_sell_popup_button.add_theme_font_size_override("font_size", 16)
	_sell_popup_button.add_theme_color_override("font_color", Color.WHITE)
	_sell_popup_button.pressed.connect(_on_sell_button_pressed)
	_sell_popup.add_child(_sell_popup_button)


func _show_sell_popup(target_ui: InventoryItemUI) -> void:
	if _selected_inventory_items.is_empty():
		_hide_sell_popup()
		return
	_ensure_sell_popup()

	var count := _selected_inventory_items.size()
	_sell_popup_button.text = "廃棄 (%d個)" % count
	_sell_overlay.visible = true

	var pop_size := _sell_popup.get_combined_minimum_size()
	var target_rect := target_ui.get_global_rect()

	var target_pos := Vector2(
		target_rect.position.x + (target_rect.size.x - pop_size.x) * 0.5,
		target_rect.end.y + 6
	)

	var vp_size := get_viewport().get_visible_rect().size
	if target_pos.y + pop_size.y > vp_size.y - 10:
		target_pos.y = target_rect.position.y - pop_size.y - 6
	target_pos.x = clampf(target_pos.x, 10, vp_size.x - pop_size.x - 10)

	_sell_popup.global_position = target_pos


func _hide_sell_popup() -> void:
	if is_instance_valid(_sell_overlay):
		_sell_overlay.visible = false


func _on_sell_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_hide_sell_popup()


func _on_sell_button_pressed() -> void:
	if _selected_inventory_items.is_empty():
		_hide_sell_popup()
		return
	var items_to_sell: Array = _selected_inventory_items.values()
	var count := items_to_sell.size()
	var rewards := GameData.discard_multiple_inventory_items(items_to_sell)
	_clear_inventory_selection()
	_hide_sell_popup()
	show_inventory_discard_pop(count, rewards)


func _clear_discard_pop() -> void:
	if is_instance_valid(_discard_pop_tween) and _discard_pop_tween.is_running():
		_discard_pop_tween.kill()
	if is_instance_valid(_discard_pop_node):
		_discard_pop_node.queue_free()
		_discard_pop_node = null


func show_inventory_discard_pop(count: int, rewards: Dictionary) -> void:
	if not inventory_window:
		return
	_clear_discard_pop()

	var has_gold_skill := GameData.get_skill_level("get_gold_when_discarding") > 0
	var has_token_skill := GameData.get_skill_level("get_token_when_discarding") > 0

	var text_str := ""
	if has_gold_skill and has_token_skill:
		text_str = "装備×%dを廃棄(🪙+%s/💎+%s)" % [
			count,
			GameData.format_num(rewards.get("gold", 0.0)),
			GameData.format_num(rewards.get("tokens", 0.0))
		]
	elif has_gold_skill:
		text_str = "装備×%dを廃棄(🪙+%s)" % [
			count,
			GameData.format_num(rewards.get("gold", 0.0))
		]
	elif has_token_skill:
		text_str = "装備×%dを廃棄(💎+%s)" % [
			count,
			GameData.format_num(rewards.get("tokens", 0.0))
		]
	else:
		text_str = "装備×%dを廃棄。" % count

	var pop := PanelContainer.new()
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discard_pop_node = pop

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.90)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.35, 0.30, 0.90)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	pop.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text_str
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pop.add_child(label)

	add_child(pop)
	pop.z_index = 70

	# 右下に配置（インベントリ最大サイズ時でも下部余白に収まりスロットと干渉しない）
	var inv_rect := inventory_window.get_global_rect()
	var pop_size := pop.get_combined_minimum_size()
	pop.global_position = Vector2(
		inv_rect.end.x - pop_size.x - 20,
		inv_rect.end.y - pop_size.y - 14
	)

	pop.modulate.a = 0.0
	_discard_pop_tween = pop.create_tween()
	_discard_pop_tween.tween_property(pop, "modulate:a", 1.0, 0.15)
	_discard_pop_tween.tween_property(pop, "modulate:a", 0.0, 0.35).set_delay(2.2)
	_discard_pop_tween.chain().tween_callback(func():
		if is_instance_valid(pop):
			pop.queue_free()
		if _discard_pop_node == pop:
			_discard_pop_node = null
	)


func _clear_inventory_selection() -> void:
	_selected_inventory_items.clear()
	_update_all_inventory_item_selection_visuals()


func _update_all_inventory_item_selection_visuals() -> void:
	for grid in [main_grid, sub_grid, accessory_grid]:
		if not grid:
			continue
		for child in grid.get_children():
			if child is InventorySlotWrapper and child.child_item_ui:
				var it_id: String = child.child_item_ui.item_id
				child.child_item_ui.set_selected(_selected_inventory_items.has(it_id))


func _on_inventory_item_selection_toggled(item_ui: InventoryItemUI, is_selected: bool) -> void:
	if is_selected:
		_selected_inventory_items[item_ui.item_id] = {
			"type": item_ui.item_type,
			"id": item_ui.item_id,
			"name": item_ui.item_name,
			"level": item_ui.item_level,
			"rarity": item_ui.item_rarity
		}
		if is_instance_valid(_sell_overlay) and _sell_overlay.visible and is_instance_valid(_sell_popup_button):
			_sell_popup_button.text = "廃棄 (%d個)" % _selected_inventory_items.size()
	else:
		_selected_inventory_items.erase(item_ui.item_id)
		if _selected_inventory_items.is_empty():
			_hide_sell_popup()
		elif is_instance_valid(_sell_overlay) and _sell_overlay.visible and is_instance_valid(_sell_popup_button):
			_sell_popup_button.text = "廃棄 (%d個)" % _selected_inventory_items.size()


func _on_inventory_item_clicked(item_ui: InventoryItemUI, button_index: int) -> void:
	if button_index == MOUSE_BUTTON_LEFT:
		if item_ui.is_selected:
			_show_sell_popup(item_ui)
		else:
			_hide_sell_popup()
			if not _selected_inventory_items.is_empty():
				_clear_inventory_selection()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			_on_quick_save_pressed()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_F8:
			_on_quick_load_pressed()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_F9:
			_on_quick_reset_pressed()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		InventoryItemUI.drag_select_mode = -1

	if not _is_inventory_open:
		return
	if _selected_inventory_items.is_empty():
		return
	# 廃棄ボタンが出現中の場合は、左クリックは現状通り廃棄ボタンのオフのままでok
	if is_instance_valid(_sell_overlay) and _sell_overlay.visible:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 選択中の装備の上にマウスがあるかチェック
		var clicked_on_selected := false
		for item_ui in _get_selected_item_uis():
			if is_instance_valid(item_ui) and item_ui.is_visible_in_tree():
				if item_ui.get_global_rect().has_point(event.global_position):
					clicked_on_selected = true
					break

		if not clicked_on_selected:
			_clear_inventory_selection()


func _get_selected_item_uis() -> Array[InventoryItemUI]:
	var result: Array[InventoryItemUI] = []
	for grid in [main_grid, sub_grid, accessory_grid]:
		if not grid:
			continue
		for child in grid.get_children():
			if child is InventorySlotWrapper and child.child_item_ui:
				if child.child_item_ui.is_selected:
					result.append(child.child_item_ui)
	return result


# --- Quick Save / Load / Reset Handlers ---

func _show_save_toast(msg: String, is_error: bool = false) -> void:
	if not save_toast_label:
		return
	save_toast_label.text = msg
	save_toast_label.modulate = Color(1.0, 0.4, 0.4, 1.0) if is_error else Color(0.4, 0.95, 0.6, 1.0)
	if _save_toast_tween and _save_toast_tween.is_valid():
		_save_toast_tween.kill()
	_save_toast_tween = create_tween()
	_save_toast_tween.tween_property(save_toast_label, "modulate:a", 1.0, 0.1)
	_save_toast_tween.tween_interval(2.2)
	_save_toast_tween.tween_property(save_toast_label, "modulate:a", 0.0, 0.6)


func _on_quick_save_pressed() -> void:
	var success := GameData.save_game()
	if success:
		var meta := GameData.get_slot_meta(GameData.current_slot_id)
		var sname: String = meta.get("name", GameData.current_slot_id)
		_show_save_toast("💾 [%s] にセーブしました" % sname)
	else:
		_show_save_toast("❌ セーブに失敗しました", true)


func _on_quick_load_pressed() -> void:
	toggle_save_slot_window()


func _on_slot_saved(_slot_id: String, slot_name: String) -> void:
	_show_save_toast("💾 [%s] にセーブしました" % slot_name)


func _on_slot_loaded(slot_id: String) -> void:
	_force_refresh_all_hud()
	var meta := GameData.get_slot_meta(slot_id)
	var sname: String = meta.get("name", slot_id)
	_show_save_toast("🔄 [%s] をロードしました" % sname)


func _on_slot_deleted(_slot_id: String) -> void:
	_show_save_toast("🗑️ スロットデータを削除しました")


func _on_quick_reset_pressed() -> void:
	if reset_confirm_dialog:
		reset_confirm_dialog.popup_centered()
	else:
		_on_reset_confirmed()


func _on_reset_confirmed() -> void:
	var success := GameData.delete_save_data()
	_force_refresh_all_hud()
	if success:
		_show_save_toast("🗑️ データを消去・初期化しました")
	else:
		_show_save_toast("🗑️ データを初期化しました")


func _force_refresh_all_hud() -> void:
	_update_all()
	_update_sidebar_star_progress()
	_update_slots_ui()
	_update_inventory_ui()
	_update_special_skill_custom_ui()
	_update_skill_nodes()
	_update_tab_button_styles()
	_update_challenge_mini_window()
	_update_chain_cross_overlay()
	if _skill_tree_instance and _skill_tree_instance.has_method("refresh_all_nodes"):
		_skill_tree_instance.refresh_all_nodes()
	if is_instance_valid(challenge_window) and challenge_window.has_method("_update_all_ui"):
		challenge_window._update_all_ui()
	if is_instance_valid(blacksmith_window) and blacksmith_window.has_method("refresh_ui"):
		blacksmith_window.refresh_ui()
	if is_instance_valid(amplifier_window) and amplifier_window.has_method("refresh_ui"):
		amplifier_window.refresh_ui()
	if is_instance_valid(reinc_tree_window) and reinc_tree_window.has_method("refresh_tree"):
		reinc_tree_window.refresh_tree()
	if is_instance_valid(reinc_ability_window) and reinc_ability_window.has_method("refresh_abilities"):
		reinc_ability_window.refresh_abilities()
	if is_instance_valid(save_slot_window) and save_slot_window.has_method("refresh_slots"):
		save_slot_window.refresh_slots()
	if skill_tree_scroll:
		skill_tree_scroll.update_culling()
