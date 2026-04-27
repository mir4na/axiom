extends Node

signal time_direction_changed(direction: int)
signal world_scaled(scale_factor: float)
signal world_rotated(delta: Vector2)
signal world_aligned
signal level_completed
signal paused(state: bool)
signal inventory_changed
signal ui_updated
signal rewind_mode_changed(active: bool)
signal axiom_equipped_changed

const TIME_FORWARD := 1
const TIME_REWIND := -1
const SCALE_MIN := 0.3
const SCALE_MAX := 3.0
const SCALE_STEP := 0.1

const LEVELS: Array[String] = [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/levels/level_02.tscn",
	"res://scenes/levels/level_03.tscn",
	"res://scenes/levels/level_04.tscn",
]

var time_direction: int = TIME_FORWARD
var world_scale: float = 1.0
var is_aligned: bool = false
var is_paused: bool = false
var current_level_index: int = 0

var world_history: Array[Dictionary] = []
var history_index: int = -1
const MAX_HISTORY: int = 10800
var is_scrubbing_past: bool = false
var mark_indices: Array[int] = []

var timeline_position: float = 100.0
const TIMELINE_MAX: float = 100.0

var slots: Array[String] = ["", "", ""]
var selected_slot: int = 0
var axiom_equipped: bool = false
var axiom_unlocked: bool = false
var recording_enabled: bool = true

var rewind_mode_active: bool = false
var rewind_pointer_index: int = -1

func _physics_process(_delta: float) -> void:
	if is_paused:
		return

	if rewind_mode_active:
		return

	if not recording_enabled:
		return

	var actor: Node = _get_rewind_actor()
	if actor == null:
		return

	if time_direction == 1 and not is_scrubbing_past:
		var snap_dict = {}
		snap_dict[actor.get_path()] = _get_actor_state(actor)

		world_history.append(snap_dict)
		if world_history.size() > MAX_HISTORY:
			world_history.pop_front()

		history_index = world_history.size() - 1
		timeline_position = (float(history_index) / float(MAX_HISTORY)) * 100.0

	else:
		var step = -1 if time_direction < 0 else (2 if time_direction > 1 else 1)
		history_index = clampi(history_index + step, 0, world_history.size() - 1)

		if world_history.size() > 0:
			var snap = world_history[history_index]
			var path: NodePath = actor.get_path()
			if snap.has(path):
				_apply_actor_state(actor, snap[path])

		timeline_position = (float(history_index) / float(MAX_HISTORY)) * 100.0

		if time_direction == 1 and history_index == world_history.size() - 1:
			is_scrubbing_past = false

func activate_rewind_mode() -> void:
	rewind_mode_active = true
	rewind_pointer_index = history_index
	if rewind_pointer_index < 0:
		rewind_pointer_index = 0
	rewind_mode_changed.emit(true)

func cancel_rewind_mode() -> void:
	if world_history.size() > 0 and rewind_pointer_index >= 0:
		var snap = world_history[history_index]
		var actor: Node = _get_rewind_actor()
		if actor != null:
			var path: NodePath = actor.get_path()
			if snap.has(path):
				_apply_actor_state(actor, snap[path])
	rewind_mode_active = false
	is_scrubbing_past = false
	time_direction = TIME_FORWARD
	rewind_mode_changed.emit(false)

func deactivate_rewind_mode(jump: bool) -> void:
	if jump and world_history.size() > 0:
		var target = clampi(rewind_pointer_index, 0, world_history.size() - 1)
		var snap = world_history[target]
		var actor: Node = _get_rewind_actor()
		if actor != null:
			var path: NodePath = actor.get_path()
			if snap.has(path):
				_apply_actor_state(actor, snap[path])

		world_history = world_history.slice(0, target + 1)
		history_index = world_history.size() - 1
		timeline_position = (float(history_index) / float(MAX_HISTORY)) * 100.0
		mark_indices = mark_indices.filter(func(i): return i < world_history.size())

	rewind_mode_active = false
	is_scrubbing_past = false
	time_direction = TIME_FORWARD
	rewind_mode_changed.emit(false)

func add_mark_current() -> void:
	if history_index >= 0 and not mark_indices.has(history_index):
		mark_indices.append(history_index)

