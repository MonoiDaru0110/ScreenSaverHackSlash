extends Node2D
## Main game scene.
## Orchestrates the DVD logo bouncing and gold drops.

var _drop_label_scene: PackedScene = preload("res://scenes/drop_label.tscn")
var _dvd_logo_scene: PackedScene = preload("res://scenes/dvd_logo.tscn")

var _sound_corner := preload("res://sound/sound_effect/角衝突音.wav")

@onready var hud: CanvasLayer = $HUD
@onready var play_area: Node2D = $PlayArea
@onready var play_area_border: Panel = $PlayArea/PlayAreaBorder
@onready var logo_container: Node2D = $PlayArea/LogoContainer
@onready var drop_container: Node2D = $PlayArea/DropContainer
@onready var background: ColorRect = $Background

var _border_style: StyleBoxFlat
var _base_border_color := Color(0.4, 0.6, 1.0, 0.8)

# Default background color (dark navy)
var _bg_default_color := Color(0.02, 0.02, 0.06)

var _over_time_timer: Timer = null
var _token_over_time_timer: Timer = null

# パフォーマンス最適化
var _is_border_animating: bool = false
var _audio_pool: Array[AudioStreamPlayer] = []
const AUDIO_POOL_SIZE: int = 4


func _ready() -> void:
	# 境界線のスタイルを動的に設定
	_border_style = StyleBoxFlat.new()
	_border_style.bg_color = Color(0, 0, 0, 0) # 透明
	_border_style.border_width_left = 4
	_border_style.border_width_top = 4
	_border_style.border_width_right = 4
	_border_style.border_width_bottom = 4
	_border_style.border_color = _base_border_color
	_border_style.corner_radius_top_left = 8
	_border_style.corner_radius_top_right = 8
	_border_style.corner_radius_bottom_right = 8
	_border_style.corner_radius_bottom_left = 8
	play_area_border.add_theme_stylebox_override("panel", _border_style)
	
	# 拡大縮小が中心基準で行われるようにピボットを設定
	play_area_border.pivot_offset = play_area_border.size / 2.0

	GameData.logo_spawn_requested.connect(_on_logo_spawn_requested)
	GameData.logo_reset_requested.connect(_on_logo_reset_requested)
	GameData.upgrades_changed.connect(_on_upgrades_changed)
	
	_setup_over_time_timer()
	_setup_token_over_time_timer()
	_spawn_initial_logos()
	# オーディオプールの初期化
	for i in AUDIO_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_audio_pool.append(player)


func _spawn_initial_logos() -> void:
	for i in GameData.logo_count:
		_spawn_one_logo()


func _spawn_one_logo() -> void:
	var play_area := play_area_border.get_rect()
	var logo := _dvd_logo_scene.instantiate()
	logo.play_area = play_area
	logo.set_size_multiplier(GameData.get_logo_size_multiplier())
	logo_container.add_child(logo)
	logo.wall_hit.connect(_on_wall_hit)


func _on_logo_spawn_requested() -> void:
	_spawn_one_logo()


func _on_logo_reset_requested() -> void:
	# Clear all logo instances
	for child in logo_container.get_children():
		child.queue_free()
	# Spawn logos based on current logo_count
	for i in GameData.logo_count:
		_spawn_one_logo()


