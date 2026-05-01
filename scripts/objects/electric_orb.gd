extends CharacterBody3D

signal finished(projectile: Node3D)

const ORB_SCALE := 1.5

@export var speed: float = 8.5
@export var damage: float = 75.0
@export var lifetime: float = 16.0
@export var radius: float = 1.25
@export var fireball_visual_scene: PackedScene
@export var world_hit_grace_duration: float = 0.12

@onready var _collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var _visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D
@onready var _model_anchor: Node3D = get_node_or_null("VisualRoot/ModelAnchor") as Node3D
@onready var _glow_light: OmniLight3D = get_node_or_null("GlowLight") as OmniLight3D

var _velocity: Vector3 = Vector3.ZERO
var _life_left: float = 16.0
var _active: bool = true
var _phase: float = 0.0
var _base_visual_scale: Vector3 = Vector3.ONE
var _radius_visual_scale: float = 1.0
var _model_instance: Node3D
var _ground_impact_enabled: bool = false
var _world_hit_grace_left: float = 0.0
var _world_hit_source_rid: RID = RID()

func _ready() -> void:
	_life_left = lifetime
	if _collision_shape != null:
		_collision_shape.disabled = true
	if _visual_root != null:
		_base_visual_scale = _visual_root.scale
	_spawn_fireball_model()
	_apply_radius()

func configure_orb(direction: Vector3, speed_value: float, damage_value: float, radius_value: float) -> void:
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	_velocity = direction.normalized() * speed_value
	speed = speed_value
	damage = damage_value
	radius = radius_value
	_life_left = lifetime
	_phase = randf() * TAU
	_world_hit_grace_left = maxf(0.0, world_hit_grace_duration)
	if _velocity.length_squared() > 0.0001:
		look_at(global_position + _velocity.normalized(), Vector3.UP)
	_apply_radius()

func set_ground_impact_enabled(enabled: bool) -> void:
	_ground_impact_enabled = enabled

func set_world_hit_source(source: CollisionObject3D) -> void:
	if source == null or not is_instance_valid(source):
		_world_hit_source_rid = RID()
		return
	_world_hit_source_rid = source.get_rid()

func force_despawn() -> void:
	if not _active:
		return
	_active = false
	if _collision_shape != null:
		_collision_shape.disabled = true
	emit_signal("finished", self)
	queue_free()

func _physics_process(delta: float) -> void:
	if not _active:
		return
	if GameState.is_time_blocked():
		return
	if _world_hit_grace_left > 0.0:
		_world_hit_grace_left = maxf(0.0, _world_hit_grace_left - delta)
	var previous_position: Vector3 = global_position
	var next_position: Vector3 = previous_position + _velocity * delta
	if _ground_impact_enabled and _world_hit_grace_left <= 0.0:
		if _try_hit_world(previous_position, next_position):
			return
	global_position = next_position
	_phase = wrapf(_phase + delta * 7.4, 0.0, TAU)
	if _visual_root != null:
		var pulse: float = 0.9 + (sin(_phase * 1.7) * 0.5 + 0.5) * 0.24
		_visual_root.scale = _base_visual_scale * (_radius_visual_scale * pulse)
		_visual_root.rotate_object_local(Vector3.UP, delta * 5.6)
	if _glow_light != null:
		_glow_light.light_energy = 3.8 + (sin(_phase * 1.9) * 0.5 + 0.5) * 4.6
	if _try_hit_player():
		return
	_life_left = maxf(0.0, _life_left - delta)
	if _life_left <= 0.0:
		force_despawn()

func _try_hit_world(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	if _world_hit_source_rid.is_valid():
		query.exclude.append(_world_hit_source_rid)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider_variant: Variant = hit.get("collider", null)
	if collider_variant is Node and (collider_variant as Node).is_in_group("player"):
		var collider_node: Node = collider_variant as Node
		if collider_node.has_method("take_damage"):
			collider_node.call("take_damage", damage)
		_active = false
		var hit_position_player: Vector3 = hit.get("position", global_position)
		global_position = hit_position_player
		_orb_explode()
		return true
	_active = false
	var hit_position: Vector3 = hit.get("position", global_position)
	global_position = hit_position
	_orb_explode()
	return true

func get_distance_to_point(point: Vector3) -> float:
	return global_position.distance_to(point)

func _try_hit_player() -> bool:
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or not is_instance_valid(player):
		return false
	var collision_radius: float = _get_collision_radius()
	var hit_distance: float = maxf(0.55, collision_radius + 0.28)
	if global_position.distance_to(player.global_position + Vector3(0.0, 0.9, 0.0)) > hit_distance:
		return false
	if player.has_method("take_damage"):
		player.call("take_damage", damage)
	_active = false
	_orb_explode()
	return true

func _orb_explode() -> void:
	var flash: Tween = create_tween().set_parallel(true)
	if _visual_root != null:
		flash.tween_property(_visual_root, "scale", _base_visual_scale * (_radius_visual_scale * 2.9), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.tween_property(_visual_root, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.03)
	if _glow_light != null:
		flash.tween_property(_glow_light, "light_energy", 25.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.tween_property(_glow_light, "omni_range", 15.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.tween_property(_glow_light, "light_energy", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.08)
	await flash.finished
	emit_signal("finished", self)
	queue_free()

func _apply_radius() -> void:
	var clamped_radius: float = maxf(0.2, radius) * ORB_SCALE
	if _collision_shape != null and _collision_shape.shape is SphereShape3D:
		(_collision_shape.shape as SphereShape3D).radius = clamped_radius
	_radius_visual_scale = maxf(0.55, clamped_radius * 0.42)
	if _visual_root != null:
		_visual_root.scale = _base_visual_scale * _radius_visual_scale
	if _glow_light != null:
		_glow_light.omni_range = clamped_radius * 3.6

func _get_collision_radius() -> float:
	if _collision_shape != null and _collision_shape.shape is SphereShape3D:
		return (_collision_shape.shape as SphereShape3D).radius
	return maxf(0.2, radius) * ORB_SCALE

func _sanitize_imported_model(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Camera3D or child is Light3D:
			child.queue_free()
			continue
		_sanitize_imported_model(child)

func _spawn_fireball_model() -> void:
	if _model_anchor == null:
		return
	_model_instance = null
	if fireball_visual_scene != null:
		for child in _model_anchor.get_children():
			child.queue_free()
		var model_node: Node = fireball_visual_scene.instantiate()
		if model_node is Node3D:
			_model_instance = model_node as Node3D
			_model_anchor.add_child(_model_instance)
			_model_instance.position = Vector3.ZERO
			_model_instance.rotation = Vector3.ZERO
			_model_instance.scale = Vector3.ONE
			_sanitize_imported_model(_model_instance)
			return
		model_node.queue_free()
	if _model_anchor.get_child_count() > 0:
		var existing_model: Node = _model_anchor.get_child(0)
		if existing_model is Node3D:
			_model_instance = existing_model as Node3D
			return
	_spawn_fallback_fireball()

func _spawn_fallback_fireball() -> void:
	var fallback_mesh: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.62
	sphere.height = 1.24
	fallback_mesh.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.4, 0.18, 1.0)
	material.roughness = 0.12
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = Color(1.0, 0.42, 0.18, 1.0)
	material.emission_energy_multiplier = 3.2
	fallback_mesh.material_override = material
	_model_anchor.add_child(fallback_mesh)
	_model_instance = fallback_mesh
