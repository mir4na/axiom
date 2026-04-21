extends Node3D

const SCALE_LERP_SPEED := 8.0
const ROTATION_SPEED := 0.005
const PITCH_LIMIT := 70.0
const INTRO_LINES := [
	{"text": "What time is it?", "duration": 2.0},
	{"text": "Why does my head feel so heavy?", "duration": 2.2},
	{"text": "Right... I still need to clear out the yard.", "duration": 2.8},
	{"text": "The scoop should still be outside.", "duration": 2.4}
]
const WORLD_SCENE_PATH := "res://scenes/world/world.tscn"
const LEVEL_ONE_SCENE_PATH := "res://scenes/levels/level_01.tscn"
const LEVEL_TWO_SCENE_PATH := "res://scenes/levels/level_02.tscn"
const LEVEL_ONE_WHITE_META := "level_one_white_intro"
const LEVEL_ONE_FLOW := preload("res://scripts/world/level_one_flow.gd")
const OBJECTIVE_PANEL_SCENE := preload("res://scenes/ui/objective_panel.tscn")

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var player_camera: Camera3D = get_node_or_null("Player/root/Skeleton3D/BoneAttachment3D/Head/Camera3D") as Camera3D
@onready var player_hud: CanvasLayer = get_node_or_null("Player/PlayerHUD") as CanvasLayer
@onready var shovel: Node3D = get_node_or_null("Shovel") as Node3D
@onready var house: Node3D = get_node_or_null("House") as Node3D
@onready var objective_config: Node = get_node_or_null("ObjectiveConfig")

var _target_scale: float = 1.0
var _yaw: float = 0.0
var _pitch: float = 0.0
var _pulse_time: float = 0.0
var _intro_motion_time: float = 0.0
var _player_spawn_position: Vector3 = Vector3(8.0, 1.0, -9.25)
var _player_spawn_rotation_y: float = PI
var _intro_camera_position: Vector3 = Vector3(7.3, 1.3, -10.0)
var _intro_camera_target: Vector3 = Vector3(8.0, 7.5, -10.9)
var _intro_running: bool = false
var _objective_state: String = ""
var _total_dig_spots: int = 0
var _completed_dig_spots: int = 0
var _transition_started: bool = false
var _dig_spots: Array[Node3D] = []
var _sofa_target: Node3D
var _window_target: Node3D
var _sofa_interactable

var _intro_ui: CanvasLayer
var _intro_camera: Camera3D
var _wake_overlay: ColorRect
var _blink_overlay: ColorRect
var _fade_overlay: ColorRect
var _white_overlay: ColorRect
var _glitch_overlay: ColorRect
var _subtitle_label: Label
var _objective_panel: Control
var _objective_tag: Label
var _objective_label: Label
var _hint_marker: ColorRect
var _hint_label: Label
var _loading_label: Label
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _sofa_aura: MeshInstance3D
var _sofa_light: OmniLight3D
var _meteor: MeshInstance3D
var _meteor_light: OmniLight3D
var _level_one_flow
var _level_two_key: Node3D
var _level_two_door: Node3D
var _level_two_trap_gate_south: StaticBody3D
var _level_two_trap_gate_north: StaticBody3D
var _level_two_trap_laser: Node3D
var _level_two_trap_beam: MeshInstance3D
var _level_two_trap_light: OmniLight3D
var _level_two_trap_triggered: bool = false
var _level_two_trap_running: bool = false

func _screen_fx() -> CanvasLayer:
	return get_node_or_null("/root/ScreenFX") as CanvasLayer

func _ready() -> void:
	GameState.world_scaled.connect(_on_world_scaled)
	GameState.world_rotated.connect(_on_world_rotated)
	GameState.inventory_changed.connect(_on_inventory_changed)
	var screen_fx := _screen_fx()
	if screen_fx != null:
		screen_fx.set_gameplay_filter_enabled(true)
	_apply_player_spawn()
	if _is_level_one_scene():
		_create_intro_ui()
		_create_intro_camera()
		_level_one_flow = LEVEL_ONE_FLOW.new(self)
		_level_one_flow.initialize()
		if player_hud != null:
			player_hud.visible = true
		if GameState.has_meta(LEVEL_ONE_WHITE_META) and bool(GameState.get_meta(LEVEL_ONE_WHITE_META)):
			_set_intro_lock(true)
			call_deferred("_play_level_one_arrival")
		return
	if _is_level_two_scene():
		_create_intro_ui()
		_create_intro_camera()
		_cache_level_two_targets()
		_reset_level_two_view_state()
		_intro_running = false
		_objective_state = "level2_key"
		call_deferred("_play_level_two_intro")
		return
	if not _is_world_intro_scene():
		return
	_configure_world_house()
	_cache_world_targets()
	_collect_dig_spots()
	_total_dig_spots = _dig_spots.size()
	GameState.reset_world_state()
	_create_intro_ui()
	_create_intro_camera()
	_create_sofa_interactable()
	_create_sofa_highlight()
	_create_meteor_nodes()
	_prepare_world_phase()
	_set_intro_lock(true)
	call_deferred("_play_intro_sequence")

