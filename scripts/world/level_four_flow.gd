extends RefCounted

const CENTER_OBJECTIVE := "Go to the center"
const DEFEAT_OBJECTIVE := "Defeat Axia"
const WORLD_SCENE_PATH := "res://scenes/world/world.tscn"
const LEVEL_FOUR_RETURN_WAKE_META := "level_four_return_wake"
const LIGHTNING_SKILL_ITEM_SCENE := preload("res://scenes/objects/lightning_skill_item.tscn")

var _world
var _boss: Node3D
var _center_objective: Area3D
var _center_hint: Node3D
var _axia_focus: Node3D
var _down_look: Node3D
var _under_look: Node3D
var _crystal_focus: Node3D
var _sky_focus: Node3D
var _walk_point_a: Node3D
var _walk_point_b: Node3D
var _combat_focus: Node3D
var _sky_head_camera: Camera3D
var _sky_head_reveal_camera: Camera3D
var _crystal_shot_start: Node3D
var _crystal_shot_end: Node3D
var _sequence_running: bool = false
var _encounter_started: bool = false
var _completed: bool = false
var _center_reached: bool = false
var _follow_axia_camera: bool = false
var _axia_follow_offset: Vector3 = Vector3(0.0, 1.35, 4.5)
var _ending_sequence_running: bool = false
var _lightning_drop_interval: float = 15.0
var _lightning_drop_timer: float = 15.0

func _init(world_ref) -> void:
	_world = world_ref

func initialize() -> void:
	_cache_nodes()
	_prepare_state()
	_connect_signals()

func process_frame() -> void:
	if _sequence_running:
		_try_recover_intro_to_encounter()
		if _follow_axia_camera:
			_update_axia_camera_follow()
		return
	_try_recover_intro_to_encounter()
	if _encounter_started and not _completed:
		_update_lightning_skill_drop()
	if _completed:
		return
	if not _center_reached:
		_update_center_hint()
		return
	if not _encounter_started:
		_hide_hint()

func play_intro_sequence() -> void:
	if _sequence_running or _completed:
		return
	_sequence_running = true
	await _wait_for_player_grounded_idle()
	_hide_hint()
	_world._hide_objective()
	_set_cinematic_ui(false)
	_world._set_intro_lock(true)
	await _world._set_cinematic_bars(true, 0.42)
	if _world.player_camera != null and _world._intro_camera != null:
		var player_transform: Transform3D = _world.player_camera.global_transform
		_world._intro_camera.global_transform = player_transform
		_world._intro_camera.make_current()
	if _world.player != null and is_instance_valid(_world.player):
		_world.player.visible = false
	await _look_to_marker(_axia_focus, 0.95)
	await _summon_axia()
	await _show_axia_line("Hey... you finally made it here.", 2.4)
	await _walk_boss_and_talk(_walk_point_a, 1.9, "Funny, right? After everything you went through, you still ended up in a place this calm.", 3.5)
	await _walk_boss_and_talk(_walk_point_b, 2.1, "You can do anything here. No pressure, no fear of failing, no one forcing you to keep getting up.", 3.8)
	_activate_sky_head_camera()
	await _show_axia_line("The sky, the light, this world... it can be the place where your exhaustion finally ends.", 3.2)
	await _world.get_tree().create_timer(0.7).timeout
	await _play_crystal_push_shot(2.35)
	await _show_axia_line("Look at that... everything here bends to your will.", 2.5)
	await _world._fade_black(1.0, 0.32)
	_prepare_player_look_down_pose()
	await _show_player_line("No. I am not staying here.", 2.0)
	await _show_player_line("The real world is hard... but that is where things actually mean something.", 2.8)
	var final_focus: Node3D = _boss if _boss != null and is_instance_valid(_boss) else (_axia_focus if _axia_focus != null else _combat_focus)
	await _show_player_line("I still want to go back. I still want to keep moving.", 2.5)
	await _show_axia_line("Then prove it.", 2.1)
	await _reveal_player_view_to_marker(final_focus, 1.15, 0.52)
	await _world._set_cinematic_bars(false, 0.3)
	if _world.player != null and is_instance_valid(_world.player):
		_world.player.visible = true
	_world._set_intro_lock(false)
	_set_cinematic_ui(true)
	_start_boss_encounter()
	_sequence_running = false

func on_boss_health_changed(current: float, maximum: float) -> void:
	if _world.player_hud != null and _world.player_hud.has_method("set_boss_bar_ratio"):
		_world.player_hud.call("set_boss_bar_ratio", current / maxf(maximum, 1.0))

