extends CanvasLayer

const TIME_STOP_OVERLAY_SHADER := preload("res://shaders/time_stop_overlay.gdshader")

@onready var prompt_label: Label = $PromptLabel
@onready var crosshair: Label = $Crosshair
@onready var slot_1: Control = $InventoryBar/Slot1
@onready var slot_2: Control = $InventoryBar/Slot2
@onready var slot_3: Control = $InventoryBar/Slot3
@onready var slot_1_back: ColorRect = $InventoryBar/Slot1/Back
@onready var slot_2_back: ColorRect = $InventoryBar/Slot2/Back
@onready var slot_3_back: ColorRect = $InventoryBar/Slot3/Back
@onready var slot_1_accent: ColorRect = $InventoryBar/Slot1/Accent
@onready var slot_2_accent: ColorRect = $InventoryBar/Slot2/Accent
@onready var slot_3_accent: ColorRect = $InventoryBar/Slot3/Accent
@onready var label_1: Label = $InventoryBar/Slot1/Label
@onready var label_2: Label = $InventoryBar/Slot2/Label
@onready var label_3: Label = $InventoryBar/Slot3/Label
@onready var status_panel: Control = $StatusPanel
@onready var health_value: Label = $StatusPanel/HealthValue
@onready var stamina_value: Label = $StatusPanel/EnergyValue
@onready var health_bar_track: Control = $StatusPanel/HealthBarTrack
@onready var stamina_bar_track: Control = $StatusPanel/StaminaBarTrack
@onready var health_bar_fill: ColorRect = $StatusPanel/HealthBarTrack/HealthBarFill
@onready var stamina_bar_fill: ColorRect = $StatusPanel/StaminaBarTrack/StaminaBarFill
@onready var glitch_overlay: ColorRect = $GlitchOverlay
@onready var timeline_bar_container: Control = $TimelineBarContainer
@onready var film_strip: Control = $TimelineBarContainer/FilmStrip
@onready var pointer_line: ColorRect = $TimelineBarContainer/FilmStrip/PointerLine
@onready var timeline_label: Label = $TimelineBarContainer/FilmStrip/TimelineLabel
@onready var marks_container: Control = $TimelineBarContainer/FilmStrip/MarksContainer
@onready var boss_bar: Control = $BossBar
@onready var boss_name: Label = $BossBar/Name
@onready var boss_fill: ColorRect = $BossBar/BarTrack/BarFill
@onready var inventory_bar: HBoxContainer = $InventoryBar
@onready var dig_progress_bar: Control = $DigProgress

var _mark_nodes: Dictionary = {}
var _invert_tween: Tween
var _glitch_tween: Tween
var _health_ratio: float = 1.0
var _stamina_ratio: float = 1.0
var _slot_effect_tweens: Array[Tween] = []
var _ammo_container: Control
var _ammo_back: ColorRect
var _ammo_label: Label
var _reload_container: Control
var _reload_track: ColorRect
var _reload_fill: ColorRect
var _threat_warning_overlay: ColorRect
var _threat_warning_intensity: float = 0.0
var _boss_ratio: float = 1.0
var _rewind_visual_active: bool = false
var _time_stop_visual_active: bool = false
var _time_stop_overlay: ColorRect
var _time_stop_overlay_material: ShaderMaterial
var _time_stop_expand_tween: Tween

func set_dig_progress(val: float, is_vis: bool) -> void:
	dig_progress_bar.set_progress(val, is_vis)

func set_health(current: float, maximum: float) -> void:
	var safe_max := maxf(maximum, 1.0)
	_health_ratio = clampf(current / safe_max, 0.0, 1.0)
	health_value.text = "%d / %d" % [int(round(current)), int(round(safe_max))]
	call_deferred("_update_status_bars")

