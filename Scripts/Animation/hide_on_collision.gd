extends Area2D

func _ready() -> void:
	SaveManager.register_item(self, hide_collider, SaveManager.MapIcon.None)

func hide_collider() -> void:
	$CollisionShape2D.position.y += 10000

func _on_body_entered(body: Node2D) -> void:
	hide_collider()
	$Foreground2.visible = false
	SaveManager.save_item(self, SaveManager.MapIcon.None)
