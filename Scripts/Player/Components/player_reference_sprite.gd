## Drives the palette-indexed sprite pipeline on a [Sprite2D].
##
## See [code]Shaders/reference_sprite.gdshader[/code] for what the two textures are.
## In short: the sprite's own texture stores a palette index per pixel, this holds the
## palette, and swapping the palette reskins every animation on that sheet at once
## without a second copy of any sheet existing.
##
## Runtime edits go through [method set_pixel], which writes into a working copy so
## the palette resource on disk is never mutated -- two players (or a player and a
## menu portrait) can wear the same palette and change it independently.
class_name PlayerReferenceSprite
extends Node

const SHADER := preload("res://Shaders/reference_sprite.gdshader")

var _sprite: Sprite2D
var _material: ShaderMaterial
## The palette as handed to us, kept so [method reset] can undo runtime edits.
var _source: Texture2D
## The working copy [method set_pixel] writes into. Null until the first edit, so a
## palette that is never edited costs no extra image.
var _working: ImageTexture
var _working_image: Image

## Puts the shader on [param sprite] and gives it [param palette] to read from.
func attach(sprite: Sprite2D, palette: Texture2D) -> void:
	_sprite = sprite
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	sprite.material = _material
	set_reference(palette)

## Swaps the palette. Drops any runtime pixel edits, since they were indices into the
## palette that is being replaced.
func set_reference(palette: Texture2D) -> void:
	_source = palette
	_working = null
	_working_image = null
	_apply(palette)

## Rewrites one palette entry, everywhere on the sprite at once.
##
## [param index] is the cell in the palette, the same pair of numbers the sheet's red
## and green channels hold for the pixels that should change.
func set_pixel(index: Vector2i, colour: Color) -> void:
	if not _ensure_working_copy():
		return
	if index.x < 0 or index.y < 0 or index.x >= _working_image.get_width() or index.y >= _working_image.get_height():
		printerr("PlayerReferenceSprite: palette index %s is outside the reference texture." % index)
		return
	_working_image.set_pixelv(index, colour)
	_working.update(_working_image)

## Reads a palette entry back.
func get_pixel(index: Vector2i) -> Color:
	if not _ensure_working_copy():
		return Color.TRANSPARENT
	return _working_image.get_pixelv(index)

## Throws away every runtime edit and goes back to the palette as authored.
func reset() -> void:
	set_reference(_source)

## Tints the looked-up colour, for blinks and flashes that have to survive the lookup.
func set_tint(colour: Color) -> void:
	if is_instance_valid(_material):
		_material.set_shader_parameter(&"tint", colour)

func _ensure_working_copy() -> bool:
	if _working_image != null:
		return true
	if _source == null:
		printerr("PlayerReferenceSprite: no reference texture to edit.")
		return false
	# get_image() on an imported texture hands back the resource's own image, so it is
	# duplicated before anything writes to it.
	var image := _source.get_image()
	if image == null:
		printerr("PlayerReferenceSprite: reference texture has no readable image.")
		return false
	_working_image = image.duplicate()
	_working_image.convert(Image.FORMAT_RGBA8)
	_working = ImageTexture.create_from_image(_working_image)
	_apply(_working)
	return true

func _apply(palette: Texture2D) -> void:
	if not is_instance_valid(_material):
		return
	_material.set_shader_parameter(&"reference_texture", palette)
	if palette != null:
		_material.set_shader_parameter(&"reference_size", Vector2(palette.get_size()))
