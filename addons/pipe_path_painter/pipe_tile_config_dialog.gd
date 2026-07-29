@tool
extends AcceptDialog

## Visual assignment of the 15 pipe shapes.
##
## Left: one row per shape, each showing a connection diagram, the tile you
## picked, and its coordinate. Right: the atlas, clickable. Select a slot,
## click a tile. With auto-advance on you can walk all 15 in 15 clicks.

signal config_changed

const PipeGlyph := preload("res://addons/pipe_path_painter/pipe_glyph.gd")
const PipeAtlasPicker := preload("res://addons/pipe_path_painter/pipe_atlas_picker.gd")

const THUMB_SIZE := 34.0

var _config: PipeTileConfig = null
var _tile_set: TileSet = null
var _active_slot := ""

var _source_option: OptionButton
var _zoom_slider: HSlider
var _auto_advance: CheckBox
var _picker: PipeAtlasPicker
var _picker_holder: ScrollContainer
var _slot_box: VBoxContainer
var _status: Label
var _hover_label: Label
var _hover_preview: TextureRect
var _button_group := ButtonGroup.new()

## slot name -> { "button": Button, "thumb": TextureRect, "coord": Label }
var _rows: Dictionary[String, Dictionary] = {}


func _init() -> void:
	title = "Pipe Tiles"
	ok_button_text = "Done"
	min_size = Vector2i(880, 560)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	root.add_child(_build_top_bar())

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 360
	root.add_child(split)

	split.add_child(_build_slot_panel())
	split.add_child(_build_picker_panel())

	root.add_child(_build_bottom_bar())


#region UI construction

func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)

	var source_label := Label.new()
	source_label.text = "Atlas source"
	bar.add_child(source_label)

	_source_option = OptionButton.new()
	_source_option.custom_minimum_size.x = 180
	_source_option.item_selected.connect(_on_source_selected)
	bar.add_child(_source_option)

	bar.add_child(VSeparator.new())

	var zoom_label := Label.new()
	zoom_label.text = "Zoom"
	bar.add_child(zoom_label)

	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = 1
	_zoom_slider.max_value = 10
	_zoom_slider.step = 1
	_zoom_slider.value = 4
	_zoom_slider.custom_minimum_size.x = 130
	_zoom_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_zoom_slider.value_changed.connect(_on_zoom_changed)
	bar.add_child(_zoom_slider)

	bar.add_child(VSeparator.new())

	_auto_advance = CheckBox.new()
	_auto_advance.text = "Auto-advance"
	_auto_advance.button_pressed = true
	_auto_advance.tooltip_text = "After assigning a tile, jump to the next unassigned slot."
	bar.add_child(_auto_advance)

	return bar


func _build_slot_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 340
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_slot_box = VBoxContainer.new()
	_slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_box.add_theme_constant_override("separation", 2)
	scroll.add_child(_slot_box)

	var category := ""
	for tile_name: String in PipeTileLayout.NAME_TO_MASK:
		var slot_category: String = PipeTileLayout.NAME_TO_CATEGORY[tile_name]
		if slot_category != category:
			category = slot_category
			_slot_box.add_child(_make_heading(category))
		_slot_box.add_child(_make_slot_row(tile_name))

	return scroll


func _make_heading(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1, 1, 1, 0.55)
	return label


func _make_slot_row(tile_name: String) -> Control:
	var mask: int = PipeTileLayout.NAME_TO_MASK[tile_name]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	row.add_child(PipeGlyph.new(mask, 26.0))

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(thumb)

	var button := Button.new()
	button.text = tile_name
	button.toggle_mode = true
	button.button_group = _button_group
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "Connects %s. Select, then click a tile in the atlas." % PipeTileLayout.mask_description(mask)
	button.pressed.connect(_on_slot_selected.bind(tile_name))
	row.add_child(button)

	var coord := Label.new()
	coord.custom_minimum_size.x = 62
	coord.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(coord)

	var clear := Button.new()
	clear.text = "x"
	clear.tooltip_text = "Clear this slot."
	clear.pressed.connect(_on_slot_cleared.bind(tile_name))
	row.add_child(clear)

	_rows[tile_name] = {"button": button, "thumb": thumb, "coord": coord}
	return row


func _build_picker_panel() -> Control:
	_picker_holder = ScrollContainer.new()
	_picker_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker_holder.add_child(center)

	_picker = PipeAtlasPicker.new()
	_picker.tile_picked.connect(_on_tile_picked)
	_picker.tile_hovered.connect(_on_tile_hovered)
	center.add_child(_picker)

	return _picker_holder


func _build_bottom_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_status)

	_hover_label = Label.new()
	_hover_label.custom_minimum_size.x = 110
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_hover_label)

	_hover_preview = TextureRect.new()
	_hover_preview.custom_minimum_size = Vector2(40, 40)
	_hover_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hover_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hover_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.add_child(_hover_preview)

	return bar

