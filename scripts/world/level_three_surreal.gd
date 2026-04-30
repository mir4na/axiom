extends Node3D

const LEVEL_FOUR_SCENE_PATH := "res://scenes/levels/level_04.tscn"

enum Stage {
	TAKE_BOOTS,
	TRIGGER_REWIND,
	CROSS_AND_FIGHT,
	TAKE_KEYCARD,
	TAME_DRAGON,
	USE_GATE,
	DONE
}

@export var bob_speed: float = 0.8
@export var bob_height: float = 0.55
@export var spin_speed: float = 0.24

@onready var _world: Node = $World
@onready var _player: CharacterBody3D = $World/Player
@onready var _boots = $World/JumpingBoots
@onready var _boots_platform: Node3D = $World/Platforms/BootsPlatform
@onready var _dragon_guard = $World/DragonGuard
@onready var _dragon_keycard = $World/DragonKeycard
@onready var _level_gate = $World/Level4Gate
@onready var _ride_start: Marker3D = $World/DragonRidePath/Start
@onready var _ride_mid: Marker3D = $World/DragonRidePath/Mid
@onready var _ride_end: Marker3D = $World/DragonRidePath/End
@onready var _player_drop: Marker3D = $World/DragonRidePath/PlayerDrop
@onready var _bridge_root: Node3D = $World/Platforms/BridgePlatforms

var _stage: Stage = Stage.TAKE_BOOTS
var _base_jump_power: float = 4.5
var _ride_running: bool = false
var _collapse_started: bool = false
var _time: float = 0.0
var _floating_nodes: Array[Node3D] = []
var _base_positions: Dictionary = {}
var _phase_map: Dictionary = {}

func _ready() -> void:
	if _player != null:
		_base_jump_power = _player.jump_power
	_collect_floaters()
	_set_bridge_enabled(false)
	if _dragon_keycard != null and _dragon_keycard.has_method("set_interactable_enabled"):
		_dragon_keycard.call("set_interactable_enabled", false)
	if _dragon_keycard != null:
		_dragon_keycard.visible = false
	if _dragon_guard != null and _dragon_guard.has_method("set_mount_enabled"):
		_dragon_guard.call("set_mount_enabled", false)
	if _level_gate != null and _level_gate.has_method("set_interactable_enabled"):
		_level_gate.call("set_interactable_enabled", false)
	if _boots != null and _boots.has_signal("collected"):
		_boots.collected.connect(_on_boots_collected)
	if _dragon_guard != null:
		if _dragon_guard.has_signal("defeated"):
			_dragon_guard.defeated.connect(_on_dragon_defeated)
		if _dragon_guard.has_signal("mount_requested"):
			_dragon_guard.mount_requested.connect(_on_dragon_mount_requested)
	if _level_gate != null and _level_gate.has_signal("gate_opened"):
		_level_gate.gate_opened.connect(_on_gate_opened)
	if not GameState.is_connected("rewind_mode_changed", Callable(self, "_on_rewind_mode_changed")):
		GameState.rewind_mode_changed.connect(_on_rewind_mode_changed)
	if not GameState.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
		GameState.inventory_changed.connect(_on_inventory_changed)
	_show_objective("Take the jumping boots")
	_show_subtitle("Find the boots and prepare for a long jump.", 2.0)

func _process(delta: float) -> void:
	if GameState.is_time_blocked():
		return
	_time += delta
	for node3d in _floating_nodes:
		if node3d == null or not is_instance_valid(node3d):
			continue
		var base_position: Vector3 = _base_positions.get(node3d, node3d.position)
		var phase: float = float(_phase_map.get(node3d, 0.0))
		node3d.position = base_position + Vector3(0.0, sin(_time * bob_speed + phase) * bob_height, 0.0)
		node3d.rotate_y(delta * spin_speed)

func _collect_floaters() -> void:
	_floating_nodes.clear()
	_base_positions.clear()
	_phase_map.clear()
	if _bridge_root != null:
		for child in _bridge_root.get_children():
			_register_floater(child as Node3D)
	var group_nodes: Array[Node] = get_tree().get_nodes_in_group("surreal_float")
	for entry in group_nodes:
		_register_floater(entry as Node3D)

func _register_floater(node3d: Node3D) -> void:
	if node3d == null:
		return
	if _floating_nodes.has(node3d):
		return
	_floating_nodes.append(node3d)
	_base_positions[node3d] = node3d.position
	_phase_map[node3d] = randf_range(0.0, TAU)

func _on_boots_collected(multiplier: float) -> void:
	if _player != null:
		_player.jump_power = _base_jump_power * multiplier
	if _stage != Stage.TAKE_BOOTS:
		return
	_stage = Stage.TRIGGER_REWIND
	_show_objective("Activate rewind to stabilize the route")
	_show_subtitle("The platform is collapsing. Rewind now.", 2.1)
	if not _collapse_started:
		_collapse_started = true
		call_deferred("_collapse_boots_platform")

