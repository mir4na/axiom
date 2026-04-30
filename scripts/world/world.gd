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
const LEVEL_THREE_SCENE_PATH := "res://scenes/levels/level_03.tscn"
const LEVEL_FOUR_SCENE_PATH := "res://scenes/levels/level_04.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const LEVEL_ONE_WHITE_META := "level_one_white_intro"
const LEVEL_FOUR_RETURN_WAKE_META := "level_four_return_wake"
const ENDING_BOARD_LINE_1 := "Congratulations."
const ENDING_BOARD_LINE_2 := "Thank you for playing this game."
const ENDING_BOARD_LINE_3 := "Hope your day is wonderful."
const ENDING_BOARD_FOOTER_TEXT := "Game Development Individual Assignment\nMuhammad Afwan Hafizh\n2306208855"
const ENDING_BOARD_CAMERA_SHOT_DURATION := 0.9
const ENDING_BOARD_TYPE_INTERVAL := 0.04
const ENDING_BOARD_LINE_PAUSE := 0.26
const ENDING_BOARD_FOOTER_PAUSE := 0.36
const ENDING_BOARD_HOLD_DURATION := 5.0
const ENDING_BOARD_FADE_DURATION := 2.6
const LEVEL_ONE_FLOW := preload("res://scripts/world/level_one_flow.gd")
const LEVEL_FOUR_FLOW := preload("res://scripts/world/level_four_flow.gd")
const OBJECTIVE_PANEL_SCENE := preload("res://scenes/ui/objective_panel.tscn")
const ENDING_BOARD_TEXT_OVERLAY_SCENE := preload("res://scenes/ui/ending_board_text_overlay.tscn")
const SPATIAL_GLITCH_SHADER := preload("res://shaders/spatial_glitch.gdshader")
const ENDING_WORLD_SKY_PATH := "res://assets/AllSkyFree_Godot-10e858fef0a9c5fa071de8bc191c3b4bef00edda/AllSkyFree/AllSkyFree_Skyboxes/AllSky_Space_AnotherPlanet Equirect.png"

@export_group("Audio Placeholder BGM")
@export var bgm_world_intro: AudioStream
@export var bgm_level_one: AudioStream
@export var bgm_level_two: AudioStream
@export var bgm_level_three: AudioStream
@export var bgm_level_four: AudioStream
@export var bgm_ending_credits: AudioStream

@export_group("Audio Placeholder SFX Global")
@export var sfx_fade_black: AudioStream
@export var sfx_fade_white: AudioStream
@export var sfx_glitch_overlay: AudioStream
@export var sfx_subtitle_popup: AudioStream
@export var sfx_objective_show: AudioStream
@export var sfx_objective_hide: AudioStream

@export_group("Audio Placeholder SFX Cinematic")
@export var sfx_sky_crack_start: AudioStream
@export var sfx_sky_crack_grow: AudioStream
@export var sfx_sky_crack_break: AudioStream
@export var sfx_board_activate: AudioStream
@export var sfx_credits_start: AudioStream
@export var sfx_ending_return_wake: AudioStream

@export_group("Ending Sky")
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.hdr", "*.exr") var ending_world_sky_path: String = ENDING_WORLD_SKY_PATH

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
var _sky_crack_overlay: ColorRect
var _subtitle_label: Label
var _objective_panel: Control
var _objective_tag: Label
var _objective_label: Label
var _hint_marker: ColorRect
var _hint_label: Label
var _loading_label: Label
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _objective_tween: Tween
var _objective_transition_serial: int = 0
var _ending_board_text_overlay: Control
var _sofa_aura: MeshInstance3D
var _sofa_light: OmniLight3D
var _meteor: MeshInstance3D
var _meteor_light: OmniLight3D
var _level_one_flow
var _level_four_flow
var _level_two_key: Node3D
var _level_two_door: Node3D
var _level_two_gun: Node3D
var _level_two_room3_button: Node3D
var _level_two_room3_door: Node3D
var _level_two_combat_trigger: Area3D
var _level_two_enemy_nodes: Array[Node3D] = []
var _level_two_active_enemies: Array[Node3D] = []
var _level_two_enemy_started: bool = false
var _level_two_enemy_reward_spawned: bool = false
var _level_two_enemy_total: int = 3
var _level_two_enemy_defeated: int = 0
var _level_two_room3_key: Node3D
var _level_two_corridor_obstacle: Node3D
var _level_two_trap_gate_south: StaticBody3D
var _level_two_trap_gate_north: StaticBody3D
var _level_two_trap_laser: Node3D
var _level_two_trap_beam: MeshInstance3D
var _level_two_trap_light: OmniLight3D
var _level_two_trap_triggered: bool = false
var _level_two_trap_running: bool = false
var _level_two_rose: Node3D
var _level_two_exit_door: Node3D
var _level_two_end_cap_near: Node3D
var _level_two_portal: Node3D
var _level_two_rose_focus: Node3D
var _level_two_tunnel_blast_focus: Node3D
var _level_two_portal_look_target: Node3D
var _level_two_room3_sequence_running: bool = false
var _level_two_room3_sequence_played: bool = false
var _ending_mode_active: bool = false
var _ending_cinematic_running: bool = false
var _ending_credits_running: bool = false
var _ending_board
var _ending_board_camera: Camera3D
var _bgm_player: AudioStreamPlayer
var _sfx_player_2d: AudioStreamPlayer2D
var _sky_crack_stage: int = 0
var _arrival_glitch_audio_active: bool = false

func _screen_fx() -> CanvasLayer:
	return get_node_or_null("/root/ScreenFX") as CanvasLayer

func _ready() -> void:
	GameState.world_scaled.connect(_on_world_scaled)
	GameState.world_rotated.connect(_on_world_rotated)
	GameState.inventory_changed.connect(_on_inventory_changed)
	var screen_fx := _screen_fx()
	if screen_fx != null:
		screen_fx.set_gameplay_filter_enabled(true)
	_setup_audio_players()
	_apply_player_spawn()
	if _is_level_one_scene():
		_play_bgm_stream(bgm_level_one)
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
		_play_bgm_stream(bgm_level_two)
		_create_intro_ui()
		_create_intro_camera()
		_cache_level_two_targets()
		_reset_intro_view_state()
		_intro_running = false
		_objective_state = "level2_key"
		call_deferred("_play_level_two_intro")
		return
	if _is_level_three_scene():
		_play_bgm_stream(bgm_level_three)
		_create_intro_ui()
		_create_intro_camera()
		_reset_intro_view_state()
		if player_hud != null:
			player_hud.visible = true
		return
	if _is_level_four_scene():
		_play_bgm_stream(bgm_level_four)
		_create_intro_ui()
		_create_intro_camera()
		_reset_intro_view_state()
		_level_four_flow = LEVEL_FOUR_FLOW.new(self)
		_level_four_flow.initialize()
		if player_hud != null:
			player_hud.visible = true
		return
	if not _is_world_intro_scene():
		return
	_play_bgm_stream(bgm_world_intro)
	_configure_world_house()
	_cache_world_targets()
	_collect_dig_spots()
	_total_dig_spots = _dig_spots.size()
	GameState.reset_world_state()
	_cache_ending_board_node()
	_set_ending_board_active(false, false)
	_create_intro_ui()
	_create_intro_camera()
	_create_sofa_interactable()
	_create_sofa_highlight()
	_create_meteor_nodes()
	if _consume_level_four_return_meta():
		_prepare_level_four_return_phase()
		call_deferred("_play_level_four_return_wake_sequence")
		return
	_prepare_world_phase()
	_set_intro_lock(true)
	call_deferred("_play_intro_sequence")

func _setup_audio_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Master"
	_bgm_player.autoplay = false
	add_child(_bgm_player)
	_sfx_player_2d = AudioStreamPlayer2D.new()
	_sfx_player_2d.name = "SFXPlayer2D"
	_sfx_player_2d.bus = "Master"
	_sfx_player_2d.autoplay = false
	add_child(_sfx_player_2d)

