extends Node3D

@onready var _world_container: Node3D = $WorldContainer
@onready var _pause_menu: Control = $PauseMenu
@onready var _win_screen: Control = $WinScreen

var _current_level: Node3D

func _ready() -> void:
	GameState.level_completed.connect(_on_level_completed)
	GameState.paused.connect(_on_paused)
	_pause_menu.hide()
	_win_screen.hide()
	_load_current_level()

func _load_current_level() -> void:
	if _current_level:
		_current_level.queue_free()
		_current_level = null
	GameState.reset_world_state()
	var path: String = GameState.LEVELS[GameState.current_level_index]
	var scene: PackedScene = load(path)
	_current_level = scene.instantiate()
	_world_container.add_child(_current_level)

func _on_level_completed() -> void:
	_win_screen.show()

func _on_paused(state: bool) -> void:
	if state:
		_pause_menu.show()
	else:
		_pause_menu.hide()

func go_to_next_level() -> void:
	_win_screen.hide()
	if GameState.has_next_level():
		GameState.advance_level()
		_load_current_level()
	else:
		go_to_main_menu()

func restart_level() -> void:
	GameState.unpause()
	_pause_menu.hide()
	_win_screen.hide()
	_load_current_level()

func go_to_main_menu() -> void:
	GameState.unpause()
	GameState.reset_level_index()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
