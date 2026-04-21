extends Interactable

var _pickup_enabled: bool = false
var _base_visual_position: Vector3 = Vector3.ZERO
var _time: float = 0.0

@onready var _collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var _visual: Node3D = get_node_or_null("Visual") as Node3D
@onready var _ghost_red: Node3D = get_node_or_null("Visual/GhostRed") as Node3D
@onready var _ghost_blue: Node3D = get_node_or_null("Visual/GhostBlue") as Node3D

func _ready() -> void:
	if _visual != null:
		_base_visual_position = _visual.position
	set_pickup_enabled(false)

func _process(delta: float) -> void:
	_time += delta
	if _visual != null:
		_visual.position = _base_visual_position + Vector3(0.0, sin(_time * 1.9) * 0.07, 0.0)
		_visual.rotation = Vector3(0.0, _time * 1.3, sin(_time * 1.6) * 0.08)
	if _ghost_red != null:
		_ghost_red.position = Vector3(-0.045 + sin(_time * 12.0) * 0.012, 0.015 + cos(_time * 8.0) * 0.008, 0.0)
	if _ghost_blue != null:
		_ghost_blue.position = Vector3(0.05 + cos(_time * 10.0) * 0.014, -0.01 + sin(_time * 7.0) * 0.01, 0.015)

func set_pickup_enabled(enabled: bool) -> void:
	_pickup_enabled = enabled
	prompt_text = "Press E to pick up Axiom" if enabled else ""
	if _collision_shape != null:
		_collision_shape.disabled = not enabled

func interact() -> void:
	if not _pickup_enabled:
		return
	_play_pickup_feedback()
	GameState.equip_axiom()
	queue_free()

func _play_pickup_feedback() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var hud := players[0].get_node_or_null("PlayerHUD")
	if hud != null and hud.has_method("play_slot_pickup_effect"):
		hud.call("play_slot_pickup_effect", GameState.selected_slot)
