extends CanvasLayer

@onready var prompt_label: Label = $PromptLabel
@onready var crosshair: Label = $Crosshair
@onready var slot_1: PanelContainer = $InventoryBar/Slot1
@onready var slot_2: PanelContainer = $InventoryBar/Slot2
@onready var slot_3: PanelContainer = $InventoryBar/Slot3
@onready var label_1: Label = $InventoryBar/Slot1/Label
@onready var label_2: Label = $InventoryBar/Slot2/Label
@onready var label_3: Label = $InventoryBar/Slot3/Label
@onready var glitch_overlay: ColorRect = $GlitchOverlay
@onready var timeline_bar_container: Control = $TimelineBarContainer
@onready var film_strip: Control = $TimelineBarContainer/FilmStrip
@onready var pointer_line: ColorRect = $TimelineBarContainer/FilmStrip/PointerLine
@onready var timeline_label: Label = $TimelineBarContainer/FilmStrip/TimelineLabel
@onready var marks_container: Control = $TimelineBarContainer/FilmStrip/MarksContainer
@onready var inventory_bar: HBoxContainer = $InventoryBar
@onready var dig_progress_bar: Control = $DigProgress

var normal_style: StyleBoxFlat
var selected_style: StyleBoxFlat
var _mark_nodes: Dictionary = {}
var _invert_tween: Tween
var _glitch_tween: Tween

func set_dig_progress(val: float, is_vis: bool) -> void:
	dig_progress_bar.set_progress(val, is_vis)

func _ready() -> void:
	prompt_label.visible = false

	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0, 0, 0, 0.6)
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.2, 0.2, 0.2, 1)

	selected_style = normal_style.duplicate()
	selected_style.border_color = Color(1, 0.9, 0.2, 1)

	GameState.inventory_changed.connect(_update_inventory_ui)
	GameState.time_direction_changed.connect(_on_time_direction_changed)
	GameState.rewind_mode_changed.connect(_on_rewind_mode_changed)

	_update_inventory_ui()

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
	if GameState.rewind_mode_active:
		return
	var target = 0.8 if dir != 1 else 0.0
	if _glitch_tween:
		_glitch_tween.kill()
	_glitch_tween = create_tween()
	_glitch_tween.tween_method(func(v): _set_shader_param("glitch_intensity", v),
		_get_shader_param("glitch_intensity"), target, 0.2)

func _on_rewind_mode_changed(active: bool) -> void:
	if _invert_tween:
		_invert_tween.kill()
	if _glitch_tween:
		_glitch_tween.kill()

	_invert_tween = create_tween().set_parallel(true)

	if active:
		_invert_tween.tween_method(func(v): _set_shader_param("invert_amount", v),
			_get_shader_param("invert_amount"), 1.0, 0.4)
		_invert_tween.tween_method(func(v): _set_shader_param("vignette_strength", v),
			_get_shader_param("vignette_strength"), 0.8, 0.4)
		_glitch_tween = create_tween()
		_glitch_tween.tween_method(func(v): _set_shader_param("glitch_intensity", v),
			_get_shader_param("glitch_intensity"), 0.3, 0.3)

		var tween_ui = create_tween().set_parallel(true)
		tween_ui.tween_property(inventory_bar, "modulate:a", 0.0, 0.25)
		tween_ui.tween_property(crosshair, "modulate:a", 0.0, 0.25)
		tween_ui.tween_property(prompt_label, "modulate:a", 0.0, 0.25)
		tween_ui.tween_property(timeline_bar_container, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)
		tween_ui.tween_property(timeline_bar_container, "modulate:a", 1.0, 0.3)
	else:
		_invert_tween.tween_method(func(v): _set_shader_param("invert_amount", v),
			_get_shader_param("invert_amount"), 0.0, 0.5)
		_invert_tween.tween_method(func(v): _set_shader_param("vignette_strength", v),
			_get_shader_param("vignette_strength"), 0.0, 0.5)
		_glitch_tween = create_tween()
		_glitch_tween.tween_method(func(v): _set_shader_param("glitch_intensity", v),
			_get_shader_param("glitch_intensity"), 0.0, 0.5)

		var tween_ui = create_tween().set_parallel(true)
		tween_ui.tween_property(inventory_bar, "modulate:a", 1.0, 0.3)
		tween_ui.tween_property(crosshair, "modulate:a", 1.0, 0.3)
		tween_ui.tween_property(prompt_label, "modulate:a", 1.0, 0.3)
		tween_ui.tween_property(timeline_bar_container, "scale", Vector2(1.0, 0.3), 0.3).set_trans(Tween.TRANS_BACK)
		tween_ui.tween_property(timeline_bar_container, "modulate:a", 0.0, 0.2)

		for key in _mark_nodes.keys():
			_mark_nodes[key].queue_free()
		_mark_nodes.clear()

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

	label_1.text = "1: " + (slots[0] if slots[0] != "" else "Empty")
	label_2.text = "2: " + (slots[1] if slots[1] != "" else "Empty")
	label_3.text = "3: " + (slots[2] if slots[2] != "" else "Empty")

	slot_1.add_theme_stylebox_override("panel", selected_style if sel == 0 else normal_style)
	slot_2.add_theme_stylebox_override("panel", selected_style if sel == 1 else normal_style)
	slot_3.add_theme_stylebox_override("panel", selected_style if sel == 2 else normal_style)
