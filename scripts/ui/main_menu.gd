extends Control

@export var sfx_start_button: AudioStream

@onready var _start_button: Button = $MenuRoot/StartButton
@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _start_sfx_player: AudioStreamPlayer = $StartSFX

func _screen_fx() -> CanvasLayer:
	return get_node_or_null("/root/ScreenFX") as CanvasLayer

func _ready() -> void:
	GameState.reset_for_main_menu()
	var screen_fx := _screen_fx()
	if screen_fx != null:
		screen_fx.set_gameplay_filter_enabled(false)
	if _start_button != null:
		_start_button.grab_focus()
	if _anim_player != null:
		_anim_player.play("pulse")
	if _start_sfx_player != null and sfx_start_button != null:
		_start_sfx_player.stream = sfx_start_button

func _on_start_pressed() -> void:
	if _start_button != null:
		_start_button.disabled = true
	if _anim_player != null:
		_anim_player.stop()
	if _start_sfx_player != null:
		if sfx_start_button != null and _start_sfx_player.stream != sfx_start_button:
			_start_sfx_player.stream = sfx_start_button
		if _start_sfx_player.stream != null:
			_start_sfx_player.pitch_scale = randf_range(0.98, 1.02)
			_start_sfx_player.play()
	var screen_fx := _screen_fx()
	if screen_fx != null:
		await screen_fx.boot_to_scene("res://scenes/world/world.tscn", true)
	else:
		get_tree().change_scene_to_file("res://scenes/world/world.tscn")
