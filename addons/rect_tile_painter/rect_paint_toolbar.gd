@tool
extends HBoxContainer

## Toolbar strip shown in the 2D viewport whenever a TileMapLayer is selected.
## Owns nothing but UI state; the plugin reads these properties.

signal enabled_changed(enabled: bool)
signal region_changed(source_id: int, region_origin: Vector2i)
signal mode_changed(summation: bool)
signal preset_save_requested(preset_name: String)
signal preset_delete_requested(preset_name: String)

const RectRegionInfo := preload("res://addons/rect_tile_painter/rect_region_info.gd")

## Item 0 of the preset dropdown is a placeholder, never a real preset.
const PRESET_PLACEHOLDER := "Presets"

var paint_enabled: bool:
	get: return _toggle != null and _toggle.button_pressed

## Summation mode: drags edit one shared shape instead of stamping rects.
var summation_enabled: bool:
	get: return _sum_toggle != null and _sum_toggle.button_pressed

var source_id: int:
	get: return int(_source_spin.value) if _source_spin != null else 0

var region_origin: Vector2i:
	get:
		if _origin_x == null:
			return Vector2i.ZERO
		return Vector2i(int(_origin_x.value), int(_origin_y.value))

## "" means "pick procedurally". Anything else forces every cell in the rect
## to that named tile -- for eyeballing that the dictionary is right. Only
## honoured in basic mode; summation mode has to pick per cell.
var forced_tile_name: String:
	get:
		if _tile_option == null or _tile_option.selected <= 0 or summation_enabled:
			return ""
		return _tile_option.get_item_text(_tile_option.selected)

var _toggle: CheckButton
var _sum_toggle: CheckButton
var _extras: HBoxContainer
var _source_spin: SpinBox
var _origin_x: SpinBox
var _origin_y: SpinBox
var _info: RectRegionInfo
var _preset_option: OptionButton
var _preset_delete: Button
var _name_dialog: ConfirmationDialog
var _name_edit: LineEdit
var _tile_option: OptionButton
var _status: Label
var _suppress_signals := false

## name -> Vector3i(source_id, origin_x, origin_y), owned by the plugin.
var _presets: Dictionary[String, Vector3i] = {}


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

	# Everything past the toggle is hidden while the tool is off, so two of
	# these strips don't stretch the 2D viewport. The controls still exist, so
	# their values survive being switched off and back on.
	_extras = HBoxContainer.new()
	_extras.add_theme_constant_override("separation", 6)
	add_child(_extras)

	_sum_toggle = CheckButton.new()
	_sum_toggle.text = "Sum"
	_sum_toggle.tooltip_text = (
		"Summation mode: treat everything painted from this region as ONE shape.\n"
		+ "LMB drag adds a rectangle to it, RMB drag subtracts one, and the\n"
		+ "outline is re-tiled so overlaps merge instead of stacking.\n"
		+ "Off = the original behaviour: each drag stamps a raw rectangle."
	)
	_sum_toggle.toggled.connect(_on_mode_toggled)
	_extras.add_child(_sum_toggle)

	_extras.add_child(_make_separator())

	_extras.add_child(_make_label("Src", "TileSet source id the region lives in."))
	_source_spin = _make_spin(0, 4096, "Atlas source id.")
	_extras.add_child(_source_spin)

	_extras.add_child(_make_label("Region", "Atlas coord of the TOP-LEFT tile of the block."))
	_origin_x = _make_spin(0, 4096, "Region origin: X (in tiles).")
	_extras.add_child(_origin_x)
	_origin_y = _make_spin(0, 4096, "Region origin: Y (in tiles).")
	_extras.add_child(_origin_y)

	_info = RectRegionInfo.new()
	_extras.add_child(_info)

	_extras.add_child(_make_separator())

	# Presets: the point is jumping between two tilesheets fast, so this is a
	# dropdown plus save/delete rather than anything modal.
	_preset_option = OptionButton.new()
	_preset_option.tooltip_text = (
		"Saved source + region coords for this TileSet.\n"
		+ "Picking one applies it immediately, in either mode."
	)
	_preset_option.custom_minimum_size.x = 104
	_preset_option.item_selected.connect(_on_preset_selected)
	_extras.add_child(_preset_option)

	var preset_save := Button.new()
	preset_save.text = "+"
	preset_save.tooltip_text = "Save the current Src + Region under a name."
	preset_save.pressed.connect(_on_preset_save_pressed)
	_extras.add_child(preset_save)

	_preset_delete = Button.new()
	_preset_delete.text = "-"
	_preset_delete.tooltip_text = "Delete the selected preset."
	_preset_delete.pressed.connect(_on_preset_delete_pressed)
	_extras.add_child(_preset_delete)

	_name_dialog = ConfirmationDialog.new()
	_name_dialog.title = "Save region preset"
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Preset name"
	_name_edit.custom_minimum_size.x = 220
	_name_dialog.add_child(_name_edit)
	_name_dialog.register_text_enter(_name_edit)
	_name_dialog.confirmed.connect(_on_preset_name_confirmed)
	add_child(_name_dialog)

	_extras.add_child(_make_separator())

	_extras.add_child(_make_label("Tile", "Debug: force every painted cell to one named tile."))
	_tile_option = OptionButton.new()
	_tile_option.tooltip_text = (
		"Auto picks corners/edges/fill from the rect shape.\n"
		+ "Picking a name floods the whole rect with that one tile, so you can\n"
		+ "confirm the dictionary entry points where you think it does.\n"
		+ "Ignored in Sum mode, which has to decide per cell."
	)
	_tile_option.add_item("Auto")
	for tile_name in RectTileLayout.tile_names():
		_tile_option.add_item(tile_name)
	_tile_option.select(0)
	_extras.add_child(_tile_option)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.modulate = Color(1, 1, 1, 0.7)
	_extras.add_child(_status)

	_rebuild_preset_items()
	_update_collapsed_state()


