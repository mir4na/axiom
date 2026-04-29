extends AnimatableBody3D

enum PlatformMode {
	STATIC,
	MOVING,
	ROTATING,
	DISAPPEARING
}

@export var platform_mode: PlatformMode = PlatformMode.STATIC
@export var active_on_forward: bool = true
@export var active_on_rewind: bool = true
@export var move_axis: Vector3 = Vector3(1.0, 0.0, 0.0)
@export var move_distance: float = 4.0
@export var move_speed: float = 1.2
@export var rotate_axis: Vector3 = Vector3.UP
@export var rotate_speed_deg: float = 45.0
@export var disappear_delay: float = 0.2
@export var reappear_delay: float = 0.0

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _trigger_area: Area3D = $StepTrigger

var _time: float = 0.0
var _base_position: Vector3 = Vector3.ZERO
var _base_basis: Basis = Basis.IDENTITY
var _active: bool = true
var _hidden: bool = false
var _disappear_started: bool = false

func _ready() -> void:
	_base_position = global_position
	_base_basis = global_transform.basis
	if _trigger_area != null:
		_trigger_area.body_entered.connect(_on_trigger_body_entered)
	GameState.time_direction_changed.connect(_on_time_direction_changed)
	_apply_state(GameState.time_direction)

func _physics_process(delta: float) -> void:
	if not _active or _hidden:
		return
	if GameState.is_time_blocked():
		return
	var direction_sign: float = 1.0
	if GameState.time_direction != GameState.TIME_FORWARD:
		direction_sign = -1.0
	_time += delta * direction_sign
	if platform_mode == PlatformMode.MOVING:
		var axis: Vector3 = move_axis
		if axis.length_squared() <= 0.0001:
			axis = Vector3.RIGHT
		var offset: Vector3 = axis.normalized() * sin(_time * move_speed) * move_distance
		global_position = _base_position + offset
		global_transform = Transform3D(_base_basis, global_position)
	elif platform_mode == PlatformMode.ROTATING:
		var axis: Vector3 = rotate_axis
		if axis.length_squared() <= 0.0001:
			axis = Vector3.UP
		var basis: Basis = _base_basis * Basis(axis.normalized(), deg_to_rad(_time * rotate_speed_deg))
		global_transform = Transform3D(basis, _base_position)
	else:
		global_transform = Transform3D(_base_basis, _base_position)

func _on_time_direction_changed(direction: int) -> void:
	_apply_state(direction)

func _apply_state(direction: int) -> void:
	if direction == GameState.TIME_FORWARD:
		_active = active_on_forward
	else:
		_active = active_on_rewind
	_sync_visibility()

func _sync_visibility() -> void:
	var enabled: bool = _active and not _hidden
	if _collision != null:
		_collision.disabled = not enabled
	if _mesh != null:
		_mesh.visible = enabled
	if _trigger_area != null:
		var can_monitor: bool = enabled and platform_mode == PlatformMode.DISAPPEARING and not _disappear_started
		_trigger_area.monitoring = can_monitor
		_trigger_area.monitorable = can_monitor

func _on_trigger_body_entered(body: Node) -> void:
	if platform_mode != PlatformMode.DISAPPEARING:
		return
	if _disappear_started or _hidden:
		return
	if body == null or not body.is_in_group("player"):
		return
	_start_disappear_sequence()

func _start_disappear_sequence() -> void:
	_disappear_started = true
	_sync_visibility()
	if disappear_delay > 0.0:
		get_tree().create_timer(disappear_delay).timeout.connect(_on_disappear_timeout, CONNECT_ONE_SHOT)
	else:
		_on_disappear_timeout()

func _on_disappear_timeout() -> void:
	if not is_inside_tree():
		return
	_hidden = true
	_sync_visibility()
	if reappear_delay > 0.0:
		get_tree().create_timer(reappear_delay).timeout.connect(_on_reappear_timeout, CONNECT_ONE_SHOT)

func _on_reappear_timeout() -> void:
	if not is_inside_tree():
		return
	_hidden = false
	_disappear_started = false
	_sync_visibility()
