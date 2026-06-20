extends Control

var parent : Button
@export var scaleMult : float = 1.1
@export var tweenRotation : float = 5
@export var tweenTime : float = 0.5
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	parent = get_parent() as Button
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_mouse_entered() -> void:
	var buttonTween : Tween = create_tween()
	buttonTween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	buttonTween.parallel().tween_property(parent,"scale",parent.scale * scaleMult,tweenTime)
	buttonTween.parallel().tween_property(parent,"rotation_degrees",parent.rotation_degrees + tweenRotation,tweenTime)
	pass # Replace with function body.


func _on_button_mouse_exited() -> void:
	var buttonTween : Tween = create_tween()
	buttonTween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BOUNCE)
	buttonTween.parallel().tween_property(parent,"scale",Vector2.ONE,tweenTime)
	buttonTween.parallel().tween_property(parent,"rotation_degrees",0,tweenTime)
	pass # Replace with function body.
