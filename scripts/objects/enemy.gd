extends CharacterBody3D

signal defeated(enemy: Node3D, defeat_position: Vector3)

@export var move_speed: float = 3.6
@export var patrol_distance: float = 3.0
@export var detection_range: float = 30.0
@export var shoot_range: float = 9.0
@export var preferred_attack_distance: float = 5.4
@export var fire_cooldown: float = 3.0
@export var charge_duration: float = 2.0
@export var prefire_delay: float = 1.0
@export var laser_duration: float = 0.18
@export var laser_damage: float = 18.0
@export var hover_height: float = 0.55
@export var hover_bob_amplitude: float = 0.12
@export var collision_vertical_offset: float = 0.86
@export var max_health: float = 50.0
@export var nav_min_x: float = -10.8
@export var nav_max_x: float = 10.8
@export var nav_min_z: float = -28.0
@export var nav_max_z: float = 166.0
@export var nav_cell_size: float = 1.6

@onready var _visual_root: Node3D = $VisualRoot
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _core: MeshInstance3D = $VisualRoot/Core
@onready var _shard_a: MeshInstance3D = $VisualRoot/ShardA
@onready var _shard_b: MeshInstance3D = $VisualRoot/ShardB
@onready var _shard_c: MeshInstance3D = $VisualRoot/ShardC
@onready var _laser_beam: MeshInstance3D = $LaserBeam
@onready var _target_beam: MeshInstance3D = $TargetBeam
@onready var _laser_light: OmniLight3D = $LaserLight
@onready var _muzzle: Node3D = $VisualRoot/Muzzle
@onready var _health_pivot: Node3D = $VisualRoot/HealthPivot
@onready var _health_fill: MeshInstance3D = $VisualRoot/HealthPivot/Fill
@onready var _health_back: MeshInstance3D = $VisualRoot/HealthPivot/Back

var _direction: int = 1
var _traveled: float = 0.0
var _fire_timer: float = 0.0
var _laser_timer: float = 0.0
var _player: CharacterBody3D
var _health: float = 50.0
var _charging_shot: bool = false
var _pending_shot: bool = false
var _charge_timer: float = 0.0
var _charge_hit_position: Vector3 = Vector3.ZERO
var _charge_hit_player: bool = false
var _flash_timer: float = 0.0
var _visual_materials: Array[StandardMaterial3D] = []
var _base_albedo_colors: Array[Color] = []
var _base_emission_colors: Array[Color] = []
var _base_emission_energies: Array[float] = []
var _spawn_position: Vector3 = Vector3.ZERO
var _navigation_grid: AStarGrid2D = AStarGrid2D.new()
var _navigation_path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _path_refresh_timer: float = 0.0
var _last_target_cell: Vector2i = Vector2i(999999, 999999)
var _spawn_animating: bool = false
var _spawn_anim_time: float = 0.0
var _spawn_anim_duration: float = 0.72

func _ready() -> void:
	add_to_group("time_actor")
	add_to_group("enemy")
	_spawn_position = global_position
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_health = max_health
	_build_navigation_grid()
	_cache_visual_materials()
	_update_health_bar()
	_sync_collision_with_visual()
	if _laser_beam != null:
		_laser_beam.visible = false
	if _target_beam != null:
		_target_beam.visible = false
	if _laser_light != null:
		_laser_light.visible = false
	if not visible:
		set_encounter_enabled(false)

func _physics_process(delta: float) -> void:
	if _spawn_animating:
		_process_spawn_animation(delta)
		_hide_attack_fx()
		return
	if GameState.is_paused or GameState.time_direction != 1 or GameState.is_scrubbing_past or GameState.rewind_mode_active:
		_hide_attack_fx()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_update_visuals(delta)
	_update_damage_flash(delta)
	_update_laser(delta)
	if _player != null and global_position.distance_to(_player.global_position) <= detection_range:
		_chase_and_fire(delta)
	else:
		_cancel_charge()
		_patrol(delta)
	move_and_slide()

func _patrol(delta: float) -> void:
	var step: float = move_speed * float(_direction) * delta
	_traveled += absf(step)
	velocity = transform.basis.x * move_speed * float(_direction)
	if _traveled >= patrol_distance:
		_traveled = 0.0
		_direction *= -1

