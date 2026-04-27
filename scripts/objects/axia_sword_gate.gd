extends Node3D

@export var duration: float = 0.95

@onready var _ring: MeshInstance3D = $Ring
@onready var _disc: MeshInstance3D = $Disc
@onready var _flare: MeshInstance3D = $Flare
@onready var _light: OmniLight3D = $Light

var _elapsed: float = 0.0

func configure(duration_value: float) -> void:
	duration = duration_value

func _ready() -> void:
	scale = Vector3(0.01, 0.01, 0.01)

func _physics_process(delta: float) -> void:
	if GameState.is_paused or GameState.rewind_mode_active or GameState.time_direction != 1 or GameState.is_scrubbing_past:
		return
	_elapsed += delta
	var ratio: float = clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var ease_in: float = sin(ratio * PI * 0.5)
	var ease_out: float = sin((1.0 - ratio) * PI * 0.5)
	var envelope: float = min(ease_in, ease_out * 1.15)
	scale = Vector3.ONE * maxf(0.01, envelope)
	rotate_y(delta * 2.8)
	if _flare != null:
		_flare.rotate_y(-delta * 4.2)
	if _light != null:
		_light.light_energy = 0.8 + envelope * 3.6
	if _ring != null:
		_ring.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.08)
	if _disc != null:
		_disc.scale = Vector3(1.0 + envelope * 0.28, 1.0, 1.0 + envelope * 0.28)
	if ratio >= 1.0:
		queue_free()
