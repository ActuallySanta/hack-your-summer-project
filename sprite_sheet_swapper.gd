class_name SpriteSheetSwapper extends Node2D

@export var sprite_sheets : Array[ Texture2D ]

var _sprite_children : Array [ Sprite2D ]

func _ready() -> void:
	_sprite_children.assign( ChildFilter.get_desendants_of_type( self, Sprite2D ) )

func set_sprite_level(level: int) -> void:
	level = clamp(level, 0, sprite_sheets.size() - 1)
	for child in _sprite_children:
		child.texture = sprite_sheets[ level ]
