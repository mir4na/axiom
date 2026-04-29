extends Area3D

@export var bind_duration: float = 5.0
@export var damage: float = 50.0
@export var blast_radius: float = 4.2
@export var wave_expand_duration: float = 1.4
@export var wave_start_scale: float = 0.2
@export var wave_end_scale: float = 18.0
@export var column_height_scale: float = 2.2
@export var spear_height: float = 8.2
@export var spear_track_lerp: float = 4.8
@export var spear_strike_duration: float = 0.22
@export var spear_fade_duration: float = 0.25

const SNARE_INDICATOR_SCENE := preload("res://scenes/objects/axia_snare_indicator.tscn")
const SNARE_SPEAR_SCENE := preload("res://scenes/objects/axia_snare_spear.tscn")

@onready var _ring: MeshInstance3D = $Ring
@onready var _column: MeshInstance3D = $Column
@onready var _light: OmniLight3D = $Light

var _player: CharacterBody3D
var _caster: Node3D
var _timer: float = 0.0
var _active: bool = false
var _released: bool = false
var _strike_started: bool = false
var _anchor_position: Vector3 = Vector3.ZERO
var _locked_target_position: Vector3 = Vector3.ZERO
var _indicator_root: CanvasLayer
var _indicator_bar: ProgressBar
var _wave_tween: Tween
var _spear_root: Node3D

func configure(player_ref: CharacterBody3D, duration_value: float, damage_value: float, radius_value: float, caster_ref: Node3D = null) -> void:
	_player = player_ref
	_caster = caster_ref
	bind_duration = maxf(duration_value, 0.1)
	damage = damage_value
	blast_radius = maxf(radius_value, 0.2)
	_timer = bind_duration
	_active = true
	_released = false
	_strike_started = false
	_anchor_position = global_position
	_locked_target_position = _anchor_position + Vector3(0.0, 0.85, 0.0)
	if _caster != null and is_instance_valid(_caster):
		_anchor_position = Vector3(_caster.global_position.x, global_position.y, _caster.global_position.z)
	if _player != null and is_instance_valid(_player):
		_locked_target_position = _player.global_position + Vector3(0.0, 0.85, 0.0)
	global_position = _anchor_position
	_setup_visuals()
	_spawn_indicator()
	_spawn_spear()
	_apply_player_time_stop(true)
	_start_wave()

func _ready() -> void:
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null:
		shape_node.disabled = true

func _physics_process(delta: float) -> void:
	if not _active:
		return
	if GameState.is_time_blocked():
		return
	global_position = _anchor_position
	_timer = maxf(_timer - delta, 0.0)
	_update_indicator()
	_update_visuals(delta)
	_update_spear_tracking(delta)
	if _timer <= 0.0 and not _strike_started:
		_strike_started = true
		call_deferred("_strike_with_spear")

func _exit_tree() -> void:
	_apply_player_time_stop(false)
	_cleanup_indicator()
	_cleanup_spear()

func _setup_visuals() -> void:
	_ring.visible = true
	_column.visible = true
	if _light != null:
		_light.visible = true
		_light.light_color = Color(0.28, 0.92, 0.55, 1.0)
		_light.light_energy = 4.8
	_ring.scale = Vector3.ONE * wave_start_scale
	_column.scale = Vector3(0.24, column_height_scale, 0.24)

