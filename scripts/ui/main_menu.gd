extends Control

@onready var _start_button: Button = $MenuRoot/StartButton
@onready var _anim_player: AnimationPlayer = $AnimationPlayer

func _screen_fx() -> CanvasLayer:
	return get_node_or_null("/root/ScreenFX") as CanvasLayer

func _ready() -> void:
	GameState.reset_level_index()
	GameState.reset_world_state()
	GameState.reset_progression()
	var screen_fx := _screen_fx()
	if screen_fx != null:
		screen_fx.set_gameplay_filter_enabled(false)
	if _start_button != null:
		_start_button.grab_focus()
	if _anim_player != null:
		_anim_player.play("pulse")

func _on_start_pressed() -> void:
	if _anim_player != null:
		_anim_player.stop()
	var screen_fx := _screen_fx()
	if screen_fx != null:
		await screen_fx.boot_to_scene("res://scenes/world/world.tscn", true)
	else:
		get_tree().change_scene_to_file("res://scenes/world/world.tscn")
