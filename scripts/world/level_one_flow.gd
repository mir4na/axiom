extends RefCounted

const LEVEL_ONE_WHITE_META := "level_one_white_intro"
const BROKEN_HOUSE_SCENE := preload("res://scenes/objects/broken_house.tscn")
const METEOR_SHADER := preload("res://shaders/spatial_glitch.gdshader")
const ESCAPE_DURATION := 60.0
const SMALL_METEOR_INTERVAL := 3.0
const TUTORIAL_PAGES := [
	"AXIOM lets you rewind the recorded state of the world.",
	"Press R to enter rewind mode, then hold R or F to move the pointer through time.",
	"Reach the underground hole before the timer ends."
]
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
var _terrain_root: Node
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
var _underground_hole_instance: Node3D
var _terrain_hidden_for_split: bool = false
var _escape_timer_running: bool = false
var _escape_time_left: float = 0.0
var _tutorial_active: bool = false
var _tutorial_page_index: int = 0
var _tutorial_space_consumed: bool = false
var _small_meteor_spawn_timer: float = 0.0
var _active_small_meteors: Array = []
var _escape_failed_sequence_started: bool = false
var _timer_label: Label
var _tutorial_panel: Panel
var _tutorial_title: Label
var _tutorial_body: Label
var _tutorial_hint: Label

func _init(world_ref) -> void:
	_world = world_ref

func initialize() -> void:
	_cache_nodes()
	_prepare_phase()
	_create_escape_ui()
	_configure_house()
	_connect_hooks()
	_set_objective_state("check_outside")

func process_objectives() -> void:
	_process_escape_phase(_world.get_process_delta_time())
	if _objective_state == "guest_key" and is_instance_valid(_key_item_instance):
		_pulse_objective_highlight(_key_item_instance, 0.55, 1.25)
		_world._update_hint_marker(_key_item_instance.global_position + Vector3(0.0, 0.55, 0.0), "KEY", _key_item_instance.global_position)
	elif _objective_state == "check_outside" and is_instance_valid(_front_door):
		_world._update_hint_marker(_front_door.global_position + Vector3(0.0, 0.8, 0.0), "DOOR", _front_door.global_position)
	elif _objective_state == "guest_unlock" and is_instance_valid(_guest_button_out):
		_world._update_hint_marker(_guest_button_out.global_position + Vector3(0.0, 0.35, 0.0), "DOOR", _guest_button_out.global_position)
	elif _objective_state == "guest_axiom" and is_instance_valid(_axiom_item_instance):
		_world._update_hint_marker(_axiom_item_instance.global_position + Vector3(0.0, 0.55, 0.0), "AXIOM", _axiom_item_instance.global_position)
	elif _objective_state == "escape_hole" and is_instance_valid(_underground_hole_instance):
		_pulse_objective_highlight(_underground_hole_instance, 0.7, 1.4)
		_world._update_hint_marker(_underground_hole_instance.global_position + Vector3(0.0, 0.85, 0.0), "HOLE", _underground_hole_instance.global_position)
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
	_terrain_root = _world.get_node_or_null("Terrain")
	_key_item_instance = _world.get_node_or_null("KeyItem") as Node3D
	_underground_hole_instance = _world.get_node_or_null("UndergroundHole") as Node3D

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
	_axiom_item_instance = null
	_broken_house_instance = null
	_terrain_hidden_for_split = false
	_escape_timer_running = false
	_escape_time_left = 0.0
	_tutorial_active = false
	_tutorial_page_index = 0
	_tutorial_space_consumed = false
	_small_meteor_spawn_timer = SMALL_METEOR_INTERVAL
	_clear_small_meteors()
	_escape_failed_sequence_started = false
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
	if _timer_label != null:
		_timer_label.visible = false
	if _tutorial_panel != null:
		_tutorial_panel.visible = false

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
	if is_instance_valid(_key_item_instance) and _key_item_instance.has_method("set_interactable_enabled"):
		_key_item_instance.call("set_interactable_enabled", false)
	if is_instance_valid(_underground_hole_instance) and _underground_hole_instance.has_method("set_interactable_enabled"):
		_underground_hole_instance.call("set_interactable_enabled", false)
	_spawn_axiom()
	if is_instance_valid(_axiom_item_instance) and _axiom_item_instance.has_method("set_pickup_enabled"):
		_axiom_item_instance.call("set_pickup_enabled", false)
	_cache_split_nodes()
	if _glitch_fragments_root != null:
		_glitch_fragments_root.visible = true

