extends Node3D

signal health_changed(current: float, maximum: float)
signal defeated

const SWORD_PROJECTILE_SCENE := preload("res://scenes/objects/axia_sword_projectile.tscn")
const SWORD_GATE_SCENE := preload("res://scenes/objects/axia_sword_gate.tscn")
const FALL_ATTACK_SCENE := preload("res://scenes/objects/axia_fall_attack.tscn")
const LIGHT_SNARE_SCENE := preload("res://scenes/objects/axia_light_snare.tscn")

@export var max_health: float = 300.0
@export var attack_interval: float = 8.0
@export var encounter_start_cooldown: float = 2.6
@export var gravity_strength: float = 21.0
@export var ground_height: float = 0.0
@export var death_fall_target_local_y: float = -0.08
@export var death_fall_gravity_multiplier: float = 1.45
@export var death_dim_duration_cap: float = 0.8
@export var death_dim_duration_ratio: float = 0.55
@export var death_visual_scale_multiplier: float = 0.94
@export var death_dissolve_duration: float = 2.2
@export var death_dissolve_self_scale_multiplier: float = 0.82
@export var death_dissolve_visual_scale_multiplier: float = 0.64
@export var death_ash_cleanup_delay: float = 0.3
@export var min_die_animation_duration: float = 0.9
@export var ash_spawn_height_offset: float = 1.0
@export var idle_hover_base: float = 0.2
@export var idle_hover_amplitude: float = 0.08
@export var idle_hover_speed: float = 0.0018
@export var aura_ring_base_scale: float = 0.95
@export var aura_ring_pulse_amplitude: float = 0.06
@export var aura_ring_pulse_speed: float = 0.0022
@export var aura_ring_rotation_speed: float = 0.7
@export var aura_light_base_energy: float = 1.5
@export var aura_light_pulse_amplitude: float = 0.3
@export var aura_light_pulse_speed: float = 0.002
@export var wind_pulse_light_color: Color = Color(0.22, 0.48, 0.28, 1.0)

@onready var _rose: CharacterBody3D = $Rose
@onready var _visual_root: Node3D = $VisualRoot
@onready var _aura_ring: MeshInstance3D = $VisualRoot/AuraRing
@onready var _wind_disc: MeshInstance3D = $VisualRoot/WindDisc
@onready var _aura_light: OmniLight3D = $VisualRoot/AuraLight
@onready var _projectile_root: Node3D = $ProjectileRoot
@onready var _snare_root: Node3D = $SnareRoot
@onready var _launchers: Node3D = $Launchers
@onready var _ash_anchor: Marker3D = $AshEffectAnchor
@onready var _ash_effect: GPUParticles3D = $AshEffect

var _player: CharacterBody3D
var _health: float = 0.0
var _encounter_active: bool = false
var _attack_running: bool = false
var _cooldown_left: float = 0.0
var _attack_cycle_index: int = 0
var _defeated: bool = false
var _vertical_velocity: float = 0.0
var _death_in_progress: bool = false
var _death_falling: bool = false
var _death_fall_velocity: float = 0.0
var _rose_initial_local_position: Vector3 = Vector3.ZERO
var _visual_root_initial_position: Vector3 = Vector3.ZERO
var _visual_root_initial_scale: Vector3 = Vector3.ONE
var _aura_ring_initial_scale: Vector3 = Vector3.ONE
var _wind_disc_initial_scale: Vector3 = Vector3.ONE
var _aura_light_initial_energy: float = 0.0
var _self_initial_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	_health = max_health
	_emit_health()
	_wind_disc.visible = false
	visible = false
	_self_initial_scale = scale
	if _rose != null:
		_rose_initial_local_position = _rose.position
	if _visual_root != null:
		_visual_root_initial_position = _visual_root.position
		_visual_root_initial_scale = _visual_root.scale
	if _aura_ring != null:
		_aura_ring_initial_scale = _aura_ring.scale
	if _wind_disc != null:
		_wind_disc_initial_scale = _wind_disc.scale
	if _aura_light != null:
		_aura_light_initial_energy = _aura_light.light_energy
	if _rose != null and _rose.has_method("play_idle"):
		_rose.call("play_idle")
	if _ash_effect != null:
		_ash_effect.emitting = false
	_set_visual_transparency(0.0)

func begin_encounter(player_ref: CharacterBody3D) -> void:
	_player = player_ref
	_encounter_active = true
	_cooldown_left = encounter_start_cooldown
	_attack_running = false
	_attack_cycle_index = 0

