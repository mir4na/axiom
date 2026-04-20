extends RefCounted

const LEVEL_ONE_WHITE_META := "level_one_white_intro"
const BROKEN_HOUSE_SCENE := preload("res://scenes/objects/broken_house.tscn")
const GUEST_REVEAL_EXTERIOR_START_POS := Vector3(-24.6, 16.0, 30.7)
const GUEST_REVEAL_EXTERIOR_START_LOOK := Vector3(0.7, -0.75, 7.2)
const GUEST_REVEAL_EXTERIOR_END_POS := Vector3(18.7, 7.8, 40.4)
const GUEST_REVEAL_EXTERIOR_END_LOOK := Vector3(1.9, -0.7, 6.8)
const GUEST_REVEAL_GUEST_START_POS := Vector3(-0.8, -0.15, 5.1)
const GUEST_REVEAL_GUEST_START_LOOK := Vector3(4.0, -0.85, 3.5)
const GUEST_REVEAL_GUEST_END_POS := Vector3(0.2, -0.05, 4.7)
const GUEST_REVEAL_GUEST_END_LOOK := Vector3(4.0, -0.85, 3.5)
const GUEST_REVEAL_FRAGMENT_CENTER := Vector3(4.0, -0.85, 3.5)

var _world
var _front_door: Node3D
var _guest_door: Node3D
var _guest_button_out: Node3D
var _guest_button_in: Node3D
var _guest_door_gap: CSGBox3D
var _glitch_fragments_root: Node3D
var _guest_door_revealed: bool = false
var _front_door_cinematic_played: bool = false
var _guest_key_spawned: bool = false
var _guest_key_collected: bool = false
var _guest_room_opened: bool = false
var _axiom_sequence_played: bool = false
var _level_one_sequence_running: bool = false
var _objective_state: String = ""
var _key_item_instance: Node3D
var _axiom_item_instance: Node3D
var _split_front_nodes: Array[Node3D] = []
var _split_back_nodes: Array[Node3D] = []
var _split_original_positions: Dictionary = {}
var _glitch_fragment_original_positions: Dictionary = {}
var _broken_house_instance: Node3D

func _init(world_ref) -> void:
	_world = world_ref

func initialize() -> void:
	_cache_nodes()
	_prepare_phase()
	_configure_house()
	_connect_hooks()

func process_objectives() -> void:
	if _objective_state == "guest_key" and is_instance_valid(_key_item_instance):
		_world._update_hint_marker(_key_item_instance.global_position + Vector3(0.0, 0.55, 0.0), "KEY", _key_item_instance.global_position)
	elif _objective_state == "guest_unlock" and is_instance_valid(_guest_button_out):
		_world._update_hint_marker(_guest_button_out.global_position + Vector3(0.0, 0.35, 0.0), "DOOR", _guest_button_out.global_position)
	elif _objective_state == "guest_axiom" and is_instance_valid(_axiom_item_instance):
		_world._update_hint_marker(_axiom_item_instance.global_position + Vector3(0.0, 0.55, 0.0), "AXIOM", _axiom_item_instance.global_position)
	else:
		_world._hint_marker.visible = false
		_world._hint_label.visible = false

func handle_inventory_changed() -> void:
	if not _guest_key_collected and GameState.has_item("key_1"):
		_guest_key_collected = true
		if _objective_state == "guest_key":
			_set_objective_state("guest_unlock")
			_world.call_deferred("_play_level_one_guest_key_pickup_subtitle")

