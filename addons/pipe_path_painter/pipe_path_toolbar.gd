@tool
extends HBoxContainer

## Viewport toolbar strip for the pipe path painter.

signal enabled_changed(enabled: bool)
signal configure_requested

var paint_enabled: bool:
	get: return _toggle != null and _toggle.button_pressed

var join_ends: bool:
	get: return _join == null or _join.button_pressed

var _toggle: CheckButton
var _extras: HBoxContainer
var _join: CheckBox
var _configure: Button
var _hint: Label
var _status: Label


func _init() -> void:
	add_theme_constant_override("separation", 6)

	_toggle = CheckButton.new()
	_toggle.text = "Pipe Path"
	_toggle.tooltip_text = (
		"LMB drag paints a path, RMB drag erases one.\n"
		+ "Hold Shift for a straight A-to-B line, Alt to run that line\n"
		+ "vertically first instead of horizontally.\n"
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

	_hint = Label.new()
	_hint.text = "Shift = line  |  Alt = vertical first"
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.modulate = Color(1, 1, 1, 0.5)
	_extras.add_child(_hint)

	_extras.add_child(VSeparator.new())

	_join = CheckBox.new()
	_join.text = "Join ends"
	_join.button_pressed = true
	_join.tooltip_text = (
		"When a path starts or stops next to an existing pipe, connect them\n"
		+ "instead of leaving two stubs facing each other."
	)
	_extras.add_child(_join)

	_configure = Button.new()
	_configure.text = "Configure Tiles..."
	_configure.tooltip_text = "Assign the 15 pipe shapes by clicking them in the atlas."
	_configure.pressed.connect(func() -> void: configure_requested.emit())
	_extras.add_child(_configure)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_extras.add_child(_status)

	_update_collapsed_state()


## Used when the rectangle painter claims the viewport, so two tools can't
## fight over the same drag.
func force_disable() -> void:
	if _toggle.button_pressed:
		_toggle.set_pressed_no_signal(false)
		_update_collapsed_state()


func set_status(text: String, is_warning: bool = false) -> void:
	_status.text = text
	_status.modulate = Color(1, 0.62, 0.45) if is_warning else Color(1, 1, 1, 0.7)


func _on_toggled(pressed: bool) -> void:
	_update_collapsed_state()
	enabled_changed.emit(pressed)


func _update_collapsed_state() -> void:
	# Guarded: a script hot-reload can fire signals on an instance whose
	# fields haven't been rebuilt yet, since _init doesn't re-run.
	if _extras != null:
		_extras.visible = paint_enabled
