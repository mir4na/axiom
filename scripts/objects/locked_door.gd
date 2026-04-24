extends Interactable

signal opened

@export var required_key: String = "key_1"

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _aura: MeshInstance3D = $Aura
@onready var _glow_light: OmniLight3D = $GlowLight

var _highlight_enabled: bool = false
var _persistent_highlight: bool = false

func _ready() -> void:
	prompt_text = "Press E to Unlock Door"
	_setup_aura_material()

func interact() -> void:
	if GameState.slots[GameState.selected_slot] == required_key:
		GameState.consume_selected()
		opened.emit()
		queue_free()
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var hud = players[0].get_node("PlayerHUD")
			hud.show_prompt("Requires active key in hand!")

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = (enabled or _persistent_highlight) and visible
	if _aura != null:
		_aura.visible = _highlight_enabled
	if _glow_light != null:
		_glow_light.visible = _highlight_enabled
	if not _highlight_enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func set_persistent_highlight(enabled: bool) -> void:
	_persistent_highlight = enabled
	set_highlight_enabled(enabled)

func _apply_highlight(strength: float) -> void:
	if _aura != null and _aura.material_override is ShaderMaterial:
		_aura.material_override.set_shader_parameter("highlight_strength", strength)
		_aura.material_override.set_shader_parameter("glow_color", Color(1.0, 0.22, 0.2, 1.0))
	if _glow_light != null:
		_glow_light.light_energy = 0.7 + strength * 2.2

func _setup_aura_material() -> void:
	if _aura == null:
		return
	var shader := load("res://shaders/objective_highlight.gdshader")
	if shader == null:
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("glow_color", Color(1.0, 0.22, 0.2, 1.0))
	_aura.material_override = material
	_aura.visible = false
	if _glow_light != null:
		_glow_light.visible = false