func play_arrival() -> void:
	if _world.player_hud != null:
		_world.player_hud.visible = false
	if _world.player != null:
		_world.player.visible = true
	if _world.player_camera != null:
		_world.player_camera.make_current()
	if _world._white_overlay != null:
		_world._white_overlay.modulate.a = 0.2
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = true
		_world._glitch_overlay.modulate.a = 1.0
		_world._set_arrival_glitch_strength(0.95)
	if _world._fade_overlay != null:
		_world._fade_overlay.modulate.a = 0.0
	await _world.get_tree().process_frame
	await _world.get_tree().process_frame
	var arrival_tween: Tween = _world.create_tween()
	if _world._white_overlay != null:
		arrival_tween.tween_property(_world._white_overlay, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrival_tween.parallel().tween_method(_world._set_arrival_glitch_strength, 0.95, 0.0, 2.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _world._glitch_overlay != null:
		arrival_tween.parallel().tween_property(_world._glitch_overlay, "modulate:a", 0.0, 2.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await arrival_tween.finished
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = false
	_world._set_intro_lock(false)
	if _world.player_hud != null:
		_world.player_hud.visible = true
	GameState.set_meta(LEVEL_ONE_WHITE_META, false)

func play_guest_key_pickup_subtitle() -> void:
	await _world._show_subtitle("A key in my kitchen now too... none of this makes sense.", 2.3)

func _cache_nodes() -> void:
	if _world.house == null:
		return
	_front_door = _world.house.get_node_or_null("FrontDoor") as Node3D
	_guest_door = _world.house.get_node_or_null("GuestDoor") as Node3D
	_guest_button_out = _world.house.get_node_or_null("GuestDoorBtnOut") as Node3D
	_guest_button_in = _world.house.get_node_or_null("GuestDoorBtnIn") as Node3D
	_guest_door_gap = _world.house.get_node_or_null("Partitions/GuestDoorGap") as CSGBox3D
	_glitch_fragments_root = _world.get_node_or_null("GlitchFragments") as Node3D

func _prepare_phase() -> void:
	GameState.full_reset_inventory()
	GameState.recording_enabled = true
	GameState.rewind_mode_active = false
	GameState.world_history.clear()
	GameState.history_index = -1
	GameState.rewind_pointer_index = -1
	GameState.mark_indices.clear()
	GameState.timeline_position = 0.0
	_guest_door_revealed = false
	_front_door_cinematic_played = false
	_guest_key_spawned = false
	_guest_key_collected = false
	_guest_room_opened = false
	_axiom_sequence_played = false
	_level_one_sequence_running = false
	_objective_state = ""
	_key_item_instance = null
	_axiom_item_instance = null
	_broken_house_instance = null
	_split_front_nodes.clear()
	_split_back_nodes.clear()
	_split_original_positions.clear()
	_glitch_fragment_original_positions.clear()
	if _world._wake_overlay != null:
		_world._wake_overlay.visible = false
	if _world._blink_overlay != null:
		_world._blink_overlay.modulate.a = 0.0
	if _world._fade_overlay != null:
		_world._fade_overlay.modulate.a = 0.0
	if _world._white_overlay != null:
		_world._white_overlay.modulate.a = 0.0
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = false
		_world._glitch_overlay.modulate.a = 0.0
	if _world._subtitle_label != null:
		_world._subtitle_label.visible = false
	if _world._objective_panel != null:
		_world._objective_panel.visible = false
	if _world._top_bar != null:
		_world._top_bar.visible = false
		_world._top_bar.offset_bottom = 0.0
	if _world._bottom_bar != null:
		_world._bottom_bar.visible = false
		_world._bottom_bar.offset_top = 0.0

func _configure_house() -> void:
	if _world.house == null:
		return
	for node_name in ["Glass1", "Glass2"]:
		var glass := _world.house.get_node_or_null(node_name) as CSGBox3D
		if glass == null:
			continue
		var material := glass.material
		if material is StandardMaterial3D:
			var copy := material.duplicate() as StandardMaterial3D
			copy.albedo_color = Color(0.72, 0.8, 0.88, 0.82)
			copy.roughness = 0.9
			copy.metallic = 0.15
			glass.material = copy
	_set_guest_entry_visible(false)
	_set_guest_buttons_locked(true)
	_spawn_axiom()
	if is_instance_valid(_axiom_item_instance) and _axiom_item_instance.has_method("set_pickup_enabled"):
		_axiom_item_instance.call("set_pickup_enabled", false)
	_cache_split_nodes()
	if _glitch_fragments_root != null:
		_glitch_fragments_root.visible = true

func _connect_hooks() -> void:
	var axiom_callable := Callable(self, "_on_axiom_equipped_changed")
	var front_door_callable := Callable(self, "_on_front_door_opened")
	var guest_door_callable := Callable(self, "_on_guest_door_opened")
	var guest_locked_callable := Callable(self, "_on_guest_door_locked_interaction")
	if not GameState.axiom_equipped_changed.is_connected(axiom_callable):
		GameState.axiom_equipped_changed.connect(axiom_callable)
	if _front_door != null and _front_door.has_signal("opened") and not _front_door.is_connected("opened", front_door_callable):
		_front_door.connect("opened", front_door_callable)
	if _guest_door != null and _guest_door.has_signal("opened") and not _guest_door.is_connected("opened", guest_door_callable):
		_guest_door.connect("opened", guest_door_callable)
	for button in [_guest_button_out, _guest_button_in]:
		if button != null and button.has_signal("locked_interaction") and not button.is_connected("locked_interaction", guest_locked_callable):
			button.connect("locked_interaction", guest_locked_callable)

func _set_guest_entry_visible(visible: bool) -> void:
	if _guest_door_gap != null:
		_guest_door_gap.operation = CSGShape3D.OPERATION_SUBTRACTION
		_guest_door_gap.material = null
	if _guest_door != null:
		_guest_door.visible = true
		_guest_door.process_mode = Node.PROCESS_MODE_INHERIT
		var guest_door_collision := _guest_door.get_node_or_null("Collision") as CollisionShape3D
		if guest_door_collision != null:
			guest_door_collision.disabled = false
	for button in [_guest_button_out, _guest_button_in]:
		if button == null:
			continue
		button.visible = visible
		button.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED
		var collision := button.get_node_or_null("Collision") as CollisionShape3D
		if collision != null:
			collision.disabled = not visible

func _set_guest_buttons_locked(locked: bool) -> void:
	for button in [_guest_button_out, _guest_button_in]:
		if button == null:
			continue
		button.set("locked", locked)
		button.set("required_item_id", "key_1")
		button.set("consume_required_item", true)
		button.set("fail_message", "You need a key to open this door.")

func _spawn_key() -> void:
	if _guest_key_spawned or _world.house == null:
		return
	var scene := load("res://scenes/objects/key_item.tscn") as PackedScene
	if scene == null:
		return
	_key_item_instance = scene.instantiate() as Node3D
	if _key_item_instance == null:
		return
	_world.add_child(_key_item_instance)
	_key_item_instance.global_position = _world.house.to_global(Vector3(-3.4, -1.0, -5.5))
	_guest_key_spawned = true

func _spawn_axiom() -> void:
	if is_instance_valid(_axiom_item_instance) or _world.house == null:
		return
	var scene := load("res://scenes/objects/axiom_item.tscn") as PackedScene
	if scene == null:
		return
	_axiom_item_instance = scene.instantiate() as Node3D
	if _axiom_item_instance == null:
		return
	_world.add_child(_axiom_item_instance)
	_axiom_item_instance.global_position = _world.house.to_global(Vector3(8.4, -1.0, 4.6))

func _cache_split_nodes() -> void:
	if _world.house == null or _split_front_nodes.size() > 0 or _split_back_nodes.size() > 0:
		return
	for path in [
		"FloorLiving",
		"CarpetGuest",
		"Living",
		"GuestBedroom",
		"GuestDoor",
		"GuestDoorBtnOut",
		"GuestDoorBtnIn",
		"Lights/LivingLight",
		"Lights/GuestLight",
	]:
		var node := _world.house.get_node_or_null(path) as Node3D
		if node != null:
			_split_front_nodes.append(node)
			_split_original_positions[node] = node.position
	for path in [
		"FloorKitchen",
		"CarpetMaster",
		"Kitchen",
		"MasterBedroom",
		"MasterDoor",
		"MasterDoorBtnOut",
		"MasterDoorBtnIn",
		"Lights/KitchenLight",
		"Lights/MasterLight",
	]:
		var node := _world.house.get_node_or_null(path) as Node3D
		if node != null:
			_split_back_nodes.append(node)
			_split_original_positions[node] = node.position
	if _glitch_fragments_root != null:
		for child in _glitch_fragments_root.get_children():
			if child is Node3D:
				_glitch_fragment_original_positions[child] = child.position

func _set_objective_state(state: String) -> void:
	_objective_state = state
	match _objective_state:
		"guest_key":
			_world._show_objective(_world._objective_text("guest_key", "OBJECTIVE: Take the key from the kitchen"))
		"guest_unlock":
			_world._show_objective(_world._objective_text("guest_unlock", "OBJECTIVE: Open the guest room door"))
		"guest_axiom":
			_world._show_objective(_world._objective_text("guest_axiom", "OBJECTIVE: Take the Axiom"))
		_:
			if _world._objective_panel != null:
				_world._objective_panel.visible = false

func _on_front_door_opened() -> void:
	if not _world._is_level_one_scene() or _front_door_cinematic_played or _level_one_sequence_running:
		return
	_front_door_cinematic_played = true
	_world.call_deferred("_play_level_one_guest_door_reveal_cinematic")

func play_guest_door_reveal_cinematic() -> void:
	if not _world._is_level_one_scene() or _level_one_sequence_running:
		return
	_level_one_sequence_running = true
	_world._set_intro_lock(true)
	_world._intro_running = false
	await _world._set_cinematic_bars(true, 0.35)
	
	var player_transform: Transform3D = _world.player_camera.global_transform
	var exterior_start: Transform3D = _make_house_camera_transform(GUEST_REVEAL_EXTERIOR_START_POS, GUEST_REVEAL_EXTERIOR_START_LOOK)
	var exterior_end: Transform3D = _make_house_camera_transform(GUEST_REVEAL_EXTERIOR_END_POS, GUEST_REVEAL_EXTERIOR_END_LOOK)
	var guest_start: Transform3D = _make_house_camera_transform(GUEST_REVEAL_GUEST_START_POS, GUEST_REVEAL_GUEST_START_LOOK)
	var guest_end: Transform3D = _make_house_camera_transform(GUEST_REVEAL_GUEST_END_POS, GUEST_REVEAL_GUEST_END_LOOK)
	
	_world._intro_camera.global_transform = player_transform
	_world._intro_camera.make_current()
	
	await _world._play_camera_shot(player_transform, exterior_start, 1.15)
	await _world._play_camera_shot(exterior_start, exterior_end, 4.1)
	await _world._show_subtitle("Wait... why does the house feel different?", 1.9)
	await _play_guest_door_materialize()
	_world._intro_camera.global_transform = guest_start
	await _world.get_tree().process_frame
	await _world._show_subtitle("That door wasn't there a second ago.", 2.1)
	await _world._play_camera_shot(guest_start, guest_end, 3.6)
	await _world._show_subtitle("No. That room should not exist.", 2.2)
	await _world._return_intro_camera_to_player(0.9)
	await _world._set_cinematic_bars(false, 0.32)
	if not _guest_key_collected:
		_spawn_key()
		_set_objective_state("guest_key")
	_world._set_intro_lock(false)
	_level_one_sequence_running = false

func _play_guest_door_materialize() -> void:
	if _guest_door_revealed:
		return
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = true
		_world._glitch_overlay.modulate.a = 0.0
		_world._set_arrival_glitch_strength(0.0)
	var flash: Tween = _world.create_tween()
	if _world._white_overlay != null:
		flash.tween_property(_world._white_overlay, "modulate:a", 0.45, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _world._glitch_overlay != null:
		flash.parallel().tween_property(_world._glitch_overlay, "modulate:a", 0.92, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.parallel().tween_method(_world._set_arrival_glitch_strength, 0.0, 0.95, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await flash.finished
	_set_guest_entry_visible(true)
	_set_guest_buttons_locked(true)
	_guest_door_revealed = true
	var settle: Tween = _world.create_tween()
	if _world._white_overlay != null:
		settle.tween_property(_world._white_overlay, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _world._glitch_overlay != null:
		settle.parallel().tween_property(_world._glitch_overlay, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		settle.parallel().tween_method(_world._set_arrival_glitch_strength, 0.95, 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await settle.finished
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = false

func _on_guest_door_locked_interaction(_button: Node) -> void:
	if not _world._is_level_one_scene() or _guest_room_opened:
		return
	if not _guest_key_collected:
		if not _guest_key_spawned:
			_spawn_key()
		if _objective_state != "guest_key":
			_set_objective_state("guest_key")
		_world.call_deferred("_play_level_one_guest_door_locked_sequence")

func play_guest_door_locked_sequence() -> void:
	await _world._show_subtitle("Locked? Then why do I feel like I need to go in there?", 2.2)
	await _world._show_subtitle("There has to be a key somewhere in the kitchen.", 2.0)

func _on_guest_door_opened() -> void:
	if not _world._is_level_one_scene() or _guest_room_opened:
		return
	if GameState.has_item("key_1"):
		GameState.consume_item("key_1")
	_guest_key_collected = true
	_guest_room_opened = true
	_set_guest_buttons_locked(false)
	_spawn_axiom()
	if is_instance_valid(_axiom_item_instance) and _axiom_item_instance.has_method("set_pickup_enabled"):
		_axiom_item_instance.call("set_pickup_enabled", true)
	_set_objective_state("guest_axiom")
	_world.call_deferred("_play_level_one_guest_room_opened_subtitle")

func play_guest_room_opened_subtitle() -> void:
	await _world._show_subtitle("That room should not be inside this house.", 2.1)
	await _world._show_subtitle("Whatever is in there is pulling me closer.", 2.0)

func _on_axiom_equipped_changed() -> void:
	if not _world._is_level_one_scene() or _axiom_sequence_played:
		return
	_axiom_sequence_played = true
	_world.call_deferred("_play_level_one_axiom_equip_sequence")

func play_axiom_equip_sequence() -> void:
	if _level_one_sequence_running:
		return
	_level_one_sequence_running = true
	_set_objective_state("")
	_world._hint_marker.visible = false
	_world._hint_label.visible = false
	_world._set_intro_lock(true)
	_world._intro_running = false
	await _world._set_cinematic_bars(true, 0.35)
	
	var player_transform: Transform3D = _world.player_camera.global_transform
	var split_start: Transform3D = Transform3D(Basis(), _world.house.to_global(Vector3(16.0, 4.0, 8.0))).looking_at(_world.house.to_global(Vector3(0.0, -0.8, 0.0)), Vector3.UP)
	var split_end: Transform3D = Transform3D(Basis(), _world.house.to_global(Vector3(20.4, 12.0, 0.4))).looking_at(_world.house.to_global(Vector3(0.0, -1.1, 0.0)), Vector3.UP)
	
	_world._intro_camera.global_transform = player_transform
	_world._intro_camera.make_current()
	await _world._play_camera_shot(player_transform, split_start, 0.9)
	await _world._show_subtitle("What did I just pick up?", 1.8)
	await _world._play_camera_shot(split_start, split_end, 1.4)
	await _play_house_split_glitch()
	await _world._show_subtitle("No... it's splitting the house apart.", 2.0)
	await _world._show_subtitle("It's recording everything now.", 1.9)
	await _world._return_intro_camera_to_player(0.95)
	await _world._set_cinematic_bars(false, 0.32)
	_world._set_intro_lock(false)
	_level_one_sequence_running = false

func _play_house_split_glitch() -> void:
	_ensure_broken_house()
	_refresh_split_origins()
	if _glitch_fragments_root != null:
		_glitch_fragments_root.visible = true
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = true
		_world._glitch_overlay.modulate.a = 0.0
	var glitch_in: Tween = _world.create_tween()
	if _world._glitch_overlay != null:
		glitch_in.tween_property(_world._glitch_overlay, "modulate:a", 0.78, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		glitch_in.parallel().tween_method(_world._set_arrival_glitch_strength, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _broken_house_instance != null:
		glitch_in.parallel().tween_method(Callable(_broken_house_instance, "set_split_weight"), 0.0, 1.0, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await glitch_in.finished
	await _world.get_tree().create_timer(0.5).timeout
	var glitch_out: Tween = _world.create_tween()
	if _world._glitch_overlay != null:
		glitch_out.tween_property(_world._glitch_overlay, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glitch_out.parallel().tween_method(_world._set_arrival_glitch_strength, 1.0, 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await glitch_out.finished
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = false

func _play_glitch_fragment_burst(from_weight: float, to_weight: float, duration: float) -> void:
	_cache_split_nodes()
	if _glitch_fragments_root == null:
		return
	_glitch_fragments_root.visible = true
	var tween: Tween = _world.create_tween()
	tween.tween_method(_set_fragment_burst_weight, from_weight, to_weight, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	var fade: Tween = _world.create_tween()
	fade.tween_method(_set_fragment_burst_weight, to_weight, 0.0, duration * 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade.finished
	_glitch_fragments_root.visible = false

func _set_fragment_burst_weight(weight: float) -> void:
	var center: Vector3 = _world.house.to_global(GUEST_REVEAL_FRAGMENT_CENTER)
	var index := 0
	var child_count := maxi(_glitch_fragment_original_positions.size(), 1)
	for child in _glitch_fragment_original_positions.keys():
		if not is_instance_valid(child):
			continue
		var angle := (float(index) / float(child_count)) * TAU
		var ring := 1.2 + fmod(float(index) * 0.41, 2.1)
		var offset := Vector3(cos(angle) * ring, sin(angle * 2.3) * 0.55, sin(angle) * ring)
		var drift := Vector3(sin(weight * 10.0 + angle * 1.7) * 0.7, cos(weight * 14.0 + angle * 0.8) * 0.3, cos(weight * 11.0 + angle * 1.3) * 0.6)
		child.global_position = center + offset * weight * 3.2 + drift * weight
		index += 1

func _make_house_camera_transform(position_offset: Vector3, look_offset: Vector3) -> Transform3D:
	return Transform3D(Basis(), _world.house.to_global(position_offset)).looking_at(_world.house.to_global(look_offset), Vector3.UP)

func _refresh_split_origins() -> void:
	if _broken_house_instance != null:
		return
	for node in _split_front_nodes:
		if is_instance_valid(node):
			_split_original_positions[node] = node.position
	for node in _split_back_nodes:
		if is_instance_valid(node):
			_split_original_positions[node] = node.position
	for child in _glitch_fragment_original_positions.keys():
		if is_instance_valid(child):
			_glitch_fragment_original_positions[child] = child.position

func _ensure_broken_house() -> void:
	if _broken_house_instance != null or _world.house == null:
		return
	var broken_scene := BROKEN_HOUSE_SCENE.instantiate() as Node3D
	if broken_scene == null:
		return
	_world.add_child(broken_scene)
	if broken_scene.has_method("build_from_house"):
		broken_scene.call("build_from_house", _world.house)
	_broken_house_instance = broken_scene

func _set_house_split_weight(weight: float) -> void:
	for node in _split_front_nodes:
		if not is_instance_valid(node):
			continue
		var original: Vector3 = _split_original_positions.get(node, node.position)
		node.position = original + Vector3(0.0, sin(weight * PI) * 0.08, weight * 1.9)
	for node in _split_back_nodes:
		if not is_instance_valid(node):
			continue
		var original: Vector3 = _split_original_positions.get(node, node.position)
		node.position = original + Vector3(0.0, sin(weight * PI) * 0.08, -weight * 1.9)
	for child in _glitch_fragment_original_positions.keys():
		if not is_instance_valid(child):
			continue
		var original: Vector3 = _glitch_fragment_original_positions.get(child, child.position)
		child.position = original + Vector3(0.0, sin(weight * 12.0 + original.x * 0.1) * 0.2, cos(weight * 10.0 + original.z * 0.08) * 0.35)
