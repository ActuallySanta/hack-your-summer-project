extends CanvasLayer


signal OnLoadingScreenReady
@export var animPlayer :AnimationPlayer

func _ready() -> void:
	await animPlayer.animation_finished
	OnLoadingScreenReady.emit()

func _OnProgressChanged(_newVal : float) -> void:
	pass

func _OnLoadFinished() -> void:
	animPlayer.play_backwards("loadingScreen_Transition")
	await animPlayer.animation_finished
	queue_free()
	pass