func _process(delta: float) -> void:
	var current: float = scale.x
	var next: float = current + ((_target_scale - current) * SCALE_LERP_SPEED * delta)
	scale = Vector3(next, next, next)

	rotation.y = lerpf(rotation.y, _yaw, SCALE_LERP_SPEED * delta)
	rotation.x = lerpf(rotation.x, _pitch, SCALE_LERP_SPEED * delta)

	_pulse_time += delta * 3.6
	if _intro_running:
		_intro_motion_time += delta
		_update_intro_camera_motion()

	if _is_level_one_scene():
		if _level_one_flow != null:
			_level_one_flow.process_objectives()
		return
	if _is_level_two_scene():
		if _objective_state == "level2_key" and is_instance_valid(_level_two_key):
			_set_level_two_target_glow(_level_two_key, true)
			_set_level_two_target_glow(_level_two_door, false)
			_update_hint_marker(_level_two_key.global_position + Vector3(0.0, 0.55, 0.0), "KEY", _level_two_key.global_position)
		elif _objective_state == "level2_door" and is_instance_valid(_level_two_door):
			_set_level_two_target_glow(_level_two_key, false)
			_set_level_two_target_glow(_level_two_door, true)
			_update_hint_marker(_level_two_door.global_position + Vector3(0.0, 1.0, 0.0), "DOOR", _level_two_door.global_position)
		else:
			_set_level_two_target_glow(_level_two_key, false)
			_set_level_two_target_glow(_level_two_door, false)
			_hint_marker.visible = false
			_hint_label.visible = false
		return
	if not _is_world_intro_scene():
		return

	if _objective_state == "scoop" and is_instance_valid(shovel):
		_update_shovel_highlight()
		_update_hint_marker(shovel.global_position + Vector3(0.0, 1.1, 0.0), "SCOOP", shovel.global_position)
	elif _objective_state == "rest" and is_instance_valid(_sofa_target):
		_update_sofa_highlight()
		_update_hint_marker(_sofa_target.global_position + Vector3(0.0, -0.8, 0.25), "SOFA", _sofa_target.global_position)
	else:
		_hint_marker.visible = false
		_hint_label.visible = false
		_clear_target_highlights()

func _on_world_scaled(scale_factor: float) -> void:
	_target_scale = scale_factor

func _on_world_rotated(delta: Vector2) -> void:
	_yaw -= delta.x * ROTATION_SPEED
	_pitch -= delta.y * ROTATION_SPEED
	_pitch = clampf(_pitch, deg_to_rad(-PITCH_LIMIT), deg_to_rad(PITCH_LIMIT))

func _on_inventory_changed() -> void:
	if _is_level_one_scene():
		if _level_one_flow != null:
			_level_one_flow.handle_inventory_changed()
		return
	if _is_level_two_scene():
		if _objective_state == "level2_key" and GameState.has_item("key_1"):
			if not _level_two_trap_triggered:
				call_deferred("_run_level_two_keycard_sequence")
			elif not _level_two_trap_running:
				_objective_state = "level2_door"
				_show_objective("Open door 1")
		return
	if not _is_world_intro_scene():
		return
	if _objective_state == "scoop" and GameState.has_item("Shovel"):
		_begin_dig_phase()

func _create_intro_ui() -> void:
	_intro_ui = CanvasLayer.new()
	_intro_ui.layer = 20
	add_child(_intro_ui)

	_wake_overlay = ColorRect.new()
	_wake_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var wake_shader := ShaderMaterial.new()
	wake_shader.shader = load("res://shaders/wake_blur.gdshader")
	_wake_overlay.material = wake_shader
	_intro_ui.add_child(_wake_overlay)

	_blink_overlay = ColorRect.new()
	_blink_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blink_overlay.color = Color(0, 0, 0, 1)
	_blink_overlay.modulate.a = 1.0
	_intro_ui.add_child(_blink_overlay)

	_fade_overlay = ColorRect.new()
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color(0, 0, 0, 1)
	_fade_overlay.modulate.a = 0.0
	_intro_ui.add_child(_fade_overlay)

	_white_overlay = ColorRect.new()
	_white_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white_overlay.color = Color(1, 1, 1, 1)
	_white_overlay.modulate.a = 0.0
	_intro_ui.add_child(_white_overlay)

	_glitch_overlay = ColorRect.new()
	_glitch_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glitch_overlay.color = Color(1, 1, 1, 1)
	var glitch_material := ShaderMaterial.new()
	glitch_material.shader = load("res://shaders/arrival_glitch.gdshader")
	_glitch_overlay.material = glitch_material
	_glitch_overlay.visible = false
	_intro_ui.add_child(_glitch_overlay)

	_top_bar = ColorRect.new()
	_top_bar.anchor_left = 0.0
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_right = 1.0
	_top_bar.anchor_bottom = 0.0
	_top_bar.offset_left = 0.0
	_top_bar.offset_top = 0.0
	_top_bar.offset_right = 0.0
	_top_bar.offset_bottom = 0.0
	_top_bar.color = Color(0, 0, 0, 1)
	_top_bar.visible = false
	_intro_ui.add_child(_top_bar)

	_bottom_bar = ColorRect.new()
	_bottom_bar.anchor_left = 0.0
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.offset_left = 0.0
	_bottom_bar.offset_top = 0.0
	_bottom_bar.offset_right = 0.0
	_bottom_bar.offset_bottom = 0.0
	_bottom_bar.color = Color(0, 0, 0, 1)
	_bottom_bar.visible = false
	_intro_ui.add_child(_bottom_bar)

	_objective_panel = OBJECTIVE_PANEL_SCENE.instantiate() as Control
	_objective_panel.anchor_left = 1.0
	_objective_panel.anchor_top = 0.0
	_objective_panel.anchor_right = 1.0
	_objective_panel.anchor_bottom = 0.0
	_objective_panel.visible = false
	_intro_ui.add_child(_objective_panel)
	_objective_tag = _objective_panel.get_node("Tag") as Label
	_objective_label = _objective_panel.get_node("Text") as Label

	_subtitle_label = Label.new()
	_subtitle_label.anchor_left = 0.16
	_subtitle_label.anchor_top = 0.76
	_subtitle_label.anchor_right = 0.84
	_subtitle_label.anchor_bottom = 0.92
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.visible = false
	_subtitle_label.add_theme_font_size_override("font_size", 28)
	_set_subtitle_palette(false)
	_intro_ui.add_child(_subtitle_label)

	_hint_marker = ColorRect.new()
	_hint_marker.color = Color(0.87, 0.98, 0.67, 0.92)
	_hint_marker.custom_minimum_size = Vector2(16.0, 16.0)
	_hint_marker.size = Vector2(16.0, 16.0)
	_hint_marker.visible = false
	_intro_ui.add_child(_hint_marker)

	_hint_label = Label.new()
	_hint_label.visible = false
	_hint_label.add_theme_font_size_override("font_size", 20)
	_hint_label.add_theme_color_override("font_color", Color(0.92, 0.98, 0.86, 1.0))
	_hint_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.88))
	_hint_label.add_theme_constant_override("outline_size", 10)
	_intro_ui.add_child(_hint_label)

	_loading_label = Label.new()
	_loading_label.anchor_left = 0.0
	_loading_label.anchor_top = 0.0
	_loading_label.anchor_right = 1.0
	_loading_label.anchor_bottom = 1.0
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 120)
	_loading_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	_loading_label.visible = false
	_intro_ui.add_child(_loading_label)

