extends Node3D

signal health_changed(current: float, maximum: float)
signal defeated

const SWORD_PROJECTILE_SCENE := preload("res://scenes/objects/axia_sword_projectile.tscn")
const SWORD_GATE_SCENE := preload("res://scenes/objects/axia_sword_gate.tscn")
const FALL_ATTACK_SCENE := preload("res://scenes/objects/axia_fall_attack.tscn")
const LIGHT_SNARE_SCENE := preload("res://scenes/objects/axia_light_snare.tscn")
const SPATIAL_GLITCH_SHADER := preload("res://shaders/spatial_glitch.gdshader")

@export var max_health: float = 300.0
@export var attack_interval: float = 8.0
@export var enraged_attack_interval: float = 10.0
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
@export var wind_charge_duration: float = 2.15
@export var wind_charge_orb_count: int = 16
@export var wind_pulse_max_radius: float = 26.0
@export var wind_pulse_damage_min: float = 12.0
@export var wind_pulse_damage_max: float = 34.0
@export var wind_pulse_knockback_min: float = 72.0
@export var wind_pulse_knockback_max: float = 168.0
@export var wind_pulse_knockup_min: float = 5.2
@export var wind_pulse_knockup_max: float = 10.8
@export var sword_circle_count: int = 20
@export var sword_projectile_speed: float = 12.8
@export var sword_projectile_damage: float = 11.0
@export var facing_yaw_offset: float = PI
@export var first_wave_attack_order: Array[String] = ["wind", "swords", "meteor", "snare"]
@export var wave_teleport_min_radius: float = 4.0
@export var wave_teleport_edge_margin: float = 1.8
@export var wave_teleport_player_clearance: float = 4.8
@export var wave_teleport_glitch_duration: float = 0.34
@export var wave_teleport_fade_duration: float = 0.12
@export_group("Audio Placeholder")
@export var sfx_manifest: AudioStream
@export var sfx_teleport: AudioStream
@export var sfx_hurt: AudioStream
@export var sfx_defeat: AudioStream
@export var sfx_wind_charge: AudioStream
@export var sfx_wind_blast: AudioStream
@export var sfx_sword_summon: AudioStream
@export var sfx_sword_fire: AudioStream
@export var sfx_meteor_cast: AudioStream
@export var sfx_snare_cast: AudioStream

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
var _attack_wave_index: int = 0
var _attack_wave_queue: Array[String] = []
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
var _glitch_meshes: Array[MeshInstance3D] = []
var _glitch_overrides: Dictionary = {}
var _sfx_player: AudioStreamPlayer

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
	_collect_glitch_meshes(self)
	if _rose != null and _rose.has_method("play_idle"):
		_rose.call("play_idle")
	if _ash_effect != null:
		_ash_effect.emitting = false
	_setup_audio_player()
	_set_visual_transparency(0.0)

func _setup_audio_player() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "BossSFX"
	_sfx_player.bus = "Master"
	_sfx_player.autoplay = false
	add_child(_sfx_player)

func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	if _sfx_player == null or not is_instance_valid(_sfx_player):
		return
	_sfx_player.stream = stream
	_sfx_player.play()

func begin_encounter(player_ref: CharacterBody3D) -> void:
	_player = player_ref
	_encounter_active = true
	_cooldown_left = encounter_start_cooldown
	_attack_running = false
	_attack_wave_index = 0
	_attack_wave_queue.clear()
	_refill_attack_wave()

func take_damage(amount: float) -> void:
	if _defeated or _death_in_progress:
		return
	_health = maxf(0.0, _health - amount)
	_play_sfx(sfx_hurt)
	_emit_health()
	if _health <= 0.0:
		_defeat()

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_update_death_fall(delta)
	if _defeated:
		return
	var time_blocked: bool = _is_time_state_blocked()
	if not time_blocked:
		_update_idle_visual(delta)
	if not _encounter_active:
		return
	if time_blocked:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		return
	_face_player(delta)
	if _attack_running:
		return
	var current_interval: float = _get_current_attack_interval()
	if _cooldown_left > current_interval:
		_cooldown_left = current_interval
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
	_face_toward_position(target_position, delta * 2.2)

func face_toward_position(target_position: Vector3) -> void:
	_face_toward_position(target_position, 1.0)

