extends Interactable

signal dig_completed(spot: Node3D)

var dig_progress: float = 0.0
var is_digging: bool = false
var is_finished: bool = false

@export var sfx_burying: AudioStream

@onready var _bury_sfx: AudioStreamPlayer3D = $BurySFX

func _ready() -> void:
	prompt_text = "Hold E to bury"
	if _bury_sfx != null and sfx_burying != null:
		_bury_sfx.stream = sfx_burying
		_bury_sfx.autoplay = false

func get_equip_hint() -> String:
	return "Shovel"

func interact() -> void:
	pass

func progress_minigame(delta: float) -> float:
	if is_finished:
		return -1.0
	if GameState.slots[GameState.selected_slot] == "Shovel":
		if not is_digging:
			is_digging = true
			prompt_text = "Keep Holding E!"
			_play_bury_sfx()
			return 0.0
		else:
			dig_progress += 40.0 * delta # Takes 2.5 seconds of holding
			if dig_progress >= 100.0:
				_finish_dig()
			return dig_progress
	return -1.0

func _finish_dig() -> void:
	is_finished = true
	is_digging = false
	_stop_bury_sfx()
	prompt_text = ""
	dig_completed.emit(self)
	queue_free()

func reset_minigame() -> void:
	if is_digging and not is_finished:
		is_digging = false
		_stop_bury_sfx()
		dig_progress = 0.0
		prompt_text = "Hold E to bury"

func _play_bury_sfx() -> void:
	if _bury_sfx == null:
		return
	if sfx_burying != null and _bury_sfx.stream != sfx_burying:
		_bury_sfx.stream = sfx_burying
	if _bury_sfx.stream == null:
		return
	if not _bury_sfx.playing:
		_bury_sfx.pitch_scale = randf_range(0.98, 1.02)
		_bury_sfx.play()

func _stop_bury_sfx() -> void:
	if _bury_sfx == null:
		return
	if _bury_sfx.playing:
		_bury_sfx.stop()
