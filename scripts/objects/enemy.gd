extends CharacterBody3D

@export var move_speed: float = 2.0
@export var patrol_distance: float = 3.0
@export var detection_range: float = 20.0
@export var fire_cooldown: float = 1.4
@export var laser_duration: float = 0.12
@export var laser_damage: float = 18.0
@export var hover_height: float = 1.2

@onready var _visual_root: Node3D = $VisualRoot
@onready var _laser_beam: MeshInstance3D = $LaserBeam
@onready var _laser_light: OmniLight3D = $LaserLight
@onready var _muzzle: Node3D = $VisualRoot/Muzzle

var _direction: int = 1
var _traveled: float = 0.0
var _fire_timer: float = 0.0
var _laser_timer: float = 0.0
var _player: CharacterBody3D

func _ready() -> void:
	add_to_group("time_actor")
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _laser_beam != null:
		_laser_beam.visible = false
	if _laser_light != null:
		_laser_light.visible = false

func _physics_process(delta: float) -> void:
	if GameState.is_paused or GameState.time_direction != 1 or GameState.is_scrubbing_past or GameState.rewind_mode_active:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_update_visuals(delta)
	_update_laser(delta)
	if _player != null and global_position.distance_to(_player.global_position) <= detection_range:
		_track_and_fire(delta)
	else:
		_patrol(delta)
	move_and_slide()

func _patrol(delta: float) -> void:
	var step: float = move_speed * float(_direction) * delta
	_traveled += absf(step)
	velocity = transform.basis.x * move_speed * float(_direction)
	if _traveled >= patrol_distance:
		_traveled = 0.0
		_direction *= -1

func _track_and_fire(delta: float) -> void:
	velocity = Vector3.ZERO
	var target: Vector3 = _player.global_position + Vector3(0.0, 1.0, 0.0)
	look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP)
	_fire_timer = maxf(0.0, _fire_timer - delta)
	if _fire_timer > 0.0:
		return
	var from: Vector3 = _muzzle.global_position if _muzzle != null else global_position + Vector3.UP * hover_height
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, target)
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	var hit_position: Vector3 = hit.get("position", target)
	_show_laser(from, hit_position)
	_fire_timer = fire_cooldown
	if collider == _player or (collider is Node and _player.is_ancestor_of(collider as Node)):
		if _player.has_method("take_damage"):
			_player.call("take_damage", laser_damage)

func _show_laser(from: Vector3, to: Vector3) -> void:
	if _laser_beam == null:
		return
	var distance: float = from.distance_to(to)
	_laser_beam.visible = true
	_laser_beam.global_position = from.lerp(to, 0.5)
	_laser_beam.look_at(to, Vector3.UP)
	_laser_beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_laser_beam.scale = Vector3(1.0, distance * 0.5, 1.0)
	if _laser_light != null:
		_laser_light.visible = true
		_laser_light.global_position = to
	_laser_timer = laser_duration

func _update_laser(delta: float) -> void:
	if _laser_timer <= 0.0:
		return
	_laser_timer = maxf(0.0, _laser_timer - delta)
	if _laser_timer > 0.0:
		return
	if _laser_beam != null:
		_laser_beam.visible = false
	if _laser_light != null:
		_laser_light.visible = false

func _update_visuals(delta: float) -> void:
	if _visual_root == null:
		return
	_visual_root.position.y = hover_height + sin(Time.get_ticks_msec() * 0.004 + global_position.z) * 0.18
	_visual_root.rotate_y(delta * 0.9)
