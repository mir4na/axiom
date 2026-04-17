extends Node3D

const SCALE_LERP_SPEED := 8.0
const ROTATION_SPEED := 0.005
const PITCH_LIMIT := 70.0
const INTRO_LINES := [
	{"text": "what time is it...?", "duration": 2.0},
	{"text": "why does my head feel like that?", "duration": 2.2},
	{"text": "right... i still have to clean up the yard.", "duration": 2.8},
	{"text": "the scoop should still be outside.", "duration": 2.4}
]
const SCOOP_OBJECTIVE := "OBJECTIVE: Pick up the scoop"
const DIG_OBJECTIVE := "OBJECTIVE: Bury the old stuff"
const WORLD_SCENE_PATH := "res://scenes/world/world.tscn"
const LEVEL_ONE_SCENE_PATH := "res://scenes/levels/level_01.tscn"

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var player_camera: Camera3D = get_node_or_null("Player/root/Skeleton3D/BoneAttachment3D/Head/Camera3D") as Camera3D
@onready var player_hud: CanvasLayer = get_node_or_null("Player/PlayerHUD") as CanvasLayer
@onready var shovel: Node3D = get_node_or_null("Shovel") as Node3D

var _target_scale: float = 1.0
var _yaw: float = 0.0
var _pitch: float = 0.0
var _pulse_time: float = 0.0
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

var _intro_ui: CanvasLayer
var _intro_camera: Camera3D
var _wake_overlay: ColorRect
var _subtitle_label: Label
var _objective_panel: PanelContainer
var _objective_label: Label
var _hint_marker: ColorRect
var _hint_label: Label

func _ready() -> void:
	GameState.world_scaled.connect(_on_world_scaled)
	GameState.world_rotated.connect(_on_world_rotated)
	GameState.inventory_changed.connect(_on_inventory_changed)
	if not _is_world_intro_scene():
		return
	_collect_dig_spots()
	_total_dig_spots = _dig_spots.size()
	GameState.reset_world_state()
	_create_intro_ui()
	_create_intro_camera()
	_prepare_world_phase()
	_set_intro_lock(true)
	call_deferred("_play_intro_sequence")

func _process(delta: float) -> void:
	var current: float = scale.x
	var next: float = current + ((_target_scale - current) * SCALE_LERP_SPEED * delta)
	scale = Vector3(next, next, next)

	rotation.y = lerpf(rotation.y, _yaw, SCALE_LERP_SPEED * delta)
	rotation.x = lerpf(rotation.x, _pitch, SCALE_LERP_SPEED * delta)

	if not _is_world_intro_scene():
		return

	_pulse_time += delta * 3.6

	if _objective_state == "scoop" and is_instance_valid(shovel):
		_update_scoop_hint()
	else:
		_hint_marker.visible = false
		_hint_label.visible = false

func _on_world_scaled(scale_factor: float) -> void:
	_target_scale = scale_factor

func _on_world_rotated(delta: Vector2) -> void:
	_yaw -= delta.x * ROTATION_SPEED
	_pitch -= delta.y * ROTATION_SPEED
	_pitch = clampf(_pitch, deg_to_rad(-PITCH_LIMIT), deg_to_rad(PITCH_LIMIT))

func _on_inventory_changed() -> void:
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
	_wake_overlay.color = Color(0.84, 0.85, 0.8, 0.95)
	_intro_ui.add_child(_wake_overlay)

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
	_subtitle_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96, 1.0))
	_subtitle_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
	_subtitle_label.add_theme_constant_override("outline_size", 12)
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

func _create_intro_camera() -> void:
	_intro_camera = Camera3D.new()
	_intro_camera.name = "IntroCamera"
	_intro_camera.current = false
	_intro_camera.position = _intro_camera_position
	_intro_camera.look_at(_intro_camera_target, Vector3.FORWARD)
	add_child(_intro_camera)

func _prepare_world_phase() -> void:
	GameState.full_reset_inventory()
	GameState.rewind_mode_active = false
	GameState.time_direction = GameState.TIME_FORWARD
	GameState.world_history.clear()
	GameState.history_index = -1
	GameState.rewind_pointer_index = -1
	_completed_dig_spots = 0
	_objective_state = ""
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

func _set_intro_lock(locked: bool) -> void:
	_intro_running = locked
	if locked:
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
	await _tween_wake_overlay(0.72, 1.0)
	for line in INTRO_LINES:
		await _show_subtitle(line["text"], float(line["duration"]))
		if line["text"] == "why does my head feel like that?":
			await _tween_wake_overlay(0.42, 1.4)
	await _tween_wake_overlay(0.0, 1.5)
	_subtitle_label.visible = false
	await _restore_player_camera()
	_show_objective(SCOOP_OBJECTIVE)
	_objective_state = "scoop"
	await _show_subtitle("i should grab the scoop before i start digging.", 2.5)
	_set_intro_lock(false)

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
	if _wake_overlay == null:
		return
	var overlay_tween := create_tween()
	overlay_tween.tween_property(_wake_overlay, "color:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await overlay_tween.finished

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

func _update_scoop_hint() -> void:
	if shovel == null or not is_instance_valid(shovel) or player_camera == null or player == null:
		_hint_marker.visible = false
		_hint_label.visible = false
		return
	var target_position := shovel.global_position + Vector3(0.0, 1.1, 0.0)
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_target := _get_screen_hint_target(target_position, viewport_size)
	var pulse := 1.0 + sin(_pulse_time) * 0.14
	var marker_size := Vector2.ONE * 16.0 * pulse
	_hint_marker.size = marker_size
	_hint_marker.position = screen_target - marker_size * 0.5
	_hint_marker.visible = true
	var distance := player.global_position.distance_to(shovel.global_position)
	_hint_label.text = "SCOOP %.1fm" % distance
	_hint_label.position = screen_target + Vector2(16.0, -14.0)
	_hint_label.visible = true

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
	_update_objective_text()
	call_deferred("_play_dig_phase_subtitle")

func _play_dig_phase_subtitle() -> void:
	await _show_subtitle("good. now i can get the old junk buried before anyone sees it.", 2.8)

func _on_dig_spot_completed(_spot: Node3D) -> void:
	if _objective_state != "dig":
		return
	_completed_dig_spots += 1
	_update_objective_text()
	if _completed_dig_spots >= _total_dig_spots and not _transition_started:
		_transition_started = true
		call_deferred("_finish_world_phase")

func _finish_world_phase() -> void:
	_show_objective("%s %d/%d" % [DIG_OBJECTIVE, _total_dig_spots, _total_dig_spots])
	await _show_subtitle("that should do it. time to move.", 2.4)
	get_tree().change_scene_to_file(LEVEL_ONE_SCENE_PATH)

func _is_world_intro_scene() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path == WORLD_SCENE_PATH