func _face_toward_position(target_position: Vector3, blend_weight: float) -> void:
	var flat_target: Vector3 = Vector3(target_position.x, global_position.y, target_position.z)
	var direction: Vector3 = flat_target - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return
	var target_yaw: float = atan2(direction.x, direction.z) + facing_yaw_offset
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(blend_weight, 0.0, 1.0))

func _start_next_attack() -> void:
	_attack_running = true
	var attack_name: String = _next_attack_name()
	call_deferred("_run_attack_sequence", attack_name)

func _run_attack_sequence(attack_name: String) -> void:
	if _should_abort_skills():
		_attack_running = false
		return
	match attack_name:
		"wind":
			await _perform_wind_pulse()
		"swords":
			await _perform_sword_volley()
		"meteor":
			await _perform_meteor_rain()
		"snare":
			await _perform_light_snare()
	if _should_abort_skills():
		_attack_running = false
		return
	if _attack_wave_queue.is_empty():
		await _perform_wave_teleport()
	if _should_abort_skills():
		_attack_running = false
		return
	_attack_running = false
	_cooldown_left = _get_current_attack_interval()

func _get_current_attack_interval() -> float:
	if _health <= max_health * 0.5:
		return maxf(0.1, enraged_attack_interval)
	return maxf(0.1, attack_interval)

func _next_attack_name() -> String:
	if _attack_wave_queue.is_empty():
		_refill_attack_wave()
	if _attack_wave_queue.is_empty():
		return "wind"
	var attack_name: String = _attack_wave_queue[0]
	_attack_wave_queue.remove_at(0)
	return attack_name

func _refill_attack_wave() -> void:
	var wave: Array[String] = _build_wave_order()
	if _attack_wave_index >= 1:
		wave.shuffle()
	_attack_wave_queue = wave
	_attack_wave_index += 1

func _build_wave_order() -> Array[String]:
	var canonical: Array[String] = ["wind", "swords", "meteor", "snare"]
	var ordered: Array[String] = []
	for attack_name in first_wave_attack_order:
		if canonical.has(attack_name) and not ordered.has(attack_name):
			ordered.append(attack_name)
	for attack_name in canonical:
		if not ordered.has(attack_name):
			ordered.append(attack_name)
	return ordered

func _perform_wave_teleport() -> void:
	if _should_abort_skills():
		return
	_play_sfx(sfx_teleport)
	var destination: Vector3 = _choose_wave_teleport_position()
	await _play_wave_teleport_glitch_out()
	if _should_abort_skills():
		_apply_glitch_overlay(false)
		return
	global_position = destination
	_vertical_velocity = 0.0
	await _play_wave_teleport_glitch_in()
	if _player != null and is_instance_valid(_player):
		_face_toward_position(_player.global_position, 1.0)

