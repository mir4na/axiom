extends Interactable

@export var is_dropped: bool = false
var is_picked_up: bool = false
var _highlight_enabled: bool = false

@onready var model: Node = $VisualRoot/Model
@onready var highlight_aura: MeshInstance3D = $HighlightAura
@onready var glow_light: OmniLight3D = $GlowLight

func _ready() -> void:
	if is_dropped:
		prompt_text = ""
	else:
		prompt_text = "Press E to pick up Shovel"
	_sanitize_imported_model(model)
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
	highlight_aura.visible = enabled
	glow_light.visible = enabled
	if not enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func _apply_highlight(strength: float) -> void:
	if highlight_aura.material_override is ShaderMaterial:
		highlight_aura.material_override.set_shader_parameter("highlight_strength", strength)
		highlight_aura.material_override.set_shader_parameter("glow_color", Color(1.0, 0.55, 0.16, 1.0))
	highlight_aura.scale = Vector3.ONE * (1.0 + strength * 0.08)
	glow_light.light_energy = 1.1 + strength * 2.8

func _setup_aura_materials() -> void:
	var shader := load("res://shaders/objective_highlight.gdshader")
	var aura_material := ShaderMaterial.new()
	aura_material.shader = shader
	aura_material.set_shader_parameter("glow_color", Color(1.0, 0.55, 0.16, 1.0))
	highlight_aura.material_override = aura_material

func _sanitize_imported_model(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Camera3D or child is Light3D:
			child.queue_free()
			continue
		_sanitize_imported_model(child)
