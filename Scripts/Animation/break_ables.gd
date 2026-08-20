extends TileMapLayer
## A layer of tiles that break when the right thing hits them, then build
## themselves back up.
##
## The layer owns the group behaviour: which cells are currently broken, what an
## attack is allowed to break, and how the whole layer is tuned. Each broken cell
## is tracked by a BreakableTileData, which owns nothing but its own animation.
##
## A cell atlas y is the kind of break it takes (see NAME_TO_ATLAS) and its
## atlas x is the animation frame. Only x 0 carries collision, so a tile is solid
## when whole and passable from the moment it is hit until it is fully repaired.

const OFFSETS = [ Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

## Converts types of tile interactions to their atlas y-coord
const NAME_TO_ATLAS : Dictionary[ StringName, int ] = {
	"any": 0, 
	"wrench": 1,
	"plasma_bullet": 2,
	"bullet": 3,
	"crumble": 4,
}
const READABLE :Dictionary[ int, StringName ] = {
	0: "any", 
	1:"wrench",
	2:"plasma_bullet",
	3:"bullet",
	4:"crumble",
}

## The attempt type the weight of the player counts as. Not an attack, which is
## why even an "any" tile ignores being walked over.
const STEP_ATTEMPT : StringName = &"crumble"

## What a layer does with the foreground tile that was hiding a block, once that
## block has finished repairing itself.
enum RepairMode {
	LEAVE_REVEALED, ## The cover stays off, so a block found once stays found.
	RESTORE_COVER, ## The cover goes back on, hiding the block again.
}

@export var destroy_neighbors : bool = false
## False leaves broken tiles gone for good, with no repair at all.
@export var respawn : bool = true
@export var destruction_offset_seconds : float = 0.1

@export_group("Timing")
## How long a broken tile stays disappeared before it starts repairing itself.
@export var time_gone_seconds : float = 2.0
## Frames of the break animation to skip between the ones that are shown, which
## is what makes a layer crumble faster or slower. 0 plays every frame. Speeds up
## the repair to match, since it is the same animation run backwards.
@export_range(0, 3) var animation_frames_skipped : int = 0

@export_group("Reveal")
## What happens to the foreground tile hiding a block once the block has repaired
## itself. Blocks that were only revealed, never broken, stay revealed either way.
@export var repair_mode : RepairMode = RepairMode.LEAVE_REVEALED

@export_group("Triggers")
## Whether "crumble" tiles on this layer give way when the player stands on them.
## The player drives this, since being stood on is not an attack; see
## Player.handle_crumbling_floor.
@export var crumbles_underfoot : bool = true

var list_of_broken_cords : Array[ BreakableTileData ]

## Break tests that stand in for the plain name match on particular tile types.
## Each is called as test(attempt_type, tile_type) -> bool, the same shape as the
## override destroy_tile takes. Filled in _init, so a layer knows what breaks it
## from the moment it exists rather than from the moment it enters the tree.
var _type_tests : Dictionary[ StringName, Callable ]

func _init() -> void:
	_type_tests = {
		&"any": _breaks_on_any_attack,
		&"bullet": _breaks_on_any_bullet,
	}

#region Break tests
## An "any" tile gives way to any attack at all, but not to being walked over:
## the weight of the player is not an attack, whatever else it may set off.
func _breaks_on_any_attack(attempt_type: StringName, _tile_type: StringName) -> bool:
	return attempt_type != STEP_ATTEMPT

## A "bullet" tile takes any shot, whichever gun fired it, so a new gun mode only
## has to name its damage type "<something>_bullet" to be able to break one.
func _breaks_on_any_bullet(attempt_type: StringName, _tile_type: StringName) -> bool:
	return attempt_type.ends_with( "_bullet" )


func _passes_test(tile_type: StringName, attempt_type: StringName, test: Callable) -> bool:
	if test.is_valid():
		return test.call( attempt_type, tile_type )

	var registered : Callable = _type_tests.get( tile_type, Callable() )
	if registered.is_valid():
		return registered.call( attempt_type, tile_type )

	return attempt_type == tile_type
#endregion

func _process(delta: float) -> void:
	var to_remove : Array[ int ]
	# Go over array
	for i in list_of_broken_cords.size():
		# Get data and iterate
		var tile_data := list_of_broken_cords[ i ]
		if not tile_data.iterate( delta ):
			continue

		if tile_data.phase == BreakableTileData.Phase.DONE:
			if tile_data.frame < 0:
				# A layer that does not respawn, so the cell stays cleared. The
				# draw below is what actually clears it.
				to_remove.append( i )
			elif PlayerOverlap.with_rect( cell_rect( tile_data.coord ), global_transform ):
				# The block would reappear inside the player, so break it again
				# and let it run the whole animation before trying once more.
				tile_data.reset()
			else:
				tile_data.restore_cover()
				to_remove.append( i )

		draw_tile( tile_data )
	
	# Descending, so removing one index doesn't shift the ones still to come.
	to_remove.reverse()
	for i in to_remove:
		list_of_broken_cords.remove_at( i )

## Draws a broken tile as the frame it has reached, or clears its cell while it
## is gone.
func draw_tile(tile_data: BreakableTileData) -> void:
	if tile_data.frame < 0:
		erase_cell( tile_data.coord )
	else:
		set_cell_with( tile_data.coord, Vector2i( tile_data.frame, tile_data.break_type ) )

func set_cell_with(coords: Vector2i, index: Vector2i) -> void:
	set_cell( coords, 0, index )

## The area a cell covers, in this layer's local space.
func cell_rect(coords: Vector2i) -> Rect2:
	var size := Vector2( tile_set.tile_size )
	# map_to_local returns the centre of the cell.
	return Rect2( map_to_local( coords ) - size * 0.5, size )


## Sets up a tile to be broken.
##
## [param attempt_type] names the kind of hit that landed, and [param foreground]
## is the layer whose tile is hiding the block, if any.
##
## [param test] optionally replaces the check of whether this hit breaks this
## tile, and is called as test(attempt_type, tile_type) -> bool. Left off, the
## test belonging to the tile type decides, and a type without one takes only the
## attack it is named after.
##
## [param can_reveal] lets a hit that fails to break the tile still strip the
## foreground hiding it, so the player learns what is buried there. A revealed
## tile is never covered again.
func destroy_tile(coords: Vector2i, attempt_type: StringName, foreground : TileMapLayer, test : Callable = Callable(), can_reveal : bool = false) -> void:
	# base case
	if not does_tile_exist( coords ):
		return
	for i in list_of_broken_cords:
		if i.coord == coords:
			return
	
	# 
	var break_type : int = get_cell_atlas_coords( coords ).y
	var tile_type : StringName = READABLE.get( break_type, &"" )
	if not _passes_test( tile_type, attempt_type, test ):
		if can_reveal:
			reveal_tile( coords, foreground )
		return

	# Create TileData
	var tile_data := BreakableTileData.new( coords, break_type, animation_frames_skipped + 1, time_gone_seconds, respawn )
	if foreground and foreground.get_cell_source_id( coords ) != -1:
		tile_data.pull_cover_from( foreground )
		if repair_mode != RepairMode.RESTORE_COVER:
			tile_data.forget_cover()
	
	list_of_broken_cords.append( tile_data )
	draw_tile( tile_data )
	
	# Handle neighbor destruction
	if not destroy_neighbors:
		return
	await get_tree().create_timer(destruction_offset_seconds).timeout
	
	# recursive case
	for i in OFFSETS:
		destroy_tile( coords + i, attempt_type, foreground, test, false )

## Removes the foreground tile hiding a block the attack could not break
func reveal_tile(coords: Vector2i, foreground: TileMapLayer) -> void:
	if foreground:
		foreground.erase_cell( coords )

## Breaks the crumbling tile under a world-space point, if there is one.
func step_on(global_point: Vector2, foreground: TileMapLayer) -> void:
	if not crumbles_underfoot:
		return
	destroy_tile( local_to_map( to_local( global_point ) ), STEP_ATTEMPT, foreground )

func does_tile_exist(coords: Vector2i) -> bool:
	return get_cell_source_id( coords ) != -1
