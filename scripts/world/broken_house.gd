extends Node3D

const HOUSE_SCENE := preload("res://scenes/objects/house.tscn")
const FRONT_DRIFT := Vector3(-0.55, 0.18, 2.85)
const BACK_DRIFT := Vector3(0.42, 0.1, -3.35)
const FRONT_TILT := Vector3(deg_to_rad(1.3), deg_to_rad(-1.9), deg_to_rad(0.8))
const BACK_TILT := Vector3(deg_to_rad(-0.9), deg_to_rad(2.4), deg_to_rad(-1.1))
const FRONT_KEEP := [
	"FrontDoor",
	"FrontDoorBtnOut",
	"FrontDoorBtnIn",
	"GuestDoor",
	"GuestDoorBtnOut",
	"GuestDoorBtnIn",
	"FloorLiving",
	"CarpetGuest",
	"Living",
	"GuestBedroom",
	"Lights",
	"Glass1",
	"Glass2",
]
const BACK_KEEP := [
	"MasterDoor",
	"MasterDoorBtnOut",
	"MasterDoorBtnIn",
	"FloorKitchen",
	"CarpetMaster",
	"Kitchen",
	"MasterBedroom",
	"Lights",
	"Glass3",
	"Glass4",
	"Glass5",
]

var _front_half: Node3D
var _back_half: Node3D
var _fracture_root: Node3D
var _front_prepared: bool = false
var _back_prepared: bool = false
var _shards: Array[Node3D] = []
var _shard_bases: Dictionary = {}

func build_from_house(source_house: Node3D) -> void:
	global_transform = source_house.global_transform
	_front_half = get_node_or_null("FrontHalf") as Node3D
	_back_half = get_node_or_null("BackHalf") as Node3D
	if _front_half == null:
		_front_half = HOUSE_SCENE.instantiate() as Node3D
		_front_half.name = "FrontHalf"
		add_child(_front_half)
	if _back_half == null:
		_back_half = HOUSE_SCENE.instantiate() as Node3D
		_back_half.name = "BackHalf"
		add_child(_back_half)
	_prepare_half(_front_half, FRONT_KEEP, true)
	_prepare_half(_back_half, BACK_KEEP, false)
	_sync_half_from_source(_front_half, source_house)
	_sync_half_from_source(_back_half, source_house)
	_ensure_fracture_root()
	_create_fracture_shards()
	set_split_weight(0.0)
	_disable_source_house(source_house)

func set_split_weight(weight: float) -> void:
	if _front_half != null:
		_front_half.position = Vector3(
			FRONT_DRIFT.x * weight,
			sin(weight * PI) * 0.12 + FRONT_DRIFT.y * weight,
			FRONT_DRIFT.z * weight
		)
		_front_half.rotation = FRONT_TILT * weight
	if _back_half != null:
		_back_half.position = Vector3(
			BACK_DRIFT.x * weight,
			sin(weight * PI) * 0.09 + BACK_DRIFT.y * weight,
			BACK_DRIFT.z * weight
		)
		_back_half.rotation = BACK_TILT * weight
	for shard in _shards:
		if not is_instance_valid(shard):
			continue
		var base: Transform3D = _shard_bases.get(shard, shard.transform)
		var drift := shard.get_meta("drift") as Vector3
		var twist := shard.get_meta("twist") as Vector3
		shard.position = base.origin + drift * weight
		shard.rotation = twist * weight

func _prepare_half(root: Node3D, keep_names: Array, is_front: bool) -> void:
	if (is_front and _front_prepared) or ((not is_front) and _back_prepared):
		return
	_prune_half(root, keep_names)
	_create_half_shell(root, is_front)
	_configure_half_lights(root, is_front)
	_disable_interactions(root)
	if is_front:
		_front_prepared = true
	else:
		_back_prepared = true

func _prune_half(root: Node3D, keep_names: Array) -> void:
	var remove_list: Array[Node] = []
	for child in root.get_children():
		if not keep_names.has(child.name):
			remove_list.append(child)
	for child in remove_list:
		child.free()

