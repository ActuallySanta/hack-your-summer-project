extends Area2D

@export var electrical : Door
@onready var sprite : Sprite2D = $Sprite2D
@onready var player_interactable : PlayerInteractable = $PlayerInteractable

func _ready() -> void:
	if SaveManager.is_station_powered():
		switch_to_powered_sprite()
		player_interactable.queue_free()
		return
	player_interactable.on_player_confirm_interaction.connect( try_insert_fuse )

func switch_to_powered_sprite() -> void:
	sprite.frame = 1
	electrical.animate_open()

func try_insert_fuse() -> void:
	if SaveManager.is_item_id_collected(SaveManager.ITEM_FUSE) \
	and !SaveManager.is_station_powered():
		GlobalSignals.RestoreStationPower.emit()
		switch_to_powered_sprite()
	else:
		LogBookManager.collect_event_log("power", "Electrical Failure")

func _on_body_entered(body: Node2D) -> void:
		try_insert_fuse()
