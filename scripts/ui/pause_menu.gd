extends Control

@onready var _main: Node3D = get_tree().get_first_node_in_group("main")

func _on_resume_pressed() -> void:
	GameState.toggle_pause()

func _on_restart_pressed() -> void:
	var main := get_tree().get_first_node_in_group("main") as Node3D
	if main and main.has_method("restart_level"):
		main.restart_level()

func _on_main_menu_pressed() -> void:
	var main := get_tree().get_first_node_in_group("main") as Node3D
	if main and main.has_method("go_to_main_menu"):
		main.go_to_main_menu()