func _play_bgm_stream(stream: AudioStream) -> void:
	if stream == null:
		return
	if _bgm_player == null or not is_instance_valid(_bgm_player):
		return
	if _bgm_player.stream == stream and _bgm_player.playing:
		return
	_bgm_player.stream = stream
	_bgm_player.play()

func _stop_bgm_stream() -> void:
	if _bgm_player == null or not is_instance_valid(_bgm_player):
		return
	_bgm_player.stop()

func _play_sfx_stream(stream: AudioStream) -> void:
	if stream == null:
		return
	if _sfx_player_2d == null or not is_instance_valid(_sfx_player_2d):
		return
	_sfx_player_2d.stream = stream
	_sfx_player_2d.play()

func _process(delta: float) -> void:
	var current: float = scale.x
	var next: float = current + ((_target_scale - current) * SCALE_LERP_SPEED * delta)
	scale = Vector3(next, next, next)

	rotation.y = lerpf(rotation.y, _yaw, SCALE_LERP_SPEED * delta)
	rotation.x = lerpf(rotation.x, _pitch, SCALE_LERP_SPEED * delta)

	_pulse_time += delta * 3.6
	if _intro_running and _is_world_intro_scene():
		_intro_motion_time += delta
		_update_intro_camera_motion()

	if _is_level_one_scene():
		if _level_one_flow != null:
			_level_one_flow.process_objectives()
		if player_hud != null and player_hud.has_method("set_threat_warning_intensity"):
			player_hud.call("set_threat_warning_intensity", 0.0)
		return
	if _is_level_two_scene():
		if not _level_two_enemy_started and GameState.has_item("Gun") and _is_player_inside_level_two_combat_trigger():
			_start_level_two_enemy_encounter()
		if _objective_state == "level2_key" and is_instance_valid(_level_two_key):
			_set_level_two_target_glow(_level_two_key, true)
			_set_level_two_target_glow(_level_two_door, false)
			_set_level_two_target_glow(_level_two_room3_key, false)
			_set_level_two_target_glow(_level_two_corridor_obstacle, false)
			_update_hint_marker(_level_two_key.global_position + Vector3(0.0, 0.55, 0.0), "KEY", _level_two_key.global_position)
		elif _objective_state == "level2_door" and is_instance_valid(_level_two_door):
			_set_level_two_target_glow(_level_two_key, false)
			_set_level_two_target_glow(_level_two_door, true)
			_set_level_two_target_glow(_level_two_gun, false)
			_set_level_two_target_glow(_level_two_room3_key, false)
			_set_level_two_target_glow(_level_two_corridor_obstacle, false)
			_update_hint_marker(_level_two_door.global_position + Vector3(0.0, 1.0, 0.0), "DOOR", _level_two_door.global_position)
		elif _objective_state == "level2_gun" and is_instance_valid(_level_two_gun):
			_set_level_two_target_glow(_level_two_key, false)
			_set_level_two_target_glow(_level_two_door, false)
			_set_level_two_target_glow(_level_two_gun, true)
			_set_level_two_target_glow(_level_two_room3_key, false)
			_set_level_two_target_glow(_level_two_corridor_obstacle, false)
			_update_hint_marker(_level_two_gun.global_position + Vector3(0.0, 0.55, 0.0), "GUN", _level_two_gun.global_position)
		elif _objective_state == "level2_enemy":
			_set_level_two_target_glow(_level_two_key, false)
			_set_level_two_target_glow(_level_two_door, false)
			_set_level_two_target_glow(_level_two_gun, false)
			_set_level_two_target_glow(_level_two_room3_key, false)
			_set_level_two_target_glow(_level_two_corridor_obstacle, false)
			_hint_marker.visible = false
			_hint_label.visible = false
		elif _objective_state == "level2_room3_key" and is_instance_valid(_level_two_room3_key):
			_set_level_two_target_glow(_level_two_key, false)
			_set_level_two_target_glow(_level_two_door, false)
			_set_level_two_target_glow(_level_two_gun, false)
			_set_level_two_target_glow(_level_two_room3_key, true)
			_set_level_two_target_glow(_level_two_corridor_obstacle, false)
			_update_hint_marker(_level_two_room3_key.global_position + Vector3(0.0, 0.55, 0.0), "KEY", _level_two_room3_key.global_position)
		elif _objective_state == "level2_obstacle" and is_instance_valid(_level_two_corridor_obstacle):
			_set_level_two_target_glow(_level_two_key, false)
			_set_level_two_target_glow(_level_two_door, false)
			_set_level_two_target_glow(_level_two_gun, false)
			_set_level_two_target_glow(_level_two_room3_key, false)
			_set_level_two_target_glow(_level_two_corridor_obstacle, true)
			_update_hint_marker(_level_two_corridor_obstacle.global_position + Vector3(0.0, 1.25, 0.0), "TARGET", _level_two_corridor_obstacle.global_position)
		elif _objective_state == "level2_room3_door" and is_instance_valid(_level_two_room3_button):
			_set_level_two_target_glow(_level_two_key, false)
			_set_level_two_target_glow(_level_two_door, false)
			_set_level_two_target_glow(_level_two_gun, false)
			_set_level_two_target_glow(_level_two_room3_key, false)
			_set_level_two_target_glow(_level_two_corridor_obstacle, false)
			_update_hint_marker(_level_two_room3_button.global_position + Vector3(0.0, 0.35, 0.0), "DOOR", _level_two_room3_button.global_position)
		elif _objective_state == "level2_portal" and is_instance_valid(_level_two_portal):
			_set_level_two_target_glow(_level_two_key, false)
			_set_level_two_target_glow(_level_two_door, false)
			_set_level_two_target_glow(_level_two_gun, false)
			_set_level_two_target_glow(_level_two_room3_key, false)
			_set_level_two_target_glow(_level_two_corridor_obstacle, false)
			_update_hint_marker(_level_two_portal.global_position + Vector3(0.0, 1.6, 0.0), "PORTAL", _level_two_portal.global_position)
		else:
			_set_level_two_target_glow(_level_two_key, false)
			_set_level_two_target_glow(_level_two_door, false)
			_set_level_two_target_glow(_level_two_gun, false)
			_set_level_two_target_glow(_level_two_room3_key, false)
			_set_level_two_target_glow(_level_two_corridor_obstacle, false)
			_hint_marker.visible = false
			_hint_label.visible = false
		_update_level_two_obstacle_warning()
		return
	if _is_level_four_scene():
		if _level_four_flow != null:
			_level_four_flow.process_frame()
		if player_hud != null and player_hud.has_method("set_threat_warning_intensity"):
			var threat_intensity: float = 0.0
			if _level_four_flow != null and _level_four_flow.has_method("get_threat_warning_intensity"):
				var value: Variant = _level_four_flow.call("get_threat_warning_intensity")
				if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
					threat_intensity = float(value)
			player_hud.call("set_threat_warning_intensity", threat_intensity)
		return
	if player_hud != null and player_hud.has_method("set_threat_warning_intensity"):
		player_hud.call("set_threat_warning_intensity", 0.0)
	if not _is_world_intro_scene():
		return
	if _ending_mode_active:
		_update_ending_board_hint()
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
		elif _objective_state == "level2_gun" and GameState.has_item("Gun"):
			_objective_state = ""
			_hide_objective()
		elif _objective_state == "level2_room3_key" and GameState.has_item("key_2"):
			_start_level_two_obstacle_phase()
		return
	if not _is_world_intro_scene():
		return
	if _ending_mode_active:
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

	_sky_crack_overlay = ColorRect.new()
	_sky_crack_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_crack_overlay.color = Color(1, 1, 1, 1)
	var crack_material := ShaderMaterial.new()
	crack_material.shader = load("res://shaders/sky_crack_overlay.gdshader")
	_sky_crack_overlay.material = crack_material
	_sky_crack_overlay.modulate.a = 0.0
	_sky_crack_overlay.visible = false
	_intro_ui.add_child(_sky_crack_overlay)

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
	_create_ending_board_text_overlay()