func _create_half_shell(root: Node3D, is_front: bool) -> void:
	var shell := CSGCombiner3D.new()
	shell.name = "HalfShell"
	shell.use_collision = true
	root.add_child(shell)

	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.92, 0.88, 0.82, 1.0)
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color(0.25, 0.22, 0.28, 1.0)

	var walls := CSGBox3D.new()
	walls.size = Vector3(24.0, 4.0, 8.8)
	walls.position = Vector3(0.0, 0.0, 4.35 if is_front else -4.35)
	walls.material = wall_material
	shell.add_child(walls)

	var hollow := CSGBox3D.new()
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	hollow.size = Vector3(23.6, 3.8, 8.4)
	hollow.position = Vector3(0.0, 0.0, 4.35 if is_front else -4.35)
	shell.add_child(hollow)

	if is_front:
		_add_gap(shell, Vector3(-1.995642, -0.8221192, 8.92), Vector3(1.6542237, 2.3557618, 0.6))
		_add_gap(shell, Vector3(-8.0, 0.3, 8.92), Vector3(2.5, 1.4, 0.6))
		_add_gap(shell, Vector3(2.0, 0.3, 8.92), Vector3(2.5, 1.4, 0.6))
	else:
		_add_gap(shell, Vector3(-8.0, 0.3, -8.92), Vector3(2.5, 1.4, 0.6))
		_add_gap(shell, Vector3(11.92, 0.3, -5.0), Vector3(0.6, 1.4, 2.5))
		_add_gap(shell, Vector3(11.92, 0.3, 4.0), Vector3(0.6, 1.4, 2.5))

	var roof := CSGBox3D.new()
	roof.size = Vector3(24.8, 0.9, 9.4)
	roof.position = Vector3(0.0, 3.85, 4.2 if is_front else -4.2)
	roof.material = roof_material
	root.add_child(roof)

	var fracture_cap := CSGBox3D.new()
	fracture_cap.name = "FractureCap"
	fracture_cap.size = Vector3(24.0, 3.8, 0.2)
	fracture_cap.position = Vector3(0.0, 0.0, 0.08 if is_front else -0.08)
	fracture_cap.material = wall_material
	root.add_child(fracture_cap)
	_add_fracture_debris(root, is_front)

func _add_gap(shell: CSGCombiner3D, gap_position: Vector3, gap_size: Vector3) -> void:
	var gap := CSGBox3D.new()
	gap.operation = CSGShape3D.OPERATION_SUBTRACTION
	gap.position = gap_position
	gap.size = gap_size
	shell.add_child(gap)

func _configure_half_lights(root: Node3D, is_front: bool) -> void:
	var lights := root.get_node_or_null("Lights")
	if lights == null:
		return
	for child in lights.get_children():
		if child is OmniLight3D:
			if is_front and child.name in ["KitchenLight", "MasterLight"]:
				child.free()
			elif not is_front and child.name in ["LivingLight", "GuestLight"]:
				child.free()

func _add_fracture_debris(root: Node3D, is_front: bool) -> void:
	var debris_root := Node3D.new()
	debris_root.name = "FractureDebris"
	root.add_child(debris_root)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.95, 1.0, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.24, 0.78, 1.0)
	material.emission_energy_multiplier = 2.6
	material.metallic = 0.28
	material.roughness = 0.22
	var points := [
		Vector3(-8.9, 1.35, 0.0),
		Vector3(-7.1, 0.35, 0.0),
		Vector3(-5.4, -0.6, 0.0),
		Vector3(-3.2, 0.95, 0.0),
		Vector3(-1.4, -1.2, 0.0),
		Vector3(0.8, -0.15, 0.0),
		Vector3(2.5, 1.2, 0.0),
		Vector3(4.3, -0.95, 0.0),
		Vector3(6.0, 0.45, 0.0),
		Vector3(8.2, -0.2, 0.0),
	]
	for i in range(points.size()):
		var chunk := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.32 + float(i % 3) * 0.14, 0.28 + float(i % 2) * 0.16, 0.08 + float(i % 4) * 0.05)
		chunk.mesh = mesh
		chunk.material_override = material
		var z_bias := 0.11 if is_front else -0.11
		chunk.position = points[i] + Vector3(
			sin(float(i) * 1.37) * 0.26,
			cos(float(i) * 1.11) * 0.12,
			z_bias + sin(float(i) * 2.4) * 0.03
		)
		chunk.rotation = Vector3(
			deg_to_rad(-18.0 + float(i) * 4.5),
			deg_to_rad(7.0 - float(i) * 2.8),
			deg_to_rad(-9.0 + float(i) * 3.2)
		)
		debris_root.add_child(chunk)

func _disable_interactions(root: Node3D) -> void:
	for child in root.get_children():
		_disable_interactions_recursive(child)

