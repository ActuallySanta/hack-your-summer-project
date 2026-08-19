@abstract
class_name Door extends Node2D

func _ready() -> void:
	setup()

	if should_be_opened_check():
		immediate_open()

## Runs code at _ready() before checking should_be_opened_check()
func setup() -> void:
	pass

@abstract
func should_be_opened_check() -> bool

@abstract
func immediate_open() -> void

@abstract
func animate_open() -> void