func _create_ending_board_text_overlay() -> void:
	if _intro_ui == null or ENDING_BOARD_TEXT_OVERLAY_SCENE == null:
		return
	var overlay_instance: Control = ENDING_BOARD_TEXT_OVERLAY_SCENE.instantiate() as Control
	if overlay_instance == null:
		return
	overlay_instance.visible = false
	_intro_ui.add_child(overlay_instance)
	_ending_board_text_overlay = overlay_instance

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
	GameState.force_time_forward()
	GameState.clear_rewind_timeline(0.0)
	_completed_dig_spots = 0
	_objective_state = ""
	_transition_started = false
	_set_ending_board_active(false, false)
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
	var intro_tree: SceneTree = get_tree()
	if intro_tree == null:
		return
	await intro_tree.process_frame
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
	var level_two_tree: SceneTree = get_tree()
	if level_two_tree == null:
		return
	await level_two_tree.process_frame
	if player != null:
		player.set_cinematic_lock(true)
	if player_hud != null:
		player_hud.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await _set_cinematic_bars(true, 0.35)
	await get_tree().create_timer(2.0).timeout
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
	_level_two_gun = get_node_or_null("Gun") as Node3D
	_level_two_room3_button = get_node_or_null("Room3Button") as Node3D
	_level_two_room3_door = get_node_or_null("Room3Door") as Node3D
	_level_two_combat_trigger = get_node_or_null("CombatTrigger") as Area3D
	_level_two_room3_key = get_node_or_null("Room3Keycard") as Node3D
	_level_two_corridor_obstacle = get_node_or_null("CorridorObstacle") as Node3D
	_level_two_rose = get_node_or_null("Rose") as Node3D
	_level_two_exit_door = get_node_or_null("ExitDoor") as Node3D
	_level_two_end_cap_near = get_node_or_null("TunnelShell/EndCapNear") as Node3D
	_level_two_portal = get_node_or_null("Portal") as Node3D
	_level_two_rose_focus = get_node_or_null("CutsceneMarkers/RoseFocus") as Node3D
	_level_two_tunnel_blast_focus = get_node_or_null("CutsceneMarkers/TunnelBlastFocus") as Node3D
	_level_two_portal_look_target = get_node_or_null("CutsceneMarkers/PortalLookTarget") as Node3D
	_level_two_enemy_nodes.clear()
	for node_name in ["Enemy01", "Enemy02", "Enemy03"]:
		var enemy_node: Node3D = get_node_or_null(node_name) as Node3D
		if enemy_node != null:
			_level_two_enemy_nodes.append(enemy_node)
	_level_two_trap_gate_south = get_node_or_null("TrapGateSouth") as StaticBody3D
	_level_two_trap_gate_north = get_node_or_null("TrapGateNorth") as StaticBody3D
	_level_two_trap_laser = get_node_or_null("TrapLaser") as Node3D

	if _level_two_room3_button != null:
		_level_two_room3_button.set("locked", true)
		_level_two_room3_button.set("required_item_id", "key_2_blocked")
		_level_two_room3_button.set("consume_required_item", true)

	if _level_two_combat_trigger != null:
		_level_two_combat_trigger.body_entered.connect(Callable(self, "_on_level_two_combat_trigger_entered"))
	if _level_two_door != null and _level_two_door.has_signal("opened"):
		_level_two_door.connect("opened", Callable(self, "_on_level_two_door_one_opened"))
	if _level_two_room3_door != null and _level_two_room3_door.has_signal("opened"):
		_level_two_room3_door.connect("opened", Callable(self, "_on_level_two_room3_opened"))
	if is_instance_valid(_level_two_room3_key) and _level_two_room3_key.has_method("set_interactable_enabled"):
		_level_two_room3_key.call("set_interactable_enabled", false)
		_level_two_room3_key.visible = false
	if is_instance_valid(_level_two_gun) and _level_two_gun.has_method("set_interactable_enabled"):
		_level_two_gun.call("set_interactable_enabled", false)
		_level_two_gun.visible = false
	for enemy_node in _level_two_enemy_nodes:
		if enemy_node.has_signal("defeated"):
			enemy_node.connect("defeated", Callable(self, "_on_level_two_enemy_defeated"))
		if enemy_node.has_method("reset_enemy_state"):
			enemy_node.call("reset_enemy_state")
		if enemy_node.has_method("set_encounter_enabled"):
			enemy_node.call("set_encounter_enabled", false)
	if _level_two_corridor_obstacle != null:
		var destroyed_callable: Callable = Callable(self, "_on_level_two_corridor_obstacle_destroyed")
		if _level_two_corridor_obstacle.has_signal("destroyed") and not _level_two_corridor_obstacle.is_connected("destroyed", destroyed_callable):
			_level_two_corridor_obstacle.connect("destroyed", destroyed_callable)
		if _level_two_corridor_obstacle.has_method("reset_obstacle_state"):
			_level_two_corridor_obstacle.call("reset_obstacle_state")
		elif _level_two_corridor_obstacle.has_method("set_obstacle_enabled"):
			_level_two_corridor_obstacle.call("set_obstacle_enabled", false)
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
	_level_two_enemy_started = false
	_level_two_enemy_reward_spawned = false
	_level_two_enemy_defeated = 0
	_level_two_room3_sequence_running = false
	_level_two_room3_sequence_played = false
	if is_instance_valid(_level_two_portal):
		_level_two_portal.visible = false
		_level_two_portal.scale = Vector3.ZERO
	_reset_level_two_enemy_nodes()
	_configure_level_two_trap_gate(_level_two_trap_gate_south, false)
	_configure_level_two_trap_gate(_level_two_trap_gate_north, false)

func _reset_intro_view_state() -> void:
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
	if _sky_crack_overlay != null:
		_sky_crack_overlay.modulate.a = 0.0
		_sky_crack_overlay.visible = false
		if _sky_crack_overlay.material is ShaderMaterial:
			_sky_crack_overlay.material.set_shader_parameter("crack_intensity", 0.0)
	_sky_crack_stage = 0
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
			var trap_tree: SceneTree = get_tree()
			if trap_tree == null:
				return
			await trap_tree.process_frame
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

func _on_level_two_combat_trigger_entered(body: Node) -> void:
	if body != player:
		return
	if _level_two_enemy_started:
		return
	if not GameState.has_item("Gun"):
		return
	_start_level_two_enemy_encounter()

func _is_player_inside_level_two_combat_trigger() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if _level_two_combat_trigger == null or not is_instance_valid(_level_two_combat_trigger):
		return false
	var shape_node: CollisionShape3D = _level_two_combat_trigger.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return false
	var box_shape: BoxShape3D = shape_node.shape as BoxShape3D
	if box_shape == null:
		return false
	var local_position: Vector3 = _level_two_combat_trigger.to_local(player.global_position)
	var half_size: Vector3 = box_shape.size * 0.5
	return absf(local_position.x) <= half_size.x and absf(local_position.y) <= half_size.y and absf(local_position.z) <= half_size.z

func _start_level_two_enemy_encounter() -> void:
	_level_two_enemy_started = true
	_level_two_enemy_defeated = 0
	if _level_two_combat_trigger != null and is_instance_valid(_level_two_combat_trigger):
		_level_two_combat_trigger.call_deferred("queue_free")
	_level_two_combat_trigger = null
	_objective_state = "level2_enemy"
	_show_objective("Beat enemy 0/%d" % _level_two_enemy_total)
	_enable_level_two_enemy_nodes()

