extends Node

signal OnProgressChanged(progress)
signal OnLoadComplete

var loadingScreen:PackedScene = preload("uid://dvefjkyxkgkqv")
var sceneToLoad: PackedScene
var scene_path:String
var progress:Array = []
var use_sub_threads: bool = false

func _ready() -> void:
	set_process(false)

func LoadScene(_scenePath : String)-> void:
	scene_path = _scenePath
	
	var loadScreenInstance = loadingScreen.instantiate()
	add_child(loadScreenInstance)
	OnProgressChanged.connect(loadScreenInstance._OnProgressChanged)
	OnLoadComplete.connect(loadScreenInstance._OnLoadFinished)
	
	await loadScreenInstance.OnLoadingScreenReady
	
	StartLoad()

func StartLoad() -> void:
	var state := ResourceLoader.load_threaded_request(scene_path,"",use_sub_threads)
	if(state == OK):
		set_process(true)

func _process(_delta: float) -> void:
	var loadStatus = ResourceLoader.load_threaded_get_status(scene_path,progress)
	OnProgressChanged.emit(progress[0])
	
	match  loadStatus:
		ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			set_process(false)
		ResourceLoader.THREAD_LOAD_LOADED:
			sceneToLoad = ResourceLoader.load_threaded_get(scene_path)
			get_tree().change_scene_to_packed(sceneToLoad)
			OnLoadComplete.emit()
