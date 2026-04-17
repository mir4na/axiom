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
const SCOOP_OBJECTIVE := "OBJECTIVE: Pick up the scoop"
const DIG_OBJECTIVE := "OBJECTIVE: Bury the old stuff"
const REST_OBJECTIVE := "OBJECTIVE: Rest on the sofa"
const WORLD_SCENE_PATH := "res://scenes/world/world.tscn"
const LEVEL_ONE_SCENE_PATH := "res://scenes/levels/level_01.tscn"
const LEVEL_ONE_WHITE_META := "level_one_white_intro"
const GUEST_KEY_OBJECTIVE := "OBJECTIVE: Take the key from the kitchen"
const GUEST_UNLOCK_OBJECTIVE := "OBJECTIVE: Open the guest room door"
const GUEST_AXIOM_OBJECTIVE := "OBJECTIVE: Take the Axiom"

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var player_camera: Camera3D = get_node_or_null("Player/root/Skeleton3D/BoneAttachment3D/Head/Camera3D") as Camera3D
@onready var player_hud: CanvasLayer = get_node_or_null("Player/PlayerHUD") as CanvasLayer
@onready var shovel: Node3D = get_node_or_null("Shovel") as Node3D
@onready var house: Node3D = get_node_or_null("House") as Node3D
@onready var _front_door: Node3D = get_node_or_null("House/FrontDoor") as Node3D
@onready var _guest_door: Node3D = get_node_or_null("House/GuestDoor") as Node3D
@onready var _guest_button_out: Node3D = get_node_or_null("House/GuestDoorBtnOut") as Node3D
@onready var _guest_button_in: Node3D = get_node_or_null("House/GuestDoorBtnIn") as Node3D
@onready var _guest_door_gap: CSGBox3D = get_node_or_null("House/Partitions/GuestDoorGap") as CSGBox3D
@onready var _glitch_fragments_root: Node3D = get_node_or_null("GlitchFragments") as Node3D

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
var _objective_panel: PanelContainer
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
var _guest_door_revealed: bool = false
var _front_door_cinematic_played: bool = false
var _guest_key_spawned: bool = false
var _guest_key_collected: bool = false
var _guest_room_opened: bool = false
var _axiom_sequence_played: bool = false
var _level_one_sequence_running: bool = false
var _key_item_instance: Node3D
var _axiom_item_instance: Node3D
var _split_front_nodes: Array[Node3D] = []
var _split_back_nodes: Array[Node3D] = []
var _split_original_positions: Dictionary = {}
var _glitch_fragment_original_positions: Dictionary = {}

func _ready() -> void:
	GameState.world_scaled.connect(_on_world_scaled)
	GameState.world_rotated.connect(_on_world_rotated)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.axiom_equipped_changed.connect(_on_axiom_equipped_changed)
	_apply_player_spawn()
	if _is_level_one_scene():
		_create_intro_ui()
		_create_intro_camera()
		_prepare_level_one_phase()
		_configure_level_one_house()
		_connect_level_one_hooks()
		if player_hud != null:
			player_hud.visible = true
		if GameState.has_meta(LEVEL_ONE_WHITE_META) and bool(GameState.get_meta(LEVEL_ONE_WHITE_META)):
			_set_intro_lock(true)
			call_deferred("_play_level_one_arrival")
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
		_process_level_one_objectives()
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
		if not _guest_key_collected and GameState.has_item("key_1"):
			_guest_key_collected = true
			if _objective_state == "guest_key":
				_objective_state = "guest_unlock"
				_update_objective_text()
				call_deferred("_play_guest_key_pickup_subtitle")
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

	_objective_panel = PanelContainer.new()
	_objective_panel.anchor_left = 0.0
	_objective_panel.anchor_top = 0.0
	_objective_panel.anchor_right = 0.0
	_objective_panel.anchor_bottom = 0.0
	_objective_panel.offset_left = 24.0
	_objective_panel.offset_top = 24.0
	_objective_panel.offset_right = 420.0
	_objective_panel.offset_bottom = 84.0
	_objective_panel.visible = false
	var objective_style := StyleBoxFlat.new()
	objective_style.bg_color = Color(0.04, 0.06, 0.05, 0.82)
	objective_style.border_width_left = 4
	objective_style.border_color = Color(0.72, 0.94, 0.62, 1.0)
	objective_style.corner_radius_top_left = 8
	objective_style.corner_radius_top_right = 8
	objective_style.corner_radius_bottom_right = 8
	objective_style.corner_radius_bottom_left = 8
	_objective_panel.add_theme_stylebox_override("panel", objective_style)
	_intro_ui.add_child(_objective_panel)

	_objective_label = Label.new()
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_font_size_override("font_size", 22)
	_objective_label.add_theme_color_override("font_color", Color(0.94, 0.97, 0.92, 1.0))
	_objective_panel.add_child(_objective_label)

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