func _create_escape_ui() -> void:
	if _world._intro_ui == null or _timer_label != null:
		return
	_timer_label = Label.new()
	_timer_label.anchor_left = 0.5
	_timer_label.anchor_top = 0.02
	_timer_label.anchor_right = 0.5
	_timer_label.anchor_bottom = 0.02
	_timer_label.offset_left = -80.0
	_timer_label.offset_top = 0.0
	_timer_label.offset_right = 80.0
	_timer_label.offset_bottom = 44.0
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 30)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.64, 1.0))
	_timer_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
	_timer_label.add_theme_constant_override("outline_size", 10)
	_timer_label.visible = false
	_world._intro_ui.add_child(_timer_label)
	_tutorial_panel = Panel.new()
	_tutorial_panel.anchor_left = 0.5
	_tutorial_panel.anchor_top = 0.5
	_tutorial_panel.anchor_right = 0.5
	_tutorial_panel.anchor_bottom = 0.5
	_tutorial_panel.offset_left = -320.0
	_tutorial_panel.offset_top = -130.0
	_tutorial_panel.offset_right = 320.0
	_tutorial_panel.offset_bottom = 130.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.88, 1.0, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	_tutorial_panel.add_theme_stylebox_override("panel", style)
	_tutorial_panel.visible = false
	_world._intro_ui.add_child(_tutorial_panel)
	_tutorial_title = Label.new()
	_tutorial_title.anchor_left = 0.0
	_tutorial_title.anchor_top = 0.0
	_tutorial_title.anchor_right = 1.0
	_tutorial_title.anchor_bottom = 0.0
	_tutorial_title.offset_left = 24.0
	_tutorial_title.offset_top = 18.0
	_tutorial_title.offset_right = -24.0
	_tutorial_title.offset_bottom = 50.0
	_tutorial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_title.text = "AXIOM"
	_tutorial_title.add_theme_font_size_override("font_size", 26)
	_tutorial_title.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	_tutorial_panel.add_child(_tutorial_title)
	_tutorial_body = Label.new()
	_tutorial_body.anchor_left = 0.0
	_tutorial_body.anchor_top = 0.0
	_tutorial_body.anchor_right = 1.0
	_tutorial_body.anchor_bottom = 1.0
	_tutorial_body.offset_left = 24.0
	_tutorial_body.offset_top = 60.0
	_tutorial_body.offset_right = -24.0
	_tutorial_body.offset_bottom = -54.0
	_tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_body.add_theme_font_size_override("font_size", 22)
	_tutorial_body.add_theme_color_override("font_color", Color(0.88, 0.96, 0.98, 1.0))
	_tutorial_panel.add_child(_tutorial_body)
	_tutorial_hint = Label.new()
	_tutorial_hint.anchor_left = 0.0
	_tutorial_hint.anchor_top = 1.0
	_tutorial_hint.anchor_right = 1.0
	_tutorial_hint.anchor_bottom = 1.0
	_tutorial_hint.offset_left = 24.0
	_tutorial_hint.offset_top = -38.0
	_tutorial_hint.offset_right = -24.0
	_tutorial_hint.offset_bottom = -12.0
	_tutorial_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tutorial_hint.text = "[SPACE] NEXT"
	_tutorial_hint.add_theme_font_size_override("font_size", 16)
	_tutorial_hint.add_theme_color_override("font_color", Color(1.0, 0.84, 0.44, 1.0))
	_tutorial_panel.add_child(_tutorial_hint)

