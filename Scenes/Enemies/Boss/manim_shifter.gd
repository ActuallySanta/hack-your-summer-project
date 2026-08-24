class_name ManualAnimatorShifter extends Node2D

signal on_special_frame

@export var frames_horiztonal : int = 5
@export var sub_anim_frame_count  : int = 4
@export var special_frame : int = 2

var manualRoot : ManualAnim
var timer := 0.0
var do_animation := false
var frame := 0:
	set(value):
		frame = value
		set_frame()

func _ready() -> void:
	var manims : Array[ ManualAnim ] = [ ]
	manims.assign( ChildFilter.get_desendants_of_type( self, ManualAnim ) )
	if manims.size() == 0:
		printerr("No Manim as child!~")
	else:
		manualRoot = manims[ 0 ]

func _process(delta: float) -> void:
	if not do_animation:
		return
	timer -= delta
	while timer <= 0:
		timer += ManualAnim.ANIM_FRAME_SECONDS
		shift()

func set_frame() -> void:
	manualRoot.anim_offset.x = frame * sub_anim_frame_count

func start_anim() -> void:
	do_animation = true
	timer = ManualAnim.ANIM_FRAME_SECONDS
	frame = 0
	manualRoot.visible = false

func shift() -> void:
	manualRoot.visible = true
	if frame == special_frame:
		on_special_frame.emit()
	
	if frame == frames_horiztonal: # base case
		frame = 0 # reset frame counter
		manualRoot.visible = false
		do_animation = false # Stop processing
		timer = 0 # reset timer
	else:
		visible = true
		frame += 1
	
