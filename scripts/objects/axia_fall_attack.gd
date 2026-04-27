extends Node3D

@export var damage: float = 40.0
@export var radius: float = 2.1
@export var warning_duration: float = 1.15
@export var fall_duration: float = 0.5
@export var fall_height: float = 14.0
@export var meteor_scale: float = 1.0

@onready var _telegraph: MeshInstance3D = $Telegraph
@onready var _meteor_root: Node3D = $MeteorRoot
@onready var _meteor_core: MeshInstance3D = $MeteorRoot/Core
@onready var _meteor_shard_a: MeshInstance3D = $MeteorRoot/ShardA
@onready var _meteor_shard_b: MeshInstance3D = $MeteorRoot/ShardB
@onready var _light: OmniLight3D = $Light

var _player: CharacterBody3D
var _target_position: Vector3 = Vector3.ZERO
var _warning_left: float = 0.0
var _fall_left: float = 0.0
var _active: bool = false
var _falling: bool = false
var _impact_done: bool = false
var _show_telegraph: bool = true

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_telegraph.visible = false
	_meteor_root.visible = false
	_light.visible = false

func configure_attack(target_position: Vector3, player_ref: CharacterBody3D, damage_value: float, radius_value: float, warning_value: float, fall_value: float, show_telegraph_value: bool = true, scale_value: float = 1.0) -> void:
	_target_position = target_position
	_player = player_ref
	damage = damage_value
	radius = radius_value
	warning_duration = warning_value
	fall_duration = fall_value
	_show_telegraph = show_telegraph_value
	meteor_scale = scale_value
	_warning_left = warning_duration
	_fall_left = fall_duration
	_active = true
	_falling = false
	_impact_done = false
	global_position = _target_position
	_telegraph.visible = _show_telegraph
	_telegraph.scale = Vector3(radius, 1.0, radius)
	_meteor_root.visible = false
	_meteor_root.scale = Vector3.ONE * meteor_scale
	_light.visible = _show_telegraph
	_light.global_position = _target_position + Vector3.UP * 0.4
	if _show_telegraph:
		_light.light_color = Color(1.0, 0.16, 0.1, 1.0)
		_light.light_energy = 1.8
	else:
		_light.light_color = Color(0.86, 0.94, 1.0, 1.0)
		_light.light_energy = 2.6

func _physics_process(delta: float) -> void:
	if not _active:
		return
	if GameState.is_paused or GameState.rewind_mode_active or GameState.time_direction != 1 or GameState.is_scrubbing_past:
		return
	if not _falling:
		_warning_left -= delta
		_update_warning_visual()
		if _warning_left <= 0.0:
			_start_fall()
		return
	_fall_left = maxf(0.0, _fall_left - delta)
	var ratio: float = 1.0 - (_fall_left / maxf(fall_duration, 0.001))
	var start_position: Vector3 = _target_position + Vector3.UP * fall_height
	_meteor_root.global_position = start_position.lerp(_target_position + Vector3.UP * 0.4, ratio)
	_meteor_root.rotate_y(delta * 6.8)
	_meteor_shard_a.rotate_x(delta * 7.2)
	_meteor_shard_b.rotate_z(delta * 8.6)
	if _light != null:
		_light.global_position = _meteor_root.global_position
		_light.light_energy = 3.0 + ratio * 3.8
	if _fall_left <= 0.0 and not _impact_done:
		_impact()

func _update_warning_visual() -> void:
	if not _show_telegraph or _telegraph == null:
		return
	var pulse: float = 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.02)
	_telegraph.scale = Vector3.ONE * radius * pulse

func _start_fall() -> void:
	_falling = true
	_telegraph.visible = false
	_meteor_root.visible = true
	_meteor_root.global_position = _target_position + Vector3.UP * fall_height
	if _light != null:
		_light.visible = true
		_light.global_position = _meteor_root.global_position

func _impact() -> void:
	_impact_done = true
	_active = false
	if _player != null and is_instance_valid(_player):
		var player_distance: float = _player.global_position.distance_to(_target_position)
		if player_distance <= radius and _player.has_method("take_damage"):
			_player.call("take_damage", damage)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_meteor_root, "scale", Vector3.ONE * meteor_scale * 3.8, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _light != null:
		tween.tween_property(_light, "light_energy", 10.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	var fade: Tween = create_tween().set_parallel(true)
	fade.tween_property(_meteor_root, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _light != null:
		fade.tween_property(_light, "light_energy", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade.finished
	queue_free()
