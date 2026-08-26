@tool
## Turns an ordinary sprite sheet into the two textures the reference-sprite shader
## wants: a shape sheet of palette indices, and the palette itself.
##
## Run it from the editor: File > Run (Ctrl+Shift+X) with this script open, after
## setting [member sheets] to the sheets to bake. Nothing is overwritten unless
## [member overwrite] is on.
##
## Baking a group of sheets together (the whole character, every animation) is the
## normal case and is what [member share_palette] does: every sheet ends up indexing
## the same palette, so one palette swap reskins all of them at once. Bake a sheet on
## its own only when it genuinely has its own colours.
##
## Afterwards, in the Import dock, both outputs need: Filter off, Mipmaps off,
## "Fix Alpha Border" off, Compress mode Lossless. The shape sheet is *data*; any
## filtering of it blends two indices into a third and shows up as a wrong colour.
extends EditorScript

## Sheets to bake.
@export var sheets: Array[String] = [
	"res://Sprites/SpaceStation_Character_Sheet.png",
	"res://Sprites/Main Character Climb.png",
	"res://Sprites/Main Character Crawl.png",
	"res://Sprites/Main Character Short Climb.png",
	"res://Sprites/character_swing.png",
]

## Where the baked shape sheets and palette go.
@export var output_dir := "res://Sprites/Reference/"

## One palette shared by every sheet in [member sheets]. Off gives each sheet its own.
@export var share_palette := true

## Name of the shared palette file, without extension.
@export var palette_name := "player_palette"

## Width of the palette in cells. Colours fill left to right, top to bottom, so a
## palette wider than the colour count simply leaves the tail empty.
@export var palette_width := 16

@export var overwrite := false

func _run() -> void:
	var palette: Array[Color] = []
	var lookup: Dictionary[Color, Vector2i] = {}
	var baked := 0

	for path in sheets:
		var image := _load_image(path)
		if image == null:
			continue
		if not share_palette:
			palette = []
			lookup = {}

		var shape := _bake_one(image, palette, lookup)
		var out := output_dir.path_join(path.get_file().get_basename() + "_shape.png")
		if _save(shape, out):
			baked += 1
		if not share_palette:
			_save(_build_palette(palette), output_dir.path_join(path.get_file().get_basename() + "_palette.png"))

	if share_palette and not palette.is_empty():
		_save(_build_palette(palette), output_dir.path_join(palette_name + ".png"))

	print("bake_reference_sprite: %d sheet(s) baked, %d colour(s) in the palette." % [baked, palette.size()])
	if palette.size() > palette_width * palette_width:
		printerr("bake_reference_sprite: %d colours needs a palette taller than it is wide; that is fine, but check the sheets are not anti-aliased." % palette.size())
	EditorInterface.get_resource_filesystem().scan()

## Replaces every pixel with the palette index of its colour, stored as (red, green).
##
## Fully transparent pixels stay transparent and take no palette entry: the shader
## discards them before it looks anything up, and giving them an index would waste
## one and make the transparent border depend on palette entry (0, 0).
func _bake_one(image: Image, palette: Array[Color], lookup: Dictionary[Color, Vector2i]) -> Image:
	var shape := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var colour := image.get_pixel(x, y)
			if colour.a <= 0.0:
				shape.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var index: Vector2i
			if lookup.has(colour):
				index = lookup[colour]
			else:
				index = Vector2i(palette.size() % palette_width, palette.size() / palette_width)
				lookup[colour] = index
				palette.append(colour)

			# The index goes in as exact 8-bit bytes; the shader rounds it back out.
			shape.set_pixel(x, y, Color(index.x / 255.0, index.y / 255.0, 0.0, colour.a))
	return shape

func _build_palette(palette: Array[Color]) -> Image:
	var height: int = maxi(1, ceili(float(palette.size()) / float(palette_width)))
	var image := Image.create_empty(palette_width, height, false, Image.FORMAT_RGBA8)
	for i in palette.size():
		image.set_pixel(i % palette_width, i / palette_width, palette[i])
	return image

func _load_image(path: String) -> Image:
	var texture := load(path) as Texture2D
	if texture == null:
		printerr("bake_reference_sprite: could not load \"%s\"." % path)
		return null
	var image := texture.get_image()
	if image == null:
		printerr("bake_reference_sprite: \"%s\" has no readable image." % path)
		return null
	image = image.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	return image

func _save(image: Image, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	if FileAccess.file_exists(path) and not overwrite:
		printerr("bake_reference_sprite: \"%s\" already exists; set overwrite to replace it." % path)
		return false
	var error := image.save_png(path)
	if error != OK:
		printerr("bake_reference_sprite: could not write \"%s\" (error %d)." % [path, error])
		return false
	return true