func _disable_interactions_recursive(node: Node) -> void:
	if node is StaticBody3D:
		node.collision_layer = 0
		node.collision_mask = 0
		node.process_mode = Node.PROCESS_MODE_DISABLED
	elif node is Area3D:
		node.collision_layer = 0
		node.collision_mask = 0
		node.process_mode = Node.PROCESS_MODE_DISABLED
	elif node is AnimatableBody3D:
		node.collision_layer = 1
		node.collision_mask = 1
		node.process_mode = Node.PROCESS_MODE_DISABLED
	if node.name.find("Btn") >= 0:
		node.visible = false
	for child in node.get_children():
		if child is CollisionShape3D:
			child.disabled = node.name.find("Btn") >= 0
		_disable_interactions_recursive(child)

func _sync_half_from_source(target_half: Node3D, source_house: Node3D) -> void:
	for child in target_half.get_children():
		var source_child := source_house.get_node_or_null(NodePath(String(child.name)))
		if source_child is Node3D and child is Node3D:
			(child as Node3D).transform = (source_child as Node3D).transform
		if source_child is CanvasItem and child is CanvasItem:
			(child as CanvasItem).visible = (source_child as CanvasItem).visible
		_sync_nested_state(child, source_child)

func _sync_nested_state(target_node: Node, source_node: Node) -> void:
	if source_node == null:
		return
	for child in target_node.get_children():
		var source_child := source_node.get_node_or_null(NodePath(String(child.name)))
		if source_child == null:
			continue
		if child is Node3D and source_child is Node3D:
			(child as Node3D).transform = (source_child as Node3D).transform
		if child is CanvasItem and source_child is CanvasItem:
			(child as CanvasItem).visible = (source_child as CanvasItem).visible
		_sync_nested_state(child, source_child)

func _ensure_fracture_root() -> void:
	if _fracture_root != null:
		return
	_fracture_root = get_node_or_null("Fracture") as Node3D
	if _fracture_root == null:
		_fracture_root = Node3D.new()
		_fracture_root.name = "Fracture"
		add_child(_fracture_root)

func _create_fracture_shards() -> void:
	if _shards.size() > 0:
		return
	var offsets := [
		Vector3(-8.7, 1.25, 0.02),
		Vector3(-7.0, 0.1, -0.08),
		Vector3(-5.2, -0.7, 0.06),
		Vector3(-3.3, 0.85, -0.03),
		Vector3(-1.5, -1.15, 0.08),
		Vector3(0.6, -0.25, -0.05),
		Vector3(2.3, 1.1, 0.04),
		Vector3(4.1, -0.85, -0.02),
		Vector3(6.1, 0.45, 0.09),
		Vector3(8.0, -0.35, -0.06),
		Vector3(9.2, 0.95, 0.03),
	]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.95, 1.0, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.15, 0.72, 1.0)
	material.emission_energy_multiplier = 3.4
	material.metallic = 0.35
	material.roughness = 0.18
	for i in range(offsets.size()):
		var shard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.45 + float(i % 3) * 0.2, 0.2 + float(i % 2) * 0.16, 0.18 + float(i % 4) * 0.08)
		shard.mesh = mesh
		shard.material_override = material
		shard.position = offsets[i]
		shard.set_meta("drift", Vector3(
			(-1.0 if i % 2 == 0 else 1.25) * (0.8 + float(i) * 0.1),
			0.28 + float(i % 4) * 0.11,
			(0.65 if i < 6 else -0.45) + sin(float(i) * 1.8) * 0.24
		))
		shard.set_meta("twist", Vector3(
			deg_to_rad(6.0 + float(i) * 2.1),
			deg_to_rad(-24.0 + float(i) * 5.3),
			deg_to_rad(14.0 - float(i) * 2.4)
		))
		_fracture_root.add_child(shard)
		_shards.append(shard)
		_shard_bases[shard] = shard.transform

func _disable_source_house(source_house: Node3D) -> void:
	source_house.visible = false
	_disable_source_recursive(source_house)

func _disable_source_recursive(node: Node) -> void:
	if node is CollisionShape3D:
		node.disabled = true
	elif node is StaticBody3D:
		node.collision_layer = 0
		node.collision_mask = 0
		node.process_mode = Node.PROCESS_MODE_DISABLED
	elif node is Area3D:
		node.collision_layer = 0
		node.collision_mask = 0
		node.process_mode = Node.PROCESS_MODE_DISABLED
	elif node is AnimatableBody3D:
		node.collision_layer = 0
		node.collision_mask = 0
		node.process_mode = Node.PROCESS_MODE_DISABLED
	elif node is CSGShape3D:
		node.use_collision = false
	for child in node.get_children():
		_disable_source_recursive(child)
