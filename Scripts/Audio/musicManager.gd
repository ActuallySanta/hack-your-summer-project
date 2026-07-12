extends AudioStreamPlayer2D

const CREW_QUARTERS_OST = preload("res://Sounds/DebugAndTemp/ChargeFire.wav")
const INTERNALS_OST = preload("res://Sounds/DebugAndTemp/ChargeFire.wav")
const LABS_OST = preload("res://Sounds/Music/Jetpack Joyride DEMO.ogg")
const BIOLOGICAL_RESEARCH_LABS_OST = preload("res://Sounds/DebugAndTemp/ChargeFire.wav")
const MAIN_MENU_OST = preload("res://Sounds/DebugAndTemp/ChargeFire.wav")
const BOSS_OST = preload("res://Sounds/DebugAndTemp/ChargeFire.wav")

@export var starting_area := "Crew Quarters"

@onready var location_audio := {
	"Crew Quarters": CREW_QUARTERS_OST,
	"Ship Internals": INTERNALS_OST,
	"Research Sector": LABS_OST,
	"Biological Research Sector": BIOLOGICAL_RESEARCH_LABS_OST,
	"Main Menu": MAIN_MENU_OST,
	"Boss 1 Room": BOSS_OST
}

func _ready() -> void:
	set_background_track( starting_area )

func set_background_track(location: String) -> void:
	stream = location_audio[ location ]
	play()
