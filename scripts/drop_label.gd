extends Node2D
## Floating text that appears when gold is earned.
## Animates with slam-downs, high-speed shakes, and slides.

@export var base_font_size: int = 14
@export var outline_size: int = 2

var pool_return_callable: Callable = Callable()
var _tween: Tween = null
var _shake_tween: Tween = null
@onready var _label: Label = $Label


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _label:
		_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_label.add_theme_font_size_override("font_size", base_font_size)
		_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		_label.add_theme_constant_override("outline_size", outline_size)
		_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		_label.modulate = Color.WHITE
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.position = Vector2(-200.0, -40.0)
		_label.size = Vector2(400.0, 80.0)
		_label.pivot_offset = Vector2(200.0, 40.0)


func setup(content: String, start_pos: Vector2, color: Color, is_corner: bool, is_crit: bool = false, is_direct: bool = false, crit_weight: int = 0) -> void:
	if is_instance_valid(_tween) and _tween.is_running():
		_tween.kill()
	if is_instance_valid(_shake_tween) and _shake_tween.is_running():
		_shake_tween.kill()

	# Position with random offset based on logo size (X: ±100, Y: ±50)
	position = start_pos + Vector2(randf_range(-100.0, 100.0), randf_range(-50.0, 50.0))

	var label: Label = _label if _label else ($Label as Label)
	label.position = Vector2(-200.0, -40.0)
	
	# Build label text based on Direct Hit and Crit Weight
	var label_text := content
	if is_direct:
		if label_text.contains("+"):
			label_text = label_text.replace("+", "+*")
		else:
			label_text = "*" + label_text
	
	var weight := crit_weight if is_crit else 0
	if is_crit and weight <= 0:
		weight = 1
	label_text += GameData.format_crit_marks(weight)
		
	label.text = label_text
	
	# 方法①：小さめのフォントサイズ（base_font_size: 14px）でレンダリングし、
	# Nearestフィルタで拡大（scale）することでガビガビ・チープなドット感を表現
	var target_scale := 2.0
	if is_corner:
		target_scale = 2.8

	if is_crit and is_direct:
		target_scale = 4.2 if is_corner else 3.4
	elif is_crit:
		target_scale = 3.8 if is_corner else 3.0
	elif is_direct:
		target_scale = 3.4 if is_corner else 2.6

	# Scale up further with crit weight
	if is_crit:
		target_scale += float(mini(weight - 1, 10)) * 0.15

	label.add_theme_color_override("font_color", color)

	_tween = create_tween()

	if is_crit or is_direct:
		# --- Special Hits (Crit, Direct, or Crit-Direct): Dynamic Slam-down & Shake Animation ---
		modulate.a = 0.0
		var capped_w := mini(weight, 10)
		var start_mult := 1.4
		if is_crit and is_direct:
			start_mult = 1.8 + float(capped_w) * 0.15
		elif is_crit:
			start_mult = 1.6 + float(capped_w) * 0.1
		
		var initial_scale := target_scale * start_mult
		label.scale = Vector2(initial_scale, initial_scale)
		
		# Slam-down animation (fade in and scale down quickly to target_scale)
		_tween.set_parallel(true)
		_tween.tween_property(self, "modulate:a", 1.0, 0.06).set_ease(Tween.EASE_OUT)
		_tween.tween_property(label, "scale", Vector2(target_scale, target_scale), 0.06).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		# High-speed shake upon landing for Critical Hits, scaling intensity with weight
		if is_crit:
			var shake_intensity := 6.0 + float(capped_w) * 1.5
			if is_direct:
				shake_intensity += 3.0
				
			_tween.chain().tween_callback(func():
				if not is_instance_valid(label):
					return
				_shake_tween = create_tween()
				var base_label_pos := Vector2(-200.0, -40.0)
				_shake_tween.tween_property(label, "position", base_label_pos + Vector2(-shake_intensity, shake_intensity * 0.7), 0.03)
				_shake_tween.tween_property(label, "position", base_label_pos + Vector2(shake_intensity * 0.8, -shake_intensity), 0.03)
				_shake_tween.tween_property(label, "position", base_label_pos, 0.03)
			)
		
		# Stay in place briefly and fade out
		_tween.chain().tween_interval(0.8)
		_tween.chain().tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
		_tween.chain().tween_callback(_on_finished)
		
	else:
		# --- Standard: Float up and fade out ---
		scale = Vector2.ONE
		label.scale = Vector2(target_scale, target_scale)
		modulate.a = 1.0
		
		_tween.set_parallel(true)
		_tween.tween_property(self, "position:y", position.y - 80.0, 1.6)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_property(self, "modulate:a", 0.0, 0.9)\
			.set_ease(Tween.EASE_IN).set_delay(0.7)
		_tween.chain().tween_callback(_on_finished)


func _on_finished() -> void:
	if pool_return_callable.is_valid():
		pool_return_callable.call(self)
	else:
		queue_free()
