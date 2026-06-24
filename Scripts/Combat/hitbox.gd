class_name Hitbox extends Area2D

## Hitbox detects Hurtbox objects and deals damage (and possibly knockback) to them.
##
## Hurtbox is an Area2D and needs a collision shape to be able to detect Hitboxes.[br]
## IT IS INTENTIONAL THAT THE BASE HITBOX SCENE HAS NO COLLISION SHAPE.[br]
## YOU ARE SUPPOSED TO ADD IT YOURSELF IN THE SCENE THAT YOU ADD THE HITBOX IN.[br]
## It is recommended to adjust the collision layer masks based on the intended
## targets of the hurtbox (CollisionObject2D -> Collison -> Mask).[br]
## [br]
## Hitbox does not apply the damage or knockback, it simply communicates those values.
## The object that the Hitbox is attached to is what processes the hit.

signal on_hit(hitbox: Hitbox, target: Hurtbox)

@export var damage: int = 1
@export var knockback_strength: float
@export var knockback_duration: float

func _on_area_entered(area: Area2D) -> void:
	#print(area.name)
	
	var hurtbox := area as Hurtbox
	if not hurtbox:
		return
	on_hit.emit(self, hurtbox)
	var hit_info := HitInfo.new(damage, knockback_strength, knockback_duration)
	hurtbox.register_hit(hit_info, self)
