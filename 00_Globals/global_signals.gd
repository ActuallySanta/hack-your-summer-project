extends Node

signal OnDialogueBegin(_conversation : Dialogue_Conversation)
signal OnDialogueEnd

signal health_changed(current_health: int, max_health: int)
signal health_extended_by_one()

signal OnGamePause
signal OnGameResume

signal PushBlockingCyborg
signal RestoreStationPower
## Emitted right after the player has been teleported to a spawn point (level
## load or checkpoint respawn). Nodes that react to the player's presence should
## re-check it here: a teleport produces no enter/exit signals until the physics
## server has stepped, which is several frames after the room is in the tree.
signal player_spawned

signal OnBossDie

## Emitted when the player has crossed into another room, before anything has moved.
## [RoomTransitionFade] takes it as its cue to start covering the screen.
signal room_transition
## Emitted by [RoomTransitionFade] once the screen is fully black. The room swap waits
## on this, so no part of it is ever seen.
signal room_transition_faded_out
## Emitted once the new room is up and the player is standing in it, which is both the
## end of the transition and [RoomTransitionFade]'s cue to clear the screen again.
signal room_transition_complete
