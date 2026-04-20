extends Node

const ROTATION_SENSITIVITY := 0.3

var _gs: Node

func _ready() -> void:
	_gs = get_node("/root/GameState")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ESCAPE:
				_gs.toggle_pause()

	if _gs.is_paused:
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_gs.emit_rotation(motion.relative * ROTATION_SENSITIVITY)