func _start_wave() -> void:
	if _wave_tween != null and _wave_tween.is_valid():
		_wave_tween.kill()
	_wave_tween = create_tween().set_parallel(true)
	_wave_tween.tween_property(_ring, "scale", Vector3.ONE * wave_end_scale, wave_expand_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_wave_tween.parallel().tween_property(_column, "scale", Vector3(wave_end_scale * 0.12, column_height_scale, wave_end_scale * 0.12), wave_expand_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _update_visuals(delta: float) -> void:
	if _ring != null:
		_ring.rotate_y(delta * 1.6)
	if _column != null:
		var pulse: float = 0.88 + sin(Time.get_ticks_msec() * 0.014) * 0.12
		_column.scale.y = column_height_scale * pulse
	if _light != null:
		_light.light_energy = 4.2 + sin(Time.get_ticks_msec() * 0.02) * 0.9

func _spawn_indicator() -> void:
	_cleanup_indicator()
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
	if _indicator_bar == null:
		return
	var ratio: float = clampf(_timer / maxf(bind_duration, 0.001), 0.0, 1.0)
	_indicator_bar.value = ratio * 100.0

func _spawn_spear() -> void:
	_cleanup_spear()
	_spear_root = SNARE_SPEAR_SCENE.instantiate() as Node3D
	if _spear_root == null:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	parent.add_child(_spear_root)
	_update_spear_tracking(0.0)

func _update_spear_tracking(delta: float) -> void:
	if _spear_root == null or not is_instance_valid(_spear_root):
		return
	if _strike_started:
		return
	var caster_origin: Vector3 = _anchor_position + Vector3.UP * spear_height
	if _caster != null and is_instance_valid(_caster):
		caster_origin = _caster.global_position + Vector3.UP * spear_height
	var wobble: Vector3 = Vector3(sin(Time.get_ticks_msec() * 0.0045) * 0.2, sin(Time.get_ticks_msec() * 0.0062) * 0.12, cos(Time.get_ticks_msec() * 0.004) * 0.2)
	var desired_origin: Vector3 = caster_origin + wobble
	_spear_root.global_position = _spear_root.global_position.lerp(desired_origin, clampf(delta * spear_track_lerp, 0.0, 1.0))
	_orient_spear_toward(_locked_target_position)

func _strike_with_spear() -> void:
	if _released:
		return
	_active = false
	var strike_target: Vector3 = _locked_target_position
	if _spear_root != null and is_instance_valid(_spear_root):
		_orient_spear_toward(strike_target)
		var strike: Tween = create_tween().set_parallel(true)
		strike.tween_property(_spear_root, "global_position", strike_target + Vector3(0.0, 0.2, 0.0), spear_strike_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if _light != null and is_instance_valid(_light):
			strike.parallel().tween_property(_light, "light_energy", 9.4, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await _await_tween_with_time_control(strike)
	_apply_strike_damage(strike_target)
	if _spear_root != null and is_instance_valid(_spear_root):
		var fade: Tween = create_tween().set_parallel(true)
		fade.tween_property(_spear_root, "scale", Vector3.ZERO, spear_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if _light != null and is_instance_valid(_light):
			fade.parallel().tween_property(_light, "light_energy", 1.8, spear_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await _await_tween_with_time_control(fade)
	_cleanup_spear()
	_release_player()

func _apply_strike_damage(strike_target: Vector3) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _player.has_method("take_damage"):
		return
	if _player.global_position.distance_to(strike_target) <= blast_radius:
		_player.call("take_damage", damage)

func _release_player() -> void:
	if _released:
		return
	_released = true
	_active = false
	_apply_player_time_stop(false)
	_cleanup_indicator()
	if _wave_tween != null and _wave_tween.is_valid():
		_wave_tween.kill()
	_ring.visible = false
	_column.visible = false
	if _light != null and is_instance_valid(_light):
		var fade: Tween = create_tween()
		fade.tween_property(_light, "light_energy", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await fade.finished
	_cleanup_spear()
	if not is_queued_for_deletion():
		queue_free()

func _apply_player_time_stop(active: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_method("set_mobility_lock"):
		_player.call("set_mobility_lock", active)
	if _player.has_method("set_time_stop_active"):
		if active:
			_player.call("set_time_stop_active", true, _anchor_position, wave_expand_duration)
		else:
			_player.call("set_time_stop_active", false, Vector3.ZERO, 0.2)

func _cleanup_indicator() -> void:
	if _indicator_root != null and is_instance_valid(_indicator_root):
		_indicator_root.queue_free()
	_indicator_root = null
	_indicator_bar = null

func _cleanup_spear() -> void:
	if _spear_root != null and is_instance_valid(_spear_root):
		_spear_root.queue_free()
	_spear_root = null

func _orient_spear_toward(target_position: Vector3) -> void:
	if _spear_root == null or not is_instance_valid(_spear_root):
		return
	_spear_root.look_at(target_position, Vector3.UP)
	_spear_root.rotate_object_local(Vector3.RIGHT, -PI * 0.5)

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
		var tree: SceneTree = get_tree()
		if tree == null:
			return
		await tree.process_frame
