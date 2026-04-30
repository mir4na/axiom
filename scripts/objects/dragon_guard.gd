extends Interactable

signal defeated(dragon: Node3D)
signal mount_requested(dragon: Node3D)

@export var max_health: float = 240.0
@export var attack_damage: float = 10.0
@export var attack_interval: float = 1.1
@export var attack_range: float = 8.5

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _model_root: Node3D = $ModelRoot
@onready var _glow: OmniLight3D = $Glow
@onready var _health_bar_fill: MeshInstance3D = $HealthPivot/HealthFill

var _player: CharacterBody3D
var _health: float = 0.0
var _dead: bool = false
var _mount_enabled: bool = false
var _attack_timer: float = 0.0
var _highlight_enabled: bool = false

func _ready() -> void:
	add_to_group("enemy")
	_health = max_health
	prompt_text = ""
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_update_health_visual()
	if _glow != null:
		_glow.light_energy = 1.25

func _physics_process(delta: float) -> void:
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
	_face_player()
	_attack_timer = maxf(0.0, _attack_timer - delta)
	var distance: float = global_position.distance_to(_player.global_position)
	if distance <= attack_range and _attack_timer <= 0.0:
		_attack_timer = attack_interval
		if _player.has_method("take_damage"):
			_player.call("take_damage", attack_damage)

func take_damage(amount: float) -> void:
	if _dead:
		return
	_health = maxf(0.0, _health - amount)
	_update_health_visual()
	if _health <= 0.0:
		_die()

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
	_dead = true
	_attack_timer = 0.0
	prompt_text = ""
	if _glow != null:
		_glow.light_color = Color(0.12, 0.12, 0.14, 1.0)
		_glow.light_energy = 0.75
	if _model_root != null:
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(_model_root, "rotation_degrees", _model_root.rotation_degrees + Vector3(-12.0, 26.0, 0.0), 0.35)
		tween.tween_property(_model_root, "position", _model_root.position + Vector3(0.0, -0.8, 0.0), 0.35)
	defeated.emit(self)

func _update_health_visual() -> void:
	if _health_bar_fill == null:
		return
	var ratio: float = 0.0
	if max_health > 0.001:
		ratio = clampf(_health / max_health, 0.0, 1.0)
	var scale_value: float = maxf(0.001, ratio)
	_health_bar_fill.scale.x = scale_value
	_health_bar_fill.position.x = -0.8 + scale_value * 0.8
	_health_bar_fill.visible = not _dead

func _face_player() -> void:
	if _player == null:
		return
	var target: Vector3 = _player.global_position
	target.y = global_position.y
	look_at(target, Vector3.UP)