func _on_wall_hit(pos: Vector2, is_corner: bool, direction: Vector2) -> void:
	var mult := GameData._cached_ascension_mult
	# キャッシュ済みスキル倍率を使用
	var gold_skill_mult := GameData._cached_gold_skill_mult

	# デバッグ用: レベル100による確率100%を防ぎ、演出を確認するために確率を50%にする
	var gold_is_crit := randf() < 0.5
	var gold_is_direct := randf() < 0.5
	var gold_mult := 1.0
	if gold_is_crit:
		gold_mult *= GameData.get_gold_crit_multiplier()
	if gold_is_direct:
		gold_mult *= GameData.get_gold_direct_multiplier()

	if is_corner:
		_play_sound(_sound_corner)
		var base_gold := (50 + GameData.boost_level * 10) * mult * gold_skill_mult
		var gold_amount := int(base_gold * gold_mult)
		
		# デバッグ用: 演出検証用に確率を50%にする
		var token_is_crit := randf() < 0.5
		var token_is_direct := randf() < 0.5
		var token_mult := 1.0
		if token_is_crit:
			token_mult *= GameData.get_token_crit_multiplier()
		if token_is_direct:
			token_mult *= GameData.get_token_direct_multiplier()

		# Apply token_boost_n skill (1.1^n multiplier where n is total level of all token_boost_n)
		var token_skill_mult := GameData._cached_token_skill_mult
		var base_tokens := (1 + GameData.boost_level) * mult * token_skill_mult
		# Apply token_luck skill (30% chance for +1 token per level)
		var token_luck_level := GameData.get_skill_level("token_luck")
		if token_luck_level > 0 and randf() < token_luck_level * 0.3:
			base_tokens += 1
		var token_amount := int(base_tokens * token_mult)

		GameData.record_bounce(true)
		GameData.add_gold(gold_amount)
		GameData.add_tokens(token_amount)
		_flash_background()

		# Spawn separate labels for Gold and Tokens
		_spawn_drop_label(pos + Vector2(-45.0, 0.0), "🪙 +%d" % gold_amount, Color(1.0, 0.95, 0.3), true, gold_is_crit, gold_is_direct)
		_spawn_drop_label(pos + Vector2(45.0, 0.0), "💎 +%d" % token_amount, Color(0.3, 0.75, 1.0), true, token_is_crit, token_is_direct)
		_start_shake(direction.normalized(), 15.0)
	else:
		var base_gold := (1 + GameData.boost_level) * mult * gold_skill_mult
		var gold_amount := int(base_gold * gold_mult)

		GameData.record_bounce(false)
		GameData.add_gold(gold_amount)

		_spawn_drop_label(pos, "🪙 +%d" % gold_amount, Color(1.0, 1.0, 0.95), false, gold_is_crit, gold_is_direct)
		_start_shake(direction, 5.0)

	# --- Equipment Drop Logic ---
	var dropped_item := GameData.roll_equipment_drop(is_corner)
	if not dropped_item.is_empty():
		if hud:
			hud.show_equipment_drop_pop(dropped_item)



func _spawn_drop_label(pos: Vector2, text_content: String, color: Color, is_corner: bool, is_crit: bool = false, is_direct: bool = false) -> void:
	var label := _drop_label_scene.instantiate()
	drop_container.add_child(label)
	label.setup(text_content, pos, color, is_corner, is_crit, is_direct)


func _set_border_width(w: int) -> void:
	if _border_style:
		_border_style.border_width_left = w
		_border_style.border_width_top = w
		_border_style.border_width_right = w
		_border_style.border_width_bottom = w


func _start_shake(direction: Vector2, strength: float) -> void:
	_is_border_animating = true
	# 画面の移動は行わない (平行移動による酔いを完全に防止)
	
	# 衝撃強度に応じて境界線パネルを一瞬拡大
	var scale_factor = 1.0 + (strength * 0.0015)
	play_area_border.scale = Vector2(scale_factor, scale_factor)
	
	# 枠線の太さを一時的に太くする
	var target_width = int(4 + strength * 0.6)
	_set_border_width(target_width)
	
	# 枠線の色を一瞬真っ白にする
	if _border_style:
		_border_style.border_color = Color(1.0, 1.0, 1.0, 1.0)


func _process(delta: float) -> void:
	if not _is_border_animating:
		return
	
	var all_settled := true
	
	# スケールを 1.0 に戻す
	if play_area_border.scale != Vector2.ONE:
		play_area_border.scale = play_area_border.scale.lerp(Vector2.ONE, 12.0 * delta)
		if (play_area_border.scale - Vector2.ONE).length() < 0.001:
			play_area_border.scale = Vector2.ONE
		else:
			all_settled = false
			
	# 枚線の太さを 4 に戻す
	if _border_style and _border_style.border_width_left > 4:
		var cur_w = lerp(float(_border_style.border_width_left), 4.0, 12.0 * delta)
		_set_border_width(int(cur_w))
		if _border_style.border_width_left <= 4:
			_set_border_width(4)
		else:
			all_settled = false
			
	# 境界線の色をネオンブルーに戻す (フラッシュの減衰)
	if _border_style:
		var cur_color = _border_style.border_color
		var r_diff: float = abs(cur_color.r - _base_border_color.r)
		var g_diff: float = abs(cur_color.g - _base_border_color.g)
		var b_diff: float = abs(cur_color.b - _base_border_color.b)
		if r_diff > 0.01 or g_diff > 0.01 or b_diff > 0.01:
			_border_style.border_color = cur_color.lerp(_base_border_color, 12.0 * delta)
			all_settled = false
		else:
			_border_style.border_color = _base_border_color
	
	if all_settled:
		_is_border_animating = false


func _flash_background() -> void:
	## Brief flash effect when a corner hit occurs.
	background.color = Color(0.15, 0.1, 0.25)
	var tween := create_tween()
	tween.tween_property(background, "color", _bg_default_color, 0.6)\
		.set_ease(Tween.EASE_OUT)


