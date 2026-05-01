extends Interactable

signal defeated(dragon: Node3D)
signal mount_requested(dragon: Node3D)
signal health_changed(current: float, maximum: float)

const SPATIAL_GLITCH_SHADER := preload("res://shaders/spatial_glitch.gdshader")
const FIREBALL_SCENE := preload("res://scenes/objects/electric_orb.tscn")

@export var max_health: float = 100.0
@export var attack_cycle_cooldown: float = 12.0
@export var fireball_burst_duration: float = 4.0
@export var fireball_burst_interval: float = 0.45
@export var fireball_damage: float = 25.0
@export var fireball_speed: float = 14.0
@export var fireball_radius: float = 1.0
@export var fireball_spawn_height: float = 1.85
@export var meteor_rain_duration: float = 2.8
@export var meteor_rain_interval: float = 0.24
@export var meteor_rain_radius: float = 9.5
@export var meteor_spawn_height: float = 20.0
@export var meteor_fall_speed: float = 18.0
@export var meteor_damage: float = 25.0
@export var meteor_radius: float = 1.1
@export var gun_hit_damage: float = 2.0
@export var bow_hit_damage: float = 8.0
@export var hit_flash_duration: float = 0.16
@export var model_yaw_offset_degrees: float = 180.0
@export var sfx_fireball_cast: AudioStream

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _model_root: Node3D = $ModelRoot
@onready var _glow: OmniLight3D = $Glow
@onready var _health_pivot: Node3D = $HealthPivot
@onready var _health_bar_fill: MeshInstance3D = $HealthPivot/HealthFill
@onready var _fireball_sfx_player: AudioStreamPlayer3D = get_node_or_null("FireballSFX") as AudioStreamPlayer3D

var _player: CharacterBody3D
var _animation_player: AnimationPlayer
var _health: float = 0.0
var _dead: bool = false
var _mount_enabled: bool = false
var _cooldown_timer: float = 0.0
var _attack_sequence_running: bool = false
var _skill_cycle_step: int = 0
var _highlight_enabled: bool = false
var _idle_time: float = 0.0
var _glitch_meshes: Array[MeshInstance3D] = []
var _hit_flash_overrides: Dictionary = {}
var _hit_flash_active: bool = false
var _hit_flash_timer: Timer
var _active_fireballs: Array[Node3D] = []
var _combat_anchor_position: Vector3 = Vector3.ZERO
var _fireball_sfx_fallback: AudioStreamPlayer

func _ready() -> void:
	add_to_group("enemy")
	_health = max_health
	prompt_text = ""
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_animation_player = _find_animation_player(_model_root)
	_update_health_visual()
	_emit_health()
	if _health_pivot != null:
		_health_pivot.visible = false
	if _glow != null:
		_glow.light_energy = 1.25
	_collect_glitch_meshes(_model_root)
	_setup_hit_flash_timer()
	if _fireball_sfx_player != null and sfx_fireball_cast != null:
		_fireball_sfx_player.stream = sfx_fireball_cast
	_setup_fireball_sfx_fallback()

func _physics_process(_delta: float) -> void:
	if _dead:
		if _player != null and is_instance_valid(_player):
			_face_player()
		return
	if GameState.is_time_blocked():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		return
	if visible:
		global_position = _combat_anchor_position
	_face_player()
	_cleanup_fireballs()
	if _attack_sequence_running:
		return
	_cooldown_timer = maxf(0.0, _cooldown_timer - _delta)
	if _cooldown_timer > 0.0:
		return
	_attack_sequence_running = true
	call_deferred("_run_attack_cycle")

func take_weapon_damage(amount: float, weapon_id: String) -> void:
	if weapon_id == "Gun":
		take_damage(gun_hit_damage)
		return
	if weapon_id == "Bow":
		take_damage(bow_hit_damage)
		return
	take_damage(amount)

func take_damage(amount: float) -> void:
	if _dead:
		return
	_health = maxf(0.0, _health - amount)
	_trigger_hit_flash()
	_update_health_visual()
	_emit_health()
	if _health <= 0.0:
		_die()

func _setup_hit_flash_timer() -> void:
	_hit_flash_timer = Timer.new()
	_hit_flash_timer.one_shot = true
	_hit_flash_timer.wait_time = maxf(0.05, hit_flash_duration)
	_hit_flash_timer.timeout.connect(_clear_hit_flash)
	add_child(_hit_flash_timer)

