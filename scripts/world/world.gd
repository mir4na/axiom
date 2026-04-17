extends Node3D

const SCALE_LERP_SPEED := 8.0
const ROTATION_SPEED := 0.005
const PITCH_LIMIT := 70.0
const INTRO_LINES := [
	{"text": "ugh... what time is it?", "duration": 2.1},
	{"text": "my head still feels heavy.", "duration": 2.2},
	{"text": "right... the old stuff.", "duration": 2.1},
	{"text": "i forgot i need to burying up barang-barang bekas.", "duration": 3.1},
	{"text": "need the scoop first.", "duration": 2.0}
]

@onready var world_environment: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var player_camera: Camera3D = get_node_or_null("Player/root/Skeleton3D/BoneAttachment3D/Head/Camera3D") as Camera3D
@onready var player_hud: CanvasLayer = get_node_or_null("Player/PlayerHUD") as CanvasLayer
@onready var shovel: Node3D = get_node_or_null("Shovel") as Node3D

var _target_scale: float = 1.0
var _yaw: float = 0.0
var _pitch: float = 0.0
var _intro_running: bool = true
var _objective_active: bool = false
var _objective_completed: bool = false
var _objective_completion_started: bool = false
var _base_camera_fov: float = 75.0
var _pulse_time: float = 0.0

var _intro_ui: CanvasLayer
var _wake_overlay: ColorRect
var _subtitle_label: Label
var _objective_panel: PanelContainer
var _objective_label: Label
var _hint_path: Line2D
var _hint_marker: ColorRect
var _hint_label: Label

func _ready() -> void:
	GameState.world_scaled.connect(_on_world_scaled)
	GameState.world_rotated.connect(_on_world_rotated)
	GameState.inventory_changed.connect(_on_inventory_changed)
	if _is_world_intro_scene() and player_camera != null and player_hud != null and shovel != null:
		_base_camera_fov = player_camera.fov
		_create_intro_ui()
		_set_intro_lock(true)
		call_deferred("_play_intro_sequence")

func _process(delta: float) -> void:
	var current: float = scale.x
	var next: float = current + ((_target_scale - current) * SCALE_LERP_SPEED * delta)
	scale = Vector3(next, next, next)

	rotation.y = lerpf(rotation.y, _yaw, SCALE_LERP_SPEED * delta)
	rotation.x = lerpf(rotation.x, _pitch, SCALE_LERP_SPEED * delta)

	_pulse_time += delta * 3.6

	if _objective_active and not _objective_completed:
		_update_hint_path()
	elif _hint_path != null:
		_hint_path.visible = false
		_hint_marker.visible = false
		_hint_label.visible = false

	if _objective_active and not _objective_completed and not _objective_completion_started and GameState.slots.has("Shovel"):
		_finish_shovel_objective()

func _on_world_scaled(scale_factor: float) -> void:
	_target_scale = scale_factor

func _on_world_rotated(delta: Vector2) -> void:
	_yaw -= delta.x * ROTATION_SPEED
	_pitch -= delta.y * ROTATION_SPEED
	_pitch = clampf(_pitch, deg_to_rad(-PITCH_LIMIT), deg_to_rad(PITCH_LIMIT))

func _on_inventory_changed() -> void:
	if _objective_active and not _objective_completed and not _objective_completion_started and GameState.slots.has("Shovel"):
		_finish_shovel_objective()

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
	_objective_panel.offset_right = 360.0
	_objective_panel.offset_bottom = 78.0
	_objective_panel.visible = false
	var objective_style := StyleBoxFlat.new()
	objective_style.bg_color = Color(0.04, 0.06, 0.05, 0.78)
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
	_objective_label.text = ""
	_objective_label.add_theme_font_size_override("font_size", 22)
	_objective_label.add_theme_color_override("font_color", Color(0.94, 0.97, 0.92, 1.0))
	_objective_label.add_theme_constant_override("line_spacing", 2)
	_objective_panel.add_child(_objective_label)

	_subtitle_label = Label.new()
	_subtitle_label.anchor_left = 0.16
	_subtitle_label.anchor_top = 0.76
	_subtitle_label.anchor_right = 0.84
	_subtitle_label.anchor_bottom = 0.92
	_subtitle_label.offset_left = 0.0
	_subtitle_label.offset_top = 0.0
	_subtitle_label.offset_right = 0.0
	_subtitle_label.offset_bottom = 0.0
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.visible = false
	_subtitle_label.add_theme_font_size_override("font_size", 28)
	_subtitle_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96, 1.0))
	_subtitle_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
	_subtitle_label.add_theme_constant_override("outline_size", 12)
	_intro_ui.add_child(_subtitle_label)

	_hint_path = Line2D.new()
	_hint_path.width = 6.0
	_hint_path.default_color = Color(0.75, 0.98, 0.62, 0.95)
	_hint_path.round_precision = 8
	_hint_path.joint_mode = Line2D.LINE_JOINT_ROUND
	_hint_path.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_hint_path.end_cap_mode = Line2D.LINE_CAP_ROUND
	_hint_path.visible = false
	_intro_ui.add_child(_hint_path)

	_hint_marker = ColorRect.new()
	_hint_marker.color = Color(0.87, 0.98, 0.67, 0.95)
	_hint_marker.custom_minimum_size = Vector2(18.0, 18.0)
	_hint_marker.size = Vector2(18.0, 18.0)
	_hint_marker.visible = false
	_intro_ui.add_child(_hint_marker)

	_hint_label = Label.new()
	_hint_label.text = "SCOOP"
	_hint_label.visible = false
	_hint_label.add_theme_font_size_override("font_size", 20)
	_hint_label.add_theme_color_override("font_color", Color(0.92, 0.98, 0.86, 1.0))
	_hint_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.88))
	_hint_label.add_theme_constant_override("outline_size", 10)
	_intro_ui.add_child(_hint_label)

