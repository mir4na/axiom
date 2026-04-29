extends Area3D

@export var bind_duration: float = 1.15
@export var damage: float = 45.0
@export var blast_radius: float = 2.0
@export var indicator_height: float = 2.9
@export var spear_height: float = 8.2
@export var spear_track_lerp: float = 4.8
@export var spear_strike_duration: float = 0.22
@export var spear_fade_duration: float = 0.25
@export var spear_release_delay: float = 0.95

const SNARE_INDICATOR_SCENE := preload("res://scenes/objects/axia_snare_indicator.tscn")
const SNARE_SPEAR_SCENE := preload("res://scenes/objects/axia_snare_spear.tscn")

@onready var _ring: MeshInstance3D = $Ring
@onready var _column: MeshInstance3D = $Column
@onready var _light: OmniLight3D = $Light

var _player: CharacterBody3D
var _timer: float = 0.0
var _active: bool = false
var _caster: Node3D
var _strike_started: bool = false
var _strike_finished: bool = false
var _released: bool = false
var _indicator_root: CanvasLayer
var _indicator_bar: ProgressBar
var _spear_root: Node3D
var _snare_anchor_position: Vector3 = Vector3.ZERO
var _strike_target_position: Vector3 = Vector3.ZERO

func configure(player_ref: CharacterBody3D, duration_value: float, damage_value: float, radius_value: float, caster_ref: Node3D = null) -> void:
	_player = player_ref
	bind_duration = duration_value
	damage = damage_value
	blast_radius = radius_value
	_caster = caster_ref
	_timer = bind_duration
	_active = true
	_strike_started = false
	_strike_finished = false
	_released = false
	_snare_anchor_position = global_position
	if _player != null and is_instance_valid(_player):
		_snare_anchor_position = Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
	_strike_target_position = _snare_anchor_position + Vector3(0.0, 0.85, 0.0)
	global_position = _snare_anchor_position
	_ring.scale = Vector3.ONE
	_column.scale = Vector3.ONE
	_ring.visible = true
	_column.visible = true
	if _light != null:
		_light.visible = true
		_light.light_color = Color(0.3, 1.0, 0.42, 1.0)
		_light.light_energy = 5.1
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null:
		shape_node.disabled = false
	if _player != null and is_instance_valid(_player):
		_player.call("set_mobility_lock", true)
	_spawn_indicator()
	_spawn_spear()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if not _active:
		return
	if GameState.is_time_blocked():
		return
	global_position = _snare_anchor_position
	_timer -= delta
	var pulse: float = 0.92 + 0.1 * sin(Time.get_ticks_msec() * 0.015)
	_ring.scale = Vector3.ONE * pulse
	_column.scale = Vector3(1.04 + pulse * 0.08, 1.0, 1.04 + pulse * 0.08)
	_update_indicator()
	_update_spear_tracking(delta)
	if _timer <= 0.0 and not _strike_started:
		_strike_started = true
		call_deferred("_strike_with_spear")
	if _timer <= -spear_release_delay and not _released:
		_release_player()

func _spawn_indicator() -> void:
	if _indicator_root != null and is_instance_valid(_indicator_root):
		_indicator_root.queue_free()
	_indicator_root = SNARE_INDICATOR_SCENE.instantiate() as CanvasLayer
	if _indicator_root == null:
		return
	get_tree().root.add_child(_indicator_root)
	_indicator_bar = _indicator_root.get_node_or_null("Root/Frame/Bar") as ProgressBar
	if _indicator_bar != null:
		_indicator_bar.value = 100.0

func _update_indicator() -> void:
	if _indicator_root == null or not is_instance_valid(_indicator_root):
		return
	var ratio: float = clampf(_timer / maxf(bind_duration, 0.001), 0.0, 1.0)
	if _indicator_bar != null:
		_indicator_bar.value = ratio * 100.0

func _spawn_spear() -> void:
	if _spear_root != null and is_instance_valid(_spear_root):
		_spear_root.queue_free()
	_spear_root = SNARE_SPEAR_SCENE.instantiate() as Node3D
	if _spear_root == null:
		return
	get_parent().add_child(_spear_root)
	_update_spear_tracking(0.0)

