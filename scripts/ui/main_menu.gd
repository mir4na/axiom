extends Control

func _screen_fx() -> CanvasLayer:
	return get_node_or_null("/root/ScreenFX") as CanvasLayer

func _ready() -> void:
	GameState.reset_level_index()
	GameState.reset_world_state()
	var screen_fx := _screen_fx()
	if screen_fx != null:
		screen_fx.set_gameplay_filter_enabled(false)

func _on_play_pressed() -> void:
	var screen_fx := _screen_fx()
	if screen_fx != null:
		await screen_fx.boot_to_scene("res://scenes/world/world.tscn", true)
	else:
		get_tree().change_scene_to_file("res://scenes/world/world.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
