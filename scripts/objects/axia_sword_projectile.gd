extends Area3D

@export var speed: float = 9.0
@export var damage: float = 10.0
@export var lifetime: float = 4.5

@onready var _visual_root: Node3D = $VisualRoot
@onready var _trail: MeshInstance3D = $VisualRoot/Trail
@onready var _blade_body: MeshInstance3D = $VisualRoot/BladeBody
@onready var _blade_edge: MeshInstance3D = $VisualRoot/BladeEdge
@onready var _impact_flash: MeshInstance3D = $VisualRoot/ImpactFlash
@onready var _light: OmniLight3D = $Light

var _direction: Vector3 = Vector3.FORWARD
var _life_left: float = 0.0
var _player: CharacterBody3D
var _active: bool = false
var _impacting: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_life_left = lifetime
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D

func configure(direction: Vector3, speed_value: float, damage_value: float, player_ref: CharacterBody3D) -> void:
	_direction = direction.normalized()
	if _direction.length_squared() <= 0.0001:
		_direction = Vector3.FORWARD
	speed = speed_value
	damage = damage_value
	_player = player_ref
	_active = true
	look_at(global_position + _direction, Vector3.UP)
	rotate_y(PI)

func _physics_process(delta: float) -> void:
	if not _active:
		return
	if GameState.is_paused or GameState.rewind_mode_active or GameState.time_direction != 1 or GameState.is_scrubbing_past:
		return
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	global_position += _direction * speed * delta
	_visual_root.rotate_z(delta * 6.2)
	if _trail != null:
		_trail.scale = Vector3(1.0 + sin(Time.get_ticks_msec() * 0.014) * 0.1, 0.7 + sin(Time.get_ticks_msec() * 0.012) * 0.08, 1.0)
	if _blade_edge != null:
		_blade_edge.scale.x = 1.02 + sin(Time.get_ticks_msec() * 0.016) * 0.06
	if _light != null:
		_light.light_energy = 1.9 + sin(Time.get_ticks_msec() * 0.018) * 0.45
	if _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position + Vector3.UP * 0.9) <= 0.75:
			_trigger_hit()

func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	if body == _player:
		_trigger_hit()

func _trigger_hit() -> void:
	if _impacting:
		return
	if _player != null and is_instance_valid(_player) and _player.has_method("take_damage"):
		_player.call("take_damage", damage)
	_impacting = true
	_active = false
	call_deferred("_play_impact")

func _play_impact() -> void:
	if _impact_flash != null:
		_impact_flash.visible = true
	var burst: Tween = create_tween().set_parallel(true)
	burst.tween_property(_visual_root, "scale", Vector3.ONE * 1.7, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _light != null:
		burst.tween_property(_light, "light_energy", 5.8, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await burst.finished
	var fade: Tween = create_tween().set_parallel(true)
	fade.tween_property(_visual_root, "scale", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _light != null:
		fade.tween_property(_light, "light_energy", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade.finished
	queue_free()
