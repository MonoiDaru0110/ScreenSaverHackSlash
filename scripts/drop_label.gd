extends Label
## Floating text that appears when gold is earned.
## Animates upward and fades out, then self-destructs.


func setup(content: String, start_pos: Vector2, color: Color, is_corner: bool) -> void:
	text = content
	modulate = color

	# Position with slight random horizontal offset
	position = start_pos + Vector2(randf_range(-30.0, 30.0), -30.0)

	# Corner hits get bigger text
	if is_corner:
		add_theme_font_size_override("font_size", 44)

	# Animate: float up and fade out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 80.0, 1.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, 1.2)\
		.set_ease(Tween.EASE_IN).set_delay(0.3)
	tween.chain().tween_callback(queue_free)