func set_stamina(current: float, maximum: float) -> void:
	var safe_max := maxf(maximum, 1.0)
	_stamina_ratio = clampf(current / safe_max, 0.0, 1.0)
	stamina_value.text = "%d / %d" % [int(round(current)), int(round(safe_max))]
	call_deferred("_update_status_bars")

func set_weapon_hud_visible(visible_state: bool) -> void:
	if _ammo_container == null:
		return
	_ammo_container.visible = visible_state
	if not visible_state and _reload_container != null:
		_reload_container.visible = false

func set_ammo(current: int, clip_size: int) -> void:
	if _ammo_label == null:
		return
	var safe_clip: int = maxi(clip_size, 1)
	var clamped_current: int = clampi(current, 0, safe_clip)
	_ammo_label.text = "AMMO %02d / \u221e" % clamped_current

func set_reload_progress(progress: float, visible_state: bool) -> void:
	if _reload_container == null or _reload_fill == null or _reload_track == null:
		return
	_reload_container.visible = visible_state
	if not visible_state:
		return
	var clamped := clampf(progress, 0.0, 1.0)
	var width := maxf(_reload_track.size.x - 8.0, 0.0)
	_reload_fill.size.x = width * clamped

func set_threat_warning_intensity(intensity: float) -> void:
	_threat_warning_intensity = clampf(intensity, 0.0, 1.0)
	if _threat_warning_overlay == null:
		return
	if _threat_warning_intensity <= 0.001:
		_threat_warning_overlay.visible = false
		_threat_warning_overlay.color = Color(1.0, 0.08, 0.06, 0.0)
		return
	_threat_warning_overlay.visible = true

func show_boss_bar(name_text: String, ratio: float) -> void:
	_boss_ratio = clampf(ratio, 0.0, 1.0)
	if boss_name != null:
		boss_name.text = name_text
	if boss_bar != null:
		boss_bar.visible = true
		boss_bar.modulate.a = 1.0
	_update_boss_bar()

func set_boss_bar_ratio(ratio: float) -> void:
	_boss_ratio = clampf(ratio, 0.0, 1.0)
	_update_boss_bar()

func hide_boss_bar() -> void:
	if boss_bar != null:
		boss_bar.visible = false

func _ready() -> void:
	prompt_label.visible = false
	_setup_weapon_hud()
	_setup_threat_warning()
	_setup_time_stop_overlay()

	GameState.inventory_changed.connect(_update_inventory_ui)
	GameState.time_direction_changed.connect(_on_time_direction_changed)
	GameState.rewind_mode_changed.connect(_on_rewind_mode_changed)
	get_viewport().size_changed.connect(_update_status_bars)

	_update_inventory_ui()
	set_health(100.0, 100.0)
	set_stamina(100.0, 100.0)
	set_ammo(0, 1)
	set_weapon_hud_visible(false)
	set_reload_progress(0.0, false)
	hide_boss_bar()
	call_deferred("_update_status_bars")
	_slot_effect_tweens.resize(3)

func _set_shader_param(param: String, value: float) -> void:
	if glitch_overlay.material is ShaderMaterial:
		(glitch_overlay.material as ShaderMaterial).set_shader_parameter(param, value)

func _get_shader_param(param: String) -> float:
	if glitch_overlay.material is ShaderMaterial:
		return (glitch_overlay.material as ShaderMaterial).get_shader_parameter(param) as float
	return 0.0

func _process(_delta: float) -> void:
	if GameState.rewind_mode_active:
		var ratio = GameState.get_pointer_ratio()
		var strip_w = film_strip.size.x
		var strip_h = film_strip.size.y
		pointer_line.position.x = ratio * strip_w
		pointer_line.size.y = strip_h

		var secs_ago = int((1.0 - ratio) * GameState.world_history.size() / 60.0)
		timeline_label.text = "-%ds" % secs_ago if secs_ago > 0 else "NOW"
		timeline_label.position.x = clampf(pointer_line.position.x + 4.0, 0.0, strip_w - 64.0)
		_update_mark_nodes()
	if _threat_warning_overlay != null:
		if _threat_warning_intensity <= 0.001:
			_threat_warning_overlay.visible = false
		else:
			_threat_warning_overlay.visible = true
			var pulse: float = 0.64 + 0.36 * sin(Time.get_ticks_msec() * 0.0125)
			var alpha: float = clampf(_threat_warning_intensity * 0.42 * pulse, 0.0, 0.62)
			_threat_warning_overlay.color = Color(1.0, 0.08, 0.06, alpha)

