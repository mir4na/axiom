extends Interactable

signal gate_opened
signal portal_activated

@export var required_key: String = "key_3"
@export var level_four_scene_path: String = "res://scenes/levels/level_04.tscn"
@export var dark_portal_color: Color = Color(0.18, 0.08, 0.3, 1.0)
@export var dark_portal_emission_energy: float = 2.4

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _aura: MeshInstance3D = $Aura
@onready var _glow: OmniLight3D = $Glow
@onready var _portal_ring: MeshInstance3D = get_node_or_null("PortalRing") as MeshInstance3D
@onready var _portal_area: Area3D = get_node_or_null("PortalArea") as Area3D
@onready var _portal_dark_glow: OmniLight3D = get_node_or_null("PortalDarkGlow") as OmniLight3D

var _enabled: bool = true
var _opening: bool = false
var _portal_active: bool = false
var _transitioning: bool = false
var _ring_pulse_time: float = 0.0

func _ready() -> void:
	_setup_highlight()
	_connect_portal_area()
	_set_portal_active(false)
	_update_prompt()

func _process(delta: float) -> void:
	if _portal_active and _portal_ring != null and _portal_ring.visible:
		_ring_pulse_time += delta
		var pulse: float = 1.0 + sin(_ring_pulse_time * 2.6) * 0.08
		_portal_ring.scale = Vector3.ONE * pulse
	if _portal_active and _portal_dark_glow != null and _portal_dark_glow.visible:
		_portal_dark_glow.light_energy = dark_portal_emission_energy + sin(Time.get_ticks_msec() * 0.0042) * 0.35
	_update_prompt()

func interact() -> void:
	if not _enabled or _opening or _transitioning:
		return
	if _portal_active:
		if _has_any_inventory_item():
			_show_prompt("Drop all items from every slot first")
		else:
			_show_prompt("Step into the dark portal ring")
		return
	if GameState.has_selected_item(required_key):
		GameState.consume_selected_item(required_key)
		await _activate_portal_with_keycard()
		portal_activated.emit()
		return
	if GameState.has_item(required_key):
		_show_prompt("Select keycard slot first")
	else:
		_show_prompt("Keycard required")

func set_interactable_enabled(enabled: bool) -> void:
	_enabled = enabled
	visible = enabled
	if _collision != null:
		_collision.disabled = not enabled
	if _aura != null:
		_aura.visible = enabled
	if _glow != null:
		_glow.visible = enabled
	if _portal_ring != null:
		_portal_ring.visible = enabled and _portal_active
	if _portal_dark_glow != null:
		_portal_dark_glow.visible = enabled and _portal_active
		if not (enabled and _portal_active):
			_portal_dark_glow.light_energy = 0.0
	if _portal_area != null:
		_portal_area.monitorable = enabled
		_portal_area.monitoring = enabled and _portal_active and not _transitioning
	_update_prompt()

func set_highlight_enabled(enabled: bool) -> void:
	if _aura != null:
		_aura.visible = enabled and _enabled

func set_highlight_strength(strength: float) -> void:
	if _aura != null and _aura.material_override is ShaderMaterial:
		(_aura.material_override as ShaderMaterial).set_shader_parameter("highlight_strength", strength)
	if _glow != null:
		_glow.light_energy = 1.4 + strength * 2.0

func _update_prompt() -> void:
	if not _enabled:
		prompt_text = ""
		return
	if _portal_active:
		if _has_any_inventory_item():
			prompt_text = "Drop all slot items, then enter ring"
		else:
			prompt_text = "Enter the dark portal ring"
		return
	if GameState.has_selected_item(required_key):
		prompt_text = "Press E to insert keycard"
	elif GameState.has_item(required_key):
		prompt_text = "Select keycard slot, then press E"
	else:
		prompt_text = "Requires keycard"

func _setup_highlight() -> void:
	if _aura == null:
		return
	var shader: Shader = load("res://shaders/objective_highlight.gdshader") as Shader
	if shader == null:
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("glow_color", Color(0.22, 1.0, 0.64, 1.0))
	material.set_shader_parameter("highlight_strength", 0.9)
	_aura.material_override = material

func _activate_portal_with_keycard() -> void:
	_opening = true
	_set_portal_active(true)
	prompt_text = ""
	var tween: Tween = create_tween().set_parallel(true)
	if _mesh != null:
		tween.tween_property(_mesh, "scale", Vector3(0.96, 0.18, 0.96), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if _glow != null:
		tween.tween_property(_glow, "light_energy", 0.16, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _portal_ring != null:
		_portal_ring.scale = Vector3.ONE * 0.84
		tween.tween_property(_portal_ring, "scale", Vector3.ONE * 1.05, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	_opening = false
	_update_prompt()

func _set_portal_active(active: bool) -> void:
	_portal_active = active
	if _portal_ring != null:
		_portal_ring.visible = _enabled and active
		if _portal_ring.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = _portal_ring.material_override as StandardMaterial3D
			mat.albedo_color = dark_portal_color
			mat.emission_enabled = true
			mat.emission = dark_portal_color
			mat.emission_energy_multiplier = dark_portal_emission_energy
	if _portal_dark_glow != null:
		_portal_dark_glow.visible = _enabled and active
		_portal_dark_glow.light_color = dark_portal_color
		_portal_dark_glow.light_energy = dark_portal_emission_energy if active else 0.0
	if _portal_area != null:
		_portal_area.monitoring = _enabled and active and not _transitioning
		_portal_area.monitorable = _enabled
	_ring_pulse_time = 0.0

func _connect_portal_area() -> void:
	if _portal_area == null:
		return
	var entered_callable: Callable = Callable(self, "_on_portal_area_body_entered")
	if not _portal_area.is_connected("body_entered", entered_callable):
		_portal_area.body_entered.connect(entered_callable)

func _on_portal_area_body_entered(body: Node) -> void:
	if not _enabled or not _portal_active or _transitioning:
		return
	if body == null or not body.is_in_group("player"):
		return
	if _has_any_inventory_item():
		_show_prompt("Drop all items from every slot first")
		return
	_transitioning = true
	if _portal_area != null:
		_portal_area.monitoring = false
	prompt_text = ""
	gate_opened.emit()

func _has_any_inventory_item() -> bool:
	for slot in GameState.slots:
		if String(slot) != "":
			return true
	return false

func _show_prompt(text: String) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var hud: Node = players[0].get_node_or_null("PlayerHUD")
	if hud != null and hud.has_method("show_prompt"):
		hud.call("show_prompt", text)
