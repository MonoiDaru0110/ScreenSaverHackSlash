extends Node2D
## Main game scene.
## Orchestrates the DVD logo bouncing and gold drops.

const PLAY_AREA_WIDTH := 1662.0
const PLAY_AREA_HEIGHT := 1080.0

var _drop_label_scene: PackedScene = preload("res://scenes/drop_label.tscn")
var _dvd_logo_scene: PackedScene = preload("res://scenes/dvd_logo.tscn")

@onready var logo_container: Node2D = $LogoContainer
@onready var drop_container: Node2D = $DropContainer
@onready var background: ColorRect = $Background

# Default background color (dark navy)
var _bg_default_color := Color(0.02, 0.02, 0.06)


func _ready() -> void:
	GameData.logo_spawn_requested.connect(_on_logo_spawn_requested)
	GameData.logo_reset_requested.connect(_on_logo_reset_requested)
	_spawn_initial_logos()


func _spawn_initial_logos() -> void:
	for i in GameData.logo_count:
		_spawn_one_logo()


func _spawn_one_logo() -> void:
	var play_area := Rect2(0, 0, PLAY_AREA_WIDTH, PLAY_AREA_HEIGHT)
	var logo := _dvd_logo_scene.instantiate()
	logo.play_area = play_area
	logo_container.add_child(logo)
	logo.wall_hit.connect(_on_wall_hit)


func _on_logo_spawn_requested() -> void:
	_spawn_one_logo()


func _on_logo_reset_requested() -> void:
	# Clear all logo instances
	for child in logo_container.get_children():
		child.queue_free()
	# Spawn 1 logo
	_spawn_one_logo()


func _on_wall_hit(pos: Vector2, is_corner: bool) -> void:
	var label_text: String
	var label_color: Color
	
	var mult := GameData.get_ascension_multiplier()
	# Apply root_gold skill (+10% gold per level)
	var gold_skill_mult := 1.0 + GameData.get_skill_level("root_gold") * 0.1

	if is_corner:
		var gold_amount := int((50 + GameData.boost_level * 10) * mult * gold_skill_mult)
		var token_amount := int((1 + GameData.boost_level) * mult)
		
		# Apply token_luck skill (30% chance for +1 token per level)
		var token_luck_level := GameData.get_skill_level("token_luck")
		if token_luck_level > 0 and randf() < token_luck_level * 0.3:
			token_amount += 1
		
		label_text = "★ 🪙 +%d / 💎 +%d ★" % [gold_amount, token_amount]
		label_color = Color(1.0, 1.0, 1.0)
		
		GameData.record_bounce(true)
		GameData.add_gold(gold_amount)
		GameData.add_tokens(token_amount)
		_flash_background()
	else:
		var gold_amount := int((1 + GameData.boost_level) * mult * gold_skill_mult)
		
		label_text = "🪙 +%d" % gold_amount
		label_color = Color(1.0, 1.0, 1.0, 0.9)
		
		GameData.record_bounce(false)
		GameData.add_gold(gold_amount)

	_spawn_drop_label(pos, label_text, label_color, is_corner)


func _spawn_drop_label(pos: Vector2, text_content: String, color: Color, is_corner: bool) -> void:
	var label := _drop_label_scene.instantiate()
	drop_container.add_child(label)
	label.setup(text_content, pos, color, is_corner)


func _flash_background() -> void:
	## Brief flash effect when a corner hit occurs.
	background.color = Color(0.15, 0.1, 0.25)
	var tween := create_tween()
	tween.tween_property(background, "color", _bg_default_color, 0.6)\
		.set_ease(Tween.EASE_OUT)
