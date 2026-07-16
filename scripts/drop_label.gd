extends Node2D
## Floating text that appears when gold is earned.
## Animates with slam-downs, high-speed shakes, and slides.


func setup(content: String, start_pos: Vector2, color: Color, is_corner: bool, is_crit: bool = false, is_direct: bool = false) -> void:
	# Position with random offset based on logo size (X: ±100, Y: ±50)
	position = start_pos + Vector2(randf_range(-100.0, 100.0), randf_range(-50.0, 50.0))

	var label := $Label
	
	# Determine text style based on Critical and Direct Hit
	var font_size := 28
	if is_corner:
		font_size = 40

	if is_crit and is_direct:
		font_size = 68 if is_corner else 56
		label.text = content + "!!"
	elif is_crit:
		font_size = 68 if is_corner else 56
		label.text = content + "!"
	elif is_direct:
		font_size = 48 if is_corner else 36
		label.text = content
	else:
		label.text = content

	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color

	# Adjust pivot offset to center based on actual label size
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size / 2.0
	# Offset label position to center it around parent Node2D position (0,0)
	label.position = -label.size / 2.0

	var tween := create_tween()

	# Only trigger the intense slam and high-speed shake for Crit-Direct (Critical AND Direct) hits
	if is_crit and is_direct:
		# --- Critical & Direct (Crit-Direct): Slam-down & High-speed Shake ---
		# Start from large scale and transparent
		modulate.a = 0.0
		label.scale = Vector2(2.5, 2.5)
		
		# Slam-down animation (fade in and scale down quickly in 0.05s)
		tween.set_parallel(true)
		tween.tween_property(self, "modulate:a", 1.0, 0.05).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2.ONE, 0.05).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		# Instantly trigger high-speed shake upon landing
		tween.chain().tween_callback(func():
			var shake_tween := create_tween()
			var base_label_pos = -label.size / 2.0
			# Rapid shake (step size: 0.02s)
			for i in range(10):
				var offset = Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
				shake_tween.tween_property(label, "position", base_label_pos + offset, 0.02).set_trans(Tween.TRANS_SINE)
			shake_tween.tween_property(label, "position", base_label_pos, 0.02)
		)
		
		# Stay in place and fade out (Extended lifetime)
		tween.chain().tween_interval(0.9)
		tween.chain().tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(queue_free)
		
	else:
		# --- Standard, Direct-only, or Crit-only: Float up and fade out ---
		# Ensure default scale and opacity settings (Extended lifetime)
		scale = Vector2.ONE
		label.scale = Vector2.ONE
		modulate.a = 1.0
		
		tween.set_parallel(true)
		tween.tween_property(self, "position:y", position.y - 80.0, 1.6)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "modulate:a", 0.0, 0.9)\
			.set_ease(Tween.EASE_IN).set_delay(0.7)
		tween.chain().tween_callback(queue_free)
