extends CharacterBody3D

signal defeated(enemy: Node3D, defeat_position: Vector3)

@export var shoot_range: float = 20.0
@export var fire_cooldown: float = 5.0
@export var laser_duration: float = 0.2
@export var laser_damage: float = 18.0
@export var hover_height: float = 0.46
@export var hover_bob_amplitude: float = 0.08
@export var collision_vertical_offset: float = 0.86
@export var max_health: float = 90.0
@export var laser_color: Color = Color(0.24, 1.0, 0.42, 0.95)
@export var laser_light_color: Color = Color(0.36, 1.0, 0.58, 1.0)
@export var laser_thickness: float = 0.085

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

var _player: CharacterBody3D
var _spawn_position: Vector3 = Vector3.ZERO
var _anchor_position: Vector3 = Vector3.ZERO
var _health: float = 90.0
var _fire_timer: float = 0.0
var _laser_timer: float = 0.0
var _time: float = 0.0
var _dying: bool = false
var _spawn_animating: bool = false
var _spawn_anim_time: float = 0.0
var _spawn_anim_duration: float = 0.55
var _flash_timer: float = 0.0
var _visual_materials: Array[StandardMaterial3D] = []
var _base_albedo_colors: Array[Color] = []
var _base_emission_colors: Array[Color] = []
var _base_emission_energies: Array[float] = []

func _ready() -> void:
	add_to_group("time_actor")
	add_to_group("enemy")
	_spawn_position = global_position
	_anchor_position = global_position
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_health = max_health
	_cache_visual_materials()
	_setup_laser_visual()
	_update_health_bar()
	_sync_collision_with_visual()
	_hide_attack_fx()
	if not visible:
		set_encounter_enabled(false)

func _physics_process(delta: float) -> void:
	if _dying:
		_hide_attack_fx()
		return
	_time += delta
	if _spawn_animating:
		_process_spawn_animation(delta)
		_hide_attack_fx()
		return
	if GameState.is_time_blocked():
		_hide_attack_fx()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_update_visuals(delta)
	global_position = _anchor_position
	_update_damage_flash(delta)
	_update_laser(delta)
	_fire_timer = maxf(0.0, _fire_timer - delta)
	if _player == null:
		return
	var target_position: Vector3 = _player.global_position + Vector3(0.0, 1.0, 0.0)
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player > shoot_range:
		return
	look_at(Vector3(target_position.x, global_position.y, target_position.z), Vector3.UP)
	if _fire_timer > 0.0:
		return
	_fire_direct(target_position)

func _fire_direct(target_position: Vector3) -> void:
	var from: Vector3 = _muzzle.global_position if _muzzle != null else global_position + Vector3.UP * hover_height
	_show_laser(from, target_position)
	_fire_timer = fire_cooldown
	if _player != null and is_instance_valid(_player) and _player.has_method("take_damage"):
		_player.call("take_damage", laser_damage)

func _show_laser(from: Vector3, to: Vector3) -> void:
	if _laser_beam == null:
		return
	_laser_beam.visible = true
	_place_beam(_laser_beam, from, to, laser_thickness)
	if _laser_light != null:
		_laser_light.visible = true
		_laser_light.light_color = laser_light_color
		_laser_light.global_position = to
	_laser_timer = laser_duration

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

func _update_visuals(_delta: float) -> void:
	if _visual_root == null:
		return
	_visual_root.position.y = hover_height + sin(_time * 2.3 + global_position.z * 0.4) * hover_bob_amplitude
	_visual_root.rotation.y = wrapf(_visual_root.rotation.y + 0.012, 0.0, TAU)
	_sync_collision_with_visual()
	var current_camera: Camera3D = get_viewport().get_camera_3d()
	if _health_pivot != null and current_camera != null:
		_health_pivot.global_basis = Basis.looking_at(
			(current_camera.global_position - _health_pivot.global_position).normalized(),
			Vector3.UP
		)

func take_damage(amount: float) -> void:
	if _dying:
		return
	_health = maxf(0.0, _health - amount)
	_flash_timer = 0.22
	_update_health_bar()
	if _health > 0.0:
		return
	_dying = true
	if _collision_shape != null:
		_collision_shape.disabled = true
	velocity = Vector3.ZERO
	_hide_attack_fx()
	await _play_defeat_sequence()
	emit_signal("defeated", self, global_position)
	queue_free()

