## A map station: walking into it reveals the regions listed on it.
##
## What it reveals is recorded twice on purpose. The station itself is a MetSys
## storable object, so a used station stays used; and the region codes go in the save
## under their own key, so a load can replay the reveal directly (see
## [method SaveManager.register_map_region_revealed]). The replay is what makes the
## revealed map survive a reload rather than depending on MetSys' per-cell discovery
## data surviving the trip through the save file intact.
##
## Both are in the save, so both revert together on death: a station used and then
## died on before saving is unused again, and the map it showed is dark again.
extends Node2D

@export_enum("DB", "CQ", "BS", "RS", "OP", "IL") var what_to_keep : Array[ String ]

@onready var animator = $AnimationPlayer
@onready var BRS = $ActiveBRS
@onready var CQ = $ActiveCQ
@onready var idle = $IdleTexture
@onready var _map_image = $Hider/MapDisplay

var _timer_passive = 0
var _start_pos : Vector2
var _is_on = false
var _has_been_interacted_with = false

func _ready() -> void:
	# No marker, as before -- a station is drawn on the map by the room it is in.
	# [constant SaveManager.MapIcon.Map] is here whenever it should have one.
	SaveManager.register_item(self, turn_off, SaveManager.MapIcon.None)
	if SaveManager.is_item_collected(self):
		return

	for i in what_to_keep:
		_map_image.show_sector( i )

	_start_pos = _map_image.global_position

func _process(delta: float) -> void:
	passiveAnim(delta)

func passiveAnim(delta: float) -> void:
	if _has_been_interacted_with and not _is_on:
		return

	_timer_passive += delta
	var time = TAU * _timer_passive
	var alpha = sin(time/10)
	var height = sin(time * 0.75)
	_map_image.modulate = Color(1, 1, 1, alpha * alpha / 2 + 0.5)
	_map_image.global_position.y = _start_pos.y + height
	_map_image.fade_fill(time)

func _on_interaction_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _has_been_interacted_with:
		return

	_has_been_interacted_with = true
	for code in what_to_keep:
		# Recorded first, so the save knows what to put back on a reload, then applied.
		SaveManager.register_map_region_revealed( code )
		MapRegions.reveal( code )
	SaveManager.save_item(self, SaveManager.MapIcon.None)
	animator.play("Active")

func turn_off() -> void:
	_has_been_interacted_with = true
	animator.play("Off")