func _collapse_boots_platform() -> void:
	if _boots_platform == null:
		return
	_set_platform_walkable(_boots_platform, true)
	var start_position: Vector3 = _boots_platform.position
	var end_position: Vector3 = start_position + Vector3(0.0, -18.0, 0.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_boots_platform, "position", end_position, 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_boots_platform, "rotation_degrees", _boots_platform.rotation_degrees + Vector3(0.0, 14.0, 6.0), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.35).timeout
	_set_platform_walkable(_boots_platform, false)
	await tween.finished

func _on_rewind_mode_changed(active: bool) -> void:
	if not active:
		return
	if _stage != Stage.TRIGGER_REWIND:
		return
	_stage = Stage.CROSS_AND_FIGHT
	_set_bridge_enabled(true)
	_show_objective("Cross the platforms and defeat the dragon")
	_show_subtitle("The route is back. Move now.", 1.8)

func _on_dragon_defeated(_dragon: Node3D) -> void:
	if _stage != Stage.CROSS_AND_FIGHT:
		return
	_stage = Stage.TAKE_KEYCARD
	if _dragon_keycard != null:
		_dragon_keycard.visible = true
		if _dragon_keycard.has_method("set_interactable_enabled"):
			_dragon_keycard.call("set_interactable_enabled", true)
	_show_objective("Grab the keycard")
	_show_subtitle("The dragon is down. Take the keycard.", 2.0)

func _on_inventory_changed() -> void:
	if _stage == Stage.TAKE_KEYCARD and GameState.has_item("key_3"):
		_stage = Stage.TAME_DRAGON
		if _dragon_guard != null and _dragon_guard.has_method("set_mount_enabled"):
			_dragon_guard.call("set_mount_enabled", true)
		_show_objective("Tame the dragon and ride to the final platform")
		return
	if _stage == Stage.USE_GATE and _level_gate != null and _level_gate.has_method("set_highlight_strength"):
		_level_gate.call("set_highlight_strength", 0.95)

func _on_dragon_mount_requested(_dragon: Node3D) -> void:
	if _stage != Stage.TAME_DRAGON:
		return
	if _ride_running:
		return
	_ride_running = true
	call_deferred("_play_dragon_ride")

func _play_dragon_ride() -> void:
	if _player == null or _dragon_guard == null:
		_ride_running = false
		return
	if GameState.rewind_mode_active:
		GameState.cancel_rewind_mode()
	_player.set_cinematic_lock(true)
	_player.set_mobility_lock(true)
	_player.visible = false
	var tween: Tween = create_tween()
	tween.tween_property(_dragon_guard, "global_position", _ride_start.global_position, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dragon_guard, "global_position", _ride_mid.global_position, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_dragon_guard, "global_position", _ride_end.global_position, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_player.global_position = _player_drop.global_position
	_player.rotation.y = _player_drop.global_rotation.y
	_player.visible = true
	_player.set_cinematic_lock(false)
	_player.set_mobility_lock(false)
	_stage = Stage.USE_GATE
	if _level_gate != null and _level_gate.has_method("set_interactable_enabled"):
		_level_gate.call("set_interactable_enabled", true)
	_show_objective("Use the keycard on the gate")
	_show_subtitle("Use the keycard and enter Level 4.", 2.0)
	_ride_running = false

func _on_gate_opened() -> void:
	if _stage != Stage.USE_GATE:
		return
	_stage = Stage.DONE
	_show_objective("")
	_transition_to_level_four()

func _transition_to_level_four() -> void:
	var screen_fx: CanvasLayer = get_node_or_null("/root/ScreenFX") as CanvasLayer
	GameState.current_level_index = 3
	if screen_fx != null and screen_fx.has_method("reboot_to_scene"):
		await screen_fx.reboot_to_scene(LEVEL_FOUR_SCENE_PATH, true)
	else:
		get_tree().change_scene_to_file(LEVEL_FOUR_SCENE_PATH)

func _set_bridge_enabled(enabled: bool) -> void:
	if _bridge_root == null:
		return
	for child in _bridge_root.get_children():
		var platform: Node3D = child as Node3D
		if platform == null:
			continue
		_set_platform_walkable(platform, enabled)

func _set_platform_walkable(platform: Node3D, enabled: bool) -> void:
	if platform == null:
		return
	platform.visible = enabled
	for node in platform.get_children():
		if node is CollisionShape3D:
			(node as CollisionShape3D).disabled = not enabled
		elif node is MeshInstance3D:
			(node as MeshInstance3D).visible = enabled
		elif node is Area3D:
			(node as Area3D).monitoring = enabled
			(node as Area3D).monitorable = enabled
			for area_child in node.get_children():
				if area_child is CollisionShape3D:
					(area_child as CollisionShape3D).disabled = not enabled

func _show_objective(text: String) -> void:
	if _world != null and _world.has_method("_show_objective"):
		if text.is_empty():
			_world.call("_hide_objective", false)
		else:
			_world.call("_show_objective", text)

func _show_subtitle(text: String, duration: float) -> void:
	if _world != null and _world.has_method("_show_subtitle"):
		_world.call_deferred("_show_subtitle", text, duration, "")
