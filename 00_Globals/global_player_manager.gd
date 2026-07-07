extends Node

var player : Player
var inDialogue: bool = false
var canMove : bool = true

const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")

#Add any other variables you need as you save them, they will be saved as a dictionary
func SavePlayer(saveIndex :int)->void:
	var saver:= SaveManager.new()
	saver.set_data("player_health",player._currentHealth)
	saver.set_data("current_room",MetSys.get_current_room_name())
	saver.save_as_text("user://save" + str(saveIndex) +".sav")
	GlobalSignals.OnSaveComplete.emit()
	pass

#Make sure you also load any variable you may have saved
func LoadPlayer(saveIndex :int)->void:
	var loader:= SaveManager.new()
	loader.load_from_text("user://save" + str(saveIndex) +".sav")
	player._currentHealth = loader.get_value("player_health")
	pass