func _create_intro_camera() -> void:
	_intro_camera = Camera3D.new()
	_intro_camera.name = "IntroCamera"
	_intro_camera.current = false
	_intro_camera.position = _intro_camera_position
	_intro_camera.look_at(_intro_camera_target, Vector3.FORWARD)
	add_child(_intro_camera)

func _create_sofa_interactable() -> void:
	if _sofa_target == null:
		return
	_sofa_interactable = StaticBody3D.new()
	_sofa_interactable.name = "SofaInteractable"
	_sofa_interactable.set_script(load("res://scripts/objects/sofa_rest.gd"))
	_sofa_interactable.collision_layer = 1
	_sofa_interactable.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.8, 1.3, 1.9)
	collision.shape = shape
	_sofa_interactable.add_child(collision)
	_sofa_interactable.position = Vector3(0.0, -1.25, 0.2)
	_sofa_target.add_child(_sofa_interactable)
	_sofa_interactable.rest_requested.connect(_on_sofa_rest_requested)
	_sofa_interactable.set_interactable_enabled(false)

func _create_sofa_highlight() -> void:
	if _sofa_target == null:
		return
	_sofa_aura = MeshInstance3D.new()
	var aura_mesh := BoxMesh.new()
	aura_mesh.size = Vector3(4.4, 1.6, 2.25)
	_sofa_aura.mesh = aura_mesh
	var aura_mat := ShaderMaterial.new()
	aura_mat.shader = load("res://shaders/objective_highlight.gdshader")
	aura_mat.set_shader_parameter("glow_color", Color(1.0, 0.72, 0.38, 1.0))
	aura_mat.set_shader_parameter("highlight_strength", 0.0)
	_sofa_aura.material_override = aura_mat
	_sofa_aura.position = Vector3(0.0, -1.32, 0.32)
	_sofa_aura.visible = false
	_sofa_target.add_child(_sofa_aura)

	_sofa_light = OmniLight3D.new()
	_sofa_light.position = Vector3(0.0, -1.0, 0.2)
	_sofa_light.light_color = Color(1.0, 0.66, 0.28, 1.0)
	_sofa_light.light_energy = 0.0
	_sofa_light.omni_range = 4.8
	_sofa_light.visible = false
	_sofa_target.add_child(_sofa_light)

func _create_meteor_nodes() -> void:
	_meteor = MeshInstance3D.new()
	var meteor_mesh := SphereMesh.new()
	meteor_mesh.radius = 0.22
	_meteor.mesh = meteor_mesh
	var meteor_mat := StandardMaterial3D.new()
	meteor_mat.emission_enabled = true
	meteor_mat.emission = Color(1.0, 0.46, 0.12, 1.0)
	meteor_mat.emission_energy_multiplier = 9.0
	meteor_mat.albedo_color = Color(1.0, 0.68, 0.25, 1.0)
	meteor_mat.metallic = 0.15
	meteor_mat.roughness = 0.18
	_meteor.material_override = meteor_mat
	_meteor.visible = false
	add_child(_meteor)

	_meteor_light = OmniLight3D.new()
	_meteor_light.light_color = Color(1.0, 0.58, 0.2, 1.0)
	_meteor_light.light_energy = 0.0
	_meteor_light.omni_range = 8.0
	_meteor_light.visible = false
	add_child(_meteor_light)

func _prepare_world_phase() -> void:
	GameState.full_reset_inventory()
	GameState.rewind_mode_active = false
	GameState.time_direction = GameState.TIME_FORWARD
	GameState.world_history.clear()
	GameState.history_index = -1
	GameState.rewind_pointer_index = -1
	_completed_dig_spots = 0
	_objective_state = ""
	_transition_started = false
	if player != null:
		player.global_position = _player_spawn_position
		player.rotation.y = _player_spawn_rotation_y

func _collect_dig_spots() -> void:
	_dig_spots.clear()
	for child in get_children():
		if child.name.begins_with("DigSpot"):
			_dig_spots.append(child)
			if child.has_signal("dig_completed"):
				child.dig_completed.connect(_on_dig_spot_completed)

func _cache_world_targets() -> void:
	if house == null:
		return
	_sofa_target = house.get_node_or_null("Living/Sofa") as Node3D
	_window_target = house.get_node_or_null("Shell/Win2") as Node3D

func _apply_player_spawn() -> void:
	if player == null:
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var spawner := current_scene.get_node_or_null("PlayerSpawner") as Marker3D
	if spawner == null:
		spawner = current_scene.get_node_or_null("SpawnPlayer") as Marker3D
	if spawner == null:
		spawner = current_scene.get_node_or_null("PlayerSpawn") as Marker3D
	if spawner == null:
		return
	_player_spawn_position = spawner.global_position
	player.global_position = _player_spawn_position
	if _is_level_two_scene():
		_player_spawn_rotation_y = player.rotation.y
	else:
		_player_spawn_rotation_y = spawner.global_rotation.y
		player.rotation.y = _player_spawn_rotation_y

