extends Interactable

@export var is_dropped: bool = false
var is_picked_up: bool = false
var _highlight_enabled: bool = false

@onready var handle: CSGCylinder3D = $Handle
@onready var handle_aura: CSGCylinder3D = $HandleAura
@onready var blade: CSGBox3D = $Blade
@onready var blade_aura: CSGBox3D = $BladeAura
@onready var glow_light: OmniLight3D = $GlowLight

func _ready() -> void:
	if is_dropped:
		prompt_text = ""
	else:
		prompt_text = "Press E to pick up Shovel"
	_setup_aura_materials()

func interact() -> void:
	if is_dropped or is_picked_up:
		return
		
	is_picked_up = true
	if GameState.add_item("Shovel"):
		prompt_text = ""
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "position", position + Vector3(0, 1.5, 0), 0.4)
		tween.tween_property(self, "rotation_degrees", rotation_degrees + Vector3(0, 360, 0), 0.4)
		tween.tween_property(self, "scale", Vector3.ZERO, 0.4)
		await tween.finished
		queue_free()

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = enabled
	handle_aura.visible = enabled
	blade_aura.visible = enabled
	glow_light.visible = enabled
	if not enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func _apply_highlight(strength: float) -> void:
	if handle_aura.material is ShaderMaterial:
		handle_aura.material.set_shader_parameter("highlight_strength", strength)
		handle_aura.material.set_shader_parameter("glow_color", Color(1.0, 0.55, 0.16, 1.0))
	if blade_aura.material is ShaderMaterial:
		blade_aura.material.set_shader_parameter("highlight_strength", strength)
		blade_aura.material.set_shader_parameter("glow_color", Color(1.0, 0.55, 0.16, 1.0))
	glow_light.light_energy = 1.1 + strength * 2.8

func _setup_aura_materials() -> void:
	var shader := load("res://shaders/objective_highlight.gdshader")
	var handle_material := ShaderMaterial.new()
	handle_material.shader = shader
	handle_material.set_shader_parameter("glow_color", Color(1.0, 0.55, 0.16, 1.0))
	handle_aura.material = handle_material
	var blade_material := ShaderMaterial.new()
	blade_material.shader = shader
	blade_material.set_shader_parameter("glow_color", Color(1.0, 0.55, 0.16, 1.0))
	blade_aura.material = blade_material