func _prepare_level_one_phase() -> void:
	GameState.full_reset_inventory()
	GameState.recording_enabled = false
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
	_split_front_nodes.clear()
	_split_back_nodes.clear()
	_split_original_positions.clear()
	_glitch_fragment_original_positions.clear()
	if _wake_overlay != null:
		_wake_overlay.visible = false
	if _blink_overlay != null:
		_blink_overlay.modulate.a = 0.0
	if _fade_overlay != null:
		_fade_overlay.modulate.a = 0.0
	if _white_overlay != null:
		_white_overlay.modulate.a = 0.0
	if _glitch_overlay != null:
		_glitch_overlay.visible = false
		_glitch_overlay.modulate.a = 0.0
	if _subtitle_label != null:
		_subtitle_label.visible = false
	if _objective_panel != null:
		_objective_panel.visible = false
	if _top_bar != null:
		_top_bar.visible = false
		_top_bar.offset_bottom = 0.0
	if _bottom_bar != null:
		_bottom_bar.visible = false
		_bottom_bar.offset_top = 0.0

func _connect_level_one_hooks() -> void:
	var front_door_callable := Callable(self, "_on_level_one_front_door_opened")
	var guest_door_callable := Callable(self, "_on_level_one_guest_door_opened")
	var guest_locked_callable := Callable(self, "_on_guest_door_locked_interaction")
	if _front_door != null and _front_door.has_signal("opened") and not _front_door.is_connected("opened", front_door_callable):
		_front_door.connect("opened", front_door_callable)
	if _guest_door != null and _guest_door.has_signal("opened") and not _guest_door.is_connected("opened", guest_door_callable):
		_guest_door.connect("opened", guest_door_callable)
	for button in [_guest_button_out, _guest_button_in]:
		if button != null and button.has_signal("locked_interaction") and not button.is_connected("locked_interaction", guest_locked_callable):
			button.connect("locked_interaction", guest_locked_callable)

func _process_level_one_objectives() -> void:
	if _objective_state == "guest_key" and is_instance_valid(_key_item_instance):
		_update_hint_marker(_key_item_instance.global_position + Vector3(0.0, 0.55, 0.0), "KEY", _key_item_instance.global_position)
	elif _objective_state == "guest_unlock" and is_instance_valid(_guest_button_out):
		_update_hint_marker(_guest_button_out.global_position + Vector3(0.0, 0.35, 0.0), "DOOR", _guest_button_out.global_position)
	elif _objective_state == "guest_axiom" and is_instance_valid(_axiom_item_instance):
		_update_hint_marker(_axiom_item_instance.global_position + Vector3(0.0, 0.55, 0.0), "AXIOM", _axiom_item_instance.global_position)
	else:
		_hint_marker.visible = false
		_hint_label.visible = false

func _spawn_level_one_key() -> void:
	if _guest_key_spawned or house == null:
		return
	var scene := load("res://scenes/objects/key_item.tscn") as PackedScene
	if scene == null:
		return
	_key_item_instance = scene.instantiate() as Node3D
	if _key_item_instance == null:
		return
	add_child(_key_item_instance)
	_key_item_instance.global_position = house.to_global(Vector3(-3.4, -1.0, -5.5))
	_guest_key_spawned = true