#endregion


#region Population

func setup(config: PipeTileConfig, tile_set: TileSet) -> void:
	_config = config
	_tile_set = tile_set
	_populate_sources()
	_select_first_unassigned()
	_refresh_all()


func _populate_sources() -> void:
	_source_option.clear()
	if _tile_set == null:
		return

	var selected_index := 0
	for index in _tile_set.get_source_count():
		var id := _tile_set.get_source_id(index)
		if _tile_set.get_source(id) is not TileSetAtlasSource:
			continue
		_source_option.add_item("Source %d" % id)
		_source_option.set_item_metadata(_source_option.item_count - 1, id)
		if id == _config.source_id:
			selected_index = _source_option.item_count - 1

	if _source_option.item_count > 0:
		_source_option.select(selected_index)
		_config.source_id = int(_source_option.get_item_metadata(selected_index))


func _current_source() -> TileSetAtlasSource:
	if _tile_set == null or not _tile_set.has_source(_config.source_id):
		return null
	return _tile_set.get_source(_config.source_id) as TileSetAtlasSource


func _thumbnail_for(coords: Vector2i) -> Texture2D:
	var source := _current_source()
	if source == null or source.texture == null or coords == PipeTileConfig.UNSET:
		return null
	if not source.has_tile(coords):
		return null
	var thumb := AtlasTexture.new()
	thumb.atlas = source.texture
	thumb.region = Rect2(source.get_tile_texture_region(coords))
	thumb.filter_clip = true
	return thumb


func _refresh_all() -> void:
	var source := _current_source()
	_picker.source = source
	_picker.zoom = _zoom_slider.value
	_picker.assigned = _config.coord_to_name()
	_picker.highlight = _config.get_coord(_active_slot) if not _active_slot.is_empty() else PipeAtlasPicker.NONE

	for tile_name: String in _rows:
		var row: Dictionary = _rows[tile_name]
		var coord := _config.get_coord(tile_name)
		var thumb: TextureRect = row["thumb"]
		var coord_label: Label = row["coord"]
		var button: Button = row["button"]

		thumb.texture = _thumbnail_for(coord)
		if coord == PipeTileConfig.UNSET:
			coord_label.text = "--"
			coord_label.modulate = Color(1, 0.6, 0.5)
		elif thumb.texture == null:
			coord_label.text = str(coord)
			coord_label.modulate = Color(1, 0.6, 0.5)
		else:
			coord_label.text = str(coord)
			coord_label.modulate = Color(1, 1, 1, 0.8)

		button.set_pressed_no_signal(tile_name == _active_slot)

	var assigned := _config.assigned_count()
	var total := _config.slot_count()
	if source == null:
		_status.text = "No atlas source on this TileSet"
		_status.modulate = Color(1, 0.6, 0.5)
	elif assigned < total:
		_status.text = "%d / %d assigned -- select a slot, then click its tile" % [assigned, total]
		_status.modulate = Color(1, 0.8, 0.45)
	else:
		_status.text = "All %d shapes assigned" % total
		_status.modulate = Color(0.6, 1, 0.7)

#endregion


#region Interaction

func _select_first_unassigned() -> void:
	for tile_name: String in PipeTileLayout.NAME_TO_MASK:
		if not _config.has_coord(tile_name):
			_active_slot = tile_name
			return
	_active_slot = PipeTileLayout.NAME_TO_MASK.keys()[0]


func _advance_from(tile_name: String) -> void:
	if not _auto_advance.button_pressed:
		return
	var names := PipeTileLayout.NAME_TO_MASK.keys()
	var start := names.find(tile_name)
	for step in range(1, names.size() + 1):
		var candidate: String = names[(start + step) % names.size()]
		if not _config.has_coord(candidate):
			_active_slot = candidate
			return


func _on_slot_selected(tile_name: String) -> void:
	_active_slot = tile_name
	_refresh_all()


func _on_slot_cleared(tile_name: String) -> void:
	_config.clear_coord(tile_name)
	_config.save()
	_active_slot = tile_name
	_refresh_all()
	config_changed.emit()


func _on_tile_picked(coords: Vector2i) -> void:
	if _active_slot.is_empty():
		return
	_config.set_coord(_active_slot, coords)
	_config.save()
	_advance_from(_active_slot)
	_refresh_all()
	config_changed.emit()


func _on_tile_hovered(coords: Vector2i) -> void:
	if coords == PipeAtlasPicker.NONE:
		_hover_label.text = ""
		_hover_preview.texture = null
		return
	_hover_label.text = str(coords)
	_hover_preview.texture = _thumbnail_for(coords)


func _on_source_selected(index: int) -> void:
	_config.source_id = int(_source_option.get_item_metadata(index))
	_config.save()
	_refresh_all()
	config_changed.emit()


func _on_zoom_changed(_value: float) -> void:
	_refresh_all()

#endregion