## Push values in without re-emitting change signals.
func set_region(new_source_id: int, new_origin: Vector2i) -> void:
	_suppress_signals = true
	_source_spin.value = new_source_id
	_origin_x.value = new_origin.x
	_origin_y.value = new_origin.y
	_suppress_signals = false


func set_presets(new_presets: Dictionary[String, Vector3i]) -> void:
	_presets = new_presets
	_rebuild_preset_items()


## The atlas the (i) popover renders. Null is fine -- it draws empty slots.
func set_preview_source(source: TileSetAtlasSource) -> void:
	if _info != null:
		_info.describe(source, source_id, region_origin, summation_enabled)


## Used when the pipe path painter claims the viewport, so two tools can't
## fight over the same drag.
func force_disable() -> void:
	if _toggle.button_pressed:
		_toggle.set_pressed_no_signal(false)
		_update_collapsed_state()


func set_status(text: String, is_warning: bool = false) -> void:
	_status.text = text
	_status.modulate = Color(1, 0.55, 0.45) if is_warning else Color(1, 1, 1, 0.7)


func _on_toggled(pressed: bool) -> void:
	_update_collapsed_state()
	enabled_changed.emit(pressed)


func _on_mode_toggled(pressed: bool) -> void:
	# Forcing one tile everywhere is meaningless once the shape decides, so
	# the dropdown goes dim rather than silently lying about what it does.
	_tile_option.disabled = pressed
	mode_changed.emit(pressed)


func _on_region_spin_changed(_value: float) -> void:
	if _suppress_signals:
		return
	region_changed.emit(source_id, region_origin)


func _on_preset_selected(index: int) -> void:
	if index <= 0:
		return
	var preset_name := _preset_option.get_item_text(index)
	if not _presets.has(preset_name):
		return
	var stored: Vector3i = _presets[preset_name]
	set_region(stored.x, Vector2i(stored.y, stored.z))
	region_changed.emit(source_id, region_origin)


func _on_preset_save_pressed() -> void:
	_name_edit.text = ""
	if _preset_option.selected > 0:
		_name_edit.text = _preset_option.get_item_text(_preset_option.selected)
	_name_dialog.popup_centered()
	_name_edit.grab_focus()


func _on_preset_name_confirmed() -> void:
	var preset_name := _name_edit.text.strip_edges()
	if preset_name.is_empty() or preset_name == PRESET_PLACEHOLDER:
		return
	preset_save_requested.emit(preset_name)


func _on_preset_delete_pressed() -> void:
	if _preset_option.selected <= 0:
		return
	preset_delete_requested.emit(_preset_option.get_item_text(_preset_option.selected))


func _rebuild_preset_items() -> void:
	if _preset_option == null:
		return
	_preset_option.clear()
	_preset_option.add_item(PRESET_PLACEHOLDER)
	for preset_name in _presets:
		_preset_option.add_item(preset_name)
	_preset_option.select(0)
	_preset_option.disabled = _presets.is_empty()
	_preset_delete.disabled = _presets.is_empty()


func _update_collapsed_state() -> void:
	# Guarded: a script hot-reload can fire signals on an instance whose
	# fields haven't been rebuilt yet, since _init doesn't re-run.
	if _extras != null:
		_extras.visible = paint_enabled


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
