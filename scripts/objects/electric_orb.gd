extends CharacterBody3D

signal finished(projectile: Node3D)

const ORB_SCALE := 1.5

@export var speed: float = 8.5
@export var damage: float = 75.0
@export var lifetime: float = 16.0
@export var radius: float = 2.9

@onready var _collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var _core_shard: MeshInstance3D = get_node_or_null("CoreShard") as MeshInstance3D
@onready var _side_shard_a: MeshInstance3D = get_node_or_null("SideShardA") as MeshInstance3D
@onready var _side_shard_b: MeshInstance3D = get_node_or_null("SideShardB") as MeshInstance3D
@onready var _side_shard_c: MeshInstance3D = get_node_or_null("SideShardC") as MeshInstance3D
@onready var _trail_shard: MeshInstance3D = get_node_or_null("TrailShard") as MeshInstance3D
@onready var _glow_light: OmniLight3D = get_node_or_null("GlowLight") as OmniLight3D

var _velocity: Vector3 = Vector3.ZERO
var _life_left: float = 16.0
var _active: bool = true
var _phase: float = 0.0
var _base_core_scale: Vector3 = Vector3.ONE
var _base_side_a_scale: Vector3 = Vector3.ONE
var _base_side_b_scale: Vector3 = Vector3.ONE
var _base_side_c_scale: Vector3 = Vector3.ONE
var _base_trail_scale: Vector3 = Vector3.ONE
var _base_side_a_rotation: Vector3 = Vector3.ZERO
var _base_side_b_rotation: Vector3 = Vector3.ZERO
var _base_side_c_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	_life_left = lifetime
	if _collision_shape != null:
		_collision_shape.disabled = true
	if _core_shard != null:
		_base_core_scale = _core_shard.scale
	if _side_shard_a != null:
		_base_side_a_scale = _side_shard_a.scale
		_base_side_a_rotation = _side_shard_a.rotation
	if _side_shard_b != null:
		_base_side_b_scale = _side_shard_b.scale
		_base_side_b_rotation = _side_shard_b.rotation
	if _side_shard_c != null:
		_base_side_c_scale = _side_shard_c.scale
		_base_side_c_rotation = _side_shard_c.rotation
	if _trail_shard != null:
		_base_trail_scale = _trail_shard.scale
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
	if _velocity.length_squared() > 0.0001:
		look_at(global_position + _velocity.normalized(), Vector3.UP)
	_apply_radius()

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
	if GameState.rewind_mode_active:
		return
	global_position += _velocity * delta
	_phase = wrapf(_phase + delta * 9.6, 0.0, TAU)
	if _core_shard != null:
		var core_pulse: float = 0.88 + (sin(_phase * 1.3) * 0.5 + 0.5) * 0.24
		_core_shard.scale = _base_core_scale * core_pulse
		_core_shard.rotate_object_local(Vector3(0.0, 0.0, 1.0), delta * 14.0)
	if _side_shard_a != null:
		var side_a_pulse: float = 0.72 + (sin(_phase * 2.0 + 0.55) * 0.5 + 0.5) * 0.6
		_side_shard_a.scale = _base_side_a_scale * side_a_pulse
		_side_shard_a.rotation = _base_side_a_rotation + Vector3(sin(_phase * 1.9) * 0.15, 0.0, cos(_phase * 2.2) * 0.2)
	if _side_shard_b != null:
		var side_b_pulse: float = 0.7 + (sin(_phase * 2.4 + 1.3) * 0.5 + 0.5) * 0.62
		_side_shard_b.scale = _base_side_b_scale * side_b_pulse
		_side_shard_b.rotation = _base_side_b_rotation + Vector3(cos(_phase * 2.1) * 0.16, 0.0, sin(_phase * 2.8) * 0.18)
	if _side_shard_c != null:
		var side_c_pulse: float = 0.68 + (sin(_phase * 2.2 + 2.1) * 0.5 + 0.5) * 0.64
		_side_shard_c.scale = _base_side_c_scale * side_c_pulse
		_side_shard_c.rotation = _base_side_c_rotation + Vector3(sin(_phase * 2.6) * 0.17, 0.0, cos(_phase * 2.0) * 0.2)
	if _trail_shard != null:
		var trail_pulse: float = 0.8 + (sin(_phase * 2.7 + 0.7) * 0.5 + 0.5) * 0.22
		_trail_shard.scale = _base_trail_scale * trail_pulse
	if _glow_light != null:
		_glow_light.light_energy = 4.2 + (sin(_phase * 1.7) * 0.5 + 0.5) * 3.4
	if _try_hit_player():
		return
	_life_left = maxf(0.0, _life_left - delta)
	if _life_left <= 0.0:
		force_despawn()

