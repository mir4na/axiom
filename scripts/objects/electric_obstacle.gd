extends Node3D

signal destroyed(obstacle: Node3D)

@export var projectile_scene: PackedScene = preload("res://scenes/objects/electric_orb.tscn")
@export var max_health: float = 120.0
@export var fire_cooldown: float = 8.0
@export var projectile_speed: float = 10.5
@export var projectile_damage: float = 50.0
@export var projectile_radius: float = 4.35
@export var detection_range: float = 260.0

@onready var _core_body: StaticBody3D = get_node_or_null("CoreBody") as StaticBody3D
@onready var _core_collision: CollisionShape3D = get_node_or_null("CoreBody/CollisionShape3D") as CollisionShape3D
@onready var _core_mesh: MeshInstance3D = get_node_or_null("CoreBody/CoreMesh") as MeshInstance3D
@onready var _aura_mesh: MeshInstance3D = get_node_or_null("AuraMesh") as MeshInstance3D
@onready var _glow_light: OmniLight3D = get_node_or_null("GlowLight") as OmniLight3D
@onready var _muzzle: Marker3D = get_node_or_null("Muzzle") as Marker3D
@onready var _corridor_light_a: OmniLight3D = get_node_or_null("CorridorLightA") as OmniLight3D
@onready var _corridor_light_b: OmniLight3D = get_node_or_null("CorridorLightB") as OmniLight3D
@onready var _corridor_light_c: OmniLight3D = get_node_or_null("CorridorLightC") as OmniLight3D

var _health: float = 120.0
var _cooldown_timer: float = 0.0
var _enabled: bool = false
var _destroyed: bool = false
var _highlight_enabled: bool = false
var _persistent_highlight: bool = false
var _flash_timer: float = 0.0
var _projectiles: Array[Node3D] = []
var _core_material: StandardMaterial3D
var _corridor_pulse_time: float = 0.0
var _shot_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	_setup_materials()
	reset_obstacle_state()

func _physics_process(delta: float) -> void:
	_cleanup_projectiles()
	_update_damage_flash(delta)
	_update_corridor_lights(delta)
	if not _enabled or _destroyed:
		return
	if GameState.is_time_blocked():
		return
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > detection_range:
		return
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	if _cooldown_timer > 0.0:
		return
	_fire_projectile(player)
	_cooldown_timer = fire_cooldown

func set_obstacle_enabled(enabled: bool) -> void:
	if _destroyed:
		return
	_enabled = enabled
	visible = enabled
	_cooldown_timer = 0.8 if enabled else 0.0
	_corridor_pulse_time = 0.0
	_shot_direction = Vector3.ZERO
	if _core_collision != null:
		_core_collision.disabled = not enabled
	if _core_body != null:
		_core_body.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if not enabled:
		_clear_projectiles()
	_set_corridor_lights_visible(enabled)
	set_highlight_enabled(_persistent_highlight)

func reset_obstacle_state() -> void:
	_destroyed = false
	_health = max_health
	_flash_timer = 0.0
	if _core_mesh != null:
		_core_mesh.scale = Vector3.ONE
		_core_mesh.rotation = Vector3.ZERO
	if _core_material != null:
		_core_material.albedo_color = Color(0.26, 0.25, 0.24, 1.0)
		_core_material.emission = Color(0.24, 0.16, 0.08, 1.0)
		_core_material.emission_energy_multiplier = 0.35
	_clear_projectiles()
	set_obstacle_enabled(false)