func _connect_hooks() -> void:
	var axiom_callable := Callable(self, "_on_axiom_equipped_changed")
	var front_door_callable := Callable(self, "_on_front_door_opened")
	var guest_door_callable := Callable(self, "_on_guest_door_opened")
	var guest_locked_callable := Callable(self, "_on_guest_door_locked_interaction")
	var hole_descended_callable := Callable(self, "_on_underground_hole_descended")
	if not GameState.axiom_equipped_changed.is_connected(axiom_callable):
		GameState.axiom_equipped_changed.connect(axiom_callable)
	if _front_door != null and _front_door.has_signal("opened") and not _front_door.is_connected("opened", front_door_callable):
		_front_door.connect("opened", front_door_callable)
	if _guest_door != null and _guest_door.has_signal("opened") and not _guest_door.is_connected("opened", guest_door_callable):
		_guest_door.connect("opened", guest_door_callable)
	for button in [_guest_button_out, _guest_button_in]:
		if button != null and button.has_signal("locked_interaction") and not button.is_connected("locked_interaction", guest_locked_callable):
			button.connect("locked_interaction", guest_locked_callable)
	if _underground_hole_instance != null and _underground_hole_instance.has_signal("descended") and not _underground_hole_instance.is_connected("descended", hole_descended_callable):
		_underground_hole_instance.connect("descended", hole_descended_callable)

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
	if _guest_key_spawned or not is_instance_valid(_key_item_instance):
		return
	if _key_item_instance.has_method("set_interactable_enabled"):
		_key_item_instance.call("set_interactable_enabled", true)
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
		"check_outside":
			_world._show_objective(_world._objective_text("check_outside", "Check outside"))
		"guest_key":
			_world._show_objective(_world._objective_text("guest_key", "Take the key from the kitchen"))
		"guest_unlock":
			_world._show_objective(_world._objective_text("guest_unlock", "Open the guest room door"))
		"guest_axiom":
			_world._show_objective(_world._objective_text("guest_axiom", "Take the Axiom"))
		"escape_hole":
			_world._show_objective("Reach the underground hole before time runs out")
		_:
			if _world._objective_panel != null:
				_world._objective_panel.visible = false

func _process_escape_phase(delta: float) -> void:
	if _tutorial_active:
		if Input.is_key_pressed(KEY_SPACE):
			if not _tutorial_space_consumed:
				_tutorial_space_consumed = true
				_tutorial_page_index += 1
				if _tutorial_page_index >= TUTORIAL_PAGES.size():
					_end_axiom_tutorial()
				else:
					_update_axiom_tutorial_page()
		else:
			_tutorial_space_consumed = false
	if not _escape_timer_running or _escape_failed_sequence_started:
		return
	_escape_time_left = maxf(0.0, _escape_time_left - delta)
	_update_escape_timer_label()
	_small_meteor_spawn_timer -= delta
	if _small_meteor_spawn_timer <= 0.0:
		_small_meteor_spawn_timer = SMALL_METEOR_INTERVAL
		_spawn_small_meteor()
		_spawn_small_meteor()
		_spawn_small_meteor()
		_spawn_small_meteor()
	_update_small_meteors(delta)
	if _escape_time_left <= 0.0:
		_escape_failed_sequence_started = true
		_world.call_deferred("_play_level_one_escape_fail_sequence")

func _begin_post_split_escape_phase() -> void:
	_set_objective_state("escape_hole")
	_start_axiom_tutorial()

func _start_axiom_tutorial() -> void:
	_tutorial_active = true
	_tutorial_page_index = 0
	_tutorial_space_consumed = true
	if _timer_label != null:
		_timer_label.visible = false
	if _world._objective_panel != null:
		_world._objective_panel.visible = false
	_world._hint_marker.visible = false
	_world._hint_label.visible = false
	_world._set_intro_lock(true)
	if _tutorial_panel != null:
		_tutorial_panel.visible = true
	_update_axiom_tutorial_page()

func _update_axiom_tutorial_page() -> void:
	if _tutorial_body != null:
		_tutorial_body.text = TUTORIAL_PAGES[_tutorial_page_index]
	if _tutorial_hint != null:
		_tutorial_hint.text = "[SPACE] CLOSE" if _tutorial_page_index == TUTORIAL_PAGES.size() - 1 else "[SPACE] NEXT"

func _end_axiom_tutorial() -> void:
	_tutorial_active = false
	_tutorial_space_consumed = false
	if _tutorial_panel != null:
		_tutorial_panel.visible = false
	_set_objective_state("escape_hole")
	_world._set_intro_lock(false)
	_escape_time_left = ESCAPE_DURATION
	_escape_timer_running = true
	_small_meteor_spawn_timer = SMALL_METEOR_INTERVAL
	_update_escape_timer_label()
	if _timer_label != null:
		_timer_label.visible = true