func _configure_world_house() -> void:
	if house == null:
		return
	var guest_door_gap := house.get_node_or_null("Partitions/GuestDoorGap") as CSGBox3D
	var guest_door = house.get_node_or_null("GuestDoor")
	var guest_btn_out = house.get_node_or_null("GuestDoorBtnOut")
	var guest_btn_in = house.get_node_or_null("GuestDoorBtnIn")
	if guest_door_gap != null:
		guest_door_gap.operation = CSGShape3D.OPERATION_UNION
		guest_door_gap.material = _make_house_wall_material()
	if guest_door != null:
		guest_door.visible = false
		guest_door.process_mode = Node.PROCESS_MODE_DISABLED
		var guest_door_collision := guest_door.get_node_or_null("Collision") as CollisionShape3D
		if guest_door_collision != null:
			guest_door_collision.disabled = true
	if guest_btn_out != null:
		guest_btn_out.visible = false
		guest_btn_out.process_mode = Node.PROCESS_MODE_DISABLED
		var guest_btn_out_collision := guest_btn_out.get_node_or_null("Collision") as CollisionShape3D
		if guest_btn_out_collision != null:
			guest_btn_out_collision.disabled = true
	if guest_btn_in != null:
		guest_btn_in.visible = false
		guest_btn_in.process_mode = Node.PROCESS_MODE_DISABLED
		var guest_btn_in_collision := guest_btn_in.get_node_or_null("Collision") as CollisionShape3D
		if guest_btn_in_collision != null:
			guest_btn_in_collision.disabled = true

func _make_house_wall_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.88, 0.82, 1.0)
	return mat

func _set_intro_lock(locked: bool) -> void:
	_intro_running = locked
	if locked:
		_intro_motion_time = 0.0
		if player != null:
			player.set_cinematic_lock(true)
		if player_hud != null:
			player_hud.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if player != null:
			player.set_cinematic_lock(false)
		if player_hud != null:
			player_hud.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _play_intro_sequence() -> void:
	await get_tree().process_frame
	_activate_intro_camera()
	_blink_overlay.modulate.a = 1.0
	await _open_eyes(0.26)
	await _tween_wake_overlay(0.72, 1.0)
	for line in INTRO_LINES:
		await _show_subtitle(line["text"], line["duration"])
		if line["text"] == "What time is it?":
			await _blink_once(0.18, 0.22)
		if line["text"] == "Why does my head feel so heavy?":
			await _tween_wake_overlay(0.42, 1.4)
		elif line["text"] == "Right... I still need to clear out the yard.":
			await _blink_once(0.09, 0.16)
	await _tween_wake_overlay(0.0, 1.5)
	_subtitle_label.visible = false
	_intro_running = false
	await _restore_player_camera()
	_show_objective(_objective_text("scoop", "OBJECTIVE: Pick up the scoop"))
	_objective_state = "scoop"
	await _show_subtitle("I should grab the scoop before I start digging.", 2.5)
	_set_intro_lock(false)

func _play_level_one_arrival() -> void:
	if _level_one_flow != null:
		await _level_one_flow.play_arrival()

func _play_level_two_intro() -> void:
	await get_tree().process_frame
	if player != null:
		player.set_cinematic_lock(true)
	if player_hud != null:
		player_hud.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await _set_cinematic_bars(true, 0.35)
	await get_tree().create_timer(3.0).timeout
	await _set_cinematic_bars(false, 0.35)
	if player != null:
		player.set_cinematic_lock(false)
	if player_hud != null:
		player_hud.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_show_objective("Take the keycard to open door 1")

func _play_level_one_guest_door_reveal_cinematic() -> void:
	if _level_one_flow != null:
		await _level_one_flow.play_guest_door_reveal_cinematic()

func _play_level_one_guest_door_locked_sequence() -> void:
	if _level_one_flow != null:
		await _level_one_flow.play_guest_door_locked_sequence()

func _play_level_one_guest_key_pickup_subtitle() -> void:
	if _level_one_flow != null:
		await _level_one_flow.play_guest_key_pickup_subtitle()

func _play_level_one_guest_room_opened_subtitle() -> void:
	if _level_one_flow != null:
		await _level_one_flow.play_guest_room_opened_subtitle()

func _play_level_one_axiom_equip_sequence() -> void:
	if _level_one_flow != null:
		await _level_one_flow.play_axiom_equip_sequence()

func _play_level_one_escape_fail_sequence() -> void:
	if _level_one_flow != null:
		await _level_one_flow.play_escape_fail_sequence()

func _play_level_one_small_meteor_explosion(position: Vector3, hit_player: bool) -> void:
	if _level_one_flow != null:
		await _level_one_flow.play_small_meteor_explosion(position, hit_player)

func _cache_level_two_targets() -> void:
	_level_two_key = get_node_or_null("KeyItem") as Node3D
	_level_two_door = get_node_or_null("Door2") as Node3D
	_level_two_trap_gate_south = get_node_or_null("TrapGateSouth") as StaticBody3D
	_level_two_trap_gate_north = get_node_or_null("TrapGateNorth") as StaticBody3D
	_level_two_trap_laser = get_node_or_null("TrapLaser") as Node3D
	if _level_two_trap_laser != null:
		_level_two_trap_beam = _level_two_trap_laser.get_node_or_null("Beam") as MeshInstance3D
		_level_two_trap_light = _level_two_trap_laser.get_node_or_null("Light") as OmniLight3D
		if _level_two_trap_beam != null:
			var beam_material := StandardMaterial3D.new()
			beam_material.albedo_color = Color(1.0, 0.08, 0.06, 0.8)
			beam_material.emission_enabled = true
			beam_material.emission = Color(1.0, 0.08, 0.06, 1.0)
			beam_material.emission_energy_multiplier = 8.5
			beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_level_two_trap_beam.material_override = beam_material
			_level_two_trap_beam.scale = Vector3(0.18, 1.0, 0.18)
		if _level_two_trap_light != null:
			_level_two_trap_light.light_energy = 0.0
		_level_two_trap_laser.visible = false
	_level_two_trap_triggered = false
	_level_two_trap_running = false
	_configure_level_two_trap_gate(_level_two_trap_gate_south, false)
	_configure_level_two_trap_gate(_level_two_trap_gate_north, false)

