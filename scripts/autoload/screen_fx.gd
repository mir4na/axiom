extends CanvasLayer

const BOOT_SCENE_SWAP_TIME := 0.34
const BOOT_DURATION := 1.2
const POWER_OFF_DURATION := 0.42
const RESPAWN_BLACK_DURATION := 0.24
const POWER_TO_CRT_BLEND_DURATION := 0.24

var _boot_backdrop: ColorRect
var _crt_rect: ColorRect
var _power_rect: ColorRect
var _crt_material: ShaderMaterial
var _power_material: ShaderMaterial
var _crt_enabled: bool = false
var _boot_running: bool = false

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	_apply_crt_state(false)
	_hide_boot_overlay()

func set_gameplay_filter_enabled(enabled: bool) -> void:
	_crt_enabled = enabled
	_apply_crt_state(enabled)

func boot_to_scene(path: String, enable_crt_after: bool = true) -> void:
	await _power_on_to_scene(path, BOOT_SCENE_SWAP_TIME, enable_crt_after)

func reboot_to_scene(path: String, enable_crt_after: bool = true) -> void:
	if _boot_running:
		return
	_boot_running = true
	get_tree().paused = false
	_boot_backdrop.visible = true
	_power_rect.visible = true
	_crt_rect.visible = _crt_enabled
	_set_power_amount(1.0)
	var power_off: Tween = create_tween()
	power_off.tween_method(_set_power_amount, 1.0, 0.0, POWER_OFF_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await power_off.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_crt_state(false)
	if _boot_backdrop != null:
		_boot_backdrop.visible = false
	if _power_rect != null:
		_power_rect.visible = true
	_set_power_amount(0.0)
	var power_on: Tween = create_tween()
	power_on.tween_method(_set_power_amount, 0.0, 1.0, BOOT_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await power_on.finished
	await _blend_power_to_crt(enable_crt_after)
	_boot_running = false

func respawn_to_scene(path: String, enable_crt_after: bool = true) -> void:
	await _power_on_to_scene(path, RESPAWN_BLACK_DURATION, enable_crt_after)

func _power_on_to_scene(path: String, black_duration: float, enable_crt_after: bool) -> void:
	if _boot_running:
		return
	_boot_running = true
	get_tree().paused = false
	_apply_crt_state(false)
	if _boot_backdrop != null:
		_boot_backdrop.visible = true
	if _power_rect != null:
		_power_rect.visible = false
	await get_tree().create_timer(black_duration, true, false, true).timeout
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	if _boot_backdrop != null:
		_boot_backdrop.visible = false
	if _power_rect != null:
		_power_rect.visible = true
	_set_power_amount(0.0)
	var power_on: Tween = create_tween()
	power_on.tween_method(_set_power_amount, 0.0, 1.0, BOOT_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await power_on.finished
	await _blend_power_to_crt(enable_crt_after)
	_boot_running = false

func _build_overlay() -> void:
	_boot_backdrop = ColorRect.new()
	_boot_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boot_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boot_backdrop.color = Color.BLACK
	add_child(_boot_backdrop)

	_crt_rect = ColorRect.new()
	_crt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt_material = ShaderMaterial.new()
	_crt_material.shader = load("res://shaders/crt_screen.gdshader")
	_crt_rect.material = _crt_material
	add_child(_crt_rect)

	_power_rect = ColorRect.new()
	_power_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_power_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_material = ShaderMaterial.new()
	_power_material.shader = load("res://shaders/crt_power_on.gdshader")
	_power_rect.material = _power_material
	add_child(_power_rect)

func _apply_crt_state(enabled: bool) -> void:
	if _crt_rect == null:
		return
	_crt_rect.visible = enabled
	if _crt_material != null:
		_crt_material.set_shader_parameter("intensity", 1.0 if enabled else 0.0)

func _show_boot_overlay() -> void:
	_boot_backdrop.visible = true
	_power_rect.visible = true

func _hide_boot_overlay() -> void:
	if _boot_backdrop != null:
		_boot_backdrop.visible = false
	if _power_rect != null:
		_power_rect.visible = false
	if _power_material != null:
		_power_material.set_shader_parameter("power", 0.0)

func _set_power_amount(value: float) -> void:
	if _power_material != null:
		_power_material.set_shader_parameter("power", value)

func _set_crt_intensity(value: float) -> void:
	if _crt_material != null:
		_crt_material.set_shader_parameter("intensity", clampf(value, 0.0, 1.0))

func _blend_power_to_crt(enable_crt_after: bool) -> void:
	_crt_enabled = enable_crt_after
	if not enable_crt_after:
		_hide_boot_overlay()
		_apply_crt_state(false)
		return
	if _crt_rect != null:
		_crt_rect.visible = true
	_set_crt_intensity(0.0)
	if _power_rect != null:
		_power_rect.modulate.a = 1.0
		_power_rect.visible = true
	var blend: Tween = create_tween()
	blend.parallel().tween_method(_set_crt_intensity, 0.0, 1.0, POWER_TO_CRT_BLEND_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _power_rect != null:
		blend.parallel().tween_property(_power_rect, "modulate:a", 0.0, POWER_TO_CRT_BLEND_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await blend.finished
	_hide_boot_overlay()
	if _power_rect != null:
		_power_rect.modulate.a = 1.0
	_apply_crt_state(true)
