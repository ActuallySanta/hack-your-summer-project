extends Sprite2D

const ANIM_TIME := 0.1

@export var door_name : String = "BrokenSmallDoor"

@onready var repair_node : RepairNode = $RepairNode
@onready var body : StaticBody2D = $StaticBody2D

var animate : bool = false
var timer : float = 0

func _ready() -> void:
	if check_save(): return
	repair_node.on_repair_start.connect( repair_start )
	repair_node.on_repair_end.connect( repair_end )

func check_save() -> bool:
	if not owner: return false
	SaveManager.register_item( self, func(): return, SaveManager.MapIcon.None )
	if SaveManager.is_item_collected(self): 
		repair_node.queue_free()
		body.queue_free()
		frame = 100
		return true
	return false

func _process(delta: float) -> void:
	if not animate: return
	timer += delta
	while timer >= ANIM_TIME:
		frame += 1
		timer -= ANIM_TIME
		if frame == 8:
			$AudioStreamPlayer2D2.play()

func repair_start() -> void:
	SaveManager.save_item( self )
	animate = true
	$AudioStreamPlayer2D.play()

func repair_end() -> void:
	body.queue_free()

func _get_object_id() -> String: 
	return door_name
