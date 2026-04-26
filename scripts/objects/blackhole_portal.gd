extends Node3D

signal player_entered(body: Node3D)

@onready var pivot: Node3D = $Pivot
@onready var core: MeshInstance3D = $Pivot/Core
@onready var ring: MeshInstance3D = $Pivot/Ring
@onready var glow: OmniLight3D = $Glow
@onready var trigger: Area3D = $Trigger

var _open_amount: float = 0.0

func _ready() -> void:
	scale = Vector3.ZERO
	visible = false
	_set_open_amount(0.0)
	if glow != null:
		glow.light_energy = 0.0
	if trigger != null:
		trigger.body_entered.connect(_on_trigger_body_entered)

func _process(delta: float) -> void:
	if not visible:
		return
	if pivot != null:
		pivot.rotate_y(delta * 0.9)
		pivot.rotate_z(delta * 0.42)
	if core != null:
		core.rotate_z(-delta * 1.45)
	if ring != null:
		ring.rotate_z(delta * 1.9)

func play_open_sequence() -> void:
	visible = true
	scale = Vector3.ZERO
	_set_open_amount(0.0)
	if glow != null:
		glow.light_energy = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 1.28, 1.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(_set_open_amount, 0.0, 1.0, 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if glow != null:
		tween.parallel().tween_property(glow, "light_energy", 2.8, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

func play_close_sequence() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_method(_set_open_amount, _open_amount, 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if glow != null:
		tween.parallel().tween_property(glow, "light_energy", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false

func _set_open_amount(value: float) -> void:
	_open_amount = clampf(value, 0.0, 1.0)
	_set_material_amount(core)
	_set_material_amount(ring)

func _set_material_amount(mesh: MeshInstance3D) -> void:
	if mesh == null:
		return
	var material: Material = mesh.material_override
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("open_amount", _open_amount)

func _on_trigger_body_entered(body: Node) -> void:
	if not visible:
		return
	if body is Node3D:
		player_entered.emit(body as Node3D)
