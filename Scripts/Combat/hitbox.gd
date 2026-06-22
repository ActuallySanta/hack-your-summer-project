class_name Hitbox extends Area2D

## Hitbox is an Area2D that is detected by Hurtbox objects and gets dealt hits.
##
## Hitbox is an Area2D and needs a collision shape to be able to detect Hitboxes.[br]
## IT IS INTENTIONAL THAT THE BASE HITBOX SCENE HAS NO COLLISION SHAPE.[br]
## YOU ARE SUPPOSED TO ADD IT YOURSELF IN THE SCENE THAT YOU ADD THE HITBOX IN.[br]
## It is recommended to adjust the collision layers based on what type of entity
## the hitbox is attached to (CollisionObject2D -> Collison -> Layer).[br]
## [br]
## When Hitbox registers a hit, it emits a signal for other scripts to process.
## Hitbox does not process hits itself; hits should be processed by the base
## object it is attached to.

signal hit(hitbox: Hitbox, hit_info: HitInfo, source: Hurtbox)

func register_hit(hit_info: HitInfo) -> void:
	hit.emit(self, hit_info)
