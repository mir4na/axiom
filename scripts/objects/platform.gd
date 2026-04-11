extends StaticBody3D

@export var active_on_forward: bool = true
@export var active_on_rewind: bool = true

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	GameState.time_direction_changed.connect(_on_time_direction_changed)
	_apply_state(GameState.time_direction)

func _on_time_direction_changed(direction: int) -> void:
	_apply_state(direction)

func _apply_state(direction: int) -> void:
	var active: bool
	if direction == GameState.TIME_FORWARD:
		active = active_on_forward
	else:
		active = active_on_rewind
	_collision.disabled = not active
	_mesh.visible = active
