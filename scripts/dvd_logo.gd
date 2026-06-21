extends Node2D
## DVD Logo that bounces around the screen like the classic screensaver.
## Changes color on each bounce and emits signals for game logic.

const LOGO_WIDTH := 200.0
const LOGO_HEIGHT := 100.0

@export var base_speed: float = 150.0

## The area in which the logo can move (set by Main scene)
var play_area := Rect2(0, 0, 1662, 1080)

var velocity: Vector2
var current_color: Color
var _color_index: int = 0

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

signal wall_hit(pos: Vector2, is_corner: bool)


func _ready() -> void:
	GameData.upgrades_changed.connect(_update_speed)

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
		randf_range(play_area.position.x + LOGO_WIDTH / 2.0 + 20.0, play_area.end.x - LOGO_WIDTH / 2.0 - 20.0),
		randf_range(play_area.position.y + LOGO_HEIGHT / 2.0 + 20.0, play_area.end.y - LOGO_HEIGHT / 2.0 - 20.0)
	)


func _process(delta: float) -> void:
	position += velocity * delta
	_check_bounds()


func _check_bounds() -> void:
	var half_w := LOGO_WIDTH / 2.0
	var half_h := LOGO_HEIGHT / 2.0
	var left := play_area.position.x
	var right := play_area.end.x
	var top := play_area.position.y
	var bottom := play_area.end.y
	var hit_x := false
	var hit_y := false

	# Horizontal bounds
	if position.x - half_w <= left:
		position.x = left + half_w
		velocity.x = absf(velocity.x)
		hit_x = true
	elif position.x + half_w >= right:
		position.x = right - half_w
		velocity.x = -absf(velocity.x)
		hit_x = true

	# Vertical bounds
	if position.y - half_h <= top:
		position.y = top + half_h
		velocity.y = absf(velocity.y)
		hit_y = true
	elif position.y + half_h >= bottom:
		position.y = bottom - half_h
		velocity.y = -absf(velocity.y)
		hit_y = true

	if hit_x or hit_y:
		_on_bounce(hit_x and hit_y)


func _on_bounce(is_corner: bool) -> void:
	_change_color()
	_play_bounce_effect(is_corner)
	wall_hit.emit(position, is_corner)


func _change_color() -> void:
	var old_index := _color_index
	while _color_index == old_index:
		_color_index = randi() % colors.size()
	current_color = colors[_color_index]
	_apply_color()


func _apply_color() -> void:
	$Label.modulate = current_color


func _play_bounce_effect(is_corner: bool) -> void:
	var label := $Label as Label
	if is_corner:
		# Big elastic bounce for corner hits
		label.scale = Vector2(1.4, 1.4)
		var tween := create_tween()
		tween.tween_property(label, "scale", Vector2.ONE, 0.4)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	else:
		# Subtle bump for wall hits
		label.scale = Vector2(1.1, 1.1)
		var tween := create_tween()
		tween.tween_property(label, "scale", Vector2.ONE, 0.15)\
			.set_ease(Tween.EASE_OUT)


func _update_speed() -> void:
	var current_speed := base_speed + GameData.speed_level * 20.0
	velocity = velocity.normalized() * current_speed
