## The map borders that change with the story.
##
## MetSys draws every cell border from a number authored in the map editor, and that
## number never changes on its own. Two of this map's borders are meant to: a secret
## passage that has to read as a plain wall until the player has been through it, and
## a security latch that has to read as shut until whatever opens it has happened.
##
## Both are still authored once, in the map editor, as the border they [i]really[/i]
## are. What this holds is a runtime override on each of them (see
## [method MetroidvaniaSystem.get_cell_override]) saying what to draw instead, and it
## rebuilds every one of those overrides from the save whenever the player spawns.
##
## A border belongs to the two cells either side of it and both are written, always,
## because the theme shares borders and either cell may be the one on screen. See
## [method _set_both_sides], which is the whole of that reasoning.
##
## [b]Secret passages[/b] ([constant SECRET], the dithered wall) need no code at all.
## They are found by reading the map, so drawing one in the editor is the whole job:
## it is a plain wall until the player crosses it — from either side — and the
## dithered wall from then on.
##
## [b]Security latches[/b] ([constant LOCKED]) are found by reading the map too, but
## [i]what opens one[/i] is a decision rather than a fact about the map, so each is
## named in [constant LOCKS] under the lock that opens it. Opening that lock turns
## every border filed under it into [constant UNLOCKED]. A latch no lock claims stays
## shut forever and says so in a warning (see [method _validate_table]).
##
## [b]Saving.[/b] There is no save format here. A revealed passage and an opened lock
## are each a flag in MetSys' [code]stored_objects[/code], which is written with the
## rest of the save and read back with it, and every spawn rebuilds the map from those
## flags. That is what makes the two things the player expects fall out for free: a
## passage found and then died on before saving is a wall again on the reload, and a
## save whose locks were open comes back with them open — including in rooms the
## player has not returned to yet, since none of this needs the room to be loaded.
extends Node

#region What the border numbers mean

## Border values as they are authored in the MetSys map editor. [code]0[/code] and
## [code]1[/code] are MetSys' own wall and passage; anything higher indexes
## [member MapTheme.borders], so [constant LOCKED] is [code]borders[0][/code],
## [constant UNLOCKED] is [code]borders[1][/code] and [constant SECRET] is
## [code]borders[2][/code].
const WALL := 0
## An ordinary opening between two cells.
const PASSAGE := 1
## A security latch, shut: the border the player cannot pass yet. Authored on both
## sides of the latch.
const LOCKED := 2
## A security latch, open. Never authored — this is only ever what a
## [constant LOCKED] border becomes.
const UNLOCKED := 3
## A secret passage, revealed: the dithered wall. Authored on both sides of the
## passage, and drawn as a plain [constant WALL] until the player crosses it.
const SECRET := 4

#endregion

#region Which lock opens which latch

## The station's main power. Everything the fuse brings back to life.
const STATION_POWER := &"station_power"

## The airlock to the player's own ship. Not on the station's power — it is opened by
## its own event, with [code]MapBorders.open_lock(MapBorders.SHIP_AIRLOCK)[/code].
const SHIP_AIRLOCK := &"ship_airlock"

## Every security latch in the map, filed under the lock that opens it.
##
## A border is written as the cell it belongs to and the side of that cell it is on:
## [code]"x,y,layer:R"[/code], with [code]R D L U[/code] for right, down, left and up.
## A latch sits between two cells and so has two names — either will do, they are
## folded together on load.
##
## [b]To add a latch:[/b] draw it in the map editor as [constant LOCKED] on both sides,
## then add its coordinates here under the lock that should open it. A latch left out
## of this table can never open, and says so in a warning at startup.
const LOCKS := {
	# The docking bay. Dead until the fuse goes in, and then all of it opens at once.
	STATION_POWER: [
		"7,-1,0:R", # bay alpha -> waiting room
		"9,-1,0:R", # waiting room -> bay gamma
		"8,-2,0:R", # service hall -> service crossroads
		"9,-2,0:R", # service crossroads -> bay gamma
		"8,-4,0:R", # maintenance room -> service crossroads
		"11,-3,0:R", # bay gamma -> storage room
	],
	# The one door in the docking bay the power does not open.
	SHIP_AIRLOCK: [
		"5,-2,0:R", # the player's ship -> bay alpha
	],
}

#endregion

#region Internals

## Direction index [b]->[/b] the step to the cell on the other side of that border.
## Matches [enum MetroidvaniaSystem.R] and friends, which is the order MetSys stores
## a cell's four borders in.
const FWD : Array[Vector3i] = [
	Vector3i(1, 0, 0), # R
	Vector3i(0, 1, 0), # D
	Vector3i(-1, 0, 0), # L
	Vector3i(0, -1, 0), # U
]

