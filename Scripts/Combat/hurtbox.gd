class_name Hurtbox extends Area2D

## Hurtbox is an Area2D that is detected by Hurtbox objects and gets dealt hits.
##
## Hurtbox is an Area2D and needs a collision shape to be able to detect Hitboxes.[br]
## IT IS INTENTIONAL THAT THE BASE Hurtbox SCENE HAS NO COLLISION SHAPE.[br]
## YOU ARE SUPPOSED TO ADD IT YOURSELF IN THE SCENE THAT YOU ADD THE HURTBOX IN.[br]
## It is recommended to adjust the collision layers based on what type of entity
## the Hurtbox is attached to (CollisionObject2D -> Collison -> Layer).[br]
## [br]
## When Hurtbox registers a hit, it emits a signal for other scripts to process.
## Hur does not process hits itself; hits should be processed by the base
## object it is attached to.

signal hit(hurtBox: Hurtbox, hit_info: HitInfo, source: Hitbox)

func register_hit(hit_info: HitInfo, source: Hitbox) -> void:
	hit.emit(self, hit_info, source)
