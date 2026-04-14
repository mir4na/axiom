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
@onready var timeline_meter: ProgressBar = $TimelineMeter

var normal_style: StyleBoxFlat
var selected_style: StyleBoxFlat

@onready var dig_progress_bar: Control = $DigProgress

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
	
	_update_inventory_ui()

func _process(_delta: float) -> void:
	timeline_meter.value = GameState.timeline_position

func _on_time_direction_changed(dir: int) -> void:
	var target_intensity = 0.0
	if dir != 1:  # If rewinding or fast-forwarding, trigger glitch!
		target_intensity = 0.8
		
	var tween = create_tween()
	tween.tween_method(_set_glitch_intensity, _get_glitch_intensity(), target_intensity, 0.2)

func _set_glitch_intensity(val: float) -> void:
	if glitch_overlay.material is ShaderMaterial:
		(glitch_overlay.material as ShaderMaterial).set_shader_parameter("glitch_intensity", val)

func _get_glitch_intensity() -> float:
	if glitch_overlay.material is ShaderMaterial:
		return (glitch_overlay.material as ShaderMaterial).get_shader_parameter("glitch_intensity") as float
	return 0.0

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