## Direction index [b]->[/b] its letter in a border name, as written in
## [constant LOCKS].
const DIR_NAMES : Array[String] = ["R", "D", "L", "U"]

## No border at all: the two cells either side of it are open to each other, and
## MetSys draws nothing between them. Never written over — see
## [method _set_both_sides].
const NO_BORDER := -1

## Namespaces for the save flags, so they cannot collide with the ids
## [method MetroidvaniaSystem.get_object_id] makes for pickups, doors and buttons —
## those share the same [code]stored_objects[/code] dictionary.
const REVEALED_FLAG := "map_secret/"
const LOCK_FLAG := "map_lock/"

## Every secret passage in the map, by border name. Read out of the map once, at
## startup, since the map itself never changes at runtime.
var _secrets : Dictionary[String, Vector4i]

## Every security latch in the map, by border name.
var _latches : Dictionary[String, Vector4i]

## Border name [b]->[/b] the lock that opens it, folded out of [constant LOCKS].
var _lock_of : Dictionary[String, StringName]

## The cell the player was in before the one they are in now, which is what says which
## border they just crossed. [constant Vector3i.MAX] until they have moved since
## spawning.
var _previous_cell := Vector3i.MAX

#endregion

func _ready() -> void:
	_read_map()
	_read_table()
	_validate_table()
	# A spawn is the one moment that follows both a load and a new game, and it lands
	# before the load screen lifts, so it is where the save becomes the authority
	# again — including after a death, which reloads the save from disk and so takes
	# back everything found since it was written.
	GlobalSignals.player_spawned.connect(_on_player_spawned)
	GlobalSignals.RestoreStationPower.connect(open_lock.bind(STATION_POWER))
	MetSys.cell_changed.connect(_on_cell_changed)
	# Anything that redraws the map announces itself here first, and every map view
	# listens to the same signal. Being an autoload we are connected before any of
	# them, so correcting the borders now means no view can draw a border we have not
	# brought up to date yet — including the moment a save is restored, which puts
	# back the overrides as they were written and emits nothing at all.
	#
	# This cannot loop: a pass that changes nothing emits nothing, and a pass that
	# does emits only on the next frame (see CellOverride._queue_commit).
	MetSys.map_updated.connect(_apply_all)

#region Public API

## Reveals the secret passage on the given side of the given cell, as though the
## player had crossed it. Done for you when they actually do; this is for a passage
## that should also open some other way.
func reveal_secret(coords: Vector3i, direction: int) -> void:
	var id := _name_of(_canonical(coords, direction))
	if not id in _secrets:
		push_warning("MapBorders: no secret passage at %s, so there is nothing to reveal." % id)
		return
	if is_secret_revealed(coords, direction):
		return
	if not _set_flag(REVEALED_FLAG + id):
		return
	_apply_secret(id)

## Whether the secret passage on the given side of the given cell has been revealed.
func is_secret_revealed(coords: Vector3i, direction: int) -> bool:
	return _flag_set(REVEALED_FLAG + _name_of(_canonical(coords, direction)))

## Opens a lock, and with it every latch [constant LOCKS] files under it. Saved from
## this moment with the rest of the game, so it survives a save and is taken back if
## the player dies before making one.
##
## Safe to call again on a lock that is already open.
func open_lock(lock: StringName) -> void:
	if not lock in LOCKS:
		push_warning("MapBorders: no lock named \"%s\" in LOCKS, so opening it does nothing." % lock)
		return
	if is_lock_open(lock):
		return
	if not _set_flag(LOCK_FLAG + lock):
		return
	for text: String in LOCKS[lock]:
		var border := _parse_name(text)
		if border.w >= 0:
			_apply_latch(_name_of(border), true)

## Whether a lock has been opened.
func is_lock_open(lock: StringName) -> bool:
	if _flag_set(LOCK_FLAG + lock):
		return true
	# The station's power is a fact the save has always kept for itself, and the debug
	# save in [GameManager] sets that and nothing else, so it is read as well as the
	# flag. Without this, powering the station through either of those routes would
	# light the bay up and leave its doors drawn shut.
	if lock == STATION_POWER:
		return GameManager.is_station_powered()
	return false

#endregion

#region Watching the player cross

## Puts the map back into the state the save describes, and takes the cell the player
## has just been placed in as their new starting point — they were put there rather
## than walking there, so it is no crossing.
func _on_player_spawned() -> void:
	_previous_cell = _player_cell()
	_apply_all()