func _update_escape_timer_label() -> void:
	if _timer_label == null:
		return
	var secs := maxi(int(ceil(_escape_time_left)), 0)
	var minutes: int = int(secs / 60)
	var seconds: int = secs % 60
	_timer_label.text = "%02d:%02d" % [minutes, seconds]
	if secs <= 10:
		_timer_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.34, 1.0))
	else:
		_timer_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.64, 1.0))

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
	await _play_axiom_bind_effect()
	await _world._set_cinematic_bars(true, 0.35)
	
	var player_transform: Transform3D = _world.player_camera.global_transform
	var split_start: Transform3D = Transform3D(Basis(), _world.house.to_global(Vector3(16.0, 4.0, 8.0))).looking_at(_world.house.to_global(Vector3(0.0, -0.8, 0.0)), Vector3.UP)
	var split_end: Transform3D = Transform3D(Basis(), _world.house.to_global(Vector3(20.4, 12.0, 0.4))).looking_at(_world.house.to_global(Vector3(0.0, -1.1, 0.0)), Vector3.UP)
	
	_world._intro_camera.global_transform = player_transform
	_world._intro_camera.make_current()
	await _world._play_camera_shot(player_transform, split_start, 1.2)
	await _world._show_subtitle("What did I just pick up?", 1.8)
	await _world._play_camera_shot(split_start, split_end, 2.1)
	await _play_house_split_glitch()
	_ensure_underground_hole()
	await _world._show_subtitle("No... it's splitting the house apart.", 2.0)
	await _world._show_subtitle("It's recording everything now.", 1.9)
	await _world._return_intro_camera_to_player(0.95)
	await _world._set_cinematic_bars(false, 0.32)
	_begin_post_split_escape_phase()
	_level_one_sequence_running = false