func take_damage(amount: float) -> void:
	if _defeated or _death_in_progress:
		return
	_health = maxf(0.0, _health - amount)
	_emit_health()
	if _health <= 0.0:
		_defeat()

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_update_death_fall(delta)
	if _defeated:
		return
	_update_idle_visual(delta)
	if not _encounter_active:
		return
	if GameState.is_paused or GameState.rewind_mode_active or GameState.time_direction != 1 or GameState.is_scrubbing_past:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		return
	_face_player(delta)
	if _attack_running:
		return
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _cooldown_left > 0.0:
		return
	_start_next_attack()

func _update_idle_visual(delta: float) -> void:
	if _visual_root != null:
		_visual_root.position.y = idle_hover_base + sin(Time.get_ticks_msec() * idle_hover_speed) * idle_hover_amplitude
	if _aura_ring != null:
		var ring_scale_factor: float = aura_ring_base_scale + sin(Time.get_ticks_msec() * aura_ring_pulse_speed) * aura_ring_pulse_amplitude
		_aura_ring.scale = _aura_ring_initial_scale * ring_scale_factor
		_aura_ring.rotate_y(delta * aura_ring_rotation_speed)
	if _aura_light != null:
		_aura_light.light_energy = aura_light_base_energy + sin(Time.get_ticks_msec() * aura_light_pulse_speed) * aura_light_pulse_amplitude

func _face_player(delta: float) -> void:
	if _player == null:
		return
	var target_position: Vector3 = _player.global_position
	var flat_target: Vector3 = Vector3(target_position.x, global_position.y, target_position.z)
	var direction: Vector3 = flat_target - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, delta * 2.2)

func _start_next_attack() -> void:
	_attack_running = true
	var attack_names: Array[String] = ["wind", "swords", "meteor", "snare"]
	var attack_name: String = attack_names[_attack_cycle_index % attack_names.size()]
	_attack_cycle_index += 1
	call_deferred("_run_attack_sequence", attack_name)

func _run_attack_sequence(attack_name: String) -> void:
	match attack_name:
		"wind":
			await _perform_wind_pulse()
		"swords":
			await _perform_sword_volley()
		"meteor":
			await _perform_meteor_rain()
		"snare":
			await _perform_light_snare()
	_attack_running = false
	_cooldown_left = attack_interval