func _choose_wave_teleport_position() -> Vector3:
	var center: Vector3 = global_position
	var max_radius: float = maxf(wave_teleport_min_radius + 0.5, 14.0)
	var shape_node: CollisionShape3D = get_node_or_null("../MainPlatformBody/CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CylinderShape3D:
		var cyl: CylinderShape3D = shape_node.shape as CylinderShape3D
		var scale_radius: float = maxf(shape_node.global_transform.basis.x.length(), shape_node.global_transform.basis.z.length())
		center = shape_node.global_position
		max_radius = maxf(wave_teleport_min_radius + 0.5, cyl.radius * scale_radius - wave_teleport_edge_margin)
	center.y = ground_height
	var min_radius: float = clampf(wave_teleport_min_radius, 0.0, maxf(max_radius - 0.5, 0.0))
	for _attempt in range(36):
		var angle: float = randf_range(0.0, TAU)
		var radius: float = randf_range(min_radius, max_radius)
		var candidate: Vector3 = center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		candidate.y = ground_height
		if _player != null and is_instance_valid(_player):
			if candidate.distance_to(_player.global_position) < wave_teleport_player_clearance:
				continue
		return candidate
	return center + Vector3(max_radius * 0.5, 0.0, 0.0)

func _play_wave_teleport_glitch_out() -> void:
	_apply_glitch_overlay(true)
	var fade: Tween = create_tween().set_parallel(true)
	fade.tween_method(_set_visual_transparency, 0.0, 1.0, wave_teleport_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _aura_light != null and is_instance_valid(_aura_light):
		fade.parallel().tween_property(_aura_light, "light_energy", _aura_light_initial_energy * 2.1, wave_teleport_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _await_tween_with_time_control(fade)
	await _wait_for_game_time(maxf(0.01, wave_teleport_glitch_duration))

func _play_wave_teleport_glitch_in() -> void:
	_apply_glitch_overlay(true)
	_set_visual_transparency(1.0)
	var settle: Tween = create_tween().set_parallel(true)
	settle.tween_method(_set_visual_transparency, 1.0, 0.0, wave_teleport_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _aura_light != null and is_instance_valid(_aura_light):
		settle.parallel().tween_property(_aura_light, "light_energy", _aura_light_initial_energy, wave_teleport_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _await_tween_with_time_control(settle)
	_apply_glitch_overlay(false)

func _collect_glitch_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_glitch_meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_glitch_meshes(child)

func _apply_glitch_overlay(active: bool) -> void:
	if active:
		for mesh in _glitch_meshes:
			if mesh == null or not is_instance_valid(mesh):
				continue
			var mesh_id: int = mesh.get_instance_id()
			if not _glitch_overrides.has(mesh_id):
				_glitch_overrides[mesh_id] = mesh.material_overlay
			var glitch_material: ShaderMaterial = ShaderMaterial.new()
			glitch_material.shader = SPATIAL_GLITCH_SHADER
			glitch_material.set_shader_parameter("glitch_speed", 8.2)
			glitch_material.set_shader_parameter("glitch_intensity", 2.6)
			glitch_material.set_shader_parameter("base_color", Vector3(0.18, 0.95, 1.0))
			glitch_material.set_shader_parameter("emission_energy", 3.7)
			glitch_material.set_shader_parameter("rim_strength", 3.2)
			glitch_material.set_shader_parameter("pulse_strength", 1.9)
			glitch_material.set_shader_parameter("stripe_density", 72.0)
			glitch_material.set_shader_parameter("alpha_flicker", 0.35)
			mesh.material_overlay = glitch_material
		return
	for mesh in _glitch_meshes:
		if mesh == null or not is_instance_valid(mesh):
			continue
		var mesh_id: int = mesh.get_instance_id()
		if _glitch_overrides.has(mesh_id):
			mesh.material_overlay = _glitch_overrides[mesh_id] as Material
		else:
			mesh.material_overlay = null
	_glitch_overrides.clear()

func _perform_wind_pulse() -> void:
	if _wind_disc == null or _should_abort_skills():
		return
	_play_sfx(sfx_wind_charge)
	var original_light_color: Color = Color(1.0, 0.9, 0.74, 1.0)
	if _aura_light != null:
		original_light_color = _aura_light.light_color
		_aura_light.light_color = wind_pulse_light_color
	await _play_cast_surge(0.7, 5.4)
	if _should_abort_skills():
		if _aura_light != null:
			_aura_light.light_color = original_light_color
		return
	var gather_root: Node3D = Node3D.new()
	_projectile_root.add_child(gather_root)
	gather_root.global_position = global_position + Vector3.UP * 1.3
	var gather_orbs: Array[MeshInstance3D] = _spawn_wind_charge_orbs(gather_root, maxi(wind_charge_orb_count, 8))
	var elapsed: float = 0.0
	var aborted: bool = false
	while elapsed < wind_charge_duration:
		if _should_abort_skills():
			aborted = true
			break
		if _is_time_state_blocked():
			var blocked_tree: SceneTree = get_tree()
			if blocked_tree == null:
				aborted = true
				break
			await blocked_tree.process_frame
			continue
		var delta: float = get_process_delta_time()
		elapsed += delta
		var ratio: float = clampf(elapsed / maxf(wind_charge_duration, 0.001), 0.0, 1.0)
		_update_wind_charge_orbs(gather_orbs, ratio, elapsed)
		var wind_tree: SceneTree = get_tree()
		if wind_tree == null:
			aborted = true
			break
		await wind_tree.process_frame
	if aborted:
		for orb in gather_orbs:
			if is_instance_valid(orb):
				orb.queue_free()
		if is_instance_valid(gather_root):
			gather_root.queue_free()
		_wind_disc.visible = false
		_wind_disc.scale = _wind_disc_initial_scale
		if _aura_light != null:
			_aura_light.light_color = original_light_color
		return
	_wind_disc.visible = true
	_wind_disc.scale = Vector3(_wind_disc_initial_scale.x * 0.35, _wind_disc_initial_scale.y, _wind_disc_initial_scale.z * 0.35)
	if _wind_disc.material_override is ShaderMaterial:
		var wind_mat: ShaderMaterial = _wind_disc.material_override as ShaderMaterial
		wind_mat.set_shader_parameter("base_color", Color(0.01, 0.01, 0.01, 0.72))
		wind_mat.set_shader_parameter("accent_color", Color(0.06, 0.06, 0.06, 0.98))
		wind_mat.set_shader_parameter("emission_energy", 8.0)
	var charge: Tween = create_tween().set_parallel(true)
	charge.tween_property(_wind_disc, "scale", Vector3(4.5, 1.0, 4.5), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	charge.parallel().tween_property(_aura_light, "light_energy", 7.2, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _await_tween_with_time_control(charge)
	if _should_abort_skills():
		for orb in gather_orbs:
			if is_instance_valid(orb):
				orb.queue_free()
		if is_instance_valid(gather_root):
			gather_root.queue_free()
		_wind_disc.visible = false
		_wind_disc.scale = _wind_disc_initial_scale
		if _aura_light != null:
			_aura_light.light_color = original_light_color
		return
	_apply_wind_damage()
	_play_sfx(sfx_wind_blast)
	var blast: Tween = create_tween().set_parallel(true)
	blast.tween_property(_wind_disc, "scale", Vector3(58.0, 1.0, 58.0), 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	blast.parallel().tween_property(_aura_light, "light_energy", 2.2, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _await_tween_with_time_control(blast)
	for orb in gather_orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	if is_instance_valid(gather_root):
		gather_root.queue_free()
	_wind_disc.visible = false
	_wind_disc.scale = _wind_disc_initial_scale
	if _aura_light != null:
		_aura_light.light_color = original_light_color

func _apply_wind_damage() -> void:
	if _should_abort_skills():
		return
	if _player == null or not is_instance_valid(_player):
		return
	var distance: float = global_position.distance_to(_player.global_position)
	if distance > wind_pulse_max_radius:
		return
	var influence: float = 1.0 - clampf(distance / maxf(wind_pulse_max_radius, 0.001), 0.0, 1.0)
	var damage: float = lerpf(wind_pulse_damage_min, wind_pulse_damage_max, influence)
	var knockback_force: float = lerpf(wind_pulse_knockback_min, wind_pulse_knockback_max, influence)
	var knockup_force: float = lerpf(wind_pulse_knockup_min, wind_pulse_knockup_max, influence)
	if _player.has_method("take_damage"):
		_player.call("take_damage", damage)
	if _player.has_method("apply_knockback"):
		var direction: Vector3 = (_player.global_position - global_position).normalized()
		_player.call("apply_knockback", direction, knockback_force, knockup_force)

func _perform_sword_volley() -> void:
	if _player == null or _should_abort_skills():
		return
	_play_sfx(sfx_sword_summon)
	await _play_cast_surge(0.62, 5.4)
	if _should_abort_skills():
		return
	var sword_points: Array[Vector3] = []
	var gates: Array[Node3D] = []
	var preview_swords: Array[Area3D] = []
	var circle_count: int = maxi(1, sword_circle_count)
	var ring_height: float = global_position.y + 8.1
	var ring_radius: float = 4.5
	for idx in range(circle_count):
		var ratio: float = float(idx) / float(circle_count)
		var angle: float = ratio * PI * 2.0
		var point: Vector3 = Vector3(
			global_position.x + cos(angle) * ring_radius,
			ring_height,
			global_position.z + sin(angle) * ring_radius
		)
		sword_points.append(point)
		var gate: Node3D = SWORD_GATE_SCENE.instantiate() as Node3D
		if gate != null:
			_projectile_root.add_child(gate)
			gate.global_position = point
			gate.rotation = Vector3.ZERO
			if gate.has_method("configure"):
				gate.call("configure", 1.25)
			gates.append(gate)
	for point in sword_points:
		if _should_abort_skills():
			break
		var projectile: Area3D = SWORD_PROJECTILE_SCENE.instantiate() as Area3D
		if projectile == null:
			continue
		_projectile_root.add_child(projectile)
		projectile.global_position = point
		var preview_target: Vector3 = _player.global_position + Vector3(0.0, 1.2, 0.0)
		var look_dir: Vector3 = (preview_target - point).normalized()
		if look_dir.length_squared() <= 0.0001:
			look_dir = Vector3.DOWN
		projectile.look_at(projectile.global_position + look_dir, Vector3.UP, true)
		preview_swords.append(projectile)
		await _wait_for_game_time(0.035)
	if _should_abort_skills():
		return
	await _wait_for_game_time(0.8)
	if _should_abort_skills():
		return
	var gate_fade: Tween = create_tween().set_parallel(true)
	for gate in gates:
		if gate != null and is_instance_valid(gate):
			gate_fade.parallel().tween_property(gate, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _await_tween_with_time_control(gate_fade)
	if _should_abort_skills():
		return
	for gate in gates:
		if gate != null and is_instance_valid(gate):
			gate.queue_free()
	await _wait_for_game_time(0.12)
	if _should_abort_skills():
		return
	var fire_speed: float = sword_projectile_speed * 1.75
	_play_sfx(sfx_sword_fire)
	for projectile in preview_swords:
		if _should_abort_skills():
			break
		if projectile == null or not is_instance_valid(projectile):
			continue
		var live_target: Vector3 = _player.global_position + Vector3(0.0, 1.2, 0.0)
		var fire_dir: Vector3 = (live_target - projectile.global_position).normalized()
		if fire_dir.length_squared() <= 0.0001:
			fire_dir = Vector3.DOWN
		projectile.look_at(projectile.global_position + fire_dir, Vector3.UP, true)
		if projectile.has_method("configure"):
			projectile.call("configure", fire_dir, fire_speed, sword_projectile_damage, _player)
		await _wait_for_game_time(0.055)

func _perform_meteor_rain() -> void:
	if _player == null or _should_abort_skills():
		return
	_play_sfx(sfx_meteor_cast)
	await _play_cast_surge(0.75, 5.0)
	if _should_abort_skills():
		return
	var rain_duration: float = 8.0
	var spawn_interval: float = 0.42
	var elapsed: float = 0.0
	while elapsed < rain_duration:
		if _should_abort_skills():
			break
		if _is_time_state_blocked():
			var meteor_tree: SceneTree = get_tree()
			if meteor_tree == null:
				break
			await meteor_tree.process_frame
			continue
		for burst_index in range(2):
			var attack: Node3D = FALL_ATTACK_SCENE.instantiate() as Node3D
			if attack == null:
				continue
			_projectile_root.add_child(attack)
			var offset: Vector3 = Vector3(randf_range(-9.4, 9.4), 0.0, randf_range(-9.4, 9.4))
			var target_position: Vector3 = Vector3(_player.global_position.x, 0.08, _player.global_position.z) + offset
			var warning_time: float = randf_range(0.75, 1.35)
			var fall_time: float = randf_range(1.8, 2.55)
			var meteor_size: float = randf_range(0.95, 1.3)
			attack.call("configure_attack", target_position, _player, 40.0, 2.35, warning_time, fall_time, true, meteor_size)
		var wait_time: float = maxf(0.3, spawn_interval + randf_range(-0.08, 0.14))
		await _wait_for_game_time(wait_time)
		elapsed += wait_time

func _perform_light_snare() -> void:
	if _player == null or _should_abort_skills():
		return
	_play_sfx(sfx_snare_cast)
	await _play_cast_surge(0.86, 5.8)
	if _should_abort_skills():
		return
	var snare: Area3D = LIGHT_SNARE_SCENE.instantiate() as Area3D
	if snare == null:
		return
	_snare_root.add_child(snare)
	snare.global_position = Vector3(global_position.x, 0.08, global_position.z)
	snare.call("configure", _player, 5.0, 50.0, 4.2, self)
	await _wait_for_game_time(5.4)

func _spawn_wind_charge_orbs(root: Node3D, count: int) -> Array[MeshInstance3D]:
	var orbs: Array[MeshInstance3D] = []
	for idx in range(count):
		var orb: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = randf_range(0.08, 0.2)
		mesh.height = mesh.radius * 2.0
		orb.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.03, 0.04, 0.05, 0.96)
		mat.metallic = 0.55
		mat.roughness = 0.12
		mat.emission_enabled = true
		mat.emission = Color(0.08, 0.22, 0.2, 1.0)
		mat.emission_energy_multiplier = 2.8
		orb.material_override = mat
		root.add_child(orb)
		orbs.append(orb)
	return orbs

func _update_wind_charge_orbs(orbs: Array[MeshInstance3D], ratio: float, elapsed: float) -> void:
	var count: int = orbs.size()
	if count <= 0:
		return
	var radius: float = lerpf(4.8, 0.95, ratio)
	for idx in range(count):
		var orb: MeshInstance3D = orbs[idx]
		if orb == null or not is_instance_valid(orb):
			continue
		var idx_ratio: float = float(idx) / float(maxi(count, 1))
		var angle: float = idx_ratio * TAU + elapsed * 2.8 + sin(elapsed * 1.6 + idx_ratio * TAU) * 0.24
		var y_wave: float = sin(elapsed * 2.2 + idx_ratio * TAU * 1.7) * 0.85
		orb.position = Vector3(cos(angle) * radius, y_wave, sin(angle) * radius)
		var scale_factor: float = lerpf(0.55, 1.0, 1.0 - ratio) + sin(elapsed * 4.0 + idx) * 0.08
		orb.scale = Vector3.ONE * maxf(0.28, scale_factor)

func _play_cast_surge(duration: float, light_target: float) -> void:
	if _aura_ring == null or _aura_light == null or _should_abort_skills():
		return
	var start_scale: Vector3 = _aura_ring.scale
	var surge: Tween = create_tween().set_parallel(true)
	surge.tween_property(_aura_ring, "scale", start_scale * 1.36, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	surge.parallel().tween_property(_aura_light, "light_energy", light_target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _await_tween_with_time_control(surge)
	if _should_abort_skills():
		return
	var settle: Tween = create_tween().set_parallel(true)
	settle.tween_property(_aura_ring, "scale", _aura_ring_initial_scale, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	settle.parallel().tween_property(_aura_light, "light_energy", _aura_light_initial_energy, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _await_tween_with_time_control(settle)

func _defeat() -> void:
	if _death_in_progress:
		return
	_play_sfx(sfx_defeat)
	_death_in_progress = true
	_defeated = true
	_encounter_active = false
	_attack_running = false
	for child in _projectile_root.get_children():
		child.queue_free()
	for child in _snare_root.get_children():
		child.queue_free()
	_apply_glitch_overlay(false)
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
	_play_sfx(sfx_manifest)
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
	_apply_glitch_overlay(false)
	_set_visual_transparency(0.0)
	if _aura_light != null:
		_aura_light.light_energy = _aura_light_initial_energy
		_aura_light.light_color = Color(0.46, 0.34, 0.28, 1.0)
	if _aura_ring != null:
		_aura_ring.visible = true
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
	if _aura_ring != null:
		_aura_ring.visible = false
	if _aura_light != null:
		_aura_light.light_color = Color(0.03, 0.03, 0.03, 1.0)
		_aura_light.light_energy = 0.0
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
		var ash_position: Vector3 = global_position
		if _rose != null and is_instance_valid(_rose):
			ash_position = _rose.global_position
			ash_position.y += 0.36
		elif _ash_anchor != null:
			ash_position = _ash_anchor.global_position
		else:
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

func _distance_point_to_segment(point: Vector3, segment_a: Vector3, segment_b: Vector3) -> float:
	var ab: Vector3 = segment_b - segment_a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.000001:
		return point.distance_to(segment_a)
	var t: float = clampf((point - segment_a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector3 = segment_a + ab * t
	return point.distance_to(closest)

func _is_time_state_blocked() -> bool:
	return GameState.is_paused or GameState.time_direction != GameState.TIME_FORWARD or GameState.is_scrubbing_past

func _should_abort_skills() -> bool:
	return _defeated or _death_in_progress or not _encounter_active or not is_inside_tree()

func _wait_for_game_time(duration: float) -> void:
	var elapsed: float = 0.0
	while elapsed < duration:
		var tree: SceneTree = get_tree()
		if tree == null:
			return
		await tree.process_frame
		if _should_abort_skills():
			return
		if _is_time_state_blocked():
			continue
		elapsed += get_process_delta_time()

func _await_tween_with_time_control(tween: Tween) -> void:
	if tween == null:
		return
	while tween.is_valid():
		if _should_abort_skills():
			tween.kill()
			return
		if _is_time_state_blocked():
			tween.pause()
		else:
			tween.play()
		if not tween.is_running() and not _is_time_state_blocked():
			break
		var tree: SceneTree = get_tree()
		if tree == null:
			return
		await tree.process_frame