func take_damage(amount: float) -> void:
	if _destroyed or not _enabled:
		return
	_health = maxf(0.0, _health - amount)
	_flash_timer = 0.2
	if _health > 0.0:
		return
	_destroyed = true
	_enabled = false
	if _core_collision != null:
		_core_collision.disabled = true
	_clear_projectiles()
	set_highlight_enabled(false)
	var explode: Tween = create_tween().set_parallel(true)
	if _core_mesh != null:
		explode.tween_property(_core_mesh, "scale", Vector3.ONE * 1.9, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		explode.tween_property(_core_mesh, "scale", Vector3.ZERO, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.16)
	if _glow_light != null:
		explode.tween_property(_glow_light, "light_energy", 18.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		explode.tween_property(_glow_light, "omni_range", 12.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		explode.tween_property(_glow_light, "light_energy", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.14)
	if _aura_mesh != null:
		explode.tween_property(_aura_mesh, "scale", Vector3.ONE * 2.2, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		explode.tween_property(_aura_mesh, "scale", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.16)
	await explode.finished
	emit_signal("destroyed", self)
	queue_free()

func set_persistent_highlight(enabled: bool) -> void:
	_persistent_highlight = enabled
	set_highlight_enabled(enabled)

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = (enabled or _persistent_highlight) and visible and not _destroyed
	if _aura_mesh != null:
		_aura_mesh.visible = _highlight_enabled
	if _glow_light != null and _enabled:
		_glow_light.visible = true
	if not _highlight_enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func get_nearest_projectile_distance_to(point: Vector3) -> float:
	var nearest: float = 999999.0
	for projectile in _projectiles:
		if projectile == null or not is_instance_valid(projectile):
			continue
		var distance: float = projectile.global_position.distance_to(point)
		if distance < nearest:
			nearest = distance
	return nearest

func _fire_projectile(player: CharacterBody3D) -> void:
	if projectile_scene == null:
		return
	var projectile_node: Node3D = projectile_scene.instantiate() as Node3D
	if projectile_node == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(projectile_node)
	var spawn_position: Vector3 = global_position + Vector3(0.0, 1.2, 0.0)
	if _muzzle != null:
		spawn_position = _muzzle.global_position
	projectile_node.global_position = spawn_position
	if _shot_direction.length_squared() <= 0.0001:
		var initial_target: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
		var initial_direction: Vector3 = initial_target - spawn_position
		initial_direction.y = 0.0
		if initial_direction.length_squared() <= 0.0001:
			var fallback: Vector3 = -global_transform.basis.z
			fallback.y = 0.0
			initial_direction = fallback
		if initial_direction.length_squared() <= 0.0001:
			initial_direction = Vector3.BACK
		_shot_direction = initial_direction.normalized()
	if projectile_node.has_method("configure_orb"):
		projectile_node.call("configure_orb", _shot_direction, projectile_speed, projectile_damage, projectile_radius)
	if projectile_node.has_signal("finished"):
		projectile_node.connect("finished", Callable(self, "_on_projectile_finished"))
	_projectiles.append(projectile_node)
	_flash_corridor_lights()

func _on_projectile_finished(projectile: Node3D) -> void:
	var remaining: Array[Node3D] = []
	for entry in _projectiles:
		if entry != projectile and entry != null and is_instance_valid(entry):
			remaining.append(entry)
	_projectiles = remaining

func _clear_projectiles() -> void:
	for projectile in _projectiles:
		if projectile != null and is_instance_valid(projectile):
			if projectile.has_method("force_despawn"):
				projectile.call("force_despawn")
			else:
				projectile.queue_free()
	_projectiles.clear()

func _cleanup_projectiles() -> void:
	var remaining: Array[Node3D] = []
	for projectile in _projectiles:
		if projectile != null and is_instance_valid(projectile):
			remaining.append(projectile)
	_projectiles = remaining

func _setup_materials() -> void:
	if _core_mesh != null:
		var base_material: StandardMaterial3D = _core_mesh.material_override as StandardMaterial3D
		if base_material == null:
			base_material = StandardMaterial3D.new()
			base_material.albedo_color = Color(0.26, 0.25, 0.24, 1.0)
			base_material.metallic = 0.78
			base_material.roughness = 0.42
			base_material.emission_enabled = true
			base_material.emission = Color(0.24, 0.16, 0.08, 1.0)
			base_material.emission_energy_multiplier = 0.35
		_core_material = base_material.duplicate() as StandardMaterial3D
		_core_mesh.material_override = _core_material
	if _aura_mesh != null:
		var aura_shader: Shader = load("res://shaders/objective_highlight.gdshader") as Shader
		if aura_shader != null:
			var aura_material: ShaderMaterial = ShaderMaterial.new()
			aura_material.shader = aura_shader
			aura_material.set_shader_parameter("glow_color", Color(0.2, 0.95, 1.0, 1.0))
			_aura_mesh.material_override = aura_material
		_aura_mesh.visible = false
	if _glow_light != null:
		_glow_light.visible = false
	_set_corridor_lights_visible(false)
	_set_corridor_light_energy(0.0, 0.0, 0.0)

func _apply_highlight(strength: float) -> void:
	var clamped: float = clampf(strength, 0.0, 1.0)
	if _aura_mesh != null and _aura_mesh.material_override is ShaderMaterial:
		_aura_mesh.material_override.set_shader_parameter("highlight_strength", clamped * 1.7)
	if _glow_light != null:
		_glow_light.light_energy = 1.2 + clamped * 4.4
		_glow_light.visible = _enabled and (_highlight_enabled or clamped > 0.01)

func _update_damage_flash(delta: float) -> void:
	if _core_material == null:
		return
	_flash_timer = maxf(0.0, _flash_timer - delta)
	var ratio: float = _flash_timer / 0.2
	_core_material.albedo_color = Color(0.26, 0.25, 0.24, 1.0).lerp(Color(0.9, 0.34, 0.18, 1.0), ratio)
	_core_material.emission = Color(0.24, 0.16, 0.08, 1.0).lerp(Color(1.0, 0.34, 0.12, 1.0), ratio)
	_core_material.emission_energy_multiplier = lerpf(0.35, 3.2, ratio)

func _update_corridor_lights(delta: float) -> void:
	if not _enabled or _destroyed:
		_set_corridor_light_energy(0.0, 0.0, 0.0)
		return
	if GameState.is_time_blocked():
		return
	_corridor_pulse_time = wrapf(_corridor_pulse_time + delta * 2.6, 0.0, TAU)
	var base: float = 1.1 + (sin(_corridor_pulse_time) * 0.5 + 0.5) * 1.2
	var mid: float = 0.9 + (sin(_corridor_pulse_time + 1.8) * 0.5 + 0.5) * 1.05
	var front: float = 1.0 + (sin(_corridor_pulse_time + 3.2) * 0.5 + 0.5) * 1.2
	_set_corridor_light_energy(base, mid, front)

func _set_corridor_lights_visible(visible_state: bool) -> void:
	if _corridor_light_a != null:
		_corridor_light_a.visible = visible_state
	if _corridor_light_b != null:
		_corridor_light_b.visible = visible_state
	if _corridor_light_c != null:
		_corridor_light_c.visible = visible_state

func _set_corridor_light_energy(a: float, b: float, c: float) -> void:
	if _corridor_light_a != null:
		_corridor_light_a.light_energy = a
	if _corridor_light_b != null:
		_corridor_light_b.light_energy = b
	if _corridor_light_c != null:
		_corridor_light_c.light_energy = c

func _flash_corridor_lights() -> void:
	var burst: Tween = create_tween().set_parallel(true)
	if _corridor_light_a != null:
		burst.tween_property(_corridor_light_a, "light_energy", 5.6, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		burst.tween_property(_corridor_light_a, "light_energy", 1.4, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.1)
	if _corridor_light_b != null:
		burst.tween_property(_corridor_light_b, "light_energy", 4.9, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		burst.tween_property(_corridor_light_b, "light_energy", 1.1, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.1)
	if _corridor_light_c != null:
		burst.tween_property(_corridor_light_c, "light_energy", 5.6, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		burst.tween_property(_corridor_light_c, "light_energy", 1.4, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.1)