func _collect_glitch_meshes(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		_glitch_meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_glitch_meshes(child)

func _trigger_hit_flash() -> void:
	if _hit_flash_timer == null:
		return
	if not _hit_flash_active:
		_hit_flash_active = true
		_hit_flash_overrides.clear()
		for mesh in _glitch_meshes:
			if mesh == null or not is_instance_valid(mesh):
				continue
			var mesh_id: int = mesh.get_instance_id()
			_hit_flash_overrides[mesh_id] = mesh.material_overlay
			var glitch_material: ShaderMaterial = ShaderMaterial.new()
			glitch_material.shader = SPATIAL_GLITCH_SHADER
			glitch_material.set_shader_parameter("glitch_speed", 15.5)
			glitch_material.set_shader_parameter("glitch_intensity", 2.4)
			glitch_material.set_shader_parameter("base_color", Vector3(1.0, 0.2, 0.2))
			glitch_material.set_shader_parameter("emission_energy", 6.4)
			glitch_material.set_shader_parameter("rim_strength", 3.4)
			glitch_material.set_shader_parameter("pulse_strength", 1.8)
			glitch_material.set_shader_parameter("stripe_density", 70.0)
			glitch_material.set_shader_parameter("alpha_flicker", 0.36)
			mesh.material_overlay = glitch_material
	_hit_flash_timer.start(maxf(0.05, hit_flash_duration))

func _clear_hit_flash() -> void:
	if not _hit_flash_active:
		return
	if _hit_flash_timer != null:
		_hit_flash_timer.stop()
	for mesh in _glitch_meshes:
		if mesh == null or not is_instance_valid(mesh):
			continue
		var mesh_id: int = mesh.get_instance_id()
		if _hit_flash_overrides.has(mesh_id):
			mesh.material_overlay = _hit_flash_overrides[mesh_id] as Material
		else:
			mesh.material_overlay = null
	_hit_flash_overrides.clear()
	_hit_flash_active = false

func set_mount_enabled(enabled: bool) -> void:
	_mount_enabled = enabled
	if _dead and _mount_enabled:
		prompt_text = "Press E to tame and ride dragon"
	else:
		prompt_text = ""

func interact() -> void:
	if not _dead:
		return
	if not _mount_enabled:
		return
	mount_requested.emit(self)

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = enabled and _dead and _mount_enabled
	_apply_highlight()

func set_highlight_strength(_strength: float) -> void:
	_apply_highlight()

func _apply_highlight() -> void:
	if _glow == null:
		return
	if _highlight_enabled:
		_glow.light_color = Color(0.22, 0.86, 1.0, 1.0)
		_glow.light_energy = 3.5
	else:
		_glow.light_color = Color(0.5, 0.3, 0.9, 1.0)
		_glow.light_energy = 1.25 if not _dead else 0.9

func _die() -> void:
	_clear_hit_flash()
	_dead = true
	_attack_sequence_running = false
	_cooldown_timer = 0.0
	_clear_fireballs()
	prompt_text = ""
	_idle_time = 0.0
	if _glow != null:
		_glow.light_color = Color(0.22, 0.86, 1.0, 1.0)
		_glow.light_energy = 1.2
	if _model_root != null:
		_model_root.rotation_degrees = Vector3.ZERO
		_model_root.position = Vector3.ZERO
	play_idle_animation()
	_update_health_visual()
	_emit_health()
	defeated.emit(self)

func set_combat_enabled(enabled: bool) -> void:
	visible = enabled
	set_physics_process(enabled)
	if _collision != null:
		_collision.disabled = not enabled
	if not enabled:
		prompt_text = ""
		_attack_sequence_running = false
		_cooldown_timer = 0.0
		_clear_fireballs()
	else:
		_combat_anchor_position = global_position
		_attack_sequence_running = false
		_cooldown_timer = maxf(0.0, attack_cycle_cooldown)

func reset_dragon_state() -> void:
	_clear_hit_flash()
	_clear_fireballs()
	_dead = false
	_mount_enabled = false
	_attack_sequence_running = false
	_skill_cycle_step = 0
	_cooldown_timer = maxf(0.0, attack_cycle_cooldown)
	_health = max_health
	prompt_text = ""
	if _collision != null:
		_collision.disabled = false
	if _model_root != null:
		_model_root.rotation_degrees = Vector3.ZERO
		_model_root.position = Vector3.ZERO
	if _glow != null:
		_glow.light_color = Color(0.5, 0.3, 0.9, 1.0)
		_glow.light_energy = 1.25
	_idle_time = 0.0
	_combat_anchor_position = global_position
	_update_health_visual()
	_emit_health()
	play_idle_animation()

func _run_attack_cycle() -> void:
	if _dead or not visible:
		_attack_sequence_running = false
		return
	var skill_index: int = _skill_cycle_step % 3
	_play_attack_animation()
	await get_tree().create_timer(0.3).timeout
	match skill_index:
		0, 1:
			await _cast_fireball_burst_skill()
		2:
			await _cast_meteor_rain_skill()
	_skill_cycle_step += 1
	_attack_sequence_running = false
	_cooldown_timer = maxf(0.0, attack_cycle_cooldown)

func _cast_fireball_burst_skill() -> void:
	var duration: float = maxf(0.2, fireball_burst_duration)
	var interval: float = maxf(0.08, fireball_burst_interval)
	var elapsed: float = 0.0
	var shot_timer: float = interval
	while elapsed < duration:
		if _dead or not visible or not is_inside_tree():
			break
		if GameState.is_time_blocked():
			if not await _await_next_frame_safe():
				break
			continue
		var delta: float = get_process_delta_time()
		elapsed += delta
		shot_timer += delta
		if shot_timer >= interval:
			shot_timer = 0.0
			_spawn_fireball_at_player()
		if not await _await_next_frame_safe():
			break

func _cast_meteor_rain_skill() -> void:
	_spawn_upward_cast_fireball()
	await get_tree().create_timer(0.55).timeout
	var duration: float = maxf(0.25, meteor_rain_duration)
	var interval: float = maxf(0.08, meteor_rain_interval)
	var elapsed: float = 0.0
	var shot_timer: float = 0.0
	while elapsed < duration:
		if _dead or not visible or not is_inside_tree():
			break
		if GameState.is_time_blocked():
			if not await _await_next_frame_safe():
				break
			continue
		var delta: float = get_process_delta_time()
		elapsed += delta
		shot_timer += delta
		if shot_timer >= interval:
			shot_timer = 0.0
			_spawn_meteor_rain_fireball()
		if not await _await_next_frame_safe():
			break

func _await_next_frame_safe() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	await tree.process_frame
	return is_inside_tree()

func _spawn_fireball_at_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_play_fireball_sfx()
	var forward: Vector3 = -global_transform.basis.z
	var spawn_position: Vector3 = global_position + Vector3(0.0, fireball_spawn_height, 0.0) + forward * 1.3
	var target_position: Vector3 = _player.global_position + Vector3(0.0, 1.0, 0.0)
	var direction: Vector3 = target_position - spawn_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = forward
	_spawn_configured_fireball(spawn_position, direction.normalized(), fireball_speed, fireball_damage, fireball_radius)

func _spawn_upward_cast_fireball() -> void:
	_play_fireball_sfx()
	var forward: Vector3 = -global_transform.basis.z.normalized()
	var spawn_position: Vector3 = global_position + Vector3(0.0, fireball_spawn_height, 0.0) + forward * 1.25
	var cast_direction: Vector3 = (forward * 0.18 + Vector3.UP * 0.98).normalized()
	_spawn_configured_fireball(spawn_position, cast_direction, fireball_speed * 0.8, fireball_damage, fireball_radius)

func _play_fireball_sfx() -> void:
	var stream_to_use: AudioStream = sfx_fireball_cast
	if stream_to_use == null and _fireball_sfx_player != null:
		stream_to_use = _fireball_sfx_player.stream
	var played_3d: bool = false
	if _fireball_sfx_player != null:
		if stream_to_use != null and _fireball_sfx_player.stream != stream_to_use:
			_fireball_sfx_player.stream = stream_to_use
		if _fireball_sfx_player.stream != null:
			_fireball_sfx_player.pitch_scale = randf_range(0.96, 1.04)
			_fireball_sfx_player.play()
			played_3d = true
	if played_3d:
		return
	if _fireball_sfx_fallback == null or not is_instance_valid(_fireball_sfx_fallback):
		_setup_fireball_sfx_fallback()
	if _fireball_sfx_fallback == null:
		return
	if stream_to_use != null and _fireball_sfx_fallback.stream != stream_to_use:
		_fireball_sfx_fallback.stream = stream_to_use
	if _fireball_sfx_fallback.stream == null:
		return
	_fireball_sfx_fallback.pitch_scale = randf_range(0.96, 1.04)
	_fireball_sfx_fallback.play()

func _setup_fireball_sfx_fallback() -> void:
	if _fireball_sfx_fallback != null and is_instance_valid(_fireball_sfx_fallback):
		return
	_fireball_sfx_fallback = AudioStreamPlayer.new()
	_fireball_sfx_fallback.name = "FireballSFXFallback"
	_fireball_sfx_fallback.bus = "Master"
	_fireball_sfx_fallback.autoplay = false
	_fireball_sfx_fallback.volume_db = -2.0
	if sfx_fireball_cast != null:
		_fireball_sfx_fallback.stream = sfx_fireball_cast
	add_child(_fireball_sfx_fallback)

func _spawn_meteor_rain_fireball() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var center: Vector3 = _player.global_position
	var offset_x: float = randf_range(-meteor_rain_radius, meteor_rain_radius)
	var offset_z: float = randf_range(-meteor_rain_radius, meteor_rain_radius)
	var target: Vector3 = center + Vector3(offset_x, 0.8, offset_z)
	var spawn_position: Vector3 = target + Vector3(randf_range(-1.2, 1.2), meteor_spawn_height, randf_range(-1.2, 1.2))
	var direction: Vector3 = (target - spawn_position).normalized()
	_spawn_configured_fireball(spawn_position, direction, meteor_fall_speed, meteor_damage, meteor_radius)

func _spawn_configured_fireball(spawn_position: Vector3, direction: Vector3, speed_value: float, damage_value: float, radius_value: float) -> void:
	if FIREBALL_SCENE == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var projectile: Node3D = FIREBALL_SCENE.instantiate() as Node3D
	if projectile == null:
		return
	var scene_root: Node = tree.current_scene
	if scene_root == null:
		scene_root = tree.root
	scene_root.add_child(projectile)
	projectile.global_position = spawn_position
	var use_direction: Vector3 = direction
	if use_direction.length_squared() <= 0.0001:
		use_direction = Vector3.FORWARD
	if projectile.has_method("configure_orb"):
		projectile.call("configure_orb", use_direction.normalized(), speed_value, damage_value, radius_value)
	if projectile.has_signal("finished"):
		projectile.connect("finished", Callable(self, "_on_fireball_finished"))
	_active_fireballs.append(projectile)

func _on_fireball_finished(projectile: Node3D) -> void:
	var index: int = _active_fireballs.find(projectile)
	if index >= 0:
		_active_fireballs.remove_at(index)
	_cleanup_fireballs()

func _cleanup_fireballs() -> void:
	for i in range(_active_fireballs.size() - 1, -1, -1):
		var projectile: Node3D = _active_fireballs[i]
		if projectile == null or not is_instance_valid(projectile):
			_active_fireballs.remove_at(i)

func _clear_fireballs() -> void:
	for projectile in _active_fireballs:
		if projectile == null or not is_instance_valid(projectile):
			continue
		if projectile.has_method("force_despawn"):
			projectile.call("force_despawn")
		else:
			projectile.queue_free()
	_active_fireballs.clear()

func _update_health_visual() -> void:
	if _health_pivot != null:
		_health_pivot.visible = false
	if _health_bar_fill == null:
		return
	var ratio: float = 0.0
	if max_health > 0.001:
		ratio = clampf(_health / max_health, 0.0, 1.0)
	var scale_value: float = maxf(0.001, ratio)
	_health_bar_fill.scale.x = scale_value
	_health_bar_fill.position.x = -0.8 + scale_value * 0.8
	_health_bar_fill.visible = false

func _emit_health() -> void:
	emit_signal("health_changed", _health, max_health)

func _face_player() -> void:
	if _player == null:
		return
	var target: Vector3 = _player.global_position
	target.y = global_position.y
	face_toward(target)

func face_toward(target: Vector3) -> void:
	var to_target: Vector3 = target - global_position
	if to_target.length_squared() <= 0.0001:
		return
	look_at(target, Vector3.UP)
	if absf(model_yaw_offset_degrees) > 0.001:
		rotate_y(deg_to_rad(model_yaw_offset_degrees))

func _play_attack_animation() -> void:
	_play_animation_with_keywords(["attack", "bite", "claw"])

func play_fly_animation() -> void:
	_play_animation_with_keywords(["fly"])

func play_idle_animation() -> void:
	_play_animation_with_keywords(["idle", "stand"])

func play_roar_animation() -> void:
	_play_animation_with_keywords(["roar", "yell", "shout"])

func get_available_animation_names() -> Array[String]:
	if _animation_player == null:
		_animation_player = _find_animation_player(_model_root)
	if _animation_player == null:
		return []
	var names: Array[String] = []
	for name_variant in _animation_player.get_animation_list():
		names.append(String(name_variant))
	return names

func _play_animation_with_keywords(keywords: Array[String]) -> void:
	if _animation_player == null:
		_animation_player = _find_animation_player(_model_root)
	if _animation_player == null:
		return
	var fallback: StringName = StringName()
	for name_variant in _animation_player.get_animation_list():
		var animation_name: StringName = name_variant
		if fallback == StringName():
			fallback = animation_name
		var lower_name: String = String(animation_name).to_lower()
		for keyword in keywords:
			if lower_name.contains(keyword):
				_animation_player.play(animation_name)
				return
	if fallback != StringName():
		_animation_player.play(fallback)

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null