func _reset_level_two_view_state() -> void:
	if _wake_overlay != null:
		if _wake_overlay.material is ShaderMaterial:
			_wake_overlay.material.set_shader_parameter("blur_strength", 0.0)
			_wake_overlay.material.set_shader_parameter("haze_strength", 0.0)
			_wake_overlay.material.set_shader_parameter("desaturate_strength", 0.0)
		_wake_overlay.visible = false
	if _blink_overlay != null:
		_blink_overlay.modulate.a = 0.0
		_blink_overlay.visible = false
	if _fade_overlay != null:
		_fade_overlay.modulate.a = 0.0
		_fade_overlay.visible = false
	if _white_overlay != null:
		_white_overlay.modulate.a = 0.0
		_white_overlay.visible = false
	if _glitch_overlay != null:
		_glitch_overlay.modulate.a = 0.0
		_glitch_overlay.visible = false
	if player_camera != null:
		player_camera.make_current()
	if player_hud != null:
		player_hud.visible = true

func _run_level_two_keycard_sequence() -> void:
	if _level_two_trap_triggered or _level_two_trap_running:
		return
	_level_two_trap_triggered = true
	_level_two_trap_running = true
	_objective_state = ""
	_hint_marker.visible = false
	_hint_label.visible = false
	_set_level_two_target_glow(_level_two_key, false)
	_set_level_two_target_glow(_level_two_door, false)
	await _play_level_two_corridor_trap()
	_level_two_trap_running = false
	_objective_state = "level2_door"
	_show_objective("Open door 1")

func _play_level_two_corridor_trap() -> void:
	await _set_level_two_trap_gate_state(true)
	while _is_player_inside_level_two_trap():
		await get_tree().create_timer(2.0).timeout
		while GameState.rewind_mode_active:
			await get_tree().process_frame
		if not _is_player_inside_level_two_trap():
			break
		await _fire_level_two_trap_laser()
	await _set_level_two_trap_gate_state(false)

func _set_level_two_trap_gate_state(closed: bool) -> void:
	var tween := create_tween().set_parallel(true)
	_tween_level_two_trap_gate(tween, _level_two_trap_gate_south, closed)
	_tween_level_two_trap_gate(tween, _level_two_trap_gate_north, closed)
	await tween.finished