func _update_mark_nodes() -> void:
	var strip_w = film_strip.size.x
	var strip_h = film_strip.size.y
	var history_size = GameState.world_history.size()

	var active_marks = GameState.mark_indices.duplicate()
	var old_keys = _mark_nodes.keys()
	for key in old_keys:
		if not active_marks.has(key):
			_mark_nodes[key].queue_free()
			_mark_nodes.erase(key)

	for idx in active_marks:
		if history_size <= 1:
			break
		var ratio = float(idx) / float(history_size - 1)
		var px = ratio * strip_w

		if not _mark_nodes.has(idx):
			var lbl = Label.new()
			lbl.text = "×"
			lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.1, 1))
			lbl.add_theme_font_size_override("font_size", 14)
			marks_container.add_child(lbl)
			_mark_nodes[idx] = lbl

		var node = _mark_nodes[idx]
		node.position = Vector2(px - 6.0, strip_h * 0.5 - 10.0)

func show_mark_screenshot_effect() -> void:
	var t = create_tween()
	t.tween_method(func(v): _set_shader_param("screenshot_flash", v), 0.0, 1.0, 0.07)
	t.tween_method(func(v): _set_shader_param("screenshot_flash", v), 1.0, 0.0, 0.55)

func remove_mark_current() -> void:
	var idx = GameState.history_index
	GameState.mark_indices.erase(idx)
	if _mark_nodes.has(idx):
		_mark_nodes[idx].queue_free()
		_mark_nodes.erase(idx)

func place_or_remove_mark() -> void:
	if not GameState.rewind_mode_active:
		return
	var idx = GameState.rewind_pointer_index
	if GameState.mark_indices.has(idx):
		GameState.mark_indices.erase(idx)
		if _mark_nodes.has(idx):
			_mark_nodes[idx].queue_free()
			_mark_nodes.erase(idx)
	else:
		GameState.mark_indices.append(idx)

func _on_time_direction_changed(dir: int) -> void:
	if _rewind_visual_active or _time_stop_visual_active:
		return
	var target = 0.8 if dir != 1 else 0.0
	if _glitch_tween:
		_glitch_tween.kill()
	_glitch_tween = create_tween()
	_glitch_tween.tween_method(func(v): _set_shader_param("glitch_intensity", v),
		_get_shader_param("glitch_intensity"), target, 0.2)

func _on_rewind_mode_changed(active: bool) -> void:
	_rewind_visual_active = active
	_animate_screen_fx(0.35 if active else 0.5)
	if active:
		var tween_ui = create_tween().set_parallel(true)
		tween_ui.tween_property(inventory_bar, "modulate:a", 0.0, 0.25)
		tween_ui.tween_property(crosshair, "modulate:a", 0.0, 0.25)
		tween_ui.tween_property(prompt_label, "modulate:a", 0.0, 0.25)
		tween_ui.tween_property(status_panel, "modulate:a", 0.22, 0.25)
		tween_ui.tween_property(timeline_bar_container, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)
		tween_ui.tween_property(timeline_bar_container, "modulate:a", 1.0, 0.3)
	else:
		var tween_ui = create_tween().set_parallel(true)
		tween_ui.tween_property(inventory_bar, "modulate:a", 1.0, 0.3)
		tween_ui.tween_property(crosshair, "modulate:a", 1.0, 0.3)
		tween_ui.tween_property(prompt_label, "modulate:a", 1.0, 0.3)
		tween_ui.tween_property(status_panel, "modulate:a", 1.0, 0.3)
		tween_ui.tween_property(timeline_bar_container, "scale", Vector2(1.0, 0.3), 0.3).set_trans(Tween.TRANS_BACK)
		tween_ui.tween_property(timeline_bar_container, "modulate:a", 0.0, 0.2)

		for key in _mark_nodes.keys():
			_mark_nodes[key].queue_free()
		_mark_nodes.clear()