func _spawn_level_one_axiom() -> void:
	if is_instance_valid(_axiom_item_instance) or house == null:
		return
	var scene := load("res://scenes/objects/axiom_item.tscn") as PackedScene
	if scene == null:
		return
	_axiom_item_instance = scene.instantiate() as Node3D
	if _axiom_item_instance == null:
		return
	add_child(_axiom_item_instance)
	_axiom_item_instance.global_position = house.to_global(Vector3(8.4, -1.0, 4.6))

func _set_guest_entry_visible(visible: bool) -> void:
	if _guest_door_gap != null:
		_guest_door_gap.operation = CSGShape3D.OPERATION_SUBTRACTION if visible else CSGShape3D.OPERATION_UNION
		_guest_door_gap.material = null if visible else _make_house_wall_material()
	if _guest_door != null:
		_guest_door.visible = visible
		_guest_door.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED
		var guest_door_collision := _guest_door.get_node_or_null("Collision") as CollisionShape3D
		if guest_door_collision != null:
			guest_door_collision.disabled = not visible
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

func _cache_split_nodes() -> void:
	if house == null or _split_front_nodes.size() > 0 or _split_back_nodes.size() > 0:
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
		var node := house.get_node_or_null(path) as Node3D
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
		var node := house.get_node_or_null(path) as Node3D
		if node != null:
			_split_back_nodes.append(node)
			_split_original_positions[node] = node.position
	if _glitch_fragments_root != null:
		for child in _glitch_fragments_root.get_children():
			if child is Node3D:
				_glitch_fragment_original_positions[child] = child.position

func _configure_level_one_house() -> void:
	if house == null:
		return
	for node_name in ["Glass1", "Glass2"]:
		var glass := house.get_node_or_null(node_name) as CSGBox3D
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
	_cache_split_nodes()
	if _glitch_fragments_root != null:
		_glitch_fragments_root.visible = false

func _apply_player_spawn() -> void:
	if player == null:
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	if current_scene.scene_file_path != LEVEL_ONE_SCENE_PATH:
		return
	var spawner := current_scene.get_node_or_null("PlayerSpawner") as Marker3D
	if spawner == null:
		spawner = current_scene.get_node_or_null("SpawnPlayer") as Marker3D
	if spawner == null:
		spawner = current_scene.get_node_or_null("PlayerSpawn") as Marker3D
	if spawner == null:
		return
	_player_spawn_position = spawner.global_position
	_player_spawn_rotation_y = spawner.global_rotation.y
	player.global_position = _player_spawn_position
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
	_show_objective(SCOOP_OBJECTIVE)
	_objective_state = "scoop"
	await _show_subtitle("I should grab the scoop before I start digging.", 2.5)
	_set_intro_lock(false)

