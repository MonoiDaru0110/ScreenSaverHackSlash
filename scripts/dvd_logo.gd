extends Node2D
## DVD Logo that bounces around the screen like the classic screensaver.
## Changes color on each bounce and emits signals for game logic.

const LOGO_WIDTH := 200.0
const LOGO_HEIGHT := 100.0

var size_multiplier: float = 1.0 : set = set_size_multiplier
var _cached_half_w: float = LOGO_WIDTH / 2.0
var _cached_half_h: float = LOGO_HEIGHT / 2.0

func get_logo_width() -> float:
	return LOGO_WIDTH * size_multiplier

func get_logo_height() -> float:
	return LOGO_HEIGHT * size_multiplier

@export var base_speed: float = 150.0

## The area in which the logo can move (set by Main scene)
var play_area := Rect2(0, 0, 1662, 1080)

var velocity: Vector2
var current_color: Color
var _color_index: int = 0
var _base_sprite_scale: Vector2 = Vector2.ONE

# Vibrant, screensaver-style color palette
var colors: Array[Color] = [
	Color("#FF6B6B"),  # Coral
	Color("#4ECDC4"),  # Teal
	Color("#45B7D1"),  # Sky Blue
	Color("#96CEB4"),  # Sage
	Color("#FFEAA7"),  # Pale Gold
	Color("#DDA0DD"),  # Plum
	Color("#F7DC6F"),  # Amber
	Color("#BB8FCE"),  # Lavender
	Color("#F0B27A"),  # Peach
	Color("#82E0AA"),  # Mint
]

signal wall_hit(pos: Vector2, is_corner: bool, direction: Vector2)


func _ready() -> void:
	GameData.upgrades_changed.connect(_update_speed)

	# Sprite2Dのサイズが200x100になるように初期スケールを設定
	var tex_size: Vector2 = $Sprite2D.texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		_base_sprite_scale = Vector2(LOGO_WIDTH / tex_size.x, LOGO_HEIGHT / tex_size.y)
		$Sprite2D.scale = _base_sprite_scale

	# Random initial direction (avoid near-horizontal/vertical angles)
	var angle := randf_range(PI / 6.0, PI / 3.0)
	if randi() % 2:
		angle = PI - angle
	if randi() % 2:
		angle = -angle
	velocity = Vector2.from_angle(angle)
	_update_speed()

	# Random initial color
	_color_index = randi() % colors.size()
	current_color = colors[_color_index]
	_apply_color()

	# Random initial position within play area
	position = Vector2(
		randf_range(play_area.position.x + get_logo_width() / 2.0 + 20.0, play_area.end.x - get_logo_width() / 2.0 - 20.0),
		randf_range(play_area.position.y + get_logo_height() / 2.0 + 20.0, play_area.end.y - get_logo_height() / 2.0 - 20.0)
	)


func set_size_multiplier(mult: float) -> void:
	size_multiplier = mult
	scale = Vector2(size_multiplier, size_multiplier)
	_cached_half_w = get_logo_width() / 2.0
	_cached_half_h = get_logo_height() / 2.0
	
	# プレイエリア内に安全に収まるようクランプ (衝突判定はトリガーしない)
	var half_w := get_logo_width() / 2.0
	var half_h := get_logo_height() / 2.0
	var left := play_area.position.x
	var right := play_area.end.x
	var top := play_area.position.y
	var bottom := play_area.end.y
	
	position.x = clampf(position.x, left + half_w, right - half_w)
	position.y = clampf(position.y, top + half_h, bottom - half_h)


func _process(delta: float) -> void:
	position += velocity * delta
	_check_bounds()


func _check_bounds() -> void:
	var half_w := _cached_half_w
	var half_h := _cached_half_h
	var left := play_area.position.x
	var right := play_area.end.x
	var top := play_area.position.y
	var bottom := play_area.end.y
	var hit_x := false
	var hit_y := false
	var hit_dir := Vector2.ZERO

	# Horizontal bounds
	if position.x - half_w <= left:
		position.x = left + half_w
		velocity.x = absf(velocity.x)
		hit_x = true
		hit_dir.x = -1.0
	elif position.x + half_w >= right:
		position.x = right - half_w
		velocity.x = -absf(velocity.x)
		hit_x = true
		hit_dir.x = 1.0

	# Vertical bounds
	if position.y - half_h <= top:
		position.y = top + half_h
		velocity.y = absf(velocity.y)
		hit_y = true
		hit_dir.y = -1.0
	elif position.y + half_h >= bottom:
		position.y = bottom - half_h
		velocity.y = -absf(velocity.y)
		hit_y = true
		hit_dir.y = 1.0

	if hit_x or hit_y:
		_on_bounce(hit_x and hit_y, hit_dir)


func _on_bounce(is_corner: bool, direction: Vector2) -> void:
	_change_color()
	_play_bounce_effect(is_corner)
	wall_hit.emit(position, is_corner, direction)


func _change_color() -> void:
	var old_index := _color_index
	while _color_index == old_index:
		_color_index = randi() % colors.size()
	current_color = colors[_color_index]
	_apply_color()


func _apply_color() -> void:
	$Sprite2D.modulate = current_color


func _play_bounce_effect(is_corner: bool) -> void:
	var sprite := $Sprite2D
	if is_corner:
		sprite.scale = _base_sprite_scale * 1.4
		var tween := create_tween()
		tween.tween_property(sprite, "scale", _base_sprite_scale, 0.4)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	else:
		sprite.scale = _base_sprite_scale * 1.1
		var tween := create_tween()
		tween.tween_property(sprite, "scale", _base_sprite_scale, 0.15)\
			.set_ease(Tween.EASE_OUT)


func _update_speed() -> void:
	var current_speed := base_speed + GameData.speed_level * 20.0 + GameData.get_skill_level("speed_boost") * 20.0
	velocity = velocity.normalized() * current_speed
