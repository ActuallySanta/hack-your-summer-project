@tool
extends HBoxContainer

## Toolbar strip shown in the 2D viewport whenever a TileMapLayer is selected.
## Owns nothing but UI state; the plugin reads these properties.

signal enabled_changed(enabled: bool)
signal region_changed(source_id: int, region_origin: Vector2i)

var paint_enabled: bool:
	get: return _toggle != null and _toggle.button_pressed

var source_id: int:
	get: return int(_source_spin.value) if _source_spin != null else 0

var region_origin: Vector2i:
	get:
		if _origin_x == null:
			return Vector2i.ZERO
		return Vector2i(int(_origin_x.value), int(_origin_y.value))

## "" means "pick procedurally". Anything else forces every cell in the rect
## to that named tile -- for eyeballing that the dictionary is right.
var forced_tile_name: String:
	get:
		if _tile_option == null or _tile_option.selected <= 0:
			return ""
		return _tile_option.get_item_text(_tile_option.selected)

var _toggle: CheckButton
var _source_spin: SpinBox
var _origin_x: SpinBox
var _origin_y: SpinBox
var _tile_option: OptionButton
var _status: Label
var _suppress_signals := false


func _init() -> void:
	add_theme_constant_override("separation", 6)

	_toggle = CheckButton.new()
	_toggle.text = "Rect Paint"
	_toggle.tooltip_text = (
		"Drag with LMB to fill a rectangle, RMB to erase one.\n"
		+ "While this is on, normal tile painting in the viewport is suspended."
	)
	_toggle.toggled.connect(_on_toggled)
	add_child(_toggle)

	add_child(_make_separator())

	add_child(_make_label("Src", "TileSet source id the 4x4 region lives in."))
	_source_spin = _make_spin(0, 4096, "Atlas source id.")
	add_child(_source_spin)

	add_child(_make_label("Region", "Atlas coord of the TOP-LEFT tile of the 4x4 block."))
	_origin_x = _make_spin(0, 4096, "4x4 region origin: X (in tiles).")
	add_child(_origin_x)
	_origin_y = _make_spin(0, 4096, "4x4 region origin: Y (in tiles).")
	add_child(_origin_y)

	add_child(_make_separator())

	add_child(_make_label("Tile", "Debug: force every painted cell to one named tile."))
	_tile_option = OptionButton.new()
	_tile_option.tooltip_text = (
		"Auto picks corners/edges/fill from the rect shape.\n"
		+ "Picking a name floods the whole rect with that one tile, so you can\n"
		+ "confirm the dictionary entry points where you think it does."
	)
	_tile_option.add_item("Auto")
	for tile_name in RectTileLayout.tile_names():
		_tile_option.add_item(tile_name)
	_tile_option.select(0)
	add_child(_tile_option)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.modulate = Color(1, 1, 1, 0.7)
	add_child(_status)

	_update_disabled_state()


## Push values in without re-emitting change signals.
func set_region(new_source_id: int, new_origin: Vector2i) -> void:
	_suppress_signals = true
	_source_spin.value = new_source_id
	_origin_x.value = new_origin.x
	_origin_y.value = new_origin.y
	_suppress_signals = false


## Used when the pipe path painter claims the viewport, so two tools can't
## fight over the same drag.
func force_disable() -> void:
	if _toggle.button_pressed:
		_toggle.set_pressed_no_signal(false)
		_update_disabled_state()


func set_status(text: String, is_warning: bool = false) -> void:
	_status.text = text
	_status.modulate = Color(1, 0.55, 0.45) if is_warning else Color(1, 1, 1, 0.7)


func _on_toggled(pressed: bool) -> void:
	_update_disabled_state()
	enabled_changed.emit(pressed)


func _on_region_spin_changed(_value: float) -> void:
	if _suppress_signals:
		return
	region_changed.emit(source_id, region_origin)


func _update_disabled_state() -> void:
	var off := not paint_enabled
	_source_spin.editable = not off
	_origin_x.editable = not off
	_origin_y.editable = not off
	_tile_option.disabled = off


func _make_label(text: String, tooltip: String) -> Label:
	var label := Label.new()
	label.text = text
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label


func _make_spin(min_value: float, max_value: float, tooltip: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1
	spin.tooltip_text = tooltip
	spin.custom_minimum_size.x = 56
	spin.value_changed.connect(_on_region_spin_changed)
	return spin


func _make_separator() -> VSeparator:
	return VSeparator.new()
