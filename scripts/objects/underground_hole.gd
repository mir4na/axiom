extends Interactable

signal descended

@export var target_level_index: int = 1

@onready var _collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var _rim_aura: MeshInstance3D = get_node_or_null("RimAura") as MeshInstance3D
@onready var _glow_light: OmniLight3D = get_node_or_null("GlowLight") as OmniLight3D

var _highlight_enabled: bool = false
var _persistent_highlight: bool = false

func _ready() -> void:
	_setup_aura_materials()
	if _collision_shape != null and _collision_shape.disabled:
		set_interactable_enabled(false)
	else:
		set_interactable_enabled(true)

func set_interactable_enabled(enabled: bool) -> void:
	visible = enabled
	prompt_text = "Press E to descend" if enabled else ""
	if _collision_shape != null:
		_collision_shape.disabled = not enabled
	_persistent_highlight = enabled
	set_highlight_enabled(enabled)
	if enabled:
		set_highlight_strength(1.0)

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = (enabled or _persistent_highlight) and visible
	if _rim_aura != null:
		_rim_aura.visible = _highlight_enabled
	if _glow_light != null:
		_glow_light.visible = _highlight_enabled
	if not _highlight_enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func _apply_highlight(strength: float) -> void:
	if _rim_aura != null and _rim_aura.material_override is ShaderMaterial:
		_rim_aura.material_override.set_shader_parameter("highlight_strength", strength)
		_rim_aura.material_override.set_shader_parameter("glow_color", Color(0.26, 1.0, 0.86, 1.0))
	if _glow_light != null:
		_glow_light.light_energy = 0.9 + strength * 2.7

func _setup_aura_materials() -> void:
	var shader := load("res://shaders/objective_highlight.gdshader")
	if shader == null:
		return
	if _rim_aura != null:
		var aura_material := ShaderMaterial.new()
		aura_material.shader = shader
		aura_material.set_shader_parameter("glow_color", Color(0.26, 1.0, 0.86, 1.0))
		_rim_aura.material_override = aura_material
		_rim_aura.visible = false
	if _glow_light != null:
		_glow_light.visible = false

func interact() -> void:
	descended.emit()
	GameState.unpause()
	GameState.current_level_index = target_level_index
	if target_level_index >= 0 and target_level_index < GameState.LEVELS.size():
		get_tree().call_deferred("change_scene_to_file", GameState.LEVELS[target_level_index])
