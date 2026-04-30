extends Interactable

var _picked_up: bool = false
var _highlight_enabled: bool = false
var _persistent_highlight: bool = true

@onready var _collision: CollisionShape3D = $Collision
@onready var _model: Node = $VisualRoot/Model
@onready var _highlight_aura: MeshInstance3D = $HighlightAura
@onready var _glow_light: OmniLight3D = $GlowLight

func _ready() -> void:
	prompt_text = "Press E to pick up Flashlight"
	var body_node: Node = self
	if body_node is RigidBody3D:
		var body: RigidBody3D = body_node as RigidBody3D
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	_sanitize_imported_model(_model)
	_setup_aura_materials()
	set_highlight_enabled(true)
	set_highlight_strength(1.0)

func interact() -> void:
	if _picked_up:
		return
	if not GameState.add_item("Flashlight"):
		return
	_picked_up = true
	prompt_text = ""
	if _collision != null:
		_collision.disabled = true
	_persistent_highlight = false
	set_highlight_enabled(false)
	_play_pickup_feedback()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector3(0.0, 1.0, 0.0), 0.35)
	tween.tween_property(self, "rotation_degrees", rotation_degrees + Vector3(0.0, 360.0, 0.0), 0.35)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.35)
	await tween.finished
	queue_free()

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = (enabled or _persistent_highlight) and visible and not _picked_up
	if _highlight_aura != null:
		_highlight_aura.visible = _highlight_enabled
	if _glow_light != null:
		_glow_light.visible = _highlight_enabled
	if not _highlight_enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func _apply_highlight(strength: float) -> void:
	if _highlight_aura != null and _highlight_aura.material_override is ShaderMaterial:
		_highlight_aura.material_override.set_shader_parameter("highlight_strength", strength)
		_highlight_aura.material_override.set_shader_parameter("glow_color", Color(1.0, 0.96, 0.54, 1.0))
		_highlight_aura.scale = Vector3(1.0, 1.18, 2.15) * (1.0 + strength * 0.09)
	if _glow_light != null:
		_glow_light.light_energy = 0.8 + strength * 2.6

func _setup_aura_materials() -> void:
	var shader := load("res://shaders/objective_highlight.gdshader")
	if shader == null:
		return
	var aura_material := ShaderMaterial.new()
	aura_material.shader = shader
	aura_material.set_shader_parameter("glow_color", Color(1.0, 0.96, 0.54, 1.0))
	if _highlight_aura != null:
		_highlight_aura.material_override = aura_material

func _play_pickup_feedback() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var hud := players[0].get_node_or_null("PlayerHUD")
	if hud != null and hud.has_method("play_slot_pickup_effect"):
		hud.call("play_slot_pickup_effect", GameState.selected_slot)

func _sanitize_imported_model(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Camera3D or child is Light3D:
			child.queue_free()
			continue
		_sanitize_imported_model(child)
