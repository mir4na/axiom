extends Node3D

@export var strike_height: float = 26.0
@export var strike_radius: float = 2.4
@export var windup_duration: float = 0.1
@export var drop_duration: float = 0.2
@export var fade_duration: float = 0.3

@onready var sword_root: Node3D = $SwordRoot
@onready var blade: MeshInstance3D = $SwordRoot/Blade
@onready var guard: MeshInstance3D = $SwordRoot/Guard
@onready var grip: MeshInstance3D = $SwordRoot/Grip
@onready var pommel: MeshInstance3D = $SwordRoot/Pommel
@onready var trail: MeshInstance3D = $SwordRoot/Trail
@onready var flash: OmniLight3D = $Flash
@onready var ground_flash: MeshInstance3D = $GroundFlash

var _sword_mats: Array[ShaderMaterial] = []
var _trail_mat: ShaderMaterial
var _ground_mat: ShaderMaterial

func _ready() -> void:
	if blade.material_override != null:
		blade.material_override = blade.material_override.duplicate()
	if guard.material_override != null:
		guard.material_override = guard.material_override.duplicate()
	if grip.material_override != null:
		grip.material_override = grip.material_override.duplicate()
	if pommel.material_override != null:
		pommel.material_override = pommel.material_override.duplicate()
	if trail.material_override != null:
		trail.material_override = trail.material_override.duplicate()
	if ground_flash.material_override != null:
		ground_flash.material_override = ground_flash.material_override.duplicate()
	_sword_mats.clear()
	if blade.material_override is ShaderMaterial:
		_sword_mats.append(blade.material_override as ShaderMaterial)
	if guard.material_override is ShaderMaterial:
		_sword_mats.append(guard.material_override as ShaderMaterial)
	if grip.material_override is ShaderMaterial:
		_sword_mats.append(grip.material_override as ShaderMaterial)
	if pommel.material_override is ShaderMaterial:
		_sword_mats.append(pommel.material_override as ShaderMaterial)
	_trail_mat = trail.material_override as ShaderMaterial
	_ground_mat = ground_flash.material_override as ShaderMaterial
	_set_sword_intensity(0.0)
	if _trail_mat != null:
		_trail_mat.set_shader_parameter("intensity", 0.0)
	if _ground_mat != null:
		_ground_mat.set_shader_parameter("intensity", 0.0)
		_ground_mat.set_shader_parameter("expansion", 0.0)
	if flash != null:
		flash.light_energy = 0.0

func play(height: float, radius: float) -> void:
	strike_height = maxf(6.0, height)
	strike_radius = maxf(0.4, radius)
	_apply_dimensions()
	_reset_pose()
	var tip_offset: float = _get_tip_offset()
	var impact_root_y: float = tip_offset
	_set_sword_intensity(1.0)
	if _trail_mat != null:
		_trail_mat.set_shader_parameter("intensity", 0.95)
	if _ground_mat != null:
		_ground_mat.set_shader_parameter("intensity", 0.0)
		_ground_mat.set_shader_parameter("expansion", 0.0)
	if flash != null:
		flash.light_energy = 0.0
	await get_tree().create_timer(windup_duration).timeout
	var drop: Tween = create_tween().set_parallel(true)
	drop.tween_property(sword_root, "position:y", impact_root_y, drop_duration)
	drop.parallel().tween_property(sword_root, "scale", Vector3.ONE, drop_duration)
	if flash != null:
		drop.parallel().tween_property(flash, "light_energy", 9.5, drop_duration * 0.55)
	await drop.finished
	if _ground_mat != null:
		_ground_mat.set_shader_parameter("intensity", 1.0)
		_ground_mat.set_shader_parameter("expansion", 0.0)
	var impact: Tween = create_tween().set_parallel(true)
	if _ground_mat != null:
		impact.tween_property(_ground_mat, "shader_parameter/expansion", 1.0, 0.26)
		impact.parallel().tween_property(_ground_mat, "shader_parameter/intensity", 0.0, 0.42)
	if _trail_mat != null:
		impact.parallel().tween_property(_trail_mat, "shader_parameter/intensity", 0.0, fade_duration)
	if flash != null:
		impact.parallel().tween_property(flash, "light_energy", 0.0, 0.34)
	impact.parallel().tween_property(sword_root, "position:y", impact_root_y - minf(0.55, tip_offset * 0.18), 0.2)
	for mat in _sword_mats:
		impact.parallel().tween_property(mat, "shader_parameter/intensity", 0.0, fade_duration)
	await impact.finished
	queue_free()

func _reset_pose() -> void:
	sword_root.position = Vector3(0.0, strike_height + 7.0, 0.0)
	sword_root.scale = Vector3.ONE * 1.14
	sword_root.rotation_degrees = Vector3(180.0, randf_range(0.0, 360.0), 0.0)

func _apply_dimensions() -> void:
	if blade.mesh is BoxMesh:
		var blade_mesh: BoxMesh = blade.mesh as BoxMesh
		blade_mesh.size = Vector3(maxf(0.26, strike_radius * 0.18), maxf(6.2, strike_height * 0.32), maxf(0.16, strike_radius * 0.1))
		blade.position.y = blade_mesh.size.y * 0.5
	if guard.mesh is BoxMesh:
		var guard_mesh: BoxMesh = guard.mesh as BoxMesh
		guard_mesh.size = Vector3(maxf(1.2, strike_radius * 0.82), 0.24, maxf(0.24, strike_radius * 0.14))
		guard.position.y = 0.18
	if grip.mesh is CylinderMesh:
		var grip_mesh: CylinderMesh = grip.mesh as CylinderMesh
		grip_mesh.top_radius = maxf(0.08, strike_radius * 0.05)
		grip_mesh.bottom_radius = maxf(0.08, strike_radius * 0.05)
		grip_mesh.height = maxf(1.0, strike_radius * 0.56)
		grip.position.y = -0.58
	if pommel.mesh is SphereMesh:
		var pommel_mesh: SphereMesh = pommel.mesh as SphereMesh
		pommel_mesh.radius = maxf(0.12, strike_radius * 0.065)
		pommel_mesh.height = pommel_mesh.radius * 2.0
		pommel.position.y = -1.32
	if trail.mesh is PlaneMesh:
		var trail_mesh: PlaneMesh = trail.mesh as PlaneMesh
		trail_mesh.size = Vector2(maxf(0.88, strike_radius * 0.46), maxf(7.2, strike_height * 0.38))
		trail.position.y = trail_mesh.size.y * 0.5
	if ground_flash.mesh is CylinderMesh:
		var ground_mesh: CylinderMesh = ground_flash.mesh as CylinderMesh
		var radius_val: float = strike_radius * 0.72
		ground_mesh.top_radius = radius_val
		ground_mesh.bottom_radius = radius_val

func _set_sword_intensity(value: float) -> void:
	for mat in _sword_mats:
		mat.set_shader_parameter("intensity", value)

func _get_tip_offset() -> float:
	if blade.mesh is BoxMesh:
		var blade_mesh: BoxMesh = blade.mesh as BoxMesh
		return maxf(1.0, blade_mesh.size.y)
	return 7.4
