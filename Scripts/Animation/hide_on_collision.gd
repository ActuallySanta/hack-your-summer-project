extends Area2D

func _ready() -> void:
	if MetSys.register_storable_object(self, hide_collider ):
		return

func hide_collider() -> void:
	$CollisionShape2D.position.y += 10000

func _on_body_entered(body: Node2D) -> void:
	hide_collider()
	$Foreground2.visible = false
	MetSys.store_object(self)