func _chase_and_fire(delta: float) -> void:
	var target: Vector3 = _player.global_position + Vector3(0.0, 1.0, 0.0)
	look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP)
	var distance_to_player: float = global_position.distance_to(_player.global_position)
	var can_shoot: bool = distance_to_player <= shoot_range
	if can_shoot and _has_line_of_sight_to_player(target):
		velocity = Vector3.ZERO
		_track_and_fire(delta, target)
		return
	_cancel_charge()
	_follow_path_to_player(delta)

func _track_and_fire(delta: float, target: Vector3) -> void:
	velocity = Vector3.ZERO
	var from: Vector3 = _muzzle.global_position if _muzzle != null else global_position + Vector3.UP * hover_height
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, target)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_cancel_charge()
		return
	var collider: Variant = hit.get("collider")
	var hit_position: Vector3 = hit.get("position", target)
	var hits_player: bool = collider == _player or (collider is Node and _player.is_ancestor_of(collider as Node))
	_fire_timer = maxf(0.0, _fire_timer - delta)
	if _charging_shot:
		if not hits_player or global_position.distance_to(_player.global_position) > shoot_range:
			_cancel_charge()
			return
		_charge_timer = maxf(0.0, _charge_timer - delta)
		_charge_hit_position = hit_position
		_charge_hit_player = hits_player
		_show_target_line(from, _charge_hit_position)
		if _charge_timer > 0.0:
			return
		_charging_shot = false
		_pending_shot = true
		_charge_timer = prefire_delay
		if _target_beam != null:
			_target_beam.visible = false
		return
	if _pending_shot:
		if global_position.distance_to(_player.global_position) > shoot_range or not hits_player:
			_cancel_charge()
			return
		_charge_timer = maxf(0.0, _charge_timer - delta)
		if _charge_timer > 0.0:
			return
		_pending_shot = false
		_show_laser(from, _charge_hit_position)
		_fire_timer = fire_cooldown
		if _charge_hit_player and _player.has_method("take_damage"):
			_player.call("take_damage", laser_damage)
		return
	if _fire_timer > 0.0:
		return
	if not hits_player:
		return
	_charging_shot = true
	_pending_shot = false
	_charge_timer = charge_duration
	_charge_hit_position = hit_position
	_charge_hit_player = hits_player
	_show_target_line(from, _charge_hit_position)

func _show_laser(from: Vector3, to: Vector3) -> void:
	if _laser_beam == null:
		return
	_laser_beam.visible = true
	_place_beam(_laser_beam, from, to, 0.12)
	if _laser_light != null:
		_laser_light.visible = true
		_laser_light.global_position = to
	_laser_timer = laser_duration

func _show_target_line(from: Vector3, to: Vector3) -> void:
	if _target_beam == null:
		return
	_target_beam.visible = true
	_place_beam(_target_beam, from, to, 0.06)

func _place_beam(beam: MeshInstance3D, from: Vector3, to: Vector3, thickness: float) -> void:
	var direction: Vector3 = to - from
	var distance: float = direction.length()
	if distance <= 0.001:
		beam.visible = false
		return
	direction /= distance
	var up_axis: Vector3 = Vector3.UP
	if absf(direction.dot(up_axis)) > 0.98:
		up_axis = Vector3.FORWARD
	var basis: Basis = Basis.looking_at(direction, up_axis)
	beam.global_transform = Transform3D(basis, from)
	beam.scale = Vector3(thickness, thickness, distance)
	beam.global_position = from.lerp(to, 0.5)

func _follow_path_to_player(delta: float) -> void:
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) <= preferred_attack_distance:
		velocity = Vector3.ZERO
		return
	_move_directly_toward(_player.global_position)

func _move_directly_toward(target_position: Vector3) -> void:
	var flat_target: Vector3 = Vector3(target_position.x, global_position.y, target_position.z)
	var direction: Vector3 = flat_target - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		velocity = Vector3.ZERO
		return
	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

func _refresh_navigation_path() -> void:
	if _player == null:
		return
	var start_cell: Vector2i = _world_to_cell(global_position)
	var end_cell: Vector2i = _world_to_cell(_player.global_position)
	_last_target_cell = end_cell
	_path_refresh_timer = 0.35
	if not _is_cell_walkable(start_cell) or not _is_cell_walkable(end_cell):
		_navigation_path = PackedVector2Array()
		_path_index = 0
		return
	_navigation_path = _navigation_grid.get_point_path(start_cell, end_cell)
	_path_index = 0