func on_boss_defeated() -> void:
	if _completed:
		return
	_completed = true
	_encounter_started = false
	_hide_hint()
	if _world.player_hud != null and _world.player_hud.has_method("hide_boss_bar"):
		_world.player_hud.call("hide_boss_bar")
	_world._hide_objective()
	call_deferred("_run_boss_defeat_transition")

func _run_boss_defeat_transition() -> void:
	await _world.get_tree().create_timer(1.4).timeout
	await _world._fade_black(1.0, 0.35)
	await _world.get_tree().create_timer(2.0).timeout
	await _world._fade_black(0.0, 0.45)
	_world.call_deferred("_play_level_four_victory_subtitle")

func play_victory_subtitle() -> void:
	if _ending_sequence_running:
		return
	_ending_sequence_running = true
	_sequence_running = true
	_set_cinematic_ui(false)
	_world._set_intro_lock(true)
	await _world._set_cinematic_bars(true, 0.35)
	if _world.player_camera != null and _world._intro_camera != null:
		_world._intro_camera.global_transform = _world.player_camera.global_transform
		_world._intro_camera.make_current()
	var sky_target: Vector3 = _sky_focus.global_position if _sky_focus != null else Vector3(0.0, 22.0, 0.0)
	if _world._intro_camera != null:
		var start_transform: Transform3D = _world._intro_camera.global_transform
		var sky_transform: Transform3D = _world._make_look_transform(start_transform.origin, sky_target)
		await _world._play_camera_shot(start_transform, sky_transform, 1.3)
	_world.call("_set_sky_crack_intensity", 0.0)
	if _world._glitch_overlay != null:
		_world._glitch_overlay.modulate.a = 0.0
		_world._glitch_overlay.visible = false
	_world.call("_set_arrival_glitch_strength", 0.0)
	var crack_phase_one: Tween = _world.create_tween()
	crack_phase_one.tween_method(_world._set_sky_crack_intensity, 0.0, 0.24, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await crack_phase_one.finished
	await _world.get_tree().create_timer(0.45).timeout
	var crack_phase_two: Tween = _world.create_tween()
	crack_phase_two.tween_method(_world._set_sky_crack_intensity, 0.24, 0.68, 2.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await crack_phase_two.finished
	await _world.get_tree().create_timer(0.32).timeout
	var crack_phase_three: Tween = _world.create_tween()
	crack_phase_three.tween_method(_world._set_sky_crack_intensity, 0.68, 1.0, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await crack_phase_three.finished
	await _world._fade_white(1.0, 0.12)
	await _world.get_tree().create_timer(1.2).timeout
	GameState.set_meta(LEVEL_FOUR_RETURN_WAKE_META, true)
	_world.get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _cache_nodes() -> void:
	_boss = _world.get_node_or_null("FloatingRealm/AxiaBoss") as Node3D
	_center_objective = _world.get_node_or_null("FloatingRealm/CenterObjective") as Area3D
	_center_hint = _world.get_node_or_null("CutsceneMarkers/CenterHint") as Node3D
	_axia_focus = _world.get_node_or_null("CutsceneMarkers/AxiaFocus") as Node3D
	_down_look = _world.get_node_or_null("CutsceneMarkers/ReplyLook") as Node3D
	_under_look = _world.get_node_or_null("CutsceneMarkers/UnderLook") as Node3D
	_crystal_focus = _world.get_node_or_null("CutsceneMarkers/CrystalFocus") as Node3D
	_sky_focus = _world.get_node_or_null("CutsceneMarkers/SkyFocus") as Node3D
	_walk_point_a = _world.get_node_or_null("CutsceneMarkers/WalkPointA") as Node3D
	_walk_point_b = _world.get_node_or_null("CutsceneMarkers/WalkPointB") as Node3D
	_combat_focus = _world.get_node_or_null("CutsceneMarkers/CombatFocus") as Node3D
	_sky_head_camera = _world.get_node_or_null("CutsceneMarkers/SkyHeadCamera") as Camera3D
	_sky_head_reveal_camera = _world.get_node_or_null("CutsceneMarkers/SkyHeadRevealCamera") as Camera3D
	_crystal_shot_start = _world.get_node_or_null("CutsceneMarkers/CrystalShotStart") as Node3D
	_crystal_shot_end = _world.get_node_or_null("CutsceneMarkers/CrystalShotEnd") as Node3D

func _prepare_state() -> void:
	GameState.current_level_index = 3
	GameState.axiom_unlocked = true
	GameState.axiom_equipped = true
	GameState.recording_enabled = true
	_ensure_item_in_inventory("Gun")
	_select_item("Gun")
	if _world.player_hud != null and _world.player_hud.has_method("hide_boss_bar"):
		_world.player_hud.call("hide_boss_bar")
	_world._show_objective(CENTER_OBJECTIVE)
	if _boss != null and is_instance_valid(_boss):
		_boss.scale = Vector3.ONE * 0.05
		if _boss.has_method("set_manifested"):
			_boss.call("set_manifested", false)
		else:
			_boss.visible = false

func _connect_signals() -> void:
	if _boss != null:
		var health_changed_callable: Callable = Callable(self, "on_boss_health_changed")
		var defeated_callable: Callable = Callable(self, "on_boss_defeated")
		if _boss.has_signal("health_changed") and not _boss.is_connected("health_changed", health_changed_callable):
			_boss.connect("health_changed", health_changed_callable)
		if _boss.has_signal("defeated") and not _boss.is_connected("defeated", defeated_callable):
			_boss.connect("defeated", defeated_callable)
	if _center_objective != null:
		var center_callable: Callable = Callable(self, "_on_center_objective_entered")
		if not _center_objective.is_connected("body_entered", center_callable):
			_center_objective.connect("body_entered", center_callable)

func _on_center_objective_entered(body: Node) -> void:
	if _center_reached or body != _world.player:
		return
	_center_reached = true
	if _center_objective != null:
		_center_objective.monitoring = false
	_center_objective.visible = false
	_hide_hint()
	_world.call_deferred("_play_level_four_intro_sequence")

func _update_center_hint() -> void:
	if _center_hint == null:
		return
	_world._update_hint_marker(_center_hint.global_position + Vector3(0.0, 0.25, 0.0), "CENTER", _center_hint.global_position)

func _hide_hint() -> void:
	if _world._hint_marker != null:
		_world._hint_marker.visible = false
	if _world._hint_label != null:
		_world._hint_label.visible = false

func _look_to_marker(marker: Node3D, duration: float) -> void:
	if marker == null or _world._intro_camera == null:
		return
	var start_transform: Transform3D = _world._intro_camera.global_transform
	var end_transform: Transform3D = _world._make_look_transform(start_transform.origin, marker.global_position)
	await _world._play_camera_shot(start_transform, end_transform, duration)

func _reveal_player_view_to_marker(marker: Node3D, duration: float, fade_duration: float) -> void:
	if _world.player == null or not is_instance_valid(_world.player):
		await _world._fade_black(0.0, fade_duration)
		return
	if _world.player_camera == null:
		await _world._fade_black(0.0, fade_duration)
		return
	var camera_origin: Vector3 = _world.player_camera.global_position
	var look_down_target: Vector3 = camera_origin + Vector3(0.0, -1.0, 1.0)
	if _down_look != null:
		look_down_target = _down_look.global_position
	var to_down: Vector3 = look_down_target - camera_origin
	if to_down.length_squared() <= 0.0001:
		to_down = Vector3(0.0, -0.5, 1.0)
	var start_dir: Vector3 = to_down.normalized()
	var target_position: Vector3 = marker.global_position if marker != null else (_axia_focus.global_position if _axia_focus != null else camera_origin + Vector3(0.0, 0.0, -3.0))
	if marker != null and marker == _boss:
		target_position += Vector3(0.0, 1.35, 0.0)
	var to_target: Vector3 = target_position - camera_origin
	if to_target.length_squared() <= 0.0001:
		to_target = Vector3(0.0, 0.0, -1.0)
	var end_dir: Vector3 = to_target.normalized()
	var start_yaw: float = atan2(-start_dir.x, -start_dir.z)
	var start_pitch: float = -rad_to_deg(asin(clampf(start_dir.y, -1.0, 1.0)))
	_world.player.call("set_cinematic_pose", _world.player.global_position, start_yaw, start_pitch)
	_world.player_camera.make_current()
	var reveal: Tween = _world.create_tween().set_parallel(true)
	if _world._fade_overlay != null:
		reveal.tween_property(_world._fade_overlay, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal.parallel().tween_method(_set_player_view_transition.bind(start_dir, end_dir), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await reveal.finished

func _prepare_player_look_down_pose() -> void:
	if _world.player == null or not is_instance_valid(_world.player):
		return
	if _world.player_camera == null:
		return
	var camera_origin: Vector3 = _world.player_camera.global_position
	var look_target: Vector3 = camera_origin + Vector3(0.0, -1.0, 1.0)
	if _down_look != null:
		look_target = _down_look.global_position
	var direction: Vector3 = look_target - camera_origin
	if direction.length_squared() <= 0.0001:
		direction = Vector3(0.0, -0.6, 1.0)
	direction = direction.normalized()
	var yaw: float = atan2(-direction.x, -direction.z)
	var pitch: float = -rad_to_deg(asin(clampf(direction.y, -1.0, 1.0)))
	_world.player.call("set_cinematic_pose", _world.player.global_position, yaw, pitch)
	_world.player_camera.make_current()

func _set_player_view_transition(weight: float, start_dir: Vector3, end_dir: Vector3) -> void:
	if _world.player == null or not is_instance_valid(_world.player):
		return
	var blended_dir: Vector3 = start_dir.slerp(end_dir, clampf(weight, 0.0, 1.0)).normalized()
	var blended_yaw: float = atan2(-blended_dir.x, -blended_dir.z)
	var blended_pitch: float = -rad_to_deg(asin(clampf(blended_dir.y, -1.0, 1.0)))
	_world.player.call("set_cinematic_pose", _world.player.global_position, blended_yaw, blended_pitch)

func _align_intro_camera_to_marker(marker: Node3D) -> void:
	if marker == null or _world._intro_camera == null:
		return
	var origin: Vector3 = _world._intro_camera.global_transform.origin
	_world._intro_camera.global_transform = _world._make_look_transform(origin, marker.global_position)
	_world._intro_camera.make_current()

func _snap_look_to_marker(marker: Node3D) -> void:
	_align_intro_camera_to_marker(marker)

func _summon_axia() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	if _boss.has_method("set_manifested"):
		_boss.call("set_manifested", true)
	else:
		_boss.visible = true
	_boss.scale = Vector3.ONE * 0.05
	_face_boss_to_player()
	if _boss.has_method("play_idle"):
		_boss.call("play_idle")
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = true
		_world._glitch_overlay.modulate.a = 0.0
		_world.call("_set_arrival_glitch_strength", 1.0)
	var summon: Tween = _world.create_tween().set_parallel(true)
	summon.tween_property(_boss, "scale", Vector3.ONE, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _world._glitch_overlay != null:
		summon.parallel().tween_property(_world._glitch_overlay, "modulate:a", 0.72, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await summon.finished
	var settle: Tween = _world.create_tween().set_parallel(true)
	if _world._glitch_overlay != null:
		settle.tween_property(_world._glitch_overlay, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await settle.finished
	if _world._glitch_overlay != null:
		_world._glitch_overlay.visible = false
		_world.call("_set_arrival_glitch_strength", 0.0)
	_face_boss_to_player()

func _walk_boss_to(marker: Node3D, duration: float) -> void:
	if _boss == null or marker == null or not is_instance_valid(_boss):
		return
	_face_boss_to_player()
	if duration > 0.0:
		await _world.get_tree().create_timer(duration).timeout
	if _boss.has_method("play_idle"):
		_boss.call("play_idle")
	_face_boss_to_player()

func _walk_boss_and_talk(marker: Node3D, duration: float, text: String, subtitle_duration: float) -> void:
	if _boss == null or marker == null or not is_instance_valid(_boss):
		return
	_follow_axia_camera = false
	_face_boss_to_player()
	if _boss.has_method("play_idle"):
		_boss.call("play_idle")
	if duration > subtitle_duration:
		await _world.get_tree().create_timer(duration - subtitle_duration).timeout
	await _world._show_subtitle(text, subtitle_duration, "axia")
	_face_boss_to_player()

func _update_axia_camera_follow() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	if _world._intro_camera == null or not _world._intro_camera.current:
		return
	var look_target: Vector3 = _boss.global_position + Vector3(0.0, 1.35, 0.0)
	var desired_origin: Vector3 = _boss.global_position + _axia_follow_offset
	desired_origin.y = maxf(desired_origin.y, _boss.global_position.y + 1.15)
	var target_transform: Transform3D = _world._make_look_transform(desired_origin, look_target)
	_world._intro_camera.global_transform = _world._intro_camera.global_transform.interpolate_with(target_transform, 0.16)

func _activate_sky_head_camera() -> void:
	var sky_camera: Camera3D = _sky_head_reveal_camera if _sky_head_reveal_camera != null else _sky_head_camera
	if sky_camera == null:
		_snap_look_to_marker(_sky_focus)
		return
	var sky_target: Vector3 = _sky_focus.global_position if _sky_focus != null else Vector3(0.0, 24.0, 0.0)
	if _world.player != null and is_instance_valid(_world.player):
		var head: Node3D = _world.player.get_node_or_null("root/Skeleton3D/BoneAttachment3D/Head") as Node3D
		var head_position: Vector3 = _world.player.global_position + Vector3(0.0, 1.62, 0.0)
		if head != null:
			head_position = head.global_position
		var back_dir: Vector3 = _world.player.global_transform.basis.z.normalized()
		var right_dir: Vector3 = _world.player.global_transform.basis.x.normalized()
		var sky_origin: Vector3 = head_position + back_dir * 0.58 + right_dir * 0.08 + Vector3(0.0, 0.14, 0.0)
		sky_camera.global_transform = _world._make_look_transform(sky_origin, sky_target)
	else:
		var sky_origin_fallback: Vector3 = sky_camera.global_transform.origin
		sky_camera.global_transform = _world._make_look_transform(sky_origin_fallback, sky_target)
	sky_camera.make_current()

func _play_crystal_push_shot(duration: float) -> void:
	if _world._intro_camera == null:
		return
	var crystal_target: Vector3 = _crystal_focus.global_position if _crystal_focus != null else Vector3(0.0, 2.5, 0.0)
	var start_position: Vector3 = _world._intro_camera.global_transform.origin
	var end_position: Vector3 = start_position
	if _crystal_shot_start != null:
		start_position = _crystal_shot_start.global_position
	elif _sky_head_camera != null:
		start_position = _sky_head_camera.global_transform.origin
	if _crystal_shot_end != null:
		end_position = _crystal_shot_end.global_position
	else:
		end_position = crystal_target + (start_position - crystal_target).rotated(Vector3.UP, deg_to_rad(95.0))
	var start_offset: Vector3 = start_position - crystal_target
	var end_offset: Vector3 = end_position - crystal_target
	var start_radius: float = Vector2(start_offset.x, start_offset.z).length()
	var end_radius: float = Vector2(end_offset.x, end_offset.z).length()
	if start_radius < 1.8:
		start_radius = 2.5
	if end_radius < 1.8:
		end_radius = start_radius
	start_radius = clampf(start_radius, 2.0, 4.2)
	end_radius = clampf(end_radius, 2.0, 4.2)
	var start_angle: float = atan2(start_offset.z, start_offset.x)
	var end_angle: float = atan2(end_offset.z, end_offset.x)
	var angle_delta: float = wrapf(end_angle - start_angle, -PI, PI)
	if absf(angle_delta) < deg_to_rad(70.0):
		angle_delta = deg_to_rad(105.0) if angle_delta >= 0.0 else deg_to_rad(-105.0)
	var start_y_offset: float = minf(start_offset.y, -0.55)
	var end_y_offset: float = minf(end_offset.y, -0.78)
	_world._intro_camera.global_transform = _world._make_look_transform(start_position, crystal_target)
	_world._intro_camera.make_current()
	var elapsed: float = 0.0
	while elapsed < duration:
		var delta: float = _world.get_process_delta_time()
		elapsed += delta
		var t: float = clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
		var eased: float = t * t * (3.0 - 2.0 * t)
		var angle: float = start_angle + angle_delta * eased
		var radius: float = lerpf(start_radius, end_radius, eased)
		var y_offset: float = lerpf(start_y_offset, end_y_offset, eased) - sin(eased * PI) * 0.1
		var current_position: Vector3 = crystal_target + Vector3(cos(angle) * radius, y_offset, sin(angle) * radius)
		_world._intro_camera.global_transform = _world._make_look_transform(current_position, crystal_target)
		await _world.get_tree().process_frame
	var final_position: Vector3 = crystal_target + Vector3(cos(start_angle + angle_delta) * end_radius, end_y_offset, sin(start_angle + angle_delta) * end_radius)
	_world._intro_camera.global_transform = _world._make_look_transform(final_position, crystal_target)

func _wait_for_player_grounded_idle() -> void:
	if _world.player == null or not is_instance_valid(_world.player):
		return
	var stable_time: float = 0.0
	var step: float = 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	while stable_time < 0.26:
		await _world.get_tree().physics_frame
		if _is_player_grounded_idle():
			stable_time += step
		else:
			stable_time = 0.0

func _is_player_grounded_idle() -> bool:
	if _world.player == null or not is_instance_valid(_world.player):
		return false
	if not _world.player.is_on_floor():
		return false
	var velocity_value: Variant = _world.player.get("velocity")
	if typeof(velocity_value) != TYPE_VECTOR3:
		return false
	var velocity: Vector3 = velocity_value as Vector3
	if absf(velocity.y) > 0.05:
		return false
	return Vector2(velocity.x, velocity.z).length() <= 0.08

func _face_boss_to_player() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	if _world.player == null or not is_instance_valid(_world.player):
		return
	var target_position: Vector3 = Vector3(_world.player.global_position.x, _boss.global_position.y, _world.player.global_position.z)
	var to_target: Vector3 = target_position - _boss.global_position
	if to_target.length_squared() <= 0.0001:
		return
	_boss.look_at(target_position, Vector3.UP)

func _show_axia_line(text: String, duration: float) -> void:
	if _boss != null and _boss.has_method("play_idle"):
		_boss.call("play_idle")
	await _world._show_subtitle(text, duration, "axia")

func _show_player_line(text: String, duration: float) -> void:
	await _world._show_subtitle(text, duration, "")

func _start_boss_encounter() -> void:
	if _encounter_started or _boss == null or not is_instance_valid(_boss):
		return
	if GameState.rewind_mode_active:
		GameState.cancel_rewind_mode()
	GameState.time_direction = GameState.TIME_FORWARD
	GameState.is_scrubbing_past = false
	GameState.rewind_mode_changed.emit(false)
	GameState.time_direction_changed.emit(GameState.time_direction)
	_encounter_started = true
	_lightning_drop_timer = _lightning_drop_interval
	_world._show_objective(DEFEAT_OBJECTIVE)
	if _world.player_hud != null and _world.player_hud.has_method("show_boss_bar"):
		_world.player_hud.call("show_boss_bar", "AXIA", 1.0)
	if _boss.has_method("begin_encounter"):
		_boss.call("begin_encounter", _world.player)

func _try_recover_intro_to_encounter() -> void:
	if _encounter_started or _completed:
		return
	if _boss == null or not is_instance_valid(_boss):
		return
	if not _boss.visible:
		return
	if _world == null:
		return
	if _world.player == null or not is_instance_valid(_world.player):
		return
	if not _world.player.visible:
		return
	_world._set_intro_lock(false)
	_sequence_running = false
	_set_cinematic_ui(true)
	_start_boss_encounter()

func _set_cinematic_ui(visible: bool) -> void:
	if _world.player_hud != null:
		_world.player_hud.visible = visible
	if not visible:
		if _world._objective_panel != null:
			_world._objective_panel.visible = false
			_hide_hint()

func _update_lightning_skill_drop() -> void:
	if GameState.is_paused or GameState.rewind_mode_active or GameState.time_direction != 1 or GameState.is_scrubbing_past:
		return
	_lightning_drop_timer -= _world.get_process_delta_time()
	if _lightning_drop_timer > 0.0:
		return
	_lightning_drop_timer = _lightning_drop_interval
	_spawn_lightning_skill_drop()

func _spawn_lightning_skill_drop() -> void:
	if LIGHTNING_SKILL_ITEM_SCENE == null:
		return
	var drop_item: Node3D = LIGHTNING_SKILL_ITEM_SCENE.instantiate() as Node3D
	if drop_item == null:
		return
	_world.add_child(drop_item)
	var center: Vector3 = Vector3.ZERO
	if _combat_focus != null:
		center = _combat_focus.global_position
	elif _world.player != null and is_instance_valid(_world.player):
		center = _world.player.global_position
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(2.4, 10.8)
	var target_position: Vector3 = center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	target_position.y = 0.08
	drop_item.global_position = target_position

func _ensure_item_in_inventory(item_id: String) -> void:
	if GameState.has_item(item_id):
		return
	for slot_index in range(GameState.slots.size()):
		if GameState.slots[slot_index] == "":
			GameState.slots[slot_index] = item_id
			GameState.inventory_changed.emit()
			return

func _select_item(item_id: String) -> void:
	for slot_index in range(GameState.slots.size()):
		if GameState.slots[slot_index] == item_id:
			GameState.select_slot(slot_index)
			return