func _perform_wind_pulse() -> void:
	if _wind_disc == null:
		return
	var original_light_color: Color = Color(1.0, 0.9, 0.74, 1.0)
	if _aura_light != null:
		original_light_color = _aura_light.light_color
		_aura_light.light_color = wind_pulse_light_color
	await _play_cast_surge(0.56, 4.8)
	_wind_disc.visible = true
	_wind_disc.scale = Vector3(_wind_disc_initial_scale.x * 0.45, _wind_disc_initial_scale.y, _wind_disc_initial_scale.z * 0.45)
	var charge: Tween = create_tween().set_parallel(true)
	charge.tween_property(_wind_disc, "scale", Vector3(3.6, 1.0, 3.6), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	charge.parallel().tween_property(_aura_light, "light_energy", 5.8, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await charge.finished
	_apply_wind_damage()
	var blast: Tween = create_tween().set_parallel(true)
	blast.tween_property(_wind_disc, "scale", Vector3(26.0, 1.0, 26.0), 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	blast.parallel().tween_property(_aura_light, "light_energy", 2.0, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await blast.finished
	_wind_disc.visible = false
	_wind_disc.scale = _wind_disc_initial_scale
	if _aura_light != null:
		_aura_light.light_color = original_light_color

func _apply_wind_damage() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var distance: float = global_position.distance_to(_player.global_position)
	if distance > 26.0:
		return
	if _player.has_method("take_damage"):
		_player.call("take_damage", 20.0)
	if _player.has_method("apply_knockback"):
		var direction: Vector3 = (_player.global_position - global_position).normalized()
		_player.call("apply_knockback", direction, 110.0, 8.4)

func _perform_sword_volley() -> void:
	if _launchers == null or _player == null:
		return
	await _play_cast_surge(0.48, 4.2)
	var markers: Array[Marker3D] = []
	for marker in _launchers.get_children():
		if marker is Marker3D:
			markers.append(marker as Marker3D)
	for marker in markers:
		var gate: Node3D = SWORD_GATE_SCENE.instantiate() as Node3D
		if gate == null:
			continue
		_projectile_root.add_child(gate)
		gate.global_position = marker.global_position
		gate.look_at(global_position + Vector3.UP * 2.4, Vector3.UP)
		if gate.has_method("configure"):
			gate.call("configure", 1.05)
	await get_tree().create_timer(0.88).timeout
	for marker in markers:
		if not (marker is Marker3D):
			continue
		var projectile: Area3D = SWORD_PROJECTILE_SCENE.instantiate() as Area3D
		if projectile == null:
			continue
		_projectile_root.add_child(projectile)
		projectile.global_position = (marker as Marker3D).global_position
		var target_position: Vector3 = _player.global_position + Vector3(
			randf_range(-5.8, 5.8),
			randf_range(0.45, 2.2),
			randf_range(-5.8, 5.8)
		)
		var direction: Vector3 = (target_position - projectile.global_position).normalized()
		projectile.call("configure", direction, 7.2, 10.0, _player)
		await get_tree().create_timer(0.16).timeout

func _perform_meteor_rain() -> void:
	if _player == null:
		return
	await _play_cast_surge(0.7, 4.8)
	var rain_duration: float = 8.0
	var spawn_interval: float = 0.28
	var elapsed: float = 0.0
	while elapsed < rain_duration:
		if GameState.is_paused or GameState.rewind_mode_active or GameState.time_direction != 1 or GameState.is_scrubbing_past:
			await get_tree().process_frame
			continue
		for burst_index in range(2):
			var attack: Node3D = FALL_ATTACK_SCENE.instantiate() as Node3D
			if attack == null:
				continue
			_projectile_root.add_child(attack)
			var offset: Vector3 = Vector3(randf_range(-9.4, 9.4), 0.0, randf_range(-9.4, 9.4))
			var target_position: Vector3 = Vector3(_player.global_position.x, 0.08, _player.global_position.z) + offset
			var warning_time: float = randf_range(0.55, 1.05)
			var fall_time: float = randf_range(1.05, 1.55)
			var meteor_size: float = randf_range(0.95, 1.3)
			attack.call("configure_attack", target_position, _player, 40.0, 2.35, warning_time, fall_time, true, meteor_size)
		var wait_time: float = maxf(0.2, spawn_interval + randf_range(-0.05, 0.08))
		await get_tree().create_timer(wait_time).timeout
		elapsed += wait_time

func _perform_light_snare() -> void:
	if _player == null:
		return
	await _play_cast_surge(0.75, 5.4)
	var snare: Area3D = LIGHT_SNARE_SCENE.instantiate() as Area3D
	if snare == null:
		return
	_snare_root.add_child(snare)
	snare.global_position = Vector3(_player.global_position.x, 0.08, _player.global_position.z)
	snare.call("configure", _player, 1.25, 50.0, 2.2)
	await get_tree().create_timer(1.9).timeout

func _play_cast_surge(duration: float, light_target: float) -> void:
	if _aura_ring == null or _aura_light == null:
		return
	var start_scale: Vector3 = _aura_ring.scale
	var surge: Tween = create_tween().set_parallel(true)
	surge.tween_property(_aura_ring, "scale", start_scale * 1.36, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	surge.parallel().tween_property(_aura_light, "light_energy", light_target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await surge.finished
	var settle: Tween = create_tween().set_parallel(true)
	settle.tween_property(_aura_ring, "scale", _aura_ring_initial_scale, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	settle.parallel().tween_property(_aura_light, "light_energy", _aura_light_initial_energy, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await settle.finished

func _defeat() -> void:
	if _death_in_progress:
		return
	_death_in_progress = true
	_defeated = true
	_encounter_active = false
	_attack_running = false
	for child in _projectile_root.get_children():
		child.queue_free()
	for child in _snare_root.get_children():
		child.queue_free()
	if _player != null and is_instance_valid(_player) and _player.has_method("set_mobility_lock"):
		_player.call("set_mobility_lock", false)
	await _play_death_sequence()
	emit_signal("defeated")
	queue_free()

func _emit_health() -> void:
	emit_signal("health_changed", _health, max_health)

func set_manifested(active: bool) -> void:
	visible = active
	if not active:
		return
	_vertical_velocity = 0.0
	_death_fall_velocity = 0.0
	_death_falling = false
	_death_in_progress = false
	if _rose != null:
		_rose.position = _rose_initial_local_position
	if _visual_root != null:
		_visual_root.position = _visual_root_initial_position
		_visual_root.scale = _visual_root_initial_scale
	if _aura_ring != null:
		_aura_ring.scale = _aura_ring_initial_scale
	if _wind_disc != null:
		_wind_disc.scale = _wind_disc_initial_scale
		_wind_disc.visible = false
	scale = _self_initial_scale
	_set_visual_transparency(0.0)
	if _aura_light != null:
		_aura_light.light_energy = _aura_light_initial_energy
	if _ash_effect != null:
		_ash_effect.emitting = false

func play_idle() -> void:
	if _rose != null and _rose.has_method("play_idle"):
		_rose.call("play_idle")

func play_move() -> void:
	if _rose != null and _rose.has_method("play_move"):
		_rose.call("play_move", false)

func _apply_gravity(delta: float) -> void:
	var current_position: Vector3 = global_position
	if current_position.y <= ground_height + 0.001:
		current_position.y = ground_height
		_vertical_velocity = 0.0
		global_position = current_position
		return
	_vertical_velocity -= gravity_strength * delta
	current_position.y += _vertical_velocity * delta
	if current_position.y <= ground_height:
		current_position.y = ground_height
		_vertical_velocity = 0.0
	global_position = current_position

func _update_death_fall(delta: float) -> void:
	if not _death_falling:
		return
	if _rose == null:
		_death_falling = false
		return
	_death_fall_velocity += gravity_strength * death_fall_gravity_multiplier * delta
	var next_y: float = _rose.position.y - (_death_fall_velocity * delta)
	if next_y <= death_fall_target_local_y:
		next_y = death_fall_target_local_y
		_death_falling = false
	_rose.position.y = next_y

func _play_death_sequence() -> void:
	if _wind_disc != null:
		_wind_disc.visible = false
	if _rose != null and _rose.has_method("play_die"):
		_rose.call("play_die")
	var die_duration: float = _get_die_animation_duration()
	var dim: Tween = create_tween().set_parallel(true)
	if _aura_light != null:
		dim.tween_property(_aura_light, "light_energy", 0.0, minf(death_dim_duration_cap, die_duration * death_dim_duration_ratio)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _visual_root != null:
		dim.tween_property(_visual_root, "scale", _visual_root_initial_scale * death_visual_scale_multiplier, minf(death_dim_duration_cap, die_duration * death_dim_duration_ratio)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(die_duration).timeout
	_death_falling = true
	_death_fall_velocity = 0.0
	while _death_falling:
		await get_tree().physics_frame
	if _ash_effect != null:
		if _ash_anchor != null:
			_ash_effect.global_position = _ash_anchor.global_position
		else:
			var ash_position: Vector3 = global_position
			ash_position.y += ash_spawn_height_offset
			_ash_effect.global_position = ash_position
		_ash_effect.restart()
		_ash_effect.emitting = true
	var dissolve: Tween = create_tween().set_parallel(true)
	dissolve.tween_method(_set_visual_transparency, 0.0, 1.0, death_dissolve_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dissolve.parallel().tween_property(self, "scale", _self_initial_scale * death_dissolve_self_scale_multiplier, death_dissolve_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _visual_root != null:
		dissolve.parallel().tween_property(_visual_root, "scale", _visual_root_initial_scale * death_dissolve_visual_scale_multiplier, death_dissolve_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await dissolve.finished
	if _ash_effect != null:
		await get_tree().create_timer(death_ash_cleanup_delay).timeout
		_ash_effect.emitting = false

func _get_die_animation_duration() -> float:
	if _rose == null:
		return 1.35
	var die_node: Node = _rose.get_node_or_null("Motions/Die")
	if die_node == null:
		return 1.35
	var animation_player: AnimationPlayer = _find_animation_player(die_node)
	if animation_player == null:
		return 1.35
	var animation_list: PackedStringArray = animation_player.get_animation_list()
	if animation_list.is_empty():
		return 1.35
	var animation: Animation = animation_player.get_animation(animation_list[0])
	if animation == null:
		return 1.35
	return maxf(min_die_animation_duration, animation.length)

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _set_visual_transparency(value: float) -> void:
	var clamped_value: float = clampf(value, 0.0, 1.0)
	_apply_transparency_recursive(self, clamped_value)

func _apply_transparency_recursive(node: Node, value: float) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		mesh_node.transparency = value
	for child in node.get_children():
		_apply_transparency_recursive(child, value)