func set_time_stop_active(active: bool, world_origin: Vector3 = Vector3.ZERO, expand_duration: float = 1.0) -> void:
	_time_stop_visual_active = active
	if active:
		_activate_time_stop_overlay(world_origin, expand_duration)
	else:
		_deactivate_time_stop_overlay()
	_animate_screen_fx(0.26 if active else 0.34)

func _animate_screen_fx(duration: float) -> void:
	if _invert_tween:
		_invert_tween.kill()
	if _glitch_tween:
		_glitch_tween.kill()
	var invert_target: float = 0.0
	var vignette_target: float = 0.0
	var glitch_target: float = 0.0
	if _rewind_visual_active:
		invert_target = 1.0
		vignette_target = 0.8
		glitch_target = 0.3
	elif _time_stop_visual_active:
		invert_target = 0.0
		vignette_target = 0.46
		glitch_target = 0.1
	_invert_tween = create_tween().set_parallel(true)
	_invert_tween.tween_method(func(v): _set_shader_param("invert_amount", v), _get_shader_param("invert_amount"), invert_target, duration)
	_invert_tween.tween_method(func(v): _set_shader_param("vignette_strength", v), _get_shader_param("vignette_strength"), vignette_target, duration)
	_glitch_tween = create_tween()
	_glitch_tween.tween_method(func(v): _set_shader_param("glitch_intensity", v), _get_shader_param("glitch_intensity"), glitch_target, duration)

func _setup_time_stop_overlay() -> void:
	_time_stop_overlay = ColorRect.new()
	_time_stop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_time_stop_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_stop_overlay.visible = false
	_time_stop_overlay_material = ShaderMaterial.new()
	_time_stop_overlay_material.shader = TIME_STOP_OVERLAY_SHADER
	_time_stop_overlay_material.set_shader_parameter("center_uv", Vector2(0.5, 0.5))
	_time_stop_overlay_material.set_shader_parameter("radius", 0.0)
	_time_stop_overlay_material.set_shader_parameter("edge_softness", 0.12)
	_time_stop_overlay_material.set_shader_parameter("intensity", 0.0)
	_time_stop_overlay.material = _time_stop_overlay_material
	add_child(_time_stop_overlay)