func _build_navigation_grid() -> void:
	var min_cell_x: int = int(floor(nav_min_x / nav_cell_size))
	var max_cell_x: int = int(ceil(nav_max_x / nav_cell_size))
	var min_cell_z: int = int(floor(nav_min_z / nav_cell_size))
	var max_cell_z: int = int(ceil(nav_max_z / nav_cell_size))
	_navigation_grid.region = Rect2i(min_cell_x, min_cell_z, max_cell_x - min_cell_x + 1, max_cell_z - min_cell_z + 1)
	_navigation_grid.cell_size = Vector2(nav_cell_size, nav_cell_size)
	_navigation_grid.offset = Vector2(nav_cell_size * 0.5, nav_cell_size * 0.5)
	_navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_navigation_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_navigation_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_navigation_grid.update()
	for x in range(min_cell_x, max_cell_x + 1):
		for z in range(min_cell_z, max_cell_z + 1):
			var cell: Vector2i = Vector2i(x, z)
			_navigation_grid.set_point_solid(cell, not _sample_walkable_cell(cell))

func _sample_walkable_cell(cell: Vector2i) -> bool:
	var sample_position: Vector3 = Vector3((float(cell.x) + 0.5) * nav_cell_size, global_position.y + 0.9, (float(cell.y) + 0.5) * nav_cell_size)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	query.position = sample_position
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hits: Array[Dictionary] = space_state.intersect_point(query, 8)
	for hit in hits:
		var collider = hit.get("collider")
		if collider == self:
			continue
		if collider is CharacterBody3D:
			continue
		return false
	return true

func _world_to_cell(world_position: Vector3) -> Vector2i:
	return Vector2i(int(floor(world_position.x / nav_cell_size)), int(floor(world_position.z / nav_cell_size)))

func _is_cell_walkable(cell: Vector2i) -> bool:
	if not _navigation_grid.is_in_boundsv(cell):
		return false
	return not _navigation_grid.is_point_solid(cell)

func _has_line_of_sight_to_player(target: Vector3) -> bool:
	var from: Vector3 = _muzzle.global_position if _muzzle != null else global_position + Vector3.UP * hover_height
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, target)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider = hit.get("collider")
	return collider == _player or (collider is Node and _player.is_ancestor_of(collider as Node))

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
	_visual_root.position.y = hover_height + sin(Time.get_ticks_msec() * 0.004 + global_position.z) * hover_bob_amplitude
	_visual_root.rotation.y = wrapf(_visual_root.rotation.y + delta * 0.9, 0.0, TAU)
	_sync_collision_with_visual()
	var current_camera: Camera3D = get_viewport().get_camera_3d()
	if _health_pivot != null and current_camera != null:
		_health_pivot.global_basis = Basis.looking_at(
			(current_camera.global_position - _health_pivot.global_position).normalized(),
			Vector3.UP
		)

func take_damage(amount: float) -> void:
	_health = maxf(0.0, _health - amount)
	_flash_timer = 0.22
	_update_health_bar()
	if _health > 0.0:
		return
	emit_signal("defeated", self, global_position)
	queue_free()

func set_encounter_enabled(enabled: bool) -> void:
	visible = enabled
	process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if enabled:
		_spawn_animating = true
		_spawn_anim_time = 0.0
		if _collision_shape != null:
			_collision_shape.disabled = true
		if _visual_root != null:
			_visual_root.scale = Vector3(0.08, 0.08, 0.08)
	else:
		_spawn_animating = false
		if _collision_shape != null:
			_collision_shape.disabled = true
	if not enabled:
		velocity = Vector3.ZERO
		_hide_attack_fx()

func reset_enemy_state() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_direction = 1
	_traveled = 0.0
	_path_index = 0
	_path_refresh_timer = 0.0
	_navigation_path = PackedVector2Array()
	_last_target_cell = Vector2i(999999, 999999)
	_fire_timer = 0.0
	_laser_timer = 0.0
	_charge_timer = 0.0
	_charging_shot = false
	_pending_shot = false
	_flash_timer = 0.0
	_health = max_health
	_spawn_animating = false
	_spawn_anim_time = 0.0
	_update_health_bar()
	if _visual_root != null:
		_visual_root.scale = Vector3.ONE
		_visual_root.rotation = Vector3.ZERO
		_visual_root.position.y = hover_height
	_sync_collision_with_visual()
	_hide_attack_fx()

