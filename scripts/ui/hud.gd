extends CanvasLayer

const TAPE_SPEED := 0.4

@onready var _state_label: Label = $Container/StateLabel
@onready var _time_label: Label = $Container/TimeLabel
@onready var _reality_label: Label = $Container/RealityLabel
@onready var _tape_bar: ProgressBar = $Container/TapeBar

var _tape_value: float = 50.0

func _ready() -> void:
	GameState.time_direction_changed.connect(_on_time_direction_changed)
	GameState.world_scaled.connect(_on_world_scaled)
	_refresh_state()

func _process(delta: float) -> void:
	if GameState.time_direction == GameState.TIME_REWIND:
		_tape_value -= TAPE_SPEED * delta * 60.0
	else:
		_tape_value += TAPE_SPEED * delta * 60.0
	_tape_value = clampf(_tape_value, 0.0, 100.0)
	_tape_bar.value = _tape_value

func _refresh_state() -> void:
	_state_label.text = "STATE: STATIC"
	_update_time_label(GameState.time_direction)
	_reality_label.text = "REALITY: STABLE"

func _on_time_direction_changed(direction: int) -> void:
	_update_time_label(direction)
	_reality_label.text = "REALITY: UNSTABLE"

func _update_time_label(direction: int) -> void:
	if direction == GameState.TIME_FORWARD:
		_time_label.text = "TIME: FORWARD"
	else:
		_time_label.text = "TIME: REWINDING"

func _on_world_scaled(_scale_factor: float) -> void:
	_reality_label.text = "REALITY: UNSTABLE"
