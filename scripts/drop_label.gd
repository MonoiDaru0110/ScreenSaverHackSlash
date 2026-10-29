extends Node2D
## Floating text that appears when gold is earned.
## Animates with slam-downs, high-speed shakes, and slides.

@export var base_font_size: int = 14
@export var outline_size: int = 2


func setup(content: String, start_pos: Vector2, color: Color, is_corner: bool, is_crit: bool = false, is_direct: bool = false, crit_weight: int = 0) -> void:
	# Position with random offset based on logo size (X: ±100, Y: ±50)
	position = start_pos + Vector2(randf_range(-100.0, 100.0), randf_range(-50.0, 50.0))

	var label := $Label
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
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
		target_scale = 4.8 if is_corner else 4.0
	elif is_crit:
		target_scale = 4.8 if is_corner else 4.0
	elif is_direct:
		target_scale = 3.4 if is_corner else 2.6

	# Scale up further with crit weight
	if is_crit:
		target_scale += float(mini(weight - 1, 10)) * 0.3

	label.add_theme_font_size_override("font_size", base_font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.modulate = Color.WHITE

	# Center label around parent Node2D position without costly get_minimum_size layout recalculation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-200.0, -40.0)
	label.size = Vector2(400.0, 80.0)
	label.pivot_offset = Vector2(200.0, 40.0)

	var tween := create_tween()

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
		tween.set_parallel(true)
		tween.tween_property(self, "modulate:a", 1.0, 0.06).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2(target_scale, target_scale), 0.06).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		# High-speed shake upon landing for Critical Hits, scaling intensity with weight
		if is_crit:
			var shake_intensity := 6.0 + float(capped_w) * 1.5
			if is_direct:
				shake_intensity += 3.0
				
			tween.chain().tween_callback(func():
				if not is_instance_valid(label):
					return
				var shake_tween := create_tween()
				var base_label_pos = -label.size / 2.0
				shake_tween.tween_property(label, "position", base_label_pos + Vector2(-shake_intensity, shake_intensity * 0.7), 0.03)
				shake_tween.tween_property(label, "position", base_label_pos + Vector2(shake_intensity * 0.8, -shake_intensity), 0.03)
				shake_tween.tween_property(label, "position", base_label_pos, 0.03)
			)
		
		# Stay in place briefly and fade out
		tween.chain().tween_interval(0.8)
		tween.chain().tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(queue_free)
		
	else:
		# --- Standard: Float up and fade out ---
		scale = Vector2.ONE
		label.scale = Vector2(target_scale, target_scale)
		modulate.a = 1.0
		
		tween.set_parallel(true)
		tween.tween_property(self, "position:y", position.y - 80.0, 1.6)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "modulate:a", 0.0, 0.9)\
			.set_ease(Tween.EASE_IN).set_delay(0.7)
		tween.chain().tween_callback(queue_free)