func _update_spear_tracking(delta: float) -> void:
	if _spear_root == null or not is_instance_valid(_spear_root):
		return
	if _strike_started:
		return
	var caster_origin: Vector3 = global_position + Vector3.UP * spear_height
	if _caster != null and is_instance_valid(_caster):
		caster_origin = _caster.global_position + Vector3.UP * spear_height
	if _player != null and is_instance_valid(_player):
		var wobble: Vector3 = Vector3(sin(Time.get_ticks_msec() * 0.0045) * 0.2, sin(Time.get_ticks_msec() * 0.0062) * 0.12, cos(Time.get_ticks_msec() * 0.004) * 0.2)
		var desired_origin: Vector3 = caster_origin + wobble
		_spear_root.global_position = _spear_root.global_position.lerp(desired_origin, clampf(delta * spear_track_lerp, 0.0, 1.0))
		_orient_spear_toward(_strike_target_position)
	else:
		_spear_root.global_position = caster_origin

func _strike_with_spear() -> void:
	if _strike_finished:
		return
	_strike_finished = true
	_hide_snare_field()
	if _spear_root == null or not is_instance_valid(_spear_root):
		_release_player()
		return
	if _player == null or not is_instance_valid(_player):
		_release_player()
		return
	var strike_target: Vector3 = _strike_target_position
	_orient_spear_toward(strike_target)
	var strike: Tween = create_tween().set_parallel(true)
	strike.tween_property(_spear_root, "global_position", strike_target + Vector3(0.0, 0.2, 0.0), spear_strike_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if _light != null:
		strike.parallel().tween_property(_light, "light_energy", 9.4, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _await_tween_with_time_control(strike)
	if _player != null and is_instance_valid(_player) and _player.has_method("take_damage"):
		if _player.global_position.distance_to(strike_target) <= blast_radius:
			_player.call("take_damage", damage)
	var fade: Tween = create_tween().set_parallel(true)
	fade.tween_property(_spear_root, "scale", Vector3.ZERO, spear_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _light != null:
		fade.parallel().tween_property(_light, "light_energy", 1.8, spear_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _await_tween_with_time_control(fade)
	if _spear_root != null and is_instance_valid(_spear_root):
		_spear_root.queue_free()
	_release_player()

func _on_body_entered(body: Node) -> void:
	if body == _player and _player != null and is_instance_valid(_player):
		_player.call("set_mobility_lock", true)

func _on_body_exited(body: Node) -> void:
	if body == _player:
		return

func _release_player() -> void:
	_released = true
	_active = false
	_hide_snare_field()
	if _player != null and is_instance_valid(_player):
		_player.call("set_mobility_lock", false)
	if _indicator_root != null and is_instance_valid(_indicator_root):
		_indicator_root.queue_free()
		_indicator_root = null
		_indicator_bar = null
	if _spear_root != null and is_instance_valid(_spear_root):
		_spear_root.queue_free()
		_spear_root = null
	if not is_queued_for_deletion():
		queue_free()

func _hide_snare_field() -> void:
	if _ring != null:
		_ring.visible = false
	if _column != null:
		_column.visible = false
	if _light != null:
		_light.visible = false
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null:
		shape_node.disabled = true

func _orient_spear_toward(target_position: Vector3) -> void:
	if _spear_root == null or not is_instance_valid(_spear_root):
		return
	_spear_root.look_at(target_position, Vector3.UP)
	_spear_root.rotate_object_local(Vector3.RIGHT, PI * 0.5)

func _is_time_state_blocked() -> bool:
	return GameState.is_time_blocked()

func _await_tween_with_time_control(tween: Tween) -> void:
	if tween == null:
		return
	while tween.is_valid():
		if _is_time_state_blocked():
			tween.pause()
		else:
			tween.play()
		if not tween.is_running() and not _is_time_state_blocked():
			break
		await get_tree().process_frame