## Reveals a secret passage the moment the player steps through it.
##
## A step only counts as a crossing if it lands on a neighbouring cell of the same
## layer. Anything further is a teleport — a respawn, a load, a lift between layers —
## and is noted as the new starting point without revealing anything.
func _on_cell_changed(new_cell: Vector3i) -> void:
	var from := _previous_cell
	_previous_cell = new_cell
	if from == Vector3i.MAX or from == new_cell or from.z != new_cell.z:
		return

	for direction in 4:
		if from + FWD[direction] != new_cell:
			continue
		if _name_of(_canonical(from, direction)) in _secrets:
			reveal_secret(from, direction)
		return

## The cell the player is standing in, worked out from their position exactly the way
## [method MetroidvaniaSystem.set_player_position] does.
##
## MetSys' own [member MetroidvaniaSystem.last_player_position] is still describing
## wherever the player was before a spawn — they are teleported and the load screen
## lifts before the next physics frame reports where they landed — so priming from it
## would leave the cell they spawned in unknown, and a passage crossed on their first
## step out of it unrevealed.
func _player_cell() -> Vector3i:
	var room: MetroidvaniaSystem.RoomInstance = MetSys.get_current_room_instance()
	var player := PlayerManager.player
	if room == null or player == null:
		return Vector3i.MAX
	var flat: Vector2i = Vector2i((player.position / MetSys.settings.in_game_cell_size).floor()) + room.min_cell
	return Vector3i(flat.x, flat.y, MetSys.current_layer)

#endregion

#region Putting the map into the state the save describes

## Rebuilds the override on every special border in the map from the save flags.
##
## Cheap enough to do outright — there are a few dozen such borders in the whole map —
## and doing it outright is what makes it idempotent: it is the same pass whether the
## game has just started, just loaded, or just watched a door open, so nothing can
## drift out of step with the save.
func _apply_all() -> void:
	if MetSys.save_data == null:
		return
	for id in _secrets:
		_apply_secret(id)

	# Each lock is read once for the whole pass rather than once per latch on it. The
	# answer is the same for every latch under a lock, and reading it can reach into
	# [GameManager], which is not always there to ask.
	var open: Dictionary[StringName, bool]
	for lock: StringName in LOCKS:
		open[lock] = is_lock_open(lock)

	for id in _latches:
		_apply_latch(id, open.get(_lock_of.get(id, &""), false))

## Draws a secret passage as itself once it has been found, and as a plain wall until
## then.
func _apply_secret(id: String) -> void:
	_set_both_sides(_secrets[id], SECRET if _flag_set(REVEALED_FLAG + id) else WALL)

## Draws a security latch as open or shut.
func _apply_latch(id: String, open: bool) -> void:
	_set_both_sides(_latches[id], UNLOCKED if open else LOCKED)

## Writes [param value] onto both sides of a border, which is what makes it look the
## same whichever of the two cells the player has discovered.
##
## The theme shares borders, so the one line drawn between two cells is drawn from
## whichever of them is on screen. MetSys folds the two facing values together with
## max(), but only for a neighbour the player has [i]already discovered[/i] (see
## CellView._draw_shared_borders) — a cell discovered on its own draws its own value
## and nothing else. Writing one side and trusting max() to carry it therefore only
## works if the player happens to have found the room on the side that was written,
## which for a door between two rooms is a coin toss.
##
## Writing both sides also settles the borders authored differently on each side, in
## favour of the special one: a passage facing a secret is a wall while the secret is
## hidden, and the secret once it is found.
##
## A side the map editor left empty is the one thing not written. There is no border
## drawn there to correct, and putting one in would draw a wall through the middle of
## a room.
func _set_both_sides(border: Vector4i, value: int) -> void:
	var near := Vector3i(border.x, border.y, border.z)
	var direction: int = border.w
	_set_side(near, direction, value)
	_set_side(near + FWD[direction], _opposite(direction), value)

## Overrides one side of one border.
func _set_side(coords: Vector3i, direction: int, value: int) -> void:
	var cell: MetroidvaniaSystem.MapData.CellData = MetSys.map_data.get_cell_at(coords)
	if cell == null or cell.borders[direction] == NO_BORDER:
		return
	var override: MetroidvaniaSystem.MapData.CellOverride = cell.get_override()
	if override == null:
		override = MetSys.get_cell_override(coords)
	override.set_border(direction, value)

#endregion

#region Save flags

func _flag_set(flag: String) -> bool:
	if MetSys.save_data == null:
		return false
	return MetSys.save_data.stored_objects.get(flag, false)

