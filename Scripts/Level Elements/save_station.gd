extends Area2D

@onready var idle = $idleTexture
@onready var green = $greenTexture
@onready var pink = $pinkTexture

@export var active_duration := 2.0
@export var cooldown_duration := 5.0

var is_on := false
var on_cooldown := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_idle()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (is_on):
		switch_active()
	
	
func activate() -> void:
	idle.enabled = false
	green.enabled = true
	
	is_on = true
	on_cooldown = true
	await get_tree().create_timer(active_duration).timeout
	set_idle()
	await get_tree().create_timer(cooldown_duration).timeout
	on_cooldown = false

func set_idle() -> void:
	is_on = false
	idle.enabled = true
	green.enabled = false
	pink.enabled = false

func switch_active() -> void:
	pink.enabled = green.enabled
	green.enabled = !green.enabled

func _on_body_entered(body: Node2D) -> void:
	if on_cooldown:
		return
	var player := body as Player
	if player:
		player.save_station_used.emit()
		MessageDisplay.add_saving_data()
		activate()