func _play_level_one_arrival() -> void:
	if player_hud != null:
		player_hud.visible = false
	if player != null:
		player.visible = true
	if player_camera != null:
		player_camera.make_current()
	if _white_overlay != null:
		_white_overlay.modulate.a = 1.0
	if _glitch_overlay != null:
		_glitch_overlay.visible = true
		_glitch_overlay.modulate.a = 1.0
		_set_arrival_glitch_strength(0.95)
	if _fade_overlay != null:
		_fade_overlay.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var arrival_tween := create_tween()
	if _white_overlay != null:
		arrival_tween.tween_property(_white_overlay, "modulate:a", 0.0, 2.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrival_tween.parallel().tween_method(_set_arrival_glitch_strength, 0.95, 0.0, 2.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _glitch_overlay != null:
		arrival_tween.parallel().tween_property(_glitch_overlay, "modulate:a", 0.0, 2.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await arrival_tween.finished
	if _glitch_overlay != null:
		_glitch_overlay.visible = false
	_set_intro_lock(false)
	if player_hud != null:
		player_hud.visible = true
	GameState.set_meta(LEVEL_ONE_WHITE_META, false)

func _on_level_one_front_door_opened() -> void:
	if not _is_level_one_scene() or _front_door_cinematic_played or _level_one_sequence_running:
		return
	_front_door_cinematic_played = true
	call_deferred("_play_guest_door_reveal_cinematic")

func _play_guest_door_reveal_cinematic() -> void:
	if not _is_level_one_scene() or _level_one_sequence_running:
		return
	_level_one_sequence_running = true
	_set_intro_lock(true)
	_intro_running = false
	await _set_cinematic_bars(true, 0.35)
	var player_transform := player_camera.global_transform
	var exterior_start := Transform3D(Basis(), house.to_global(Vector3(-2.2, 1.2, 16.0))).looking_at(house.to_global(Vector3(-1.4, -0.8, 9.0)), Vector3.UP)
	var exterior_end := Transform3D(Basis(), house.to_global(Vector3(0.5, 1.7, 13.2))).looking_at(house.to_global(Vector3(1.5, -0.4, 8.7)), Vector3.UP)
	var guest_start := Transform3D(Basis(), house.to_global(Vector3(-0.8, -0.15, 5.1))).looking_at(house.to_global(Vector3(4.0, -0.85, 3.5)), Vector3.UP)
	var guest_end := Transform3D(Basis(), house.to_global(Vector3(0.2, -0.05, 4.7))).looking_at(house.to_global(Vector3(4.0, -0.85, 3.5)), Vector3.UP)
	_intro_camera.global_transform = player_transform
	_intro_camera.make_current()
	await _play_camera_shot(player_transform, exterior_start, 0.85)
	await _play_camera_shot(exterior_start, exterior_end, 2.8)
	await _show_subtitle("Wait... why does the house feel different?", 1.9)
	await _play_guest_door_materialize()
	await _play_camera_shot(exterior_end, guest_start, 1.0)
	await _show_subtitle("That door wasn't there a second ago.", 2.1)
	await _play_camera_shot(guest_start, guest_end, 3.6)
	await _show_subtitle("No. That room should not exist.", 2.2)
	await _return_intro_camera_to_player(0.9)
	await _set_cinematic_bars(false, 0.32)
	_set_intro_lock(false)
	_level_one_sequence_running = false

func _play_guest_door_materialize() -> void:
	if _guest_door_revealed:
		return
	if _glitch_overlay != null:
		_glitch_overlay.visible = true
		_glitch_overlay.modulate.a = 0.0
		_set_arrival_glitch_strength(0.0)
	var flash := create_tween()
	if _white_overlay != null:
		flash.tween_property(_white_overlay, "modulate:a", 0.45, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _glitch_overlay != null:
		flash.parallel().tween_property(_glitch_overlay, "modulate:a", 0.92, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash.parallel().tween_method(_set_arrival_glitch_strength, 0.0, 0.95, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await flash.finished
	_set_guest_entry_visible(true)
	_set_guest_buttons_locked(true)
	_spawn_level_one_axiom()
	_guest_door_revealed = true
	var settle := create_tween()
	if _white_overlay != null:
		settle.tween_property(_white_overlay, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _glitch_overlay != null:
		settle.parallel().tween_property(_glitch_overlay, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		settle.parallel().tween_method(_set_arrival_glitch_strength, 0.95, 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await settle.finished
	if _glitch_overlay != null:
		_glitch_overlay.visible = false

func _on_guest_door_locked_interaction(_button: Node) -> void:
	if not _is_level_one_scene() or _guest_key_spawned:
		return
	_spawn_level_one_key()
	_objective_state = "guest_key"
	_update_objective_text()
	call_deferred("_play_guest_door_locked_sequence")

func _play_guest_door_locked_sequence() -> void:
	await _show_subtitle("Locked? Then why do I feel like I need to go in there?", 2.2)
	await _show_subtitle("There has to be a key somewhere in the kitchen.", 2.0)

func _play_guest_key_pickup_subtitle() -> void:
	await _show_subtitle("A key in my kitchen now too... none of this makes sense.", 2.3)

func _on_level_one_guest_door_opened() -> void:
	if not _is_level_one_scene() or _guest_room_opened:
		return
	_guest_room_opened = true
	_objective_state = "guest_axiom"
	_update_objective_text()
	call_deferred("_play_guest_room_opened_subtitle")

func _play_guest_room_opened_subtitle() -> void:
	await _show_subtitle("That room should not be inside this house.", 2.1)
	await _show_subtitle("Whatever is in there is pulling me closer.", 2.0)

func _on_axiom_equipped_changed() -> void:
	if not _is_level_one_scene() or _axiom_sequence_played:
		return
	_axiom_sequence_played = true
	call_deferred("_play_axiom_equip_sequence")

func _play_axiom_equip_sequence() -> void:
	if _level_one_sequence_running:
		return
	_level_one_sequence_running = true
	_objective_state = ""
	_update_objective_text()
	_hint_marker.visible = false
	_hint_label.visible = false
	_set_intro_lock(true)
	_intro_running = false
	await _set_cinematic_bars(true, 0.35)
	var player_transform := player_camera.global_transform
	var split_start := Transform3D(Basis(), house.to_global(Vector3(16.0, 4.0, 8.0))).looking_at(house.to_global(Vector3(0.0, -0.8, 0.0)), Vector3.UP)
	var split_end := Transform3D(Basis(), house.to_global(Vector3(14.4, 4.7, 0.8))).looking_at(house.to_global(Vector3(0.0, -1.1, 0.0)), Vector3.UP)
	_intro_camera.global_transform = player_transform
	_intro_camera.make_current()
	await _play_camera_shot(player_transform, split_start, 0.9)
	await _show_subtitle("What did I just pick up?", 1.8)
	await _play_camera_shot(split_start, split_end, 1.4)
	await _play_house_split_glitch()
	await _show_subtitle("No... it's splitting the house apart.", 2.0)
	await _show_subtitle("It's recording everything now.", 1.9)
	await _return_intro_camera_to_player(0.95)
	await _set_cinematic_bars(false, 0.32)
	_set_intro_lock(false)
	_level_one_sequence_running = false

func _play_house_split_glitch() -> void:
	_cache_split_nodes()
	if _glitch_fragments_root != null:
		_glitch_fragments_root.visible = true
	if _glitch_overlay != null:
		_glitch_overlay.visible = true
		_glitch_overlay.modulate.a = 0.0
	var glitch_in := create_tween()
	if _glitch_overlay != null:
		glitch_in.tween_property(_glitch_overlay, "modulate:a", 0.78, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		glitch_in.parallel().tween_method(_set_arrival_glitch_strength, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	glitch_in.parallel().tween_method(_set_house_split_weight, 0.0, 1.0, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await glitch_in.finished
	await get_tree().create_timer(0.5).timeout
	var glitch_out := create_tween()
	if _glitch_overlay != null:
		glitch_out.tween_property(_glitch_overlay, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glitch_out.parallel().tween_method(_set_arrival_glitch_strength, 1.0, 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glitch_out.parallel().tween_method(_set_house_split_weight, 1.0, 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await glitch_out.finished
	if _glitch_overlay != null:
		_glitch_overlay.visible = false
	if _glitch_fragments_root != null:
		_glitch_fragments_root.visible = false

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
	_objective_panel.visible = true
	var tween := create_tween()
	tween.tween_property(_objective_panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _update_objective_text() -> void:
	if _objective_state == "scoop":
		_show_objective(SCOOP_OBJECTIVE)
	elif _objective_state == "dig":
		_show_objective("%s %d/%d" % [DIG_OBJECTIVE, _completed_dig_spots, _total_dig_spots])
	elif _objective_state == "rest":
		_show_objective(REST_OBJECTIVE)
	elif _objective_state == "guest_key":
		_show_objective(GUEST_KEY_OBJECTIVE)
	elif _objective_state == "guest_unlock":
		_show_objective(GUEST_UNLOCK_OBJECTIVE)
	elif _objective_state == "guest_axiom":
		_show_objective(GUEST_AXIOM_OBJECTIVE)
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
	_show_objective("%s %d/%d" % [DIG_OBJECTIVE, _total_dig_spots, _total_dig_spots])
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
