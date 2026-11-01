extends BaseWindow
## Window for configuring automations.

@onready var auto_buying_card: AutoBuyingCard = %AutoBuyingCard
@onready var auto_ascend_card: AutoAscendCard = %AutoAscendCard


func _ready() -> void:
	super._ready()
	sync_from_data()


func sync_from_data() -> void:
	if auto_buying_card:
		auto_buying_card.sync_from_data()
	if auto_ascend_card:
		auto_ascend_card.sync_from_data()