func _cache_visual_materials() -> void:
	_visual_materials.clear()
	_base_albedo_colors.clear()
	_base_emission_colors.clear()
	_base_emission_energies.clear()
	for mesh in [_core, _shard_a, _shard_b, _shard_c]:
		if mesh == null:
			continue
		var source: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		if source == null:
			continue
		var duplicate_material: StandardMaterial3D = source.duplicate() as StandardMaterial3D
		mesh.material_override = duplicate_material
		_visual_materials.append(duplicate_material)
		_base_albedo_colors.append(duplicate_material.albedo_color)
		_base_emission_colors.append(duplicate_material.emission)
		_base_emission_energies.append(duplicate_material.emission_energy_multiplier)

func _update_damage_flash(delta: float) -> void:
	if _visual_materials.is_empty():
		return
	_flash_timer = maxf(0.0, _flash_timer - delta)
	var flash_ratio: float = _flash_timer / 0.22
	for index in range(_visual_materials.size()):
		var material: StandardMaterial3D = _visual_materials[index]
		var base_albedo: Color = _base_albedo_colors[index]
		var base_emission: Color = _base_emission_colors[index]
		var base_energy: float = _base_emission_energies[index]
		material.albedo_color = base_albedo.lerp(Color(1.0, 0.1, 0.16, base_albedo.a), flash_ratio)
		material.emission = base_emission.lerp(Color(1.0, 0.08, 0.12, 1.0), flash_ratio)
		material.emission_energy_multiplier = lerpf(base_energy, base_energy + 3.6, flash_ratio)

func _update_health_bar() -> void:
	var ratio: float = 0.0 if max_health <= 0.0 else clampf(_health / max_health, 0.0, 1.0)
	if _health_fill != null:
		var fill_transform := _health_fill.transform
		fill_transform.basis = Basis().scaled(Vector3(maxf(0.001, ratio), 1.0, 1.0))
		fill_transform.origin.x = -0.45 + ratio * 0.45
		_health_fill.transform = fill_transform
		_health_fill.visible = true
	if _health_back != null:
		_health_back.visible = true

func _cancel_charge() -> void:
	_charging_shot = false
	_charge_timer = 0.0
	_pending_shot = false
	if _target_beam != null:
		_target_beam.visible = false

func _hide_attack_fx() -> void:
	_cancel_charge()
	if _laser_beam != null:
		_laser_beam.visible = false
	if _laser_light != null:
		_laser_light.visible = false

func _process_spawn_animation(delta: float) -> void:
	_spawn_anim_time += delta
	var ratio: float = 1.0
	if _spawn_anim_duration > 0.0:
		ratio = clampf(_spawn_anim_time / _spawn_anim_duration, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - ratio, 3.0)
	var jitter: float = (1.0 - ratio) * 0.2
	if _visual_root != null:
		_visual_root.position.y = hover_height + sin(Time.get_ticks_msec() * 0.004 + global_position.z) * hover_bob_amplitude
		var random_scale: float = eased + randf_range(-jitter, jitter)
		random_scale = maxf(random_scale, 0.05)
		_visual_root.scale = Vector3(random_scale, random_scale, random_scale)
		_visual_root.rotation.x = randf_range(-0.22, 0.22) * (1.0 - ratio)
		_visual_root.rotation.z = randf_range(-0.22, 0.22) * (1.0 - ratio)
	_sync_collision_with_visual()
	_update_spawn_material_flash(1.0 - ratio)
	if ratio < 1.0:
		return
	_spawn_animating = false
	if _visual_root != null:
		_visual_root.scale = Vector3.ONE
		_visual_root.rotation = Vector3.ZERO
	_update_spawn_material_flash(0.0)
	if _collision_shape != null:
		_collision_shape.disabled = false

func _sync_collision_with_visual() -> void:
	if _collision_shape == null or _visual_root == null:
		return
	_collision_shape.position.y = _visual_root.position.y + collision_vertical_offset

func _update_spawn_material_flash(strength: float) -> void:
	if _visual_materials.is_empty():
		return
	var clamped_strength: float = clampf(strength, 0.0, 1.0)
	for index in range(_visual_materials.size()):
		var material: StandardMaterial3D = _visual_materials[index]
		var base_albedo: Color = _base_albedo_colors[index]
		var base_emission: Color = _base_emission_colors[index]
		var base_energy: float = _base_emission_energies[index]
		var emission_boost: float = clamped_strength * (4.2 + randf() * 2.2)
		material.albedo_color = base_albedo.lerp(Color(0.9, 0.2, 1.0, base_albedo.a), clamped_strength * 0.55)
		material.emission = base_emission.lerp(Color(1.0, 0.18, 0.94, 1.0), clamped_strength)
		material.emission_energy_multiplier = base_energy + emission_boost
