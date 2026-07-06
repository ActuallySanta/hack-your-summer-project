extends Node2D

@onready var idle = $idleTexture
@onready var green = $greenTexture
@onready var pink = $pinkTexture

var is_on := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_idle()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (is_on):
		switch_active()
	
func activate() -> void:
	idle.enabled = false;
	green.enabled = true;
	is_on = true;

func set_idle() -> void:
	idle.enabled = true
	green.enabled = false
	pink.enabled = false

func switch_active() -> void:
	pink.enabled = green.enabled
	green.enabled = !green.enabled
	
