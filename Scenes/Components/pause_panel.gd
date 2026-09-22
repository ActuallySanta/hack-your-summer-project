class_name PausePanel extends Node2D

const SCROLL_BAR_SIZE := 26

@onready var text_display := $TextDisplay
@onready var click_box := $ClickBox
@onready var scroll_interactable := $ScrollInteractable

func _ready() -> void:
	click_box.on_mouse_held.connect( on_mouse_hold )
	text_display.draw_scroll_bar(Vector2i(29, SCROLL_BAR_SIZE), TextElement.Axis.Vertical, SCROLL_BAR_SIZE, 1000)
	scroll_interactable.on_mouse_pressed.connect( func(): click_box.was_pressed = true )

func _process(_delta: float) -> void:
	pass

func on_mouse_hold() -> void:
	text_display.draw_scroll_bar(Vector2i(29, SCROLL_BAR_SIZE), TextElement.Axis.Vertical, SCROLL_BAR_SIZE, text_display._get_scroll_bar_quarters_from_percent(SCROLL_BAR_SIZE, 1 - click_box.get_mouse_percent().y))
 