func move_rewind_pointer(direction: int) -> void:
	if not rewind_mode_active:
		return
	var step = 8 * direction
	rewind_pointer_index = clampi(rewind_pointer_index + step, 0, world_history.size() - 1)
	timeline_position = (float(rewind_pointer_index) / float(MAX_HISTORY)) * 100.0

	if world_history.size() > 0:
		var snap = world_history[rewind_pointer_index]
		var actor: Node = _get_rewind_actor()
		if actor != null:
			var path: NodePath = actor.get_path()
			if snap.has(path):
				_apply_actor_state(actor, snap[path])

func get_pointer_ratio() -> float:
	if world_history.size() <= 1:
		return 1.0
	return float(rewind_pointer_index) / float(world_history.size() - 1)

func prune_timeline() -> void:
	if history_index < world_history.size() - 1 and history_index >= 0:
		world_history = world_history.slice(0, history_index + 1)
		is_scrubbing_past = false
		mark_indices = mark_indices.filter(func(i): return i < world_history.size())

func _get_rewind_actor() -> Node:
	return get_tree().get_first_node_in_group("player")

func _get_actor_state(actor: Node) -> Dictionary:
	var state = {"pos": actor.position, "rot": actor.rotation}
	if actor.is_in_group("player"):
		state["head_rot_x"] = actor.get("camera_x_rotation") if actor.get("camera_x_rotation") != null else 0.0
		state["crouch"] = actor.get("is_crouching")
	return state

func _apply_actor_state(actor: Node, state: Dictionary) -> void:
	actor.position = state["pos"]
	actor.rotation = state["rot"]
	if actor.is_in_group("player"):
		var crouch = state.get("crouch", false)
		var head_rot = state.get("head_rot_x", 0.0)
		actor.set("camera_x_rotation", head_rot)
		if crouch != actor.get("is_crouching"):
			actor.set("is_crouching", crouch)

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

func reset_axiom_recording() -> void:
	recording_enabled = true
	rewind_mode_active = false
	is_scrubbing_past = false
	time_direction = TIME_FORWARD
	rewind_pointer_index = -1
	world_history.clear()
	history_index = -1
	mark_indices.clear()
	timeline_position = 0.0
	rewind_mode_changed.emit(false)
	time_direction_changed.emit(time_direction)

func full_reset_inventory() -> void:
	slots = ["", "", ""]
	selected_slot = 0
	axiom_equipped = axiom_unlocked
	inventory_changed.emit()
	ui_updated.emit()

func reset_progression() -> void:
	slots = ["", "", ""]
	selected_slot = 0
	axiom_equipped = false
	axiom_unlocked = false
	recording_enabled = true
	rewind_mode_active = false
	rewind_pointer_index = -1
	world_history.clear()
	history_index = -1
	mark_indices.clear()
	timeline_position = 100.0
	inventory_changed.emit()
	ui_updated.emit()

func select_slot(index: int) -> void:
	selected_slot = index
	inventory_changed.emit()

func add_item(item_id: String) -> bool:
	if selected_slot >= 0 and selected_slot < slots.size() and slots[selected_slot] == "":
		slots[selected_slot] = item_id
		inventory_changed.emit()
		return true
	return false

func consume_item(item_id: String) -> bool:
	for i in range(slots.size()):
		if slots[i] == item_id:
			slots[i] = ""
			inventory_changed.emit()
			return true
	return false

func equip_axiom() -> void:
	if axiom_equipped:
		return
	axiom_unlocked = true
	axiom_equipped = true
	recording_enabled = true
	axiom_equipped_changed.emit()
	ui_updated.emit()

func consume_selected() -> String:
	var item = slots[selected_slot]
	slots[selected_slot] = ""
	inventory_changed.emit()
	return item

func has_item(item_id: String) -> bool:
	return slots.has(item_id)

func has_selected_item(item_id: String) -> bool:
	if selected_slot < 0 or selected_slot >= slots.size():
		return false
	return slots[selected_slot] == item_id

func has_rewind_access() -> bool:
	if axiom_equipped or current_level_index >= 1:
		return true
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false
	return current_scene.scene_file_path == LEVELS[1]

func consume_selected_item(item_id: String) -> bool:
	if selected_slot < 0 or selected_slot >= slots.size():
		return false
	if slots[selected_slot] != item_id:
		return false
	slots[selected_slot] = ""
	inventory_changed.emit()
	return true
