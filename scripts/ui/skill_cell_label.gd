extends Label
class_name SkillCellLabel

var skill_data: Dictionary = {}


func _make_custom_tooltip(_for_text: String) -> Object:
	if skill_data.is_empty():
		return null
	var tooltip := preload("res://scenes/ui/skill_tooltip.tscn").instantiate() as SkillTooltip
	tooltip.setup(skill_data)
	return tooltip
