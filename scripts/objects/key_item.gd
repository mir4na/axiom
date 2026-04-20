extends Interactable

@export var key_id: String = "key_1"

@onready var _collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var _card_aura: MeshInstance3D = get_node_or_null("CardAura") as MeshInstance3D
@onready var _stripe_aura: MeshInstance3D = get_node_or_null("StripeAura") as MeshInstance3D
@onready var _glow_light: OmniLight3D = get_node_or_null("GlowLight") as OmniLight3D

var _highlight_enabled: bool = false

func _ready() -> void:
	_setup_aura_materials()
	if _collision_shape != null and _collision_shape.disabled:
		set_interactable_enabled(false)
	else:
		set_interactable_enabled(true)

func set_interactable_enabled(enabled: bool) -> void:
	visible = enabled
	prompt_text = "Press E to pick up Keycard" if enabled else ""
	if _collision_shape != null:
		_collision_shape.disabled = not enabled
	if not enabled:
		set_highlight_enabled(false)

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = enabled and visible
	if _card_aura != null:
		_card_aura.visible = _highlight_enabled
	if _stripe_aura != null:
		_stripe_aura.visible = _highlight_enabled
	if _glow_light != null:
		_glow_light.visible = _highlight_enabled
	if not _highlight_enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func _apply_highlight(strength: float) -> void:
	if _card_aura != null and _card_aura.material_override is ShaderMaterial:
		_card_aura.material_override.set_shader_parameter("highlight_strength", strength)
		_card_aura.material_override.set_shader_parameter("glow_color", Color(0.22, 0.88, 1.0, 1.0))
	if _stripe_aura != null and _stripe_aura.material_override is ShaderMaterial:
		_stripe_aura.material_override.set_shader_parameter("highlight_strength", strength)
		_stripe_aura.material_override.set_shader_parameter("glow_color", Color(0.22, 0.88, 1.0, 1.0))
	if _glow_light != null:
		_glow_light.light_energy = 0.8 + strength * 2.4

func _setup_aura_materials() -> void:
	var shader := load("res://shaders/objective_highlight.gdshader")
	if shader == null:
		return
	if _card_aura != null:
		var card_material := ShaderMaterial.new()
		card_material.shader = shader
		card_material.set_shader_parameter("glow_color", Color(0.22, 0.88, 1.0, 1.0))
		_card_aura.material_override = card_material
		_card_aura.visible = false
	if _stripe_aura != null:
		var stripe_material := ShaderMaterial.new()
		stripe_material.shader = shader
		stripe_material.set_shader_parameter("glow_color", Color(0.22, 0.88, 1.0, 1.0))
		_stripe_aura.material_override = stripe_material
		_stripe_aura.visible = false
	if _glow_light != null:
		_glow_light.visible = false

func interact() -> void:
	var collected = GameState.add_item(key_id)
	if collected:
		queue_free()