func get_distance_to_point(point: Vector3) -> float:
	return global_position.distance_to(point)

func _try_hit_player() -> bool:
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or not is_instance_valid(player):
		return false
	var hit_distance: float = maxf(0.6, radius * ORB_SCALE + 0.62)
	if global_position.distance_to(player.global_position + Vector3(0.0, 0.9, 0.0)) > hit_distance:
		return false
	if player.has_method("take_damage"):
		player.call("take_damage", damage)
	_active = false
	_orb_explode()
	return true

func _orb_explode() -> void:
	var flash: Tween = create_tween().set_parallel(true)
	if _core_shard != null:
		flash.tween_property(_core_shard, "scale", _base_core_scale * 3.4, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.tween_property(_core_shard, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.02)
	if _side_shard_a != null:
		flash.tween_property(_side_shard_a, "scale", _base_side_a_scale * 2.8, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.tween_property(_side_shard_a, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.02)
	if _side_shard_b != null:
		flash.tween_property(_side_shard_b, "scale", _base_side_b_scale * 2.8, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.tween_property(_side_shard_b, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.02)
	if _side_shard_c != null:
		flash.tween_property(_side_shard_c, "scale", _base_side_c_scale * 2.8, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.tween_property(_side_shard_c, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.02)
	if _trail_shard != null:
		flash.tween_property(_trail_shard, "scale", _base_trail_scale * 2.4, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.tween_property(_trail_shard, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.03)
	if _glow_light != null:
		flash.tween_property(_glow_light, "light_energy", 24.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.tween_property(_glow_light, "omni_range", 15.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.tween_property(_glow_light, "light_energy", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.08)
	await flash.finished
	emit_signal("finished", self)
	queue_free()

func _apply_radius() -> void:
	var clamped_radius: float = maxf(0.2, radius) * ORB_SCALE
	if _collision_shape != null and _collision_shape.shape is SphereShape3D:
		(_collision_shape.shape as SphereShape3D).radius = clamped_radius
	if _core_shard != null and _core_shard.mesh is SphereMesh:
		var core_mesh: SphereMesh = _core_shard.mesh as SphereMesh
		core_mesh.radius = clamped_radius * 0.52
		core_mesh.height = clamped_radius * 1.04
	if _side_shard_a != null and _side_shard_a.mesh is BoxMesh:
		var side_mesh_a: BoxMesh = _side_shard_a.mesh as BoxMesh
		side_mesh_a.size = Vector3(clamped_radius * 0.2, clamped_radius * 0.18, clamped_radius * 0.62)
	if _side_shard_b != null and _side_shard_b.mesh is BoxMesh:
		var side_mesh_b: BoxMesh = _side_shard_b.mesh as BoxMesh
		side_mesh_b.size = Vector3(clamped_radius * 0.2, clamped_radius * 0.18, clamped_radius * 0.62)
	if _side_shard_c != null and _side_shard_c.mesh is BoxMesh:
		var side_mesh_c: BoxMesh = _side_shard_c.mesh as BoxMesh
		side_mesh_c.size = Vector3(clamped_radius * 0.2, clamped_radius * 0.18, clamped_radius * 0.62)
	if _trail_shard != null and _trail_shard.mesh is BoxMesh:
		var trail_mesh: BoxMesh = _trail_shard.mesh as BoxMesh
		trail_mesh.size = Vector3(clamped_radius * 0.34, clamped_radius * 0.28, clamped_radius * 1.05)
	if _glow_light != null:
		_glow_light.omni_range = clamped_radius * 3.6