func _activate_time_stop_overlay(world_origin: Vector3, expand_duration: float) -> void:
	if _time_stop_overlay == null or _time_stop_overlay_material == null:
		return
	_time_stop_overlay.visible = true
	var center_uv: Vector2 = _world_to_screen_uv(world_origin)
	_time_stop_overlay_material.set_shader_parameter("center_uv", center_uv)
	_time_stop_overlay_material.set_shader_parameter("radius", 0.0)
	_time_stop_overlay_material.set_shader_parameter("intensity", 1.0)
	if _time_stop_expand_tween != null:
		_time_stop_expand_tween.kill()
	_time_stop_expand_tween = create_tween()
	_time_stop_expand_tween.tween_method(func(v): _time_stop_overlay_material.set_shader_parameter("radius", v), 0.0, 1.65, maxf(0.08, expand_duration)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _deactivate_time_stop_overlay() -> void:
	if _time_stop_overlay == null or _time_stop_overlay_material == null:
		return
	if _time_stop_expand_tween != null:
		_time_stop_expand_tween.kill()
	var fade: Tween = create_tween()
	fade.tween_method(func(v): _time_stop_overlay_material.set_shader_parameter("intensity", v), 1.0, 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade.finished
	if _time_stop_overlay != null:
		_time_stop_overlay.visible = false
	_time_stop_overlay_material.set_shader_parameter("radius", 0.0)

func _world_to_screen_uv(world_origin: Vector3) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2(0.5, 0.5)
	var cam: Camera3D = viewport.get_camera_3d()
	if cam == null:
		return Vector2(0.5, 0.5)
	var screen_pos: Vector2 = cam.unproject_position(world_origin)
	var size: Vector2 = viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2(0.5, 0.5)
	return Vector2(clampf(screen_pos.x / size.x, 0.0, 1.0), clampf(screen_pos.y / size.y, 0.0, 1.0))

func trigger_pointer_glitch() -> void:
	if _glitch_tween:
		_glitch_tween.kill()
	_glitch_tween = create_tween()
	_glitch_tween.tween_method(func(v): _set_shader_param("glitch_intensity", v),
		_get_shader_param("glitch_intensity"), 1.0, 0.05)
	_glitch_tween.tween_method(func(v): _set_shader_param("glitch_intensity", v),
		1.0, 0.3, 0.15)

func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = true

func hide_prompt() -> void:
	prompt_label.visible = false

func set_crosshair_active(active: bool, is_dig: bool = false) -> void:
	if active:
		crosshair.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))
		if is_dig:
			crosshair.text = "⊕"
			crosshair.add_theme_font_size_override("font_size", 28)
		else:
			crosshair.text = "+"
			crosshair.remove_theme_font_size_override("font_size")
	else:
		crosshair.remove_theme_color_override("font_color")
		crosshair.text = "+"
		crosshair.remove_theme_font_size_override("font_size")

func _update_inventory_ui() -> void:
	var slots = GameState.slots
	var sel = GameState.selected_slot

	label_1.text = _format_slot_name(slots[0])
	label_2.text = _format_slot_name(slots[1])
	label_3.text = _format_slot_name(slots[2])
	_apply_slot_state(slot_1_back, slot_1_accent, sel == 0)
	_apply_slot_state(slot_2_back, slot_2_accent, sel == 1)
	_apply_slot_state(slot_3_back, slot_3_accent, sel == 2)

func _format_slot_name(item_id: String) -> String:
	if item_id == "":
		return "EMPTY"
	if item_id == "Gun":
		return "GUN"
	if item_id == "LightningSkill":
		return "SWORD"
	if item_id == "key_1" or item_id == "key_2":
		return "KEYCARD"
	return item_id.replace("_", " ").to_upper()

func _update_status_bars() -> void:
	if not is_instance_valid(health_bar_track) or not is_instance_valid(stamina_bar_track):
		return
	var health_width := maxf(284.0 - 12.0, 0.0)
	var stamina_width := maxf(224.0 - 8.0, 0.0)
	health_bar_fill.size.x = health_width * _health_ratio
	stamina_bar_fill.size.x = stamina_width * _stamina_ratio
	_update_boss_bar()

func _update_boss_bar() -> void:
	if boss_fill == null:
		return
	var boss_width: float = maxf(436.0 - 12.0, 0.0)
	boss_fill.size.x = boss_width * _boss_ratio

func _apply_slot_state(back: ColorRect, accent: ColorRect, selected: bool) -> void:
	if selected:
		back.color = Color(0.15, 0.03, 0.05, 0.98)
		accent.color = Color(0.98, 0.82, 0.24, 1.0)
	else:
		back.color = Color(0.05, 0.05, 0.06, 0.96)
		accent.color = Color(0.94, 0.18, 0.23, 1.0)

