extends Node2D
## Floating text that appears when gold is earned.
## Animates with slam-downs, high-speed shakes, and slides.


func setup(content: String, start_pos: Vector2, color: Color, is_corner: bool, is_crit: bool = false, is_direct: bool = false, crit_weight: int = 0) -> void:
	# Position with random offset based on logo size (X: ±100, Y: ±50)
	position = start_pos + Vector2(randf_range(-100.0, 100.0), randf_range(-50.0, 50.0))

	var label := $Label
	
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
	for i in range(weight):
		label_text += "!"
		
	label.text = label_text
	
	# Determine text style based on Critical and Direct Hit
	var font_size := 28
	if is_corner:
		font_size = 40

	if is_crit and is_direct:
		font_size = 68 if is_corner else 56
	elif is_crit:
		font_size = 68 if is_corner else 56
	elif is_direct:
		font_size = 48 if is_corner else 36

	# Scale font size with crit weight
	if is_crit:
		font_size += mini(weight - 1, 10) * 4

	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color

	# Adjust pivot offset to center based on actual label size
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size / 2.0
	# Offset label position to center it around parent Node2D position (0,0)
	label.position = -label.size / 2.0

	var tween := create_tween()

	if is_crit or is_direct:
		# --- Special Hits (Crit, Direct, or Crit-Direct): Dynamic Slam-down & Shake Animation ---
		modulate.a = 0.0
		var capped_w := mini(weight, 10)
		var start_scale := 1.4
		if is_crit and is_direct:
			start_scale = 2.2 + float(capped_w) * 0.3
		elif is_crit:
			start_scale = 1.8 + float(capped_w) * 0.2
		
		label.scale = Vector2(start_scale, start_scale)
		
		# Slam-down animation (fade in and scale down quickly)
		tween.set_parallel(true)
		tween.tween_property(self, "modulate:a", 1.0, 0.06).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2.ONE, 0.06).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		# High-speed shake upon landing for Critical Hits, scaling intensity with weight
		if is_crit:
			var shake_count := 6 + mini(weight * 2, 20)
			var shake_intensity := 6.0 + float(capped_w) * 1.5
			if is_direct:
				shake_intensity += 3.0
				shake_count += 4
				
			tween.chain().tween_callback(func():
				var shake_tween := create_tween()
				var base_label_pos = -label.size / 2.0
				for i in range(shake_count):
					var offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
					shake_tween.tween_property(label, "position", base_label_pos + offset, 0.02).set_trans(Tween.TRANS_SINE)
				shake_tween.tween_property(label, "position", base_label_pos, 0.02)
			)
		
		# Stay in place briefly and fade out
		tween.chain().tween_interval(0.8)
		tween.chain().tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(queue_free)
		
	else:
		# --- Standard: Float up and fade out ---
		scale = Vector2.ONE
		label.scale = Vector2.ONE
		modulate.a = 1.0
		
		tween.set_parallel(true)
		tween.tween_property(self, "position:y", position.y - 80.0, 1.6)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "modulate:a", 0.0, 0.9)\
			.set_ease(Tween.EASE_IN).set_delay(0.7)
		tween.chain().tween_callback(queue_free)
