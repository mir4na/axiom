extends Area3D

@export var bind_duration: float = 1.15
@export var damage: float = 45.0
@export var blast_radius: float = 2.0

const FALL_ATTACK_SCENE := preload("res://scenes/objects/axia_fall_attack.tscn")

@onready var _ring: MeshInstance3D = $Ring
@onready var _column: MeshInstance3D = $Column
@onready var _light: OmniLight3D = $Light

var _player: CharacterBody3D
var _timer: float = 0.0
var _active: bool = false
var _comet_summoned: bool = false

func configure(player_ref: CharacterBody3D, duration_value: float, damage_value: float, radius_value: float) -> void:
	_player = player_ref
	bind_duration = duration_value
	damage = damage_value
	blast_radius = radius_value
	_timer = bind_duration
	_active = true
	_comet_summoned = false
	_ring.scale = Vector3.ONE
	_column.scale = Vector3.ONE
	if _player != null and is_instance_valid(_player):
		_player.call("set_mobility_lock", true)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if not _active:
		return
	if GameState.is_paused or GameState.rewind_mode_active or GameState.time_direction != 1 or GameState.is_scrubbing_past:
		return
	_timer -= delta
	var pulse: float = 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.015)
	_ring.scale = Vector3.ONE * pulse
	_column.scale = Vector3(1.0 + pulse * 0.08, 1.0, 1.0 + pulse * 0.08)
	if _timer <= 0.0 and not _comet_summoned:
		_summon_comet()
	if _timer <= -0.55:
		_release_player()
		queue_free()

func _summon_comet() -> void:
	_comet_summoned = true
	var comet: Node3D = FALL_ATTACK_SCENE.instantiate() as Node3D
	if comet == null:
		return
	get_parent().add_child(comet)
	comet.call("configure_attack", global_position, _player, damage, blast_radius, 0.0, 0.42, false, 1.18)

func _on_body_entered(body: Node) -> void:
	if body == _player and _player != null and is_instance_valid(_player):
		_player.call("set_mobility_lock", true)

func _on_body_exited(body: Node) -> void:
	if body == _player and _player != null and is_instance_valid(_player):
		_player.call("set_mobility_lock", false)

func _release_player() -> void:
	if _player != null and is_instance_valid(_player):
		_player.call("set_mobility_lock", false)
