extends CharacterBody3D

@export var default_motion: StringName = &"idle"
@export var move_speed_scale: float = 0.8

@onready var base_visual: Node3D = $"Rose FBX"
@onready var idle_visual: Node3D = $Motions/Idle
@onready var move_visual: Node3D = $Motions/Move
@onready var jump_visual: Node3D = $Motions/Jump
@onready var die_visual: Node3D = $Motions/Die

var _players: Dictionary = {}
var _current_motion: StringName = &""

func _ready() -> void:
	base_visual.visible = false
	_register_motion(&"idle", idle_visual)
	_register_motion(&"move", move_visual)
	_register_motion(&"jump", jump_visual)
	_register_motion(&"die", die_visual)
	play_motion(default_motion)

func play_motion(motion: StringName, speed_scale: float = 1.0) -> void:
	if not _players.has(String(motion)):
		return
	_current_motion = motion
	idle_visual.visible = motion == &"idle"
	move_visual.visible = motion == &"move"
	jump_visual.visible = motion == &"jump"
	die_visual.visible = motion == &"die"
	var player: AnimationPlayer = _players[String(motion)]
	player.speed_scale = speed_scale
	var animations := player.get_animation_list()
	if animations.size() > 0:
		var animation_name: StringName = animations[0]
		if player.current_animation != animation_name:
			player.play(animation_name)

func play_idle() -> void:
	play_motion(&"idle")

func play_move(is_sprinting: bool = false) -> void:
	play_motion(&"move", 1.0 if is_sprinting else move_speed_scale)

func play_jump() -> void:
	play_motion(&"jump")

func play_die() -> void:
	play_motion(&"die")

func get_current_motion() -> StringName:
	return _current_motion

func _register_motion(name: StringName, visual: Node) -> void:
	_disable_runtime_side_effects(visual)
	var player := _find_animation_player(visual)
	if player != null:
		var animations := player.get_animation_list()
		if animations.size() > 0:
			player.play(animations[0])
		_players[String(name)] = player

func _disable_runtime_side_effects(node: Node) -> void:
	if node is Light3D:
		node.visible = false
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_runtime_side_effects(child)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var player := _find_animation_player(child)
		if player != null:
			return player
	return null
