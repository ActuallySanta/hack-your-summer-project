class_name Settings extends Object

# Global visuals

# Docking bay visuals
static var db_drone_bg : bool = true

#TODO SFX integration not implemented
# Global Audio
static var master_volume: float:
	set(value): master_volume = clamp(value, 0.0, 1.0)

static var sfx_volume: float:
	set(value): sfx_volume = clamp(value, 0.0, 1.0)

static var music_volume: float:
	set(value): music_volume = clamp(value, 0.0, 1.0)