func _enable_level_two_enemy_nodes() -> void:
	_level_two_active_enemies.clear()
	for enemy_node in _level_two_enemy_nodes:
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if enemy_node.has_method("reset_enemy_state"):
			enemy_node.call("reset_enemy_state")
		if enemy_node.has_method("set_encounter_enabled"):
			enemy_node.call("set_encounter_enabled", true)
		enemy_node.set("max_health", 50.0)
		_level_two_active_enemies.append(enemy_node)

func _reset_level_two_enemy_nodes() -> void:
	_level_two_active_enemies.clear()
	for enemy_node in _level_two_enemy_nodes:
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if enemy_node.has_method("reset_enemy_state"):
			enemy_node.call("reset_enemy_state")
		if enemy_node.has_method("set_encounter_enabled"):
			enemy_node.call("set_encounter_enabled", false)

func _on_level_two_enemy_defeated(enemy: Node3D, defeat_position: Vector3) -> void:
	var remaining_enemies: Array[Node3D] = []
	for entry in _level_two_active_enemies:
		if is_instance_valid(entry) and entry != enemy:
			remaining_enemies.append(entry)
	_level_two_active_enemies = remaining_enemies
	_level_two_enemy_defeated += 1
	if _level_two_enemy_defeated < _level_two_enemy_total:
		_show_objective("Beat enemy %d/%d" % [_level_two_enemy_defeated, _level_two_enemy_total])
		return
	_show_objective("Beat enemy %d/%d" % [_level_two_enemy_total, _level_two_enemy_total])
	if not _level_two_enemy_reward_spawned:
		_level_two_enemy_reward_spawned = true
		call_deferred("_spawn_level_two_room3_keycard", defeat_position)

