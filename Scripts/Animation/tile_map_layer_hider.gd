class_name Area2DHider extends Area2D

@export var fade_amount : float = 0.05
# Functional
var player_is_in : bool
var is_anim : bool
var is_shown : bool

func _ready() -> void:
	player_is_in = false
	is_anim = false
	is_shown = true
	# Connect here rather than in the editor: this script is usually added as a
	# custom-type Area2D, so scene-file connections don't come along with it.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if is_shown and player_is_in:
		make_visible(false)
	elif not is_shown and not player_is_in:
		make_visible(true)

func iterate_on_alpha(delta_a: float) -> void:
	modulate.a = clamp(modulate.a + delta_a, 0, 1)

func make_visible(value: bool) -> void:
	if is_anim:
		return

	is_anim = true
	var goal = 1 if value else 0
	var delta = fade_amount if value else -fade_amount
	# Animate
	while not modulate.a == goal:
		iterate_on_alpha(delta)
		await get_tree().process_frame
	
	is_anim = false
	is_shown = value

func _on_body_entered(body: Node2D) -> void:
	print("ENTER: " + body.name)
	if body.is_in_group("player"):
		player_is_in = true


func _on_body_exited(body: Node2D) -> void:
	print("EXIT: " + body.name)
	if body.is_in_group("player"):
		player_is_in = false
