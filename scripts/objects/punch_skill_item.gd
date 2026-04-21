extends Interactable

var _picked_up: bool = false
var _highlight_enabled: bool = false
var _persistent_highlight: bool = true

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _book_aura: MeshInstance3D = $BookAura
@onready var _glow_light: OmniLight3D = $GlowLight

func _ready() -> void:
	prompt_text = "Press E to pick up Punch Skill"
	_setup_aura_materials()
	set_highlight_enabled(true)
	set_highlight_strength(1.0)

func interact() -> void:
	if _picked_up:
		return
	if not GameState.add_item("PunchSkill"):
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
	if _book_aura != null:
		_book_aura.visible = _highlight_enabled
	if _glow_light != null:
		_glow_light.visible = _highlight_enabled
	if not _highlight_enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func _apply_highlight(strength: float) -> void:
	if _book_aura != null and _book_aura.material_override is ShaderMaterial:
		_book_aura.material_override.set_shader_parameter("highlight_strength", strength)
		_book_aura.material_override.set_shader_parameter("glow_color", Color(1.0, 0.32, 0.28, 1.0))
	if _glow_light != null:
		_glow_light.light_energy = 0.85 + strength * 2.8

func _setup_aura_materials() -> void:
	var shader := load("res://shaders/objective_highlight.gdshader")
	if shader == null:
		return
	if _book_aura != null:
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("glow_color", Color(1.0, 0.32, 0.28, 1.0))
		_book_aura.material_override = material
		_book_aura.visible = false
	if _glow_light != null:
		_glow_light.visible = false

func _play_pickup_feedback() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var hud := players[0].get_node_or_null("PlayerHUD")
	if hud != null and hud.has_method("play_slot_pickup_effect"):
		hud.call("play_slot_pickup_effect", GameState.selected_slot)
