extends Node2D

@onready var detial : Sprite2D = $BackgroundDetailed
@onready var sectors : Dictionary[ String, Node2D ] = {
	"DB" : $DockingBay,
	"CQ" : $CrewQuarters,
	"BS" : $BRS,
	"RS" : $"Research Sector",
	"OP" : $Operations,
	"IL" : $Internals,
}

func _ready() -> void:
	for i in sectors:
		var node : Node2D = sectors[ i ]
		node.hide()

func fade_fill(time: float) -> void:
	var alpha = sin(time/10)
	detial.self_modulate = Color(1, 1, 1, alpha * alpha)

func show_sector(sector_id: String) -> void:
	var node : Node2D = sectors[ sector_id ]
	node.show()
