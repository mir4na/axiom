extends Interactable

var _picked_up: bool = false
var _highlight_enabled: bool = false
var _persistent_highlight: bool = true
var _landing_ready: bool = false
var _pulse_time: float = 0.0

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _core: MeshInstance3D = $Core
@onready var _aura: MeshInstance3D = $Aura
@onready var _trail: MeshInstance3D = $Trail
@onready var _trace_beam: MeshInstance3D = $TraceBeam
@onready var _light: OmniLight3D = $GlowLight

func _ready() -> void:
	prompt_text = "Press E to pick up Lightning Skill"
	_setup_aura_materials()
	set_highlight_enabled(true)
	set_highlight_strength(1.0)
	call_deferred("_play_starfall_arrival")

func _process(delta: float) -> void:
	if _picked_up:
		return
	_pulse_time += delta
	if not _landing_ready:
		return
	var pulse: float = sin(_pulse_time * 3.2) * 0.5 + 0.5
	if _trace_beam != null:
		_trace_beam.visible = true
		if _trace_beam.material_override is ShaderMaterial:
			var trace_mat: ShaderMaterial = _trace_beam.material_override as ShaderMaterial
			trace_mat.set_shader_parameter("alpha_boost", lerpf(0.62, 1.08, pulse))
	if _trail != null:
		_trail.visible = true
		if _trail.material_override is ShaderMaterial:
			var trail_mat: ShaderMaterial = _trail.material_override as ShaderMaterial
			trail_mat.set_shader_parameter("alpha_boost", lerpf(0.38, 0.76, pulse))
	if _light != null:
		_light.visible = true
		_light.light_energy = lerpf(1.35, 2.8, pulse)
	if _core != null and _core.material_override is StandardMaterial3D:
		var core_mat: StandardMaterial3D = _core.material_override as StandardMaterial3D
		core_mat.emission_energy_multiplier = lerpf(2.8, 4.8, pulse)
	if _aura != null:
		_aura.visible = true
	if _aura != null and _aura.material_override is ShaderMaterial:
		var aura_mat: ShaderMaterial = _aura.material_override as ShaderMaterial
		aura_mat.set_shader_parameter("highlight_strength", lerpf(1.2, 2.0, pulse))
		aura_mat.set_shader_parameter("glow_color", Color(0.07, 0.07, 0.1, 1.0))

func interact() -> void:
	if _picked_up or not _landing_ready:
		return
	if not GameState.add_item("LightningSkill"):
		return
	_picked_up = true
	prompt_text = ""
	if _collision != null:
		_collision.disabled = true
	_persistent_highlight = false
	set_highlight_enabled(false)
	if _trace_beam != null:
		_trace_beam.visible = false
	if _trail != null:
		_trail.visible = false
	if _light != null:
		_light.visible = false
	if _aura != null:
		_aura.visible = false
	_play_pickup_feedback()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", position + Vector3(0.0, 1.0, 0.0), 0.35)
	tween.parallel().tween_property(self, "rotation_degrees", rotation_degrees + Vector3(0.0, 360.0, 0.0), 0.35)
	tween.parallel().tween_property(self, "scale", Vector3.ZERO, 0.35)
	await tween.finished
	queue_free()

func set_highlight_enabled(enabled: bool) -> void:
	_highlight_enabled = (enabled or _persistent_highlight) and visible and not _picked_up
	if _aura != null:
		_aura.visible = _highlight_enabled
	if _light != null:
		_light.visible = _highlight_enabled
	if not _highlight_enabled:
		_apply_highlight(0.0)

func set_highlight_strength(strength: float) -> void:
	if not _highlight_enabled:
		return
	_apply_highlight(strength)

func _apply_highlight(strength: float) -> void:
	if _aura != null and _aura.material_override is ShaderMaterial:
		_aura.material_override.set_shader_parameter("highlight_strength", strength)
		_aura.material_override.set_shader_parameter("glow_color", Color(0.2, 0.24, 0.32, 1.0))
	if _light != null:
		_light.light_energy = 0.9 + strength * 3.2

func _setup_aura_materials() -> void:
	var shader: Shader = load("res://shaders/objective_highlight.gdshader") as Shader
	if shader == null:
		return
	if _aura != null:
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("glow_color", Color(0.2, 0.24, 0.32, 1.0))
		_aura.material_override = material
	if _light != null:
		_light.light_color = Color(0.3, 0.32, 0.38, 1.0)
		_light.visible = false

func _play_starfall_arrival() -> void:
	if _collision != null:
		_collision.disabled = true
	_landing_ready = false
	var landing_position: Vector3 = global_position
	global_position = landing_position + Vector3(0.0, 15.5, 0.0)
	if _trail != null:
		_trail.visible = true
	if _trace_beam != null:
		_trace_beam.visible = true
		if _trace_beam.material_override is ShaderMaterial:
			_trace_beam.material_override.set_shader_parameter("alpha_boost", 1.25)
	if _aura != null:
		_aura.visible = false
	if _light != null:
		_light.visible = true
		_light.light_energy = 5.6
	var fall: Tween = create_tween().set_parallel(true)
	fall.tween_property(self, "global_position", landing_position, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(self, "scale", Vector3.ONE * 1.12, 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await fall.finished
	_spawn_dark_impact_pulse(landing_position)
	var impact: Tween = create_tween().set_parallel(true)
	impact.tween_property(self, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _light != null:
		impact.parallel().tween_property(_light, "light_energy", 1.8, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _trace_beam != null and _trace_beam.material_override is ShaderMaterial:
		impact.parallel().tween_property(_trace_beam.material_override, "shader_parameter/alpha_boost", 0.5, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await impact.finished
	if _trail != null and _trail.material_override is ShaderMaterial:
		(_trail.material_override as ShaderMaterial).set_shader_parameter("alpha_boost", 0.48)
	if _trace_beam != null:
		_trace_beam.visible = true
		if _trace_beam.material_override is ShaderMaterial:
			(_trace_beam.material_override as ShaderMaterial).set_shader_parameter("alpha_boost", 0.75)
	if _collision != null:
		_collision.disabled = false
	_landing_ready = true

func _play_pickup_feedback() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var hud_node: Node = players[0].get_node_or_null("PlayerHUD")
	if hud_node != null and hud_node.has_method("play_slot_pickup_effect"):
		hud_node.call("play_slot_pickup_effect", GameState.selected_slot)

func _spawn_dark_impact_pulse(position: Vector3) -> void:
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var pulse: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.85
	mesh.bottom_radius = 0.85
	mesh.height = 0.04
	pulse.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.04, 0.04, 0.05, 0.78)
	mat.emission_enabled = true
	mat.emission = Color(0.16, 0.16, 0.18, 1.0)
	mat.emission_energy_multiplier = 3.6
	pulse.material_override = mat
	pulse.global_position = position + Vector3(0.0, 0.04, 0.0)
	parent.add_child(pulse)
	var pulse_tween: Tween = create_tween().set_parallel(true)
	pulse_tween.tween_property(pulse, "scale", Vector3(3.6, 1.0, 3.6), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pulse_tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await pulse_tween.finished
	pulse.queue_free()
