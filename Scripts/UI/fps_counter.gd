extends Label


var average : float
var current : float
var fps_min : float = INF
var fps_max : float = -INF

func _process(_delta: float) -> void:
	var delta = RealDelta.get_delta()
	if Input.is_action_just_pressed("ToggleFPSCounter", true):
		visible = not visible
		fps_min = INF
		fps_max = -INF
	if not visible:
		return

	average = Engine.get_frames_per_second()
	var new_curr = 1 / delta
	current = new_curr
	fps_min = min(fps_min, current)
	fps_max = max(fps_max, current)
	text = "FPS: (Current: %d, Max: %d, Avg: %d, Min %d)" % [current, fps_max, average, fps_min]
	var text_color : Color
	if current >= 120:
		text_color = Color.GREEN
	elif current >= 100:
		text_color = Color.GREEN_YELLOW
	elif current >= 60:
		text_color = Color.YELLOW
	elif current >= 30:
		text_color = Color.ORANGE
	else:
		text_color = Color.RED
	self_modulate = text_color