func _setup_over_time_timer() -> void:
	_over_time_timer = Timer.new()
	_over_time_timer.name = "GoldOverTimeTimer"
	_over_time_timer.timeout.connect(_on_over_time_timeout)
	add_child(_over_time_timer)
	_update_over_time_timer()


func _update_over_time_timer() -> void:
	if not _over_time_timer:
		return
		
	var has_skill := GameData.get_skill_level("get_gold_over_time") >= 1
	if has_skill:
		var cooldown := 5.0 * pow(0.9, GameData.total_gold_cooltime_boost_level)
		if not _over_time_timer.is_stopped():
			if not is_equal_approx(_over_time_timer.wait_time, cooldown):
				_over_time_timer.wait_time = cooldown
				_over_time_timer.start()
		else:
			_over_time_timer.wait_time = cooldown
			_over_time_timer.start()
	else:
		_over_time_timer.stop()


func _setup_token_over_time_timer() -> void:
	_token_over_time_timer = Timer.new()
	_token_over_time_timer.name = "TokenOverTimeTimer"
	_token_over_time_timer.timeout.connect(_on_token_over_time_timeout)
	add_child(_token_over_time_timer)
	_update_token_over_time_timer()


func _update_token_over_time_timer() -> void:
	if not _token_over_time_timer:
		return
		
	var has_skill := GameData.get_skill_level("get_token_over_time_1") >= 1
	if has_skill:
		var cooldown := 5.0 * pow(0.9, GameData.total_token_cooltime_boost_level)
		if not _token_over_time_timer.is_stopped():
			if not is_equal_approx(_token_over_time_timer.wait_time, cooldown):
				_token_over_time_timer.wait_time = cooldown
				_token_over_time_timer.start()
		else:
			_token_over_time_timer.wait_time = cooldown
			_token_over_time_timer.start()
	else:
		_token_over_time_timer.stop()


func _on_upgrades_changed() -> void:
	_update_over_time_timer()
	_update_token_over_time_timer()
	_update_logo_sizes()


func _update_logo_sizes() -> void:
	var mult := GameData.get_logo_size_multiplier()
	for logo in logo_container.get_children():
		if logo.has_method("set_size_multiplier"):
			logo.set_size_multiplier(mult)


func _on_over_time_timeout() -> void:
	var logos := logo_container.get_children()
	if logos.is_empty():
		return
		
	var mult := GameData._cached_ascension_mult
	var gold_skill_mult := GameData._cached_gold_skill_mult
	
	# Base amount is 10% of normal wall bounce gold
	var base_hit_gold := int((1 + GameData.boost_level) * mult * gold_skill_mult)
	var base_over_time_gold := base_hit_gold * 0.1
	
	var boost_mult := GameData._cached_gold_over_time_boost_mult
	var final_amount := int(base_over_time_gold * boost_mult)
	final_amount = max(1, final_amount)
	
	# ゴールドを一括加算し、すべてのロゴからポップアップを表示
	var logo_count := logos.size()
	var total_gold := final_amount * logo_count
	GameData.add_gold(total_gold)
	
	for logo in logos:
		if logo is Node2D:
			_spawn_drop_label(logo.global_position, "🪙 +%d" % final_amount, Color(1.0, 1.0, 1.0, 0.7), false)


func _play_sound(stream: AudioStream) -> void:
	# オーディオプールから空きプレイヤーを検索
	for player in _audio_pool:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	# 全プレイヤーが使用中の場合はスキップ


func _on_token_over_time_timeout() -> void:
	var logos := logo_container.get_children()
	if logos.is_empty():
		return
		
	var mult := GameData._cached_ascension_mult
	
	# Base amount is 10% of normal corner bounce tokens
	var base_corner_tokens := (1 + GameData.boost_level) * mult * GameData._cached_token_skill_mult
	var base_over_time_token := base_corner_tokens * 0.1
	
	var boost_mult := GameData._cached_token_over_time_boost_mult
	var final_amount := int(base_over_time_token * boost_mult)
	final_amount = max(1, final_amount)
	
	# トークンを一括加算し、すべてのロゴからポップアップを表示
	var logo_count := logos.size()
	var total_tokens := final_amount * logo_count
	GameData.add_tokens(total_tokens)
	
	for logo in logos:
		if logo is Node2D:
			_spawn_drop_label(logo.global_position, "💎 +%d" % final_amount, Color(0.3, 0.75, 1.0, 0.7), false)