func _play_house_split_glitch() -> void:
	_set_level_one_terrain_enabled(false)
	_ensure_broken_house()
	_attach_underground_hole_to_broken_house()
	_refresh_split_origins()
	if _glitch_fragments_root != null:
		_glitch_fragments_root.visible = true
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = true
		_world._glitch_overlay.modulate.a = 0.0
	var glitch_in: Tween = _world.create_tween()
	if _world._glitch_overlay != null:
		glitch_in.tween_property(_world._glitch_overlay, "modulate:a", 0.78, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		glitch_in.parallel().tween_method(_world._set_arrival_glitch_strength, 0.0, 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _broken_house_instance != null:
		glitch_in.parallel().tween_method(Callable(_broken_house_instance, "set_split_weight"), 0.0, 1.0, 1.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await glitch_in.finished
	await _world.get_tree().create_timer(0.72).timeout
	var glitch_out: Tween = _world.create_tween()
	if _world._glitch_overlay != null:
		glitch_out.tween_property(_world._glitch_overlay, "modulate:a", 0.0, 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glitch_out.parallel().tween_method(_world._set_arrival_glitch_strength, 1.0, 0.0, 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await glitch_out.finished
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = false

func play_escape_fail_sequence() -> void:
	_escape_timer_running = false
	_tutorial_active = false
	_clear_small_meteors()
	if _timer_label != null:
		_timer_label.visible = false
	if _tutorial_panel != null:
		_tutorial_panel.visible = false
	_set_objective_state("")
	_world._hint_marker.visible = false
	_world._hint_label.visible = false
	_world._set_intro_lock(true)
	_world._intro_running = false
	await _world._set_cinematic_bars(true, 0.28)
	var house_origin: Vector3 = _world.house.global_position
	var fail_start: Transform3D = Transform3D(Basis(), _world.house.to_global(Vector3(25.6, 14.2, 5.8))).looking_at(_world.house.to_global(Vector3(0.0, -0.8, 0.0)), Vector3.UP)
	_world._intro_camera.global_transform = fail_start
	_world._intro_camera.make_current()
	await _world.get_tree().create_timer(0.7).timeout
	var meteor_root := Node3D.new()
	_world.add_child(meteor_root)
	var meteor_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.6
	sphere.height = 5.2
	meteor_mesh.mesh = sphere
	meteor_mesh.material_override = _make_glitch_meteor_material(Color(0.26, 0.98, 1.0, 1.0), 3.2, 3.3)
	meteor_root.add_child(meteor_mesh)
	var meteor_light := OmniLight3D.new()
	meteor_light.light_color = Color(0.26, 0.92, 1.0, 1.0)
	meteor_light.light_energy = 2.0
	meteor_light.omni_range = 22.0
	meteor_root.add_child(meteor_light)
	var start_position: Vector3 = house_origin + Vector3(42.0, 44.0, 28.0)
	var impact_position: Vector3 = house_origin + Vector3(0.4, 1.2, -0.4)
	meteor_root.global_position = start_position
	_world._intro_camera.global_transform = fail_start
	_world._intro_camera.make_current()
	var fall: Tween = _world.create_tween()
	fall.tween_property(meteor_root, "global_position", impact_position, 3.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(meteor_root, "scale", Vector3(2.2, 2.2, 2.2), 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fall.finished
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = true
		_world._glitch_overlay.modulate.a = 0.0
	var impact_flash: Tween = _world.create_tween()
	if _world._white_overlay != null:
		impact_flash.tween_property(_world._white_overlay, "modulate:a", 0.9, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		impact_flash.parallel().tween_property(_world._white_overlay, "modulate:a", 0.0, 0.48).set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _world._glitch_overlay != null:
		impact_flash.parallel().tween_property(_world._glitch_overlay, "modulate:a", 0.95, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		impact_flash.parallel().tween_property(_world._glitch_overlay, "modulate:a", 0.0, 0.7).set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		impact_flash.parallel().tween_method(_world._set_arrival_glitch_strength, 0.0, 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		impact_flash.parallel().tween_method(_world._set_arrival_glitch_strength, 1.0, 0.0, 0.7).set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _play_meteor_explosion(impact_position, 12.0, 1.4)
	await impact_flash.finished
	meteor_root.queue_free()
	await _world.get_tree().create_timer(0.9).timeout
	_world.restart_current_level()

func _spawn_small_meteor() -> void:
	if _world.house == null:
		return
	var meteor_root := Node3D.new()
	_world.add_child(meteor_root)
	var meteor_mesh := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.36
	mesh.height = 0.72
	meteor_mesh.mesh = mesh
	meteor_mesh.material_override = _make_glitch_meteor_material(Color(1.0, 0.26, 0.84, 1.0), 2.2, 2.4)
	meteor_root.add_child(meteor_mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.42, 0.86, 1.0)
	light.light_energy = 1.4
	light.omni_range = 6.5
	meteor_root.add_child(light)
	var angle := randf() * TAU
	var radius := 7.0 + randf() * 10.0
	var target_position: Vector3 = _world.house.to_global(Vector3(cos(angle) * radius, 0.3 + randf() * 0.8, sin(angle) * radius))
	var start_position: Vector3 = target_position + Vector3(randf_range(-1.6, 1.6), 17.0 + randf() * 4.0, randf_range(-1.6, 1.6))
	meteor_root.global_position = start_position
	var velocity: Vector3 = (target_position - start_position).normalized() * (12.0 + randf() * 4.0)
	_active_small_meteors.append({
		"node": meteor_root,
		"velocity": velocity,
		"life": 3.2
	})

func _update_small_meteors(delta: float) -> void:
	if _active_small_meteors.is_empty():
		return
	var space_state: PhysicsDirectSpaceState3D = _world.get_world_3d().direct_space_state
	var survivors: Array = []
	for meteor_data in _active_small_meteors:
		var meteor_root := meteor_data["node"] as Node3D
		if not is_instance_valid(meteor_root):
			continue
		var velocity: Vector3 = meteor_data["velocity"]
		var life: float = float(meteor_data["life"]) - delta
		var from := meteor_root.global_position
		var to := from + velocity * delta
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = true
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			meteor_root.global_position = to
			meteor_root.rotate_y(delta * 7.0)
			meteor_data["life"] = life
			if life > 0.0:
				survivors.append(meteor_data)
			else:
				_play_small_meteor_hit(meteor_root.global_position, false)
				meteor_root.queue_free()
			continue
		var collider = hit.get("collider")
		var hit_position: Vector3 = hit.get("position", to)
		var hit_player := false
		if collider == _world.player:
			hit_player = true
		elif collider is Node and _world.player != null:
			var collider_node: Node = collider as Node
			if collider_node != null and _world.player.is_ancestor_of(collider_node):
				hit_player = true
		_play_small_meteor_hit(hit_position, hit_player)
		meteor_root.queue_free()
	_active_small_meteors = survivors

func _play_small_meteor_hit(position: Vector3, hit_player: bool) -> void:
	_world.call_deferred("_play_level_one_small_meteor_explosion", position, hit_player)

func play_small_meteor_explosion(position: Vector3, hit_player: bool) -> void:
	await _play_meteor_explosion(position, 7.8 if hit_player else 5.4, 0.42, 30.0, 4.6 if hit_player else 3.8)

func _play_meteor_explosion(position: Vector3, scale: float, duration: float, damage_amount: float = 0.0, damage_radius: float = 0.0) -> void:
	if damage_amount > 0.0 and damage_radius > 0.0 and _world.player != null and _world.player.has_method("take_damage"):
		var player_distance: float = _world.player.global_position.distance_to(position)
		if player_distance <= damage_radius:
			_world.player.call("take_damage", damage_amount)
	var explosion := Node3D.new()
	_world.add_child(explosion)
	explosion.global_position = position
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	sphere.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.34, 0.88, 0.42)
	material.emission_enabled = true
	material.emission = Color(0.28, 0.96, 1.0, 1.0)
	material.emission_energy_multiplier = 3.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material_override = material
	explosion.add_child(sphere)
	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 0.94, 1.0, 1.0)
	light.light_energy = 3.0
	light.omni_range = 9.0 * scale
	explosion.add_child(light)
	var burst: Tween = _world.create_tween()
	burst.set_parallel(true)
	burst.tween_property(explosion, "scale", Vector3.ONE * scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	burst.tween_property(light, "light_energy", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	burst.tween_property(sphere, "transparency", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await burst.finished
	explosion.queue_free()

func _make_glitch_meteor_material(color: Color, energy: float, rim: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = METEOR_SHADER
	material.set_shader_parameter("base_color", Vector3(color.r, color.g, color.b))
	material.set_shader_parameter("emission_energy", energy)
	material.set_shader_parameter("glitch_intensity", 1.5)
	material.set_shader_parameter("rim_strength", rim)
	material.set_shader_parameter("pulse_strength", 1.5)
	return material

func _play_axiom_bind_effect() -> void:
	if _world.player == null:
		return
	var root := Node3D.new()
	root.position = _world.player.global_position + Vector3(0.0, 0.95, 0.0)
	_world.add_child(root)
	var aura_material := StandardMaterial3D.new()
	aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_material.albedo_color = Color(0.16, 0.82, 1.0, 0.28)
	aura_material.emission_enabled = true
	aura_material.emission = Color(0.16, 0.82, 1.0, 1.0)
	aura_material.emission_energy_multiplier = 1.8
	aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var spark_material := StandardMaterial3D.new()
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.albedo_color = Color(1.0, 0.3, 0.78, 0.24)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.3, 0.78, 1.0)
	spark_material.emission_energy_multiplier = 2.0
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.52
	sphere_mesh.height = 1.04
	sphere.mesh = sphere_mesh
	sphere.material_override = aura_material
	root.add_child(sphere)
	var ring_a := MeshInstance3D.new()
	var ring_mesh_a := CylinderMesh.new()
	ring_mesh_a.top_radius = 0.72
	ring_mesh_a.bottom_radius = 0.72
	ring_mesh_a.height = 0.06
	ring_a.mesh = ring_mesh_a
	ring_a.material_override = aura_material
	ring_a.position = Vector3(0.0, -0.32, 0.0)
	root.add_child(ring_a)
	var ring_b := MeshInstance3D.new()
	var ring_mesh_b := CylinderMesh.new()
	ring_mesh_b.top_radius = 0.38
	ring_mesh_b.bottom_radius = 0.38
	ring_mesh_b.height = 0.05
	ring_b.mesh = ring_mesh_b
	ring_b.material_override = spark_material
	ring_b.position = Vector3(0.0, 0.24, 0.0)
	root.add_child(ring_b)
	var light := OmniLight3D.new()
	light.light_color = Color(0.28, 0.88, 1.0, 1.0)
	light.light_energy = 0.25
	light.omni_range = 4.0
	root.add_child(light)
	var particles := GPUParticles3D.new()
	particles.amount = 42
	particles.lifetime = 0.95
	particles.one_shot = false
	particles.explosiveness = 0.15
	particles.randomness = 0.65
	var particle_material := ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0.0, 1.0, 0.0)
	particle_material.spread = 70.0
	particle_material.initial_velocity_min = 0.35
	particle_material.initial_velocity_max = 1.15
	particle_material.gravity = Vector3(0.0, 0.2, 0.0)
	particle_material.scale_min = 0.08
	particle_material.scale_max = 0.16
	particle_material.color = Color(0.8, 0.96, 1.0, 1.0)
	particles.process_material = particle_material
	var particle_draw := SphereMesh.new()
	particle_draw.radius = 0.045
	particle_draw.height = 0.09
	particles.draw_pass_1 = particle_draw
	root.add_child(particles)
	particles.emitting = true
	sphere.scale = Vector3(0.2, 0.2, 0.2)
	ring_a.scale = Vector3(0.4, 1.0, 0.4)
	ring_b.scale = Vector3(0.3, 1.0, 0.3)
	var pulse: Tween = _world.create_tween()
	pulse.set_parallel(true)
	pulse.tween_property(sphere, "scale", Vector3(1.7, 1.7, 1.7), 0.92).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse.tween_property(sphere, "position:y", 0.18, 0.92).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse.tween_property(ring_a, "scale", Vector3(2.8, 1.0, 2.8), 0.92).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pulse.tween_property(ring_b, "scale", Vector3(3.5, 1.0, 3.5), 0.92).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pulse.tween_property(ring_b, "position:y", 0.72, 0.92).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pulse.tween_property(light, "light_energy", 2.2, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse.tween_property(light, "light_energy", 0.0, 0.5).set_delay(0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	pulse.tween_property(root, "rotation:y", TAU, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(sphere, "transparency", 1.0, 0.34).set_delay(0.58)
	pulse.tween_property(ring_a, "transparency", 1.0, 0.34).set_delay(0.58)
	pulse.tween_property(ring_b, "transparency", 1.0, 0.34).set_delay(0.58)
	await _world.get_tree().create_timer(0.98).timeout
	root.queue_free()

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

func _ensure_underground_hole() -> void:
	if not is_instance_valid(_underground_hole_instance):
		return
	if _underground_hole_instance.has_method("set_interactable_enabled"):
		_underground_hole_instance.call("set_interactable_enabled", true)
	_pulse_objective_highlight(_underground_hole_instance, 1.0, 1.0)

func _attach_underground_hole_to_broken_house() -> void:
	if not is_instance_valid(_underground_hole_instance) or _broken_house_instance == null:
		return
	var back_half := _broken_house_instance.get_node_or_null("BackHalf") as Node3D
	if back_half == null or _underground_hole_instance.get_parent() == back_half:
		return
	var hole_transform := _underground_hole_instance.global_transform
	var current_parent := _underground_hole_instance.get_parent()
	if current_parent != null:
		current_parent.remove_child(_underground_hole_instance)
	back_half.add_child(_underground_hole_instance)
	_underground_hole_instance.global_transform = hole_transform

func _on_underground_hole_descended() -> void:
	_escape_timer_running = false
	_tutorial_active = false
	_escape_failed_sequence_started = true
	_clear_small_meteors()
	if _timer_label != null:
		_timer_label.visible = false
	if _tutorial_panel != null:
		_tutorial_panel.visible = false
	_set_objective_state("")
	_world._hint_marker.visible = false
	_world._hint_label.visible = false

func _clear_small_meteors() -> void:
	for meteor_data in _active_small_meteors:
		var meteor_root := meteor_data.get("node") as Node3D
		if is_instance_valid(meteor_root):
			meteor_root.queue_free()
	_active_small_meteors.clear()

func _pulse_objective_highlight(target: Node, minimum: float, maximum: float) -> void:
	if target == null or not target.has_method("set_highlight_strength"):
		return
	var pulse := sin(_world._pulse_time * 1.6) * 0.5 + 0.5
	target.call("set_highlight_strength", lerpf(minimum, maximum, pulse))

func _set_level_one_terrain_enabled(enabled: bool) -> void:
	if _terrain_root == null:
		return
	if _terrain_root is CanvasItem:
		(_terrain_root as CanvasItem).visible = enabled
	elif _terrain_root is Node3D:
		(_terrain_root as Node3D).visible = enabled
	_set_level_one_terrain_enabled_recursive(_terrain_root, enabled)

func _set_level_one_terrain_enabled_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enabled
	elif node is StaticBody3D:
		(node as StaticBody3D).collision_layer = 1 if enabled else 0
		(node as StaticBody3D).collision_mask = 1 if enabled else 0
	elif node is Area3D:
		(node as Area3D).collision_layer = 1 if enabled else 0
		(node as Area3D).collision_mask = 1 if enabled else 0
	elif node is CSGShape3D:
		(node as CSGShape3D).use_collision = enabled
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).visible = enabled
	elif node is Node3D:
		(node as Node3D).visible = enabled
	for child in node.get_children():
		_set_level_one_terrain_enabled_recursive(child, enabled)

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
