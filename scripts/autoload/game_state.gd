extends Node


signal time_direction_changed(direction: int)
signal world_scaled(scale_factor: float)
signal world_rotated(delta: Vector2)
signal world_aligned
signal level_completed
signal paused(state: bool)

signal inventory_changed
signal ui_updated

const TIME_FORWARD := 1
const TIME_REWIND := -1

const SCALE_MIN := 0.3
const SCALE_MAX := 3.0
const SCALE_STEP := 0.1

const LEVELS: Array[String] = [
	"res://scenes/levels/level_01.tscn",
]

var time_direction: int = TIME_FORWARD
var world_scale: float = 1.0
var is_aligned: bool = false
var is_paused: bool = false
var current_level_index: int = 0

var world_history: Array[Dictionary] = []
var history_index: int = -1
const MAX_HISTORY: int = 1200
var is_scrubbing_past: bool = false

var timeline_position: float = 100.0
const TIMELINE_MAX: float = 100.0
const TIMELINE_SPEED: float = 15.0

var slots: Array[String] = ["", "", ""]
var selected_slot: int = 0

func _physics_process(_delta: float) -> void:
	if is_paused:
		return
		
	var actors = get_tree().get_nodes_in_group("time_actor")

	if time_direction == 1 and not is_scrubbing_past:
		# NORMAL PLAY: Record state
		var snap_dict = {}
		for actor in actors:
			snap_dict[actor.get_path()] = _get_actor_state(actor)
			
		world_history.append(snap_dict)
		if world_history.size() > MAX_HISTORY:
			world_history.pop_front()
		
		history_index = world_history.size() - 1
		timeline_position = (float(history_index) / float(MAX_HISTORY)) * 100.0

	else:
		# SCRUB AND HYBRID PLAY: We are either rewinding/fast-forwarding, or auto-playing the past
		var step = -1 if time_direction < 0 else (2 if time_direction > 1 else 1)
		history_index = clampi(history_index + step, 0, world_history.size() - 1)
		
		if world_history.size() > 0:
			var snap = world_history[history_index]
			for actor in actors:
				var path = actor.get_path()
				if snap.has(path):
					_apply_actor_state(actor, snap[path])
					
		timeline_position = (float(history_index) / float(MAX_HISTORY)) * 100.0
		
		# If auto-playing caught up to present
		if time_direction == 1 and history_index == world_history.size() - 1:
			is_scrubbing_past = false

func prune_timeline() -> void:
	if history_index < world_history.size() - 1 and history_index >= 0:
		world_history = world_history.slice(0, history_index + 1)
		is_scrubbing_past = false

func _get_actor_state(actor: Node) -> Dictionary:
	var state = {"pos": actor.position, "rot": actor.rotation}
	if actor.is_in_group("player"):
		var cam = actor.get_node("Head/Camera3D")
		if cam:
			state["head_rot_x"] = cam.rotation_degrees.x
		state["crouch"] = actor.get("is_crouching")
	return state

func _apply_actor_state(actor: Node, state: Dictionary) -> void:
	actor.position = state["pos"]
	actor.rotation = state["rot"]
	if actor.is_in_group("player"):
		var cam = actor.get_node("Head/Camera3D")
		var crouch = state.get("crouch", false)
		if cam:
			cam.rotation_degrees.x = state["head_rot_x"]
			actor.camera_x_rotation = -state["head_rot_x"]
		if crouch != actor.get("is_crouching"):
			actor.is_crouching = crouch
			var coll = actor.get_node("CollisionShape3D")
			var head = actor.get_node("Head")
			coll.shape.height = actor.crouch_height if crouch else (actor.normal_height * 2.0)
			head.position.y = 0.0 if crouch else 0.5


func set_time_direction(direction: int) -> void:
	if time_direction == direction:
		return
		
	if direction < 0:
		is_scrubbing_past = true
		
	time_direction = direction
	time_direction_changed.emit(time_direction)

func apply_scale_delta(delta: float) -> void:
	world_scale = clampf(world_scale + delta, SCALE_MIN, SCALE_MAX)
	world_scaled.emit(world_scale)

func emit_rotation(delta: Vector2) -> void:
	world_rotated.emit(delta)

func complete_level() -> void:
	level_completed.emit()

func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	paused.emit(is_paused)

func unpause() -> void:
	is_paused = false
	get_tree().paused = false
	paused.emit(false)

func has_next_level() -> bool:
	return current_level_index + 1 < LEVELS.size()

func advance_level() -> void:
	current_level_index += 1

func reset_level_index() -> void:
	current_level_index = 0

func reset_world_state() -> void:
	time_direction = TIME_FORWARD
	world_scale = 1.0
	is_aligned = false
	# Intentionally DO NOT clear slots to keep inventory persistent during time resets!

func full_reset_inventory() -> void:
	slots = ["", "", ""]
	selected_slot = 0
	inventory_changed.emit()
	ui_updated.emit()

func select_slot(index: int) -> void:
	selected_slot = index
	inventory_changed.emit()

func add_item(item_id: String) -> bool:
	for i in range(slots.size()):
		if slots[i] == "":
			slots[i] = item_id
			inventory_changed.emit()
			return true
	return false

func consume_selected() -> String:
	var item = slots[selected_slot]
	slots[selected_slot] = ""
	inventory_changed.emit()
	return item

func has_item(item_id: String) -> bool:
	return slots.has(item_id)
