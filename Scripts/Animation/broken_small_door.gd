extends Sprite2D

@onready var repair_node : RepairNode = $RepairNode
@onready var body : StaticBody2D = $StaticBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SaveManager.register_item( self, func(): return, SaveManager.MapIcon.None )
	if SaveManager.is_item_collected(self): 
		body.queue_free()
		return
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
