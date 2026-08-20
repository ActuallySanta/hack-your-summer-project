extends Area2D

@export var powered_texture : Texture2D
@export var electrical : Door
@onready var sprite : Sprite2D = $Sprite2D

func _ready() -> void:
	if GameManager.is_station_powered():
		switch_to_powered_sprite()
	body_entered.connect(_on_body_entered)

func switch_to_powered_sprite() -> void:
	sprite.texture = powered_texture
	electrical.animate_open()

func try_insert_fuse() -> void:
	if GameManager.is_object_collected(GameManager.PICKUP_FUSE_ID) \
	and !GameManager.is_station_powered():
		GlobalSignals.RestoreStationPower.emit()
		switch_to_powered_sprite()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		try_insert_fuse()
