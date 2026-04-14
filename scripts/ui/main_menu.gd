extends Control

func _ready() -> void:
	GameState.reset_level_index()
	GameState.reset_world_state()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
