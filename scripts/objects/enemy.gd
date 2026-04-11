extends CharacterBody3D

@export var move_speed: float = 2.0
@export var patrol_distance: float = 3.0

var _direction: int = 1
var _traveled: float = 0.0

func _ready() -> void:
	add_to_group("time_actor")

func _physics_process(delta: float) -> void:
	if GameState.is_paused or GameState.time_direction != 1 or GameState.is_scrubbing_past:
		return
		
	var step: float = move_speed * float(_direction) * delta
	_traveled += absf(step)

	velocity = transform.basis.x * move_speed * float(_direction)
	if _traveled >= patrol_distance:
		_traveled = 0.0
		_direction *= -1

	move_and_slide()