## Writes a save flag, reporting whether there was save data to write it to.
func _set_flag(flag: String) -> bool:
	if MetSys.save_data == null:
		push_warning("MapBorders: no save data yet, so \"%s\" cannot be recorded." % flag)
		return false
	MetSys.save_data.stored_objects[flag] = true
	return true

#endregion

#region Border names

## The canonical form of a border. The two cells either side of one both name it, so
## both are folded onto the lower cell's [constant MetroidvaniaSystem.R] or
## [constant MetroidvaniaSystem.D] side and a border ends up with exactly one name.
func _canonical(coords: Vector3i, direction: int) -> Vector4i:
	if direction == MetroidvaniaSystem.L or direction == MetroidvaniaSystem.U:
		coords += FWD[direction]
		direction = _opposite(direction)
	return Vector4i(coords.x, coords.y, coords.z, direction)

func _name_of(border: Vector4i) -> String:
	return "%d,%d,%d:%s" % [border.x, border.y, border.z, DIR_NAMES[border.w]]

## Reads a border written the way [constant LOCKS] writes them, canonicalised. Returns
## a [Vector4i] with a negative [code]w[/code] if the text is not a border name.
func _parse_name(text: String) -> Vector4i:
	const NOT_A_BORDER := Vector4i(0, 0, 0, -1)

	var parts := text.split(":")
	if parts.size() != 2:
		return NOT_A_BORDER

	var direction := DIR_NAMES.find(parts[1].strip_edges().to_upper())
	if direction < 0:
		return NOT_A_BORDER

	var numbers := parts[0].split(",")
	if numbers.size() != 3:
		return NOT_A_BORDER

	var coords := Vector3i.ZERO
	for i in 3:
		var number := numbers[i].strip_edges()
		if not number.is_valid_int():
			return NOT_A_BORDER
		coords[i] = number.to_int()

	return _canonical(coords, direction)

func _opposite(direction: int) -> int:
	return (direction + 2) % 4

#endregion

#region Reading the map and checking the table

## Finds every secret passage and every security latch in the map, once, at startup.
## The map data itself is fixed from then on — only the overrides on top of it ever
## move — so there is nothing to keep up to date afterwards.
func _read_map() -> void:
	for coords in MetSys.map_data.cells:
		var cell: MetroidvaniaSystem.MapData.CellData = MetSys.map_data.cells[coords]
		for direction in 4:
			match cell.borders[direction]:
				SECRET:
					var border := _canonical(coords, direction)
					_secrets[_name_of(border)] = border
				LOCKED:
					var border := _canonical(coords, direction)
					_latches[_name_of(border)] = border

func _read_table() -> void:
	for lock: StringName in LOCKS:
		for text: String in LOCKS[lock]:
			var border := _parse_name(text)
			if border.w < 0:
				push_warning("MapBorders: \"%s\" under lock \"%s\" is not a border name. Expected \"x,y,layer:R\", with R D L U for the side of the cell." % [text, lock])
				continue
			_lock_of[_name_of(border)] = lock

## Reports every way the table and the map can disagree, once, at startup. Each of
## these is otherwise invisible until you are standing in front of the door it names,
## still shut.
func _validate_table() -> void:
	if not OS.is_debug_build():
		return

	# Gathered up and reported as one warning per kind of problem. A map still being
	# drawn has whole areas of latches waiting for the lock that will open them, and a
	# warning apiece would bury everything else in the log.
	var missing : PackedStringArray
	var not_a_latch : PackedStringArray
	var contradictory : PackedStringArray

	for id in _lock_of:
		if id in _latches:
			continue
		not_a_latch.append("%s (claimed by \"%s\"%s)" % [id, _lock_of[id],
			", and drawn as a secret passage" if id in _secrets else ""])

	for id in _latches:
		if not id in _lock_of:
			missing.append(id)
		if id in _secrets:
			contradictory.append(id)

	if not not_a_latch.is_empty():
		push_warning("MapBorders: LOCKS names %d border(s) that are not security latches. Check them against the map editor: %s" % [not_a_latch.size(), ", ".join(not_a_latch)])

	if not missing.is_empty():
		push_warning("MapBorders: %d security latch(es) are under no lock, so nothing can ever open them. Add them to LOCKS: %s" % [missing.size(), ", ".join(missing)])

	if not contradictory.is_empty():
		push_warning("MapBorders: %d border(s) are drawn as a secret passage on one side and a security latch on the other. Pick one: %s" % [contradictory.size(), ", ".join(contradictory)])

#endregion
