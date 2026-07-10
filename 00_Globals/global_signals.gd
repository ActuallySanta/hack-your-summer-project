extends Node

signal OnDialogueBegin(_conversation : Dialogue_Conversation)
signal OnDialogueEnd

signal OnSaveComplete
signal OnLoadComplete

signal health_changed(current_health: int, max_health: int)