func _tween_level_two_trap_gate(tween: Tween, gate: StaticBody3D, closed: bool) -> void:
	if gate == null:
		return
	var collision := gate.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if closed:
		_configure_level_two_trap_gate(gate, true)
		gate.scale = Vector3(1.0, 0.04, 1.0)
		tween.tween_property(gate, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if collision != null:
			collision.disabled = false
	else:
		_configure_level_two_trap_gate(gate, true)
		tween.tween_property(gate, "scale", Vector3(1.0, 0.04, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.finished.connect(_configure_level_two_trap_gate.bind(gate, false), CONNECT_ONE_SHOT)

func _configure_level_two_trap_gate(gate: StaticBody3D, enabled: bool) -> void:
	if gate == null:
		return
	gate.visible = enabled
	var collision := gate.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = not enabled
	if not enabled:
		gate.scale = Vector3.ONE

func _fire_level_two_trap_laser() -> void:
	if GameState.rewind_mode_active:
		return
	if _level_two_trap_laser == null or _level_two_trap_beam == null:
		return
	_level_two_trap_laser.visible = true
	_level_two_trap_beam.scale = Vector3(0.1, 1.05, 0.1)
	if _level_two_trap_light != null:
		_level_two_trap_light.light_energy = 0.0
	var flash_in := create_tween().set_parallel(true)
	flash_in.tween_property(_level_two_trap_beam, "scale", Vector3(9.2, 1.15, 9.8), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _level_two_trap_light != null:
		flash_in.tween_property(_level_two_trap_light, "light_energy", 12.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await flash_in.finished
	_apply_level_two_trap_damage()
	await get_tree().create_timer(0.32).timeout
	var flash_out := create_tween().set_parallel(true)
	flash_out.tween_property(_level_two_trap_beam, "scale", Vector3(0.06, 1.02, 0.06), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _level_two_trap_light != null:
		flash_out.tween_property(_level_two_trap_light, "light_energy", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await flash_out.finished
	_level_two_trap_laser.visible = false

func _apply_level_two_trap_damage() -> void:
	if GameState.rewind_mode_active:
		return
	if not _is_player_inside_level_two_trap():
		return
	if player != null and player.has_method("take_damage"):
		player.call("take_damage", 50.0)

func _is_player_inside_level_two_trap() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var player_position := player.global_position
	var within_x := player_position.x >= -10.55 and player_position.x <= -3.35
	var within_z := player_position.z >= -14.15 and player_position.z <= -9.85
	var within_y := player_position.y >= -0.5 and player_position.y <= 3.6
	return within_x and within_z and within_y

func _set_level_two_target_glow(target, enabled: bool) -> void:
	if target == null:
		return
	if not is_instance_valid(target):
		return
	if target.has_method("set_persistent_highlight"):
		target.call("set_persistent_highlight", enabled)
	if target.has_method("set_highlight_enabled"):
		target.call("set_highlight_enabled", enabled)
	if enabled and target.has_method("set_highlight_strength"):
		target.call("set_highlight_strength", 0.65 + (sin(_pulse_time * 1.45) * 0.5 + 0.5) * 0.75)

func _play_camera_shot(start_transform: Transform3D, end_transform: Transform3D, duration: float) -> void:
	if _intro_camera == null:
		return
	var tween := create_tween()
	tween.tween_method(_blend_intro_camera.bind(start_transform, end_transform), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _return_intro_camera_to_player(duration: float) -> void:
	if _intro_camera == null or player_camera == null:
		return
	var current_transform := _intro_camera.global_transform
	var player_transform := player_camera.global_transform
	await _play_camera_shot(current_transform, player_transform, duration)
	player_camera.make_current()

func _activate_intro_camera() -> void:
	if _intro_camera == null:
		return
	_intro_camera.position = _intro_camera_position
	_intro_camera.look_at(_intro_camera_target, Vector3.FORWARD)
	_intro_camera.make_current()

func _restore_player_camera() -> void:
	if player != null:
		player.set_cinematic_pose(_player_spawn_position, _player_spawn_rotation_y, 0.0)
	if _intro_camera != null and player_camera != null:
		var start_transform := _intro_camera.global_transform
		var end_transform := player_camera.global_transform
		var blend_tween := create_tween()
		blend_tween.tween_method(_blend_intro_camera.bind(start_transform, end_transform), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await blend_tween.finished
	if player_camera != null:
		player_camera.make_current()

func _blend_intro_camera(weight: float, start_transform: Transform3D, end_transform: Transform3D) -> void:
	if _intro_camera == null:
		return
	_intro_camera.global_transform = start_transform.interpolate_with(end_transform, weight)

func _tween_wake_overlay(target_alpha: float, duration: float) -> void:
	if _wake_overlay == null or not (_wake_overlay.material is ShaderMaterial):
		return
	var overlay_tween := create_tween()
	overlay_tween.tween_method(_set_wake_blur_strength, _get_wake_blur_strength(), target_alpha * 3.2, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	overlay_tween.parallel().tween_method(_set_wake_haze_strength, _get_wake_haze_strength(), target_alpha * 0.32, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	overlay_tween.parallel().tween_method(_set_wake_desaturate_strength, _get_wake_desaturate_strength(), target_alpha * 0.24, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await overlay_tween.finished

func _blink_once(close_duration: float, open_duration: float) -> void:
	if _blink_overlay == null:
		return
	var blink_close := create_tween()
	blink_close.tween_property(_blink_overlay, "modulate:a", 1.0, close_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await blink_close.finished
	await _open_eyes(open_duration)

func _open_eyes(duration: float) -> void:
	if _blink_overlay == null:
		return
	var blink_open := create_tween()
	blink_open.tween_property(_blink_overlay, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await blink_open.finished

func _update_intro_camera_motion() -> void:
	if _intro_camera == null or not _intro_camera.current:
		return
	var bob := Vector3(
		sin(_intro_motion_time * 1.35) * 0.035,
		sin(_intro_motion_time * 0.82 + 0.6) * 0.022,
		cos(_intro_motion_time * 1.08) * 0.026
	)
	var target_offset := Vector3(
		sin(_intro_motion_time * 0.74) * 0.18,
		cos(_intro_motion_time * 0.56) * 0.24,
		sin(_intro_motion_time * 0.93) * 0.14
	)
	_intro_camera.global_position = _intro_camera_position + bob
	_intro_camera.look_at(_intro_camera_target + target_offset, Vector3.FORWARD)

func _set_wake_blur_strength(value: float) -> void:
	if _wake_overlay.material is ShaderMaterial:
		_wake_overlay.material.set_shader_parameter("blur_strength", value)

func _set_wake_haze_strength(value: float) -> void:
	if _wake_overlay.material is ShaderMaterial:
		_wake_overlay.material.set_shader_parameter("haze_strength", value)

func _set_wake_desaturate_strength(value: float) -> void:
	if _wake_overlay.material is ShaderMaterial:
		_wake_overlay.material.set_shader_parameter("desaturate_strength", value)

func _get_wake_blur_strength() -> float:
	if _wake_overlay.material is ShaderMaterial:
		var value = _wake_overlay.material.get_shader_parameter("blur_strength")
		if value is float or value is int:
			return value
	return 0.0

func _get_wake_haze_strength() -> float:
	if _wake_overlay.material is ShaderMaterial:
		var value = _wake_overlay.material.get_shader_parameter("haze_strength")
		if value is float or value is int:
			return value
	return 0.0

func _get_wake_desaturate_strength() -> float:
	if _wake_overlay.material is ShaderMaterial:
		var value = _wake_overlay.material.get_shader_parameter("desaturate_strength")
		if value is float or value is int:
			return value
	return 0.0

func _show_subtitle(text: String, duration: float) -> void:
	if _subtitle_label == null:
		return
	_subtitle_label.text = text
	_subtitle_label.modulate = Color(1, 1, 1, 0)
	_subtitle_label.visible = true
	var tween := create_tween()
	tween.tween_property(_subtitle_label, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(duration).timeout
	var fade := create_tween()
	fade.tween_property(_subtitle_label, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade.finished

func _show_objective(text: String) -> void:
	_objective_label.text = text
	_objective_panel.modulate = Color(1, 1, 1, 0)
	_objective_panel.position.y = 12.0
	_objective_panel.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_objective_panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_objective_panel, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _objective_text(key: String, fallback: String) -> String:
	if objective_config != null and objective_config.has_method("get_objective_text"):
		return objective_config.get_objective_text(key, fallback)
	return fallback

func _update_objective_text() -> void:
	if _objective_state == "scoop":
		_show_objective(_objective_text("scoop", "Pick up the scoop"))
	elif _objective_state == "dig":
		_show_objective("%s %d/%d" % [_objective_text("dig", "Bury the old stuff"), _completed_dig_spots, _total_dig_spots])
	elif _objective_state == "rest":
		_show_objective(_objective_text("rest", "Rest on the sofa"))
	elif _objective_panel != null:
		_objective_panel.visible = false

func _update_hint_marker(world_target: Vector3, label_text: String, distance_target: Vector3) -> void:
	if player_camera == null or player == null:
		_hint_marker.visible = false
		_hint_label.visible = false
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_target := _get_screen_hint_target(world_target, viewport_size)
	var pulse := 1.0 + sin(_pulse_time) * 0.14
	var marker_size := Vector2.ONE * 16.0 * pulse
	_hint_marker.size = marker_size
	_hint_marker.position = screen_target - marker_size * 0.5
	_hint_marker.visible = true
	var distance := player.global_position.distance_to(distance_target)
	_hint_label.text = "%s %.1fm" % [label_text, distance]
	_hint_label.position = screen_target + Vector2(16.0, -14.0)
	_hint_label.visible = true

func _update_shovel_highlight() -> void:
	if shovel != null and is_instance_valid(shovel) and shovel.has_method("set_highlight_enabled") and shovel.has_method("set_highlight_strength"):
		shovel.set_highlight_enabled(true)
		shovel.set_highlight_strength(0.55 + (sin(_pulse_time * 1.35) * 0.5 + 0.5) * 0.7)

func _update_sofa_highlight() -> void:
	if _sofa_aura == null or _sofa_light == null:
		return
	var strength := 0.45 + (sin(_pulse_time * 1.18) * 0.5 + 0.5) * 0.75
	_sofa_aura.visible = true
	_sofa_light.visible = true
	if _sofa_aura.material_override is ShaderMaterial:
		_sofa_aura.material_override.set_shader_parameter("highlight_strength", strength)
	_sofa_light.light_energy = 1.2 + strength * 1.5

func _clear_target_highlights() -> void:
	if shovel != null and is_instance_valid(shovel) and shovel.has_method("set_highlight_enabled"):
		shovel.set_highlight_enabled(false)
	if _sofa_aura != null:
		_sofa_aura.visible = false
		if _sofa_aura.material_override is ShaderMaterial:
			_sofa_aura.material_override.set_shader_parameter("highlight_strength", 0.0)
	if _sofa_light != null:
		_sofa_light.visible = false
		_sofa_light.light_energy = 0.0

func _get_screen_hint_target(world_target: Vector3, viewport_size: Vector2) -> Vector2:
	if not player_camera.is_position_behind(world_target):
		var projected := player_camera.unproject_position(world_target)
		projected.x = clampf(projected.x, 28.0, viewport_size.x - 28.0)
		projected.y = clampf(projected.y, 28.0, viewport_size.y - 28.0)
		return projected
	var local_target := player_camera.global_transform.basis.inverse() * (world_target - player_camera.global_position)
	var edge_direction := Vector2(local_target.x, -local_target.y)
	if edge_direction.length_squared() < 0.001:
		edge_direction = Vector2.RIGHT
	edge_direction = edge_direction.normalized()
	var center := viewport_size * 0.5
	var radius := minf(viewport_size.x, viewport_size.y) * 0.34
	return center + edge_direction * radius

func _begin_dig_phase() -> void:
	_objective_state = "dig"
	_hint_marker.visible = false
	_hint_label.visible = false
	_clear_target_highlights()
	_update_objective_text()
	call_deferred("_play_dig_phase_subtitle")

func _play_dig_phase_subtitle() -> void:
	await _show_subtitle("Good. Now I can bury the old junk before anyone notices.", 2.8)

func _on_dig_spot_completed(_spot: Node3D) -> void:
	if _objective_state != "dig":
		return
	_completed_dig_spots += 1
	_update_objective_text()
	if _completed_dig_spots >= _total_dig_spots:
		call_deferred("_finish_world_phase")

func _finish_world_phase() -> void:
	if _objective_state != "dig":
		return
	_show_objective("%s %d/%d" % [_objective_text("dig", "Bury the old stuff"), _total_dig_spots, _total_dig_spots])
	await _show_subtitle("That should take care of it. I need to sit down for a minute.", 2.6)
	_objective_state = "rest"
	_transition_started = false
	if _sofa_interactable != null:
		_sofa_interactable.set_interactable_enabled(true)
	_update_objective_text()
	await _show_subtitle("The sofa should be enough for a quick rest.", 2.5)

func _play_rest_cinematic() -> void:
	if _sofa_interactable != null:
		_sofa_interactable.set_interactable_enabled(false)
	_objective_state = ""
	if player != null:
		player.visible = false
	_objective_panel.visible = false
	_hint_marker.visible = false
	_hint_label.visible = false
	_clear_target_highlights()
	_set_intro_lock(true)
	_intro_running = false
	_set_cinematic_bars(true, 0.45)
	await _drop_to_sofa_pov()
	await _show_subtitle("I just need to close my eyes for a moment.", 2.1)
	await _fade_black(1.0, 1.6)
	await get_tree().create_timer(2).timeout
	await _play_loading_dots()
	_set_world_night_state()
	_activate_window_camera()
	await _fade_black(0.0, 1.4)
	await get_tree().create_timer(3.2).timeout
	await _play_meteor_impact()
	await _fade_white(1.0, 0.18)
	_set_subtitle_palette(true)
	await _show_subtitle("What was that?", 1.8)
	await _show_subtitle("What is happening?", 2.0)
	_set_subtitle_palette(false)
	GameState.set_meta(LEVEL_ONE_WHITE_META, true)
	get_tree().change_scene_to_file(LEVEL_ONE_SCENE_PATH)

func _activate_window_camera() -> void:
	if _intro_camera == null:
		return
	var target_position := Vector3(2.0, 0.3, 9.0)
	var camera_position := Vector3(-1.0, -0.35, 5.25)
	if _window_target != null:
		target_position = _window_target.global_position
	elif house != null:
		target_position = house.to_global(Vector3(2.0, 0.3, 9.0))
	if house != null:
		camera_position = house.to_global(Vector3(-1.05, -0.35, 5.35))
	_intro_camera.global_position = camera_position
	_intro_camera.look_at(target_position + Vector3(0.0, 0.15, 0.0), Vector3.UP)
	_intro_camera.make_current()

func _play_loading_dots() -> void:
	_loading_label.visible = true
	_loading_label.text = "."
	await get_tree().create_timer(0.9).timeout
	_loading_label.text = ".."
	await get_tree().create_timer(0.9).timeout
	_loading_label.text = "..."
	await get_tree().create_timer(1.2).timeout
	_loading_label.visible = false

func _play_meteor_impact() -> void:
	if _meteor == null or _meteor_light == null:
		return
	var window_position := Vector3(2.0, 0.3, 9.0)
	if _window_target != null:
		window_position = _window_target.global_position
	elif house != null:
		window_position = house.to_global(Vector3(2.0, 0.3, 9.0))
	var start_position := window_position + Vector3(2.6, 1.6, 18.0)
	var impact_position := window_position + Vector3(0.35, 0.3, 1.1)
	_meteor.visible = true
	_meteor_light.visible = true
	_meteor.global_position = start_position
	_meteor.scale = Vector3.ONE * 0.7
	_meteor.look_at(impact_position, Vector3.UP)
	_meteor_light.global_position = start_position
	_meteor_light.light_energy = 4.5
	var travel := create_tween()
	travel.tween_property(_meteor, "global_position", impact_position, 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	travel.parallel().tween_property(_meteor_light, "global_position", impact_position, 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	travel.parallel().tween_property(_meteor, "scale", Vector3.ONE * 1.18, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	travel.parallel().tween_property(_meteor_light, "light_energy", 7.8, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await travel.finished
	var burst := create_tween()
	burst.tween_property(_meteor, "scale", Vector3.ONE * 4.8, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	burst.parallel().tween_property(_meteor_light, "light_energy", 20.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await burst.finished
	_meteor.visible = false
	_meteor_light.visible = false
	_meteor_light.light_energy = 0.0

func _drop_to_sofa_pov() -> void:
	if _intro_camera == null or _sofa_target == null:
		return
	var start_transform := player_camera.global_transform if player_camera != null else _intro_camera.global_transform
	var sofa_eye := _sofa_target.to_global(Vector3(0.0, -0.82, -0.18))
	var sofa_focus := _sofa_target.to_global(Vector3(0.0, 1.25, 0.45))
	var end_transform := Transform3D(Basis(), sofa_eye).looking_at(sofa_focus, Vector3.UP)
	_intro_camera.global_transform = start_transform
	_intro_camera.make_current()
	var fall := create_tween()
	fall.tween_method(_blend_rest_camera.bind(start_transform, end_transform), 0.0, 1.0, 1.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await fall.finished

func _blend_rest_camera(weight: float, start_transform: Transform3D, end_transform: Transform3D) -> void:
	if _intro_camera == null:
		return
	_intro_camera.global_transform = start_transform.interpolate_with(end_transform, weight)

func _fade_black(target_alpha: float, duration: float) -> void:
	if _fade_overlay == null:
		return
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _fade_white(target_alpha: float, duration: float) -> void:
	if _white_overlay == null:
		return
	var tween := create_tween()
	tween.tween_property(_white_overlay, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _set_arrival_glitch_strength(value: float) -> void:
	if _glitch_overlay != null and _glitch_overlay.material is ShaderMaterial:
		_glitch_overlay.material.set_shader_parameter("glitch_strength", value)

func _set_world_night_state() -> void:
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null and world_environment.environment.sky != null:
		var sky_material := world_environment.environment.sky.sky_material
		if sky_material is ProceduralSkyMaterial:
			sky_material.sky_top_color = Color(0.02, 0.02, 0.08, 1.0)
			sky_material.sky_horizon_color = Color(0.06, 0.08, 0.16, 1.0)
			sky_material.ground_bottom_color = Color(0.01, 0.01, 0.03, 1.0)
			sky_material.ground_horizon_color = Color(0.03, 0.04, 0.08, 1.0)
		world_environment.environment.ambient_light_color = Color(0.12, 0.13, 0.2, 1.0)
		world_environment.environment.ambient_light_energy = 0.18
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(0.34, 0.42, 0.62, 1.0)
		sun.light_energy = 0.18

func _set_cinematic_bars(visible: bool, duration: float) -> void:
	if _top_bar == null or _bottom_bar == null:
		return
	var target_height := 88.0 if visible else 0.0
	_top_bar.visible = true
	_bottom_bar.visible = true
	var tween := create_tween()
	tween.tween_property(_top_bar, "offset_bottom", target_height, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_bottom_bar, "offset_top", -target_height, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if not visible:
		_top_bar.visible = false
		_bottom_bar.visible = false

func _set_subtitle_palette(dark_text: bool) -> void:
	if _subtitle_label == null:
		return
	if dark_text:
		_subtitle_label.add_theme_color_override("font_color", Color(0.07, 0.07, 0.07, 1.0))
		_subtitle_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
		_subtitle_label.add_theme_constant_override("outline_size", 8)
	else:
		_subtitle_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96, 1.0))
		_subtitle_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
		_subtitle_label.add_theme_constant_override("outline_size", 12)

func _on_sofa_rest_requested() -> void:
	if _objective_state != "rest" or _transition_started:
		return
	_transition_started = true
	call_deferred("_play_rest_cinematic")

func _is_world_intro_scene() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path == WORLD_SCENE_PATH

func _is_level_one_scene() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path == LEVEL_ONE_SCENE_PATH

func _is_level_two_scene() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path == LEVEL_TWO_SCENE_PATH

func restart_current_level() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	GameState.set_meta(LEVEL_ONE_WHITE_META, false)
	GameState.rewind_mode_active = false
	GameState.time_direction = GameState.TIME_FORWARD
	var screen_fx := _screen_fx()
	if screen_fx != null and screen_fx.has_method("reboot_to_scene"):
		await screen_fx.reboot_to_scene(current_scene.scene_file_path, true)
	else:
		get_tree().change_scene_to_file(current_scene.scene_file_path)