func _spawn_level_two_room3_keycard(spawn_position: Vector3) -> void:
	var keycard: Node3D = _level_two_room3_key
	if keycard == null or not is_instance_valid(keycard):
		return
	var floor_position: Vector3 = spawn_position
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var floor_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(spawn_position + Vector3(0.0, 2.6, 0.0), spawn_position + Vector3(0.0, -3.4, 0.0))
	floor_query.collide_with_areas = false
	floor_query.collide_with_bodies = true
	var floor_hit: Dictionary = space_state.intersect_ray(floor_query)
	if not floor_hit.is_empty():
		floor_position = floor_hit.get("position", spawn_position)
	floor_position.y += 0.05
	keycard.global_position = floor_position + Vector3(0.0, 1.3, 0.0)
	if keycard.has_method("set_interactable_enabled"):
		keycard.call("set_interactable_enabled", false)
	keycard.visible = true
	keycard.scale = Vector3.ZERO
	var settle_rotation: Vector3 = keycard.rotation_degrees + Vector3(0.0, 540.0, 0.0)
	var reveal: Tween = create_tween().set_parallel(true)
	reveal.tween_property(keycard, "global_position", floor_position, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(keycard, "rotation_degrees", settle_rotation, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(keycard, "scale", Vector3.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await reveal.finished
	if is_instance_valid(keycard) and keycard.has_method("set_interactable_enabled"):
		keycard.call("set_interactable_enabled", true)
	_objective_state = "level2_room3_key"
	_show_objective("Take the keycard")

func _start_level_two_obstacle_phase() -> void:
	_objective_state = "level2_obstacle"
	_show_objective("Destroy the electric obstacle")
	if _level_two_room3_button != null and is_instance_valid(_level_two_room3_button):
		_level_two_room3_button.set("locked", true)
		_level_two_room3_button.set("required_item_id", "key_2_blocked")
		_level_two_room3_button.set("consume_required_item", true)
	if _level_two_corridor_obstacle != null and is_instance_valid(_level_two_corridor_obstacle):
		if _level_two_corridor_obstacle.has_method("set_obstacle_enabled"):
			_level_two_corridor_obstacle.call("set_obstacle_enabled", true)

func _on_level_two_corridor_obstacle_destroyed(_obstacle: Node3D) -> void:
	if _objective_state != "level2_obstacle":
		return
	if _level_two_room3_button != null and is_instance_valid(_level_two_room3_button):
		_level_two_room3_button.set("locked", true)
		_level_two_room3_button.set("required_item_id", "key_2")
		_level_two_room3_button.set("consume_required_item", true)
	_objective_state = "level2_room3_door"
	_show_objective("Open room 3")

func _on_level_two_room3_opened() -> void:
	if _level_two_room3_sequence_running or _level_two_room3_sequence_played:
		return
	if _objective_state == "level2_room3_door":
		_objective_state = ""
		_hide_objective()
	await _play_level_two_room3_sequence()

func _on_level_two_door_one_opened() -> void:
	if _objective_state == "level2_door":
		_objective_state = "level2_gun"
		if is_instance_valid(_level_two_gun) and _level_two_gun.has_method("set_interactable_enabled"):
			_level_two_gun.call("set_interactable_enabled", true)
		elif is_instance_valid(_level_two_gun):
			_level_two_gun.visible = true
		_show_objective("Take the gun")

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

func _update_level_two_obstacle_warning() -> void:
	if player_hud == null or not player_hud.has_method("set_threat_warning_intensity"):
		return
	if _objective_state != "level2_obstacle":
		player_hud.call("set_threat_warning_intensity", 0.0)
		return
	if player == null or not is_instance_valid(player):
		player_hud.call("set_threat_warning_intensity", 0.0)
		return
	if _level_two_corridor_obstacle == null or not is_instance_valid(_level_two_corridor_obstacle):
		player_hud.call("set_threat_warning_intensity", 0.0)
		return
	if not _level_two_corridor_obstacle.has_method("get_nearest_projectile_distance_to"):
		player_hud.call("set_threat_warning_intensity", 0.0)
		return
	var nearest_distance_variant: Variant = _level_two_corridor_obstacle.call("get_nearest_projectile_distance_to", player.global_position)
	var nearest_distance: float = 999999.0
	if typeof(nearest_distance_variant) == TYPE_FLOAT or typeof(nearest_distance_variant) == TYPE_INT:
		nearest_distance = float(nearest_distance_variant)
	if nearest_distance >= 900000.0:
		player_hud.call("set_threat_warning_intensity", 0.0)
		return
	var warning_distance: float = 22.0
	var intensity: float = clampf(1.0 - (nearest_distance / warning_distance), 0.0, 1.0)
	player_hud.call("set_threat_warning_intensity", intensity)

func _play_level_two_room3_sequence() -> void:
	_level_two_room3_sequence_running = true
	_level_two_room3_sequence_played = true
	if GameState.rewind_mode_active:
		GameState.cancel_rewind_mode()
	if player != null:
		player.set_cinematic_lock(true)
	if _level_two_rose != null and _level_two_rose.has_method("play_idle"):
		_level_two_rose.call("play_idle")
	_set_level_two_cinematic_ui(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await _set_cinematic_bars(true, 0.28)
	if _intro_camera == null:
		_create_intro_camera()
	if _intro_camera == null:
		await _finish_level_two_room3_sequence()
		return
	var rose_target: Vector3 = _level_two_rose_focus.global_position if _level_two_rose_focus != null else ((_level_two_rose.global_position if _level_two_rose != null else Vector3(0.0, 1.5, 0.0)) + Vector3(0.0, 1.35, 0.0))
	var player_view_transform: Transform3D = player_camera.global_transform if player_camera != null else _make_look_transform(rose_target + Vector3(0.0, 1.6, -5.0), rose_target)
	var rose_align_transform: Transform3D = _make_look_transform(player_view_transform.origin, rose_target)
	var rose_end_origin: Vector3 = player_view_transform.origin + rose_align_transform.basis.z * -0.12
	var rose_start_transform: Transform3D = rose_align_transform
	var rose_end_transform: Transform3D = _make_look_transform(rose_end_origin, rose_target)
	_intro_camera.global_transform = player_view_transform
	_intro_camera.make_current()
	await _play_camera_shot(player_view_transform, rose_start_transform, 1.05)
	var flashlight_fx: SpotLight3D = _create_level_two_flashlight_fx(rose_target)
	await _play_camera_shot(rose_start_transform, rose_end_transform, 2.9)
	await _show_subtitle("Axia: Hey... so you finally opened it.", 2.4, "axia")
	await _show_subtitle("Axia: This place gets weird every time you start second-guessing yourself.", 2.8, "axia")
	await _show_subtitle("Axia: I can help you get through this part... and get you closer to what you're after.", 3.1, "axia")
	await _show_subtitle("Axia: Just watch, okay? I'll open the way.", 2.5, "axia")
	if is_instance_valid(flashlight_fx):
		flashlight_fx.queue_free()
	await _play_level_two_rose_glitch_disappear()
	var tunnel_anchor: Vector3 = _level_two_tunnel_blast_focus.global_position if _level_two_tunnel_blast_focus != null else ((_level_two_end_cap_near.global_position if _level_two_end_cap_near != null else (_level_two_exit_door.global_position if _level_two_exit_door != null else rose_target + Vector3(0.0, 0.0, 7.5))) + Vector3(0.0, 0.75, 0.0))
	var tunnel_start_transform: Transform3D = rose_end_transform
	var tunnel_end_transform: Transform3D = _make_look_transform(rose_end_origin, tunnel_anchor)
	_intro_camera.global_transform = tunnel_start_transform
	_intro_camera.make_current()
	await _play_camera_shot(tunnel_start_transform, tunnel_end_transform, 1.7)
	await _play_level_two_tunnel_breach_sequence(tunnel_anchor)
	await _show_subtitle("Axia: There. Go on... the portal will take you through.", 2.7, "axia")
	if _level_two_portal != null:
		var portal_target: Vector3 = _level_two_portal_look_target.global_position if _level_two_portal_look_target != null else tunnel_anchor
		if _level_two_portal.has_signal("player_entered") and not _level_two_portal.is_connected("player_entered", Callable(self, "_on_level_two_portal_entered")):
			_level_two_portal.connect("player_entered", Callable(self, "_on_level_two_portal_entered"))
		if _level_two_portal.has_method("play_open_sequence"):
			_level_two_portal.call("play_open_sequence")
		_intro_camera.global_transform = _make_look_transform(rose_end_origin, portal_target)
		await get_tree().create_timer(2.0).timeout
	await _complete_level_two_room3_cutscene()

func _complete_level_two_room3_cutscene() -> void:
	await _set_cinematic_bars(false, 0.2)
	if player_camera != null:
		player_camera.make_current()
	if player != null:
		player.set_cinematic_lock(false)
	if player_hud != null:
		player_hud.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_objective_state = "level2_portal"
	_show_objective("Enter the portal")
	_level_two_room3_sequence_running = false

func _set_level_two_cinematic_ui(visible: bool) -> void:
	if player_hud != null:
		player_hud.visible = visible
	if _objective_panel != null and not visible:
		_objective_panel.visible = false
	if _hint_marker != null and not visible:
		_hint_marker.visible = false
	if _hint_label != null and not visible:
		_hint_label.visible = false
	if _subtitle_label != null:
		_subtitle_label.visible = true

func _on_level_two_portal_entered(body: Node3D) -> void:
	if _objective_state != "level2_portal":
		return
	if body != player:
		return
	_objective_state = ""
	_hide_objective()
	call_deferred("_finish_level_two_room3_sequence")

func _finish_level_two_room3_sequence() -> void:
	if player != null:
		player.set_cinematic_lock(true)
	if player_hud != null:
		player_hud.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if is_instance_valid(_level_two_portal) and _level_two_portal.has_method("play_close_sequence"):
		await _level_two_portal.call("play_close_sequence")
	if _fade_overlay != null:
		_fade_overlay.visible = true
		_fade_overlay.modulate.a = 0.0
		var fade: Tween = create_tween()
		fade.tween_property(_fade_overlay, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await fade.finished
	GameState.current_level_index = 2
	var screen_fx := _screen_fx()
	if screen_fx != null and screen_fx.has_method("reboot_to_scene"):
		await screen_fx.reboot_to_scene(LEVEL_THREE_SCENE_PATH, true)
	else:
		get_tree().change_scene_to_file(LEVEL_THREE_SCENE_PATH)

func _make_look_transform(origin: Vector3, target: Vector3) -> Transform3D:
	var pivot: Node3D = Node3D.new()
	add_child(pivot)
	pivot.global_position = origin
	var direction: Vector3 = target - origin
	if direction.length_squared() <= 0.000001:
		direction = Vector3.FORWARD
	var look_target: Vector3 = origin + direction.normalized()
	var up_axis: Vector3 = Vector3.UP
	if abs(direction.normalized().dot(up_axis)) > 0.98:
		up_axis = Vector3.RIGHT
		if abs(direction.normalized().dot(up_axis)) > 0.98:
			up_axis = Vector3.FORWARD
	pivot.look_at(look_target, up_axis)
	var result: Transform3D = pivot.global_transform
	pivot.queue_free()
	return result

func _create_level_two_flashlight_fx(target: Vector3) -> SpotLight3D:
	if _intro_camera == null:
		return null
	var light: SpotLight3D = SpotLight3D.new()
	light.light_color = Color(1.0, 0.96, 0.84, 1.0)
	light.light_energy = 4.2
	light.spot_range = 28.0
	light.spot_angle = 18.0
	light.spot_attenuation = 0.45
	light.shadow_enabled = true
	_intro_camera.add_child(light)
	light.position = Vector3.ZERO
	light.look_at(target, Vector3.UP)
	return light

func _play_level_two_rose_glitch_disappear() -> void:
	if _level_two_rose == null or not is_instance_valid(_level_two_rose):
		return
	var materials: Array[ShaderMaterial] = []
	_collect_level_two_glitch_materials(_level_two_rose, materials)
	if _glitch_overlay != null:
		_glitch_overlay.visible = true
		_glitch_overlay.modulate.a = 0.0
		_set_arrival_glitch_strength(0.0)
	var flash_in: Tween = create_tween().set_parallel(true)
	flash_in.tween_method(_set_level_two_glitch_material_intensity.bind(materials), 0.0, 1.9, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash_in.parallel().tween_property(_level_two_rose, "scale", Vector3.ONE * 1.05, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _glitch_overlay != null:
		flash_in.parallel().tween_property(_glitch_overlay, "modulate:a", 0.72, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash_in.parallel().tween_method(_set_arrival_glitch_strength, 0.0, 0.9, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await flash_in.finished
	var flash_out: Tween = create_tween().set_parallel(true)
	flash_out.tween_method(_set_level_two_glitch_material_intensity.bind(materials), 1.9, 3.4, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flash_out.parallel().tween_property(_level_two_rose, "scale", Vector3.ONE * 0.05, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if _glitch_overlay != null:
		flash_out.parallel().tween_property(_glitch_overlay, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		flash_out.parallel().tween_method(_set_arrival_glitch_strength, 0.9, 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await flash_out.finished
	_level_two_rose.visible = false
	if _glitch_overlay != null:
		_glitch_overlay.visible = false
	_level_two_rose.scale = Vector3.ONE

func _collect_level_two_glitch_materials(node: Node, materials: Array[ShaderMaterial]) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SPATIAL_GLITCH_SHADER
		material.set_shader_parameter("base_color", Vector3(0.18, 1.0, 0.98))
		material.set_shader_parameter("emission_energy", 5.4)
		material.set_shader_parameter("rim_strength", 3.8)
		material.set_shader_parameter("pulse_strength", 1.6)
		material.set_shader_parameter("glitch_speed", 7.5)
		material.set_shader_parameter("glitch_intensity", 0.0)
		mesh_instance.material_override = material
		materials.append(material)
	for child in node.get_children():
		_collect_level_two_glitch_materials(child, materials)

func _set_level_two_glitch_material_intensity(materials: Array[ShaderMaterial], value: float) -> void:
	for material in materials:
		if material != null:
			material.set_shader_parameter("glitch_intensity", value)

func _play_level_two_tunnel_breach_sequence(breach_position: Vector3) -> void:
	var breach_root: Node3D = Node3D.new()
	add_child(breach_root)
	breach_root.global_position = breach_position
	var seal: MeshInstance3D = MeshInstance3D.new()
	var seal_mesh: BoxMesh = BoxMesh.new()
	seal_mesh.size = Vector3(6.2, 5.4, 0.8)
	seal.mesh = seal_mesh
	var seal_material: ShaderMaterial = ShaderMaterial.new()
	seal_material.shader = SPATIAL_GLITCH_SHADER
	seal_material.set_shader_parameter("base_color", Vector3(0.16, 0.94, 1.0))
	seal_material.set_shader_parameter("emission_energy", 4.6)
	seal_material.set_shader_parameter("rim_strength", 3.4)
	seal_material.set_shader_parameter("pulse_strength", 1.4)
	seal_material.set_shader_parameter("glitch_speed", 5.8)
	seal_material.set_shader_parameter("glitch_intensity", 0.45)
	seal.material_override = seal_material
	breach_root.add_child(seal)
	var blast_light: OmniLight3D = OmniLight3D.new()
	blast_light.light_color = Color(1.0, 0.72, 0.48, 1.0)
	blast_light.light_energy = 0.0
	blast_light.omni_range = 18.0
	breach_root.add_child(blast_light)
	var shards: Array[MeshInstance3D] = []
	for index in range(10):
		var shard: MeshInstance3D = MeshInstance3D.new()
		var shard_mesh: BoxMesh = BoxMesh.new()
		shard_mesh.size = Vector3(randf_range(0.3, 0.85), randf_range(0.3, 1.2), randf_range(0.12, 0.36))
		shard.mesh = shard_mesh
		var shard_material: ShaderMaterial = ShaderMaterial.new()
		shard_material.shader = SPATIAL_GLITCH_SHADER
		shard_material.set_shader_parameter("base_color", Vector3(0.3, 1.0, 0.95))
		shard_material.set_shader_parameter("emission_energy", 6.8)
		shard_material.set_shader_parameter("rim_strength", 4.2)
		shard_material.set_shader_parameter("pulse_strength", 1.85)
		shard_material.set_shader_parameter("glitch_speed", 8.2)
		shard_material.set_shader_parameter("glitch_intensity", 1.2)
		shard.material_override = shard_material
		shard.position = Vector3(randf_range(-2.2, 2.2), randf_range(-1.9, 1.9), randf_range(-0.2, 0.2))
		breach_root.add_child(shard)
		shards.append(shard)
	if _white_overlay != null:
		_white_overlay.visible = true
		_white_overlay.modulate.a = 0.0
	if _glitch_overlay != null:
		_glitch_overlay.visible = true
		_glitch_overlay.modulate.a = 0.0
		_set_arrival_glitch_strength(0.0)
	var flash_in: Tween = create_tween().set_parallel(true)
	if _white_overlay != null:
		flash_in.tween_property(_white_overlay, "modulate:a", 0.85, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _glitch_overlay != null:
		flash_in.parallel().tween_property(_glitch_overlay, "modulate:a", 0.88, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flash_in.parallel().tween_method(_set_arrival_glitch_strength, 0.0, 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash_in.parallel().tween_property(blast_light, "light_energy", 10.5, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await flash_in.finished
	var burst: Tween = create_tween().set_parallel(true)
	burst.tween_property(seal, "scale", Vector3(0.08, 0.08, 0.08), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for shard in shards:
		var target_position: Vector3 = shard.position + Vector3(randf_range(-3.8, 3.8), randf_range(-2.4, 2.4), randf_range(2.4, 4.6))
		var target_rotation: Vector3 = Vector3(randf_range(280.0, 720.0), randf_range(280.0, 720.0), randf_range(280.0, 720.0))
		burst.parallel().tween_property(shard, "position", target_position, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		burst.parallel().tween_property(shard, "rotation_degrees", target_rotation, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		burst.parallel().tween_property(shard, "scale", Vector3.ZERO, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _white_overlay != null:
		burst.parallel().tween_property(_white_overlay, "modulate:a", 0.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _glitch_overlay != null:
		burst.parallel().tween_property(_glitch_overlay, "modulate:a", 0.0, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		burst.parallel().tween_method(_set_arrival_glitch_strength, 1.0, 0.0, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	burst.parallel().tween_property(blast_light, "light_energy", 0.0, 0.56).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await burst.finished
	if _white_overlay != null:
		_white_overlay.visible = false
	if _glitch_overlay != null:
		_glitch_overlay.visible = false
	if _level_two_end_cap_near != null and is_instance_valid(_level_two_end_cap_near):
		_level_two_end_cap_near.visible = false
	if _level_two_exit_door != null and is_instance_valid(_level_two_exit_door):
		_level_two_exit_door.visible = false
	breach_root.queue_free()


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

func _show_subtitle(text: String, duration: float, speaker: String = "") -> void:
	if _subtitle_label == null:
		return
	_play_sfx_stream(sfx_subtitle_popup)
	_set_subtitle_speaker_palette(speaker)
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

func _set_subtitle_speaker_palette(speaker: String) -> void:
	if _subtitle_label == null:
		return
	if speaker.to_lower() == "axia":
		_subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.94, 1.0, 1.0))
		_subtitle_label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.12, 0.96))
		_subtitle_label.add_theme_constant_override("outline_size", 12)
		return
	_set_subtitle_palette(false)

func _show_objective(text: String) -> void:
	if _objective_panel == null or _objective_label == null:
		return
	_play_sfx_stream(sfx_objective_show)
	_objective_transition_serial += 1
	var transition_serial: int = _objective_transition_serial
	if _objective_tween != null:
		_objective_tween.kill()
	var has_visible_objective: bool = _objective_panel.visible and _objective_panel.modulate.a > 0.01
	if has_visible_objective:
		_objective_tween = create_tween().set_parallel(true)
		_objective_tween.tween_property(_objective_panel, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_objective_tween.tween_property(_objective_panel, "position:y", -10.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await _objective_tween.finished
		if transition_serial != _objective_transition_serial:
			return
	_apply_objective_text(text)
	_objective_panel.modulate = Color(1, 1, 1, 0)
	_objective_panel.visible = true
	_objective_tween = create_tween().set_parallel(true)
	_objective_tween.tween_property(_objective_panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_objective_tween.tween_property(_objective_panel, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _hide_objective(animated: bool = true) -> void:
	if _objective_panel == null:
		return
	_play_sfx_stream(sfx_objective_hide)
	_objective_transition_serial += 1
	if _objective_tween != null:
		_objective_tween.kill()
	if not animated:
		_objective_panel.visible = false
		return
	_objective_tween = create_tween().set_parallel(true)
	_objective_tween.tween_property(_objective_panel, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_objective_tween.tween_property(_objective_panel, "position:y", -12.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _objective_tween.finished
	if _objective_panel != null:
		_objective_panel.visible = false

func _apply_objective_text(text: String) -> void:
	if _objective_label == null or _objective_panel == null:
		return
	_objective_label.text = text
	_objective_panel.position.y = 12.0

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
		_hide_objective(false)

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
	if target_alpha > 0.001:
		_play_sfx_stream(sfx_fade_black)
	if target_alpha > 0.001:
		_fade_overlay.visible = true
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if target_alpha <= 0.001:
		_fade_overlay.visible = false

func _fade_white(target_alpha: float, duration: float) -> void:
	if _white_overlay == null:
		return
	if target_alpha > 0.001:
		_play_sfx_stream(sfx_fade_white)
	var tween := create_tween()
	tween.tween_property(_white_overlay, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _set_arrival_glitch_strength(value: float) -> void:
	if value > 0.001 and not _arrival_glitch_audio_active:
		_play_sfx_stream(sfx_glitch_overlay)
		_arrival_glitch_audio_active = true
	elif value <= 0.001:
		_arrival_glitch_audio_active = false
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

func _apply_ending_world_sky() -> void:
	if ending_world_sky_path.is_empty():
		return
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		return
	var ending_texture: Texture2D = null
	var image: Image = Image.load_from_file(ending_world_sky_path)
	if image != null and not image.is_empty():
		ending_texture = ImageTexture.create_from_image(image)
	else:
		var loaded_texture: Variant = load(ending_world_sky_path)
		if loaded_texture is Texture2D:
			ending_texture = loaded_texture as Texture2D
	if ending_texture == null:
		return
	world_environment.environment = world_environment.environment.duplicate(true)
	var panorama_material := PanoramaSkyMaterial.new()
	panorama_material.panorama = ending_texture
	var sky := Sky.new()
	sky.sky_material = panorama_material
	world_environment.environment.background_mode = Environment.BG_SKY
	world_environment.environment.sky = sky
	world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	world_environment.environment.ambient_light_energy = 0.6
	world_environment.environment.ambient_light_color = Color(0.62, 0.68, 0.78, 1.0)
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(0.66, 0.72, 0.86, 1.0)
		sun.light_energy = 0.28

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
	if _ending_mode_active:
		return
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

func _is_level_three_scene() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path == LEVEL_THREE_SCENE_PATH

func _is_level_four_scene() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path == LEVEL_FOUR_SCENE_PATH

func _play_level_four_intro_sequence() -> void:
	if _level_four_flow != null:
		await _level_four_flow.play_intro_sequence()

func _play_level_four_victory_subtitle() -> void:
	if _level_four_flow != null:
		await _level_four_flow.play_victory_subtitle()

func _consume_level_four_return_meta() -> bool:
	if not GameState.has_meta(LEVEL_FOUR_RETURN_WAKE_META):
		return false
	var active: bool = bool(GameState.get_meta(LEVEL_FOUR_RETURN_WAKE_META))
	GameState.set_meta(LEVEL_FOUR_RETURN_WAKE_META, false)
	return active

func _prepare_level_four_return_phase() -> void:
	_intro_running = false
	_transition_started = false
	_objective_state = ""
	GameState.current_level_index = 0
	GameState.full_reset_inventory()
	GameState.reset_axiom_recording()
	GameState.recording_enabled = false
	GameState.axiom_equipped = false
	GameState.axiom_unlocked = false
	GameState.axiom_equipped_changed.emit()
	GameState.ui_updated.emit()
	_ending_mode_active = true
	_ending_cinematic_running = true
	_ending_credits_running = false
	_apply_ending_world_sky()
	_set_ending_board_active(false, false)
	_hide_objective(false)
	_clear_target_highlights()
	if _hint_marker != null:
		_hint_marker.visible = false
	if _hint_label != null:
		_hint_label.visible = false
	if _sofa_interactable != null:
		_sofa_interactable.set_interactable_enabled(false)
	_position_player_for_level_four_return()

func _position_player_for_level_four_return() -> void:
	if player == null or not is_instance_valid(player):
		return
	var target_position: Vector3 = _player_spawn_position
	var target_yaw: float = _player_spawn_rotation_y
	if _sofa_target != null and is_instance_valid(_sofa_target):
		target_position = _sofa_target.to_global(Vector3(0.0, -0.9, -0.28))
		target_yaw = _sofa_target.global_rotation.y
	_player_spawn_position = target_position
	_player_spawn_rotation_y = target_yaw
	player.global_position = target_position
	player.rotation.y = target_yaw
	if player.get("camera_x_rotation") != null:
		player.set("camera_x_rotation", -6.0)

func _play_level_four_return_wake_sequence() -> void:
	if not _ending_mode_active:
		return
	_reset_intro_view_state()
	_set_intro_lock(true)
	_intro_running = false
	if player != null:
		player.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _intro_camera == null:
		_create_intro_camera()
	if _intro_camera == null:
		_ending_cinematic_running = false
		_set_intro_lock(false)
		_show_ending_board()
		return
	var wake_eye: Vector3 = _player_spawn_position + Vector3(0.0, 1.02, 0.04)
	var wake_focus: Vector3 = wake_eye + Vector3(0.0, 2.85, 0.1)
	if _sofa_target != null and is_instance_valid(_sofa_target):
		wake_eye = _sofa_target.to_global(Vector3(0.0, -0.84, -0.2))
		wake_focus = _sofa_target.to_global(Vector3(0.0, 2.15, 0.18))
	_intro_camera.global_transform = _make_look_transform(wake_eye, wake_focus)
	_intro_camera.make_current()
	if _wake_overlay != null:
		_wake_overlay.visible = true
	_set_wake_blur_strength(2.8)
	_set_wake_haze_strength(0.28)
	_set_wake_desaturate_strength(0.22)
	if _white_overlay != null:
		_white_overlay.visible = true
		_white_overlay.modulate.a = 1.0
	_play_sfx_stream(sfx_ending_return_wake)
	await get_tree().create_timer(0.36).timeout
	await _fade_white(0.0, 2.25)
	await _tween_wake_overlay(0.0, 1.35)
	await get_tree().create_timer(0.28).timeout
	await _show_subtitle("Am I dreaming?", 1.8, "")
	if player != null:
		player.visible = true
	await _return_intro_camera_to_player(0.9)
	_set_intro_lock(false)
	_ending_cinematic_running = false
	_show_ending_board()

func _cache_ending_board_node() -> void:
	if _ending_board == null or not is_instance_valid(_ending_board):
		_ending_board = get_node_or_null("EndingBoard")
	if _ending_board_camera == null or not is_instance_valid(_ending_board_camera):
		_ending_board_camera = get_node_or_null("EndingBoardCamera") as Camera3D

func _set_ending_board_active(visible: bool, interactable: bool) -> void:
	_cache_ending_board_node()
	if _ending_board == null or not is_instance_valid(_ending_board):
		return
	if _ending_board_text_overlay != null and is_instance_valid(_ending_board_text_overlay):
		_ending_board_text_overlay.visible = false
	_ending_board.visible = visible
	_ending_board.set_board_text("")
	_ending_board.set_message_visible(false)
	_ending_board.set_footer_text("")
	_ending_board.set_footer_visible(false)
	_ending_board.set_interactable_enabled(interactable)
	var activated_callable: Callable = Callable(self, "_on_ending_board_activated")
	if not _ending_board.is_connected("board_activated", activated_callable):
		_ending_board.connect("board_activated", activated_callable)

func _show_ending_board() -> void:
	_set_ending_board_active(true, true)
	_show_objective("Inspect the board")

func _update_ending_board_hint() -> void:
	if _ending_cinematic_running or _ending_credits_running:
		if _hint_marker != null:
			_hint_marker.visible = false
		if _hint_label != null:
			_hint_label.visible = false
		return
	if _ending_board == null or not is_instance_valid(_ending_board):
		if _hint_marker != null:
			_hint_marker.visible = false
		if _hint_label != null:
			_hint_label.visible = false
		return
	var hint_target: Vector3 = _ending_board.get_focus_position()
	_update_hint_marker(hint_target, "BOARD", _ending_board.global_position)

func _on_ending_board_activated() -> void:
	if _ending_cinematic_running or _ending_credits_running:
		return
	_play_sfx_stream(sfx_board_activate)
	call_deferred("_play_ending_board_cinematic")

func _play_ending_board_cinematic() -> void:
	if _ending_board == null or not is_instance_valid(_ending_board):
		return
	_ending_cinematic_running = true
	_ending_credits_running = true
	_hide_objective(false)
	if _hint_marker != null:
		_hint_marker.visible = false
	if _hint_label != null:
		_hint_label.visible = false
	if _subtitle_label != null:
		_subtitle_label.visible = false
	_set_intro_lock(true)
	if player_hud != null:
		player_hud.visible = false
	if _intro_camera == null:
		_create_intro_camera()
	if _intro_camera == null:
		await _return_to_main_menu_after_credits()
		return
	if _ending_board_text_overlay == null or not is_instance_valid(_ending_board_text_overlay):
		_create_ending_board_text_overlay()
	if _ending_board_text_overlay != null and is_instance_valid(_ending_board_text_overlay):
		_ending_board_text_overlay.visible = false
		if _ending_board_text_overlay.has_method("set_content"):
			_ending_board_text_overlay.call("set_content", ENDING_BOARD_LINE_1, ENDING_BOARD_LINE_2, ENDING_BOARD_LINE_3, ENDING_BOARD_FOOTER_TEXT)
		if _ending_board_text_overlay.has_method("reset_content"):
			_ending_board_text_overlay.call("reset_content")
	var start_transform: Transform3D = player_camera.global_transform if player_camera != null else _intro_camera.global_transform
	var start_fov: float = player_camera.fov if player_camera != null else _intro_camera.fov
	var end_transform: Transform3D = _resolve_ending_board_camera_transform(start_transform)
	var end_fov: float = _resolve_ending_board_camera_fov(start_fov)
	_intro_camera.global_transform = start_transform
	_intro_camera.make_current()
	_intro_camera.fov = start_fov
	await _set_cinematic_bars(true, 0.35)
	var camera_tween := create_tween().set_parallel(true)
	camera_tween.tween_method(_blend_intro_camera.bind(start_transform, end_transform), 0.0, 1.0, ENDING_BOARD_CAMERA_SHOT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(_intro_camera, "fov", end_fov, ENDING_BOARD_CAMERA_SHOT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await camera_tween.finished
	_ending_board.set_message_visible(false)
	_ending_board.set_footer_visible(false)
	await _play_ending_board_overlay_text()
	await get_tree().create_timer(ENDING_BOARD_HOLD_DURATION).timeout
	await _fade_black(1.0, ENDING_BOARD_FADE_DURATION)
	await _show_ending_credits_roll()
	await _return_to_main_menu_after_credits()

func _get_ending_board_cinematic_focus() -> Vector3:
	if _ending_board == null or not is_instance_valid(_ending_board):
		return Vector3.ZERO
	var fallback_focus: Vector3 = _ending_board.global_position + Vector3(0.0, 1.28, 0.0)
	if _ending_board.has_method("get_focus_position"):
		var focus_value: Variant = _ending_board.call("get_focus_position")
		if typeof(focus_value) == TYPE_VECTOR3:
			var focus: Vector3 = focus_value as Vector3
			if focus.distance_to(_ending_board.global_position) <= 2.0:
				return focus
	return fallback_focus

func _resolve_ending_board_camera_transform(fallback_start: Transform3D) -> Transform3D:
	if _ending_board_camera != null and is_instance_valid(_ending_board_camera):
		return _ending_board_camera.global_transform
	var fallback_focus: Vector3 = _get_ending_board_cinematic_focus()
	var fallback_dir: Vector3 = fallback_start.origin - fallback_focus
	if fallback_dir.length_squared() <= 0.0001:
		fallback_dir = Vector3.BACK
	fallback_dir = fallback_dir.normalized()
	return _make_look_transform(fallback_focus + fallback_dir * 0.62, fallback_focus)

func _resolve_ending_board_camera_fov(fallback_fov: float) -> float:
	if _ending_board_camera != null and is_instance_valid(_ending_board_camera):
		return _ending_board_camera.fov
	return fallback_fov

func _play_ending_board_overlay_text() -> void:
	if _ending_board_text_overlay == null or not is_instance_valid(_ending_board_text_overlay):
		return
	if _ending_board_text_overlay.has_method("play_typewriter"):
		await _ending_board_text_overlay.call("play_typewriter", ENDING_BOARD_TYPE_INTERVAL, ENDING_BOARD_LINE_PAUSE, ENDING_BOARD_FOOTER_PAUSE)

func _show_ending_credits_roll() -> void:
	if _intro_ui == null:
		return
	_play_bgm_stream(bgm_ending_credits)
	_play_sfx_stream(sfx_credits_start)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var credits_root := Control.new()
	credits_root.name = "EndingCredits"
	credits_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_ui.add_child(credits_root)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0, 0, 0, 1)
	credits_root.add_child(background)
	var credit_text := Label.new()
	credit_text.anchor_left = 0.08
	credit_text.anchor_top = 0.0
	credit_text.anchor_right = 0.92
	credit_text.anchor_bottom = 0.0
	credit_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	credit_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit_text.add_theme_font_size_override("font_size", 34)
	credit_text.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96, 1.0))
	credit_text.text = "CREDITS\n\nAXIOM\n\nDesign, Programming, Art\nmir4na\n\nSpecial Thanks\nYou, for playing\n\nThank you for playing this game."
	credit_text.custom_minimum_size = Vector2(viewport_size.x * 0.84, 1680.0)
	credit_text.size = credit_text.custom_minimum_size
	credits_root.add_child(credit_text)
	var start_y: float = viewport_size.y + 110.0
	var end_y: float = -credit_text.custom_minimum_size.y - 180.0
	credit_text.position = Vector2(0.0, start_y)
	var credits_tween := create_tween()
	credits_tween.tween_property(credit_text, "position:y", end_y, 23.0).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	await credits_tween.finished
	credits_root.queue_free()

func _return_to_main_menu_after_credits() -> void:
	var screen_fx := _screen_fx()
	if screen_fx != null and screen_fx.has_method("set_gameplay_filter_enabled"):
		screen_fx.set_gameplay_filter_enabled(false)
	_stop_bgm_stream()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _set_sky_crack_intensity(value: float) -> void:
	if _sky_crack_overlay == null:
		return
	var intensity: float = clampf(value, 0.0, 1.0)
	if intensity < 0.06:
		_sky_crack_stage = 0
	elif intensity >= 0.06 and intensity < 0.42 and _sky_crack_stage < 1:
		_sky_crack_stage = 1
		_play_sfx_stream(sfx_sky_crack_start)
	elif intensity >= 0.42 and intensity < 0.86 and _sky_crack_stage < 2:
		_sky_crack_stage = 2
		_play_sfx_stream(sfx_sky_crack_grow)
	elif intensity >= 0.86 and _sky_crack_stage < 3:
		_sky_crack_stage = 3
		_play_sfx_stream(sfx_sky_crack_break)
	if _sky_crack_overlay.material is ShaderMaterial:
		_sky_crack_overlay.material.set_shader_parameter("crack_intensity", intensity)
	_sky_crack_overlay.modulate.a = intensity
	_sky_crack_overlay.visible = intensity > 0.001

func restart_current_level() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	GameState.force_time_forward()
	GameState.reset_axiom_recording()
	GameState.set_meta(LEVEL_ONE_WHITE_META, false)
	GameState.set_meta(LEVEL_FOUR_RETURN_WAKE_META, false)
	if _is_level_one_scene():
		GameState.reset_progression()
	else:
		GameState.full_reset_inventory()
	var screen_fx := _screen_fx()
	if screen_fx != null and screen_fx.has_method("reboot_to_scene"):
		await screen_fx.reboot_to_scene(current_scene.scene_file_path, true)
	else:
		get_tree().change_scene_to_file(current_scene.scene_file_path)