func play_slot_pickup_effect(slot_index: int) -> void:
	if slot_index < 0 or slot_index > 2:
		return
	var slot := _get_slot_control(slot_index)
	var accent := _get_slot_accent(slot_index)
	if slot == null or accent == null:
		return
	if slot_index < _slot_effect_tweens.size() and _slot_effect_tweens[slot_index] != null:
		_slot_effect_tweens[slot_index].kill()
	slot.pivot_offset = slot.size * 0.5
	accent.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween := create_tween().set_parallel(true)
	_slot_effect_tweens[slot_index] = tween
	tween.tween_property(slot, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(accent, "modulate", Color(1.45, 1.2, 1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(slot, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(accent, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _get_slot_control(slot_index: int) -> Control:
	match slot_index:
		0:
			return slot_1
		1:
			return slot_2
		2:
			return slot_3
	return null

func _get_slot_accent(slot_index: int) -> ColorRect:
	match slot_index:
		0:
			return slot_1_accent
		1:
			return slot_2_accent
		2:
			return slot_3_accent
	return null

func _setup_weapon_hud() -> void:
	_ammo_container = Control.new()
	_ammo_container.anchor_left = 1.0
	_ammo_container.anchor_top = 1.0
	_ammo_container.anchor_right = 1.0
	_ammo_container.anchor_bottom = 1.0
	_ammo_container.offset_left = -250.0
	_ammo_container.offset_top = -126.0
	_ammo_container.offset_right = -24.0
	_ammo_container.offset_bottom = -56.0
	_ammo_container.visible = false
	add_child(_ammo_container)

	_ammo_back = ColorRect.new()
	_ammo_back.anchor_right = 1.0
	_ammo_back.anchor_bottom = 1.0
	_ammo_back.offset_right = 0.0
	_ammo_back.offset_bottom = 0.0
	_ammo_back.color = Color(0.03, 0.03, 0.04, 0.84)
	_ammo_container.add_child(_ammo_back)

	_ammo_label = Label.new()
	_ammo_label.anchor_right = 1.0
	_ammo_label.anchor_bottom = 1.0
	_ammo_label.offset_left = 18.0
	_ammo_label.offset_top = 16.0
	_ammo_label.offset_right = -14.0
	_ammo_label.offset_bottom = -14.0
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ammo_label.add_theme_font_size_override("font_size", 24)
	_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8, 1.0))
	_ammo_label.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.01, 0.9))
	_ammo_label.add_theme_constant_override("outline_size", 8)
	_ammo_label.text = "AMMO 00 / \u221e"
	_ammo_container.add_child(_ammo_label)

	_reload_container = Control.new()
	_reload_container.anchor_left = 0.5
	_reload_container.anchor_top = 0.5
	_reload_container.anchor_right = 0.5
	_reload_container.anchor_bottom = 0.5
	_reload_container.offset_left = -182.0
	_reload_container.offset_top = 188.0
	_reload_container.offset_right = 182.0
	_reload_container.offset_bottom = 222.0
	_reload_container.visible = false
	add_child(_reload_container)

	_reload_track = ColorRect.new()
	_reload_track.anchor_right = 1.0
	_reload_track.anchor_bottom = 1.0
	_reload_track.offset_right = 0.0
	_reload_track.offset_bottom = 28.0
	_reload_track.color = Color(0.06, 0.06, 0.08, 0.86)
	_reload_container.add_child(_reload_track)

	_reload_fill = ColorRect.new()
	_reload_fill.offset_left = 4.0
	_reload_fill.offset_top = 4.0
	_reload_fill.offset_right = 4.0
	_reload_fill.offset_bottom = 24.0
	_reload_fill.color = Color(0.98, 0.28, 0.12, 0.96)
	_reload_track.add_child(_reload_fill)

func _setup_threat_warning() -> void:
	_threat_warning_overlay = ColorRect.new()
	_threat_warning_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_threat_warning_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_threat_warning_overlay.color = Color(1.0, 0.08, 0.06, 0.0)
	_threat_warning_overlay.visible = false
	add_child(_threat_warning_overlay)
