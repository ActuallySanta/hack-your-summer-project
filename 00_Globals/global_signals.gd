extends Node

signal OnDialogueBegin(_conversation : Dialogue_Conversation)
signal OnDialogueEnd

signal health_changed(current_health: int, max_health: int)
signal health_extended_by_one()

signal OnGamePause
signal OnGameResume

## Emitted right after the player has been teleported to a spawn point (level
## load or checkpoint respawn). Nodes that react to the player's presence should
## re-check it here: a teleport produces no enter/exit signals until the physics
## server has stepped, which is several frames after the room is in the tree.
signal player_spawned
