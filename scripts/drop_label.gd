extends Label
## Floating text that appears when gold is earned.
## Animates upward and fades out, then self-destructs.


func setup(content: String, start_pos: Vector2, color: Color, is_corner: bool, is_crit: bool = false, is_direct: bool = false) -> void:
	# Position with slight random horizontal offset
	position = start_pos + Vector2(randf_range(-30.0, 30.0), -30.0)

	# Determine text style based on Critical and Direct Hit
	var font_size := 28
	if is_corner:
		font_size = 40

	if is_crit and is_direct:
		font_size = 68 if is_corner else 56
		text = content + "!!"
	elif is_crit:
		font_size = 68 if is_corner else 56
		text = content + "!"
	elif is_direct:
		font_size = 48 if is_corner else 36
		text = content
	else:
		text = content

	add_theme_font_size_override("font_size", font_size)
	modulate = color

	# Animate based on event types
	var tween := create_tween()
	tween.set_parallel(true)

	if is_crit and is_direct:
		# Both: shake slightly in random directions, stay in place, and fade out
		var shake_tween := create_tween()
		var original_pos = position
		# Perform a rapid random offset shake (smaller magnitude: 5px max)
		for i in range(6):
			var offset = Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
			shake_tween.tween_property(self, "position", original_pos + offset, 0.05).set_trans(Tween.TRANS_SINE)
		shake_tween.tween_property(self, "position", original_pos, 0.05)
		
		# Stay in place (no drift) and fade out
		tween.tween_property(self, "modulate:a", 0.0, 0.8)\
			.set_ease(Tween.EASE_IN).set_delay(0.4)
			
		tween.chain().tween_callback(queue_free)
	else:
		# Standard / Single hit: float up and fade out
		tween.tween_property(self, "position:y", position.y - 80.0, 1.2)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "modulate:a", 0.0, 1.2)\
			.set_ease(Tween.EASE_IN).set_delay(0.3)
			
		tween.chain().tween_callback(queue_free)