func _set_intro_lock(locked: bool) -> void:
	_intro_running = locked
	if locked:
		if player != null:
			player.process_mode = Node.PROCESS_MODE_DISABLED
		if player_hud != null:
			player_hud.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if player_camera != null:
			player_camera.fov = _base_camera_fov * 0.8
	else:
		if player != null:
			player.process_mode = Node.PROCESS_MODE_INHERIT
		if player_hud != null:
			player_hud.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if player_camera != null:
			player_camera.fov = _base_camera_fov

func _play_intro_sequence() -> void:
	await get_tree().process_frame
	await _tween_wake_overlay(0.72, 1.1)
	for line in INTRO_LINES:
		await _show_subtitle(line["text"], float(line["duration"]))
		if line["text"] == "my head still feels heavy.":
			await _tween_wake_overlay(0.46, 1.5)
		elif line["text"] == "i forgot i need to burying up barang-barang bekas.":
			await _tween_wake_overlay(0.14, 1.2)
	await _tween_wake_overlay(0.0, 1.4)
	_subtitle_label.visible = false
	_show_objective("OBJECTIVE: Find the scoop outside")
	_objective_active = true
	_set_intro_lock(false)

func _tween_wake_overlay(target_alpha: float, duration: float) -> void:
	if _wake_overlay == null or player_camera == null:
		return
	var overlay_tween := create_tween()
	overlay_tween.tween_property(_wake_overlay, "color:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	overlay_tween.parallel().tween_property(player_camera, "fov", lerpf(player_camera.fov, _base_camera_fov, 0.65), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await overlay_tween.finished

func _show_subtitle(text: String, duration: float) -> void:
	_subtitle_label.text = text
	_subtitle_label.modulate.a = 0.0
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

func _update_hint_path() -> void:
	if not is_instance_valid(shovel) or player_camera == null:
		_hint_path.visible = false
		_hint_marker.visible = false
		_hint_label.visible = false
		return

	var world_target := shovel.global_position + Vector3(0.0, 1.1, 0.0)
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_target := _get_screen_hint_target(world_target, viewport_size)

	var start := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.82)
	var mid := start.lerp(screen_target, 0.58) + Vector2(0.0, -48.0)
	_hint_path.points = PackedVector2Array([start, mid, screen_target])
	_hint_path.visible = true

	var pulse := 1.0 + sin(_pulse_time) * 0.16
	var marker_size := Vector2.ONE * 18.0 * pulse
	_hint_marker.size = marker_size
	_hint_marker.position = screen_target - marker_size * 0.5
	_hint_marker.visible = true

	_hint_label.position = screen_target + Vector2(18.0, -14.0)
	_hint_label.visible = true

func _get_screen_hint_target(world_target: Vector3, viewport_size: Vector2) -> Vector2:
	if not player_camera.is_position_behind(world_target):
		var projected := player_camera.unproject_position(world_target)
		projected.x = clampf(projected.x, 36.0, viewport_size.x - 36.0)
		projected.y = clampf(projected.y, 36.0, viewport_size.y - 36.0)
		return projected

	var local_target := player_camera.global_transform.basis.inverse() * (world_target - player_camera.global_position)
	var edge_direction := Vector2(local_target.x, -local_target.y)
	if edge_direction.length_squared() < 0.001:
		edge_direction = Vector2.RIGHT
	edge_direction = edge_direction.normalized()
	var center := viewport_size * 0.5
	var radius := minf(viewport_size.x, viewport_size.y) * 0.34
	return center + edge_direction * radius

func _finish_shovel_objective() -> void:
	_objective_completion_started = true
	_objective_active = false
	_objective_completed = true
	_hint_path.visible = false
	_hint_marker.visible = false
	_hint_label.visible = false
	_show_objective("OBJECTIVE: Scoop acquired")
	call_deferred("_play_completion_subtitle")

func _play_completion_subtitle() -> void:
	await _show_subtitle("there it is. time to deal with the rest.", 2.3)

func _is_world_intro_scene() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path == "res://scenes/world/world.tscn"
