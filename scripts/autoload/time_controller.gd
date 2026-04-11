extends Node

const ROTATION_SENSITIVITY := 0.3

var _gs: Node

func _ready() -> void:
	_gs = get_node("/root/GameState")

func _process(_delta: float) -> void:
	if _gs.is_paused: return
	
	# Handle time scrubbing continuously based on input holds
	if Input.is_key_pressed(KEY_R):
		_gs.set_time_direction(_gs.TIME_REWIND)
	elif Input.is_key_pressed(KEY_F):
		# Assuming 2 is Fast Forward, or you can just use TIME_FORWARD but maybe x2 speed in visual effect?
		# For now, we will simulate Fast-Forward mechanically by multiplying time if the level supports it,
		# but AGENTS.md mentioned "rewind and fast-forward". So we can pass 2 for FF, and -1 for Rewind.
		_gs.set_time_direction(2) 
	else:
		_gs.set_time_direction(_gs.TIME_FORWARD)

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

	if event is InputEventMouseButton:
		var btn := event as InputEventMouseButton
		if btn.pressed:
			if btn.button_index == MOUSE_BUTTON_WHEEL_UP:
				_gs.apply_scale_delta(-_gs.SCALE_STEP)
			elif btn.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_gs.apply_scale_delta(_gs.SCALE_STEP)