func set_encounter_enabled(enabled: bool) -> void:
	visible = enabled
	process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if enabled:
		_spawn_animating = true
		_spawn_anim_time = 0.0
		_fire_timer = 0.0
		if _collision_shape != null:
			_collision_shape.disabled = true
		if _visual_root != null:
			_visual_root.scale = Vector3(0.08, 0.08, 0.08)
	else:
		_spawn_animating = false
		if _collision_shape != null:
			_collision_shape.disabled = true
		velocity = Vector3.ZERO
		_hide_attack_fx()

func reset_enemy_state() -> void:
	_dying = false
	set_physics_process(true)
	global_position = _spawn_position
	_anchor_position = _spawn_position
	velocity = Vector3.ZERO
	_fire_timer = 0.0
	_laser_timer = 0.0
	_flash_timer = 0.0
	_time = 0.0
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

func _setup_laser_visual() -> void:
	if _laser_beam != null:
		var beam_mat := _laser_beam.material_override as StandardMaterial3D
		if beam_mat != null:
			var m := beam_mat.duplicate() as StandardMaterial3D
			m.albedo_color = laser_color
			_laser_beam.material_override = m
	if _target_beam != null:
		_target_beam.visible = false
	if _laser_light != null:
		_laser_light.light_color = laser_light_color

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
		material.albedo_color = base_albedo.lerp(Color(1.0, 0.08, 0.14, base_albedo.a), flash_ratio)
		material.emission = base_emission.lerp(Color(1.0, 0.1, 0.18, 1.0), flash_ratio)
		material.emission_energy_multiplier = lerpf(base_energy, base_energy + 3.2, flash_ratio)

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

func _hide_attack_fx() -> void:
	if _target_beam != null:
		_target_beam.visible = false
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
	var jitter: float = (1.0 - ratio) * 0.14
	if _visual_root != null:
		_visual_root.position.y = hover_height + sin(_time * 2.3 + global_position.z * 0.4) * hover_bob_amplitude
		var random_scale: float = eased + randf_range(-jitter, jitter)
		random_scale = maxf(random_scale, 0.05)
		_visual_root.scale = Vector3(random_scale, random_scale, random_scale)
		_visual_root.rotation.x = randf_range(-0.2, 0.2) * (1.0 - ratio)
		_visual_root.rotation.z = randf_range(-0.2, 0.2) * (1.0 - ratio)
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
	var clamped_strength := clampf(strength, 0.0, 1.0)
	for index in range(_visual_materials.size()):
		var material := _visual_materials[index]
		var base_albedo := _base_albedo_colors[index]
		var base_emission := _base_emission_colors[index]
		var base_energy := _base_emission_energies[index]
		var emission_boost := clamped_strength * (3.4 + randf() * 1.4)
		material.albedo_color = base_albedo.lerp(Color(0.7, 1.0, 0.82, base_albedo.a), clamped_strength * 0.48)
		material.emission = base_emission.lerp(Color(0.48, 1.0, 0.66, 1.0), clamped_strength)
		material.emission_energy_multiplier = base_energy + emission_boost

func _play_defeat_sequence() -> void:
	var explode: Tween = create_tween().set_parallel(true)
	if _visual_root != null:
		explode.tween_property(_visual_root, "scale", Vector3.ONE * 1.65, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		explode.tween_property(_visual_root, "rotation_degrees", _visual_root.rotation_degrees + Vector3(24.0, 190.0, -26.0), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		explode.tween_property(_visual_root, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.1)
	if _laser_light != null:
		explode.tween_property(_laser_light, "light_energy", 12.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		explode.tween_property(_laser_light, "omni_range", 7.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		explode.tween_property(_laser_light, "light_energy", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.08)
	for index in range(_visual_materials.size()):
		var material: StandardMaterial3D = _visual_materials[index]
		if material == null:
			continue
		var start_energy: float = material.emission_energy_multiplier
		explode.tween_method(_set_material_emission_energy.bind(material), start_energy, start_energy + 5.8, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		explode.tween_method(_set_material_emission_energy.bind(material), start_energy + 5.8, 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.1)
	await explode.finished

func _set_material_emission_energy(value: float, material: StandardMaterial3D) -> void:
	if material == null:
		return
	material.emission_energy_multiplier = value
