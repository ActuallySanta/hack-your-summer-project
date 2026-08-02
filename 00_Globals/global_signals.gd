extends Node

signal OnDialogueBegin(_conversation : Dialogue_Conversation)
signal OnDialogueEnd

signal health_changed(current_health: int, max_health: int)
signal health_extended_by_one()

signal OnGamePause
signal OnGameResume

signal PushBlockingCyborg
signal RestoreStationPower
