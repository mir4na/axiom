extends Node3D

const LEVEL_FOUR_SCENE_PATH := "res://scenes/levels/level_04.tscn"
const BROKEN_HOUSE_SCENE := preload("res://scenes/objects/broken_house.tscn")
const HOUSE_SCENE := preload("res://scenes/objects/house.tscn")
const DRAGON_PROP_SCENE := preload("res://scenes/objects/dragon_2.tscn")
const DRAGON_ALT_PROP_SCENE := preload("res://scenes/objects/dragon.tscn")
const ENEMY_SCENE := preload("res://scenes/objects/enemy.tscn")
const ELECTRIC_ORB_SCENE := preload("res://scenes/objects/electric_orb.tscn")
const SHOVEL_SCENE := preload("res://scenes/objects/shovel.tscn")
const ROSE_SCENE := preload("res://scenes/characters/rose.tscn")
const HAZMAT_SCENE := preload("res://scenes/characters/hazmat.tscn")

enum Stage {
	TAKE_BOOTS,
	TRIGGER_REWIND,
	REACH_ARENA,
	FIGHT_DRAGON,
	TAKE_KEYCARD,
	TAME_DRAGON,
	USE_GATE,
	DONE
}

@export var bob_speed: float = 0.8
@export var bob_height: float = 0.55
@export var spin_speed: float = 0.24
@export_range(1, 4, 1) var floating_update_slices: int = 2
@export var extra_float_mesh_count: int = 8
@export var extra_float_prop_count: int = 16
@export var surreal_field_center: Vector3 = Vector3(36.0, 34.0, -10.0)
@export var surreal_field_extent: Vector3 = Vector3(58.0, 26.0, 44.0)
@export var surreal_spawn_safe_radius: float = 24.0

@onready var _world: Node = $World
@onready var _player: CharacterBody3D = $World/Player
@onready var _spawn_platform: Node3D = $World/Platforms/SpawnPlatform
@onready var _boots = $World/Platforms/BootsHouse/JumpingBoots
@onready var _boots_trace_marker: Marker3D = get_node_or_null("World/Platforms/BootsTraceMarker") as Marker3D
@onready var _dragon_guard = $World/DragonGuard
@onready var _dragon_keycard = $World/DragonKeycard
@onready var _level_gate = $World/Level4Gate
@onready var _bridge_root: Node3D = $World/Platforms/BridgePlatforms
@onready var _surreal_shapes_root: Node3D = $World/SurrealShapes
@onready var _fall_death_zone: Area3D = get_node_or_null("World/LevelFallDeathZone") as Area3D
@onready var _anomaly_encounter_root: Node3D = get_node_or_null("World/AnomalyEncounter") as Node3D
@onready var _anomaly_trigger: Area3D = get_node_or_null("World/AnomalyEncounter/Trigger") as Area3D
@onready var _anomaly_enemies_root: Node3D = get_node_or_null("World/AnomalyEncounter/Enemies") as Node3D
@onready var _dragon_arena_trigger: Area3D = get_node_or_null("World/DragonEncounter/ArenaTrigger") as Area3D
@onready var _dragon_spawn_marker: Marker3D = get_node_or_null("World/DragonEncounter/DragonSpawnMarker") as Marker3D
@onready var _dragon_arch_markers_root: Node3D = get_node_or_null("World/DragonEncounter/ArchMarkers") as Node3D
@onready var _dragon_ride_release_area: Area3D = get_node_or_null("World/DragonEncounter/RideReleaseArea") as Area3D
@onready var _dragon_escape_target: Marker3D = get_node_or_null("World/DragonEncounter/DragonEscapeTarget") as Marker3D
@onready var _dragon_mount_socket: Marker3D = get_node_or_null("World/DragonGuard/ModelRoot/RideSocket") as Marker3D
@onready var _dragon_camera_socket: Marker3D = get_node_or_null("World/DragonGuard/ModelRoot/RideCameraSocket") as Marker3D
@onready var _bow_pickup: Node3D = get_node_or_null("World/BowPickup") as Node3D
@onready var _dragon_intro_orbit_a: Marker3D = get_node_or_null("World/DragonEncounter/IntroOrbitA") as Marker3D
@onready var _dragon_intro_orbit_b: Marker3D = get_node_or_null("World/DragonEncounter/IntroOrbitB") as Marker3D
@onready var _dragon_intro_orbit_c: Marker3D = get_node_or_null("World/DragonEncounter/IntroOrbitC") as Marker3D
@onready var _dragon_intro_landing_marker: Marker3D = get_node_or_null("World/DragonEncounter/IntroLandingMarker") as Marker3D
@onready var _dragon_ride_path_start: Marker3D = get_node_or_null("World/DragonRidePath/Start") as Marker3D
@onready var _dragon_ride_path_mid: Marker3D = get_node_or_null("World/DragonRidePath/Mid") as Marker3D
@onready var _dragon_ride_path_end: Marker3D = get_node_or_null("World/DragonRidePath/End") as Marker3D
@onready var _dragon_ride_player_drop: Marker3D = get_node_or_null("World/DragonRidePath/PlayerDrop") as Marker3D

@export var dragon_ride_speed: float = 23.0
@export var dragon_ride_vertical_speed: float = 14.0
@export var dragon_ride_turn_speed: float = 1.9
@export var dragon_ride_boost_multiplier: float = 1.7
@export var dragon_ride_accel: float = 3.8
@export var dragon_ride_visual_yaw_offset_degrees: float = 180.0
@export var dragon_takeoff_impulse: float = 8.0
@export var dragon_idle_descent_speed: float = 2.2
@export var dragon_ground_probe_height: float = 3.2
@export var dragon_ground_probe_depth: float = 6.2
@export var dragon_ground_clearance: float = 0.08
@export var dragon_cursor_steer_max_ray_distance: float = 300.0
@export var dragon_cursor_deadzone: float = 0.08
@export var dragon_cursor_horizontal_steer: float = 1.35
@export var dragon_camera_anchor_position_smooth: float = 8.0
@export var dragon_camera_anchor_rotation_smooth: float = 8.0
@export var dragon_camera_look_distance: float = 32.0
@export var boots_forward_speed_multiplier: float = 1.15

var _stage: Stage = Stage.TAKE_BOOTS
var _base_jump_power: float = 4.5
var _base_move_speed: float = 4.0
var _base_sprint_speed: float = 7.0
var _ride_running: bool = false
var _time: float = 0.0
var _floating_nodes: Array[Node3D] = []
var _base_positions: Dictionary = {}
var _phase_map: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _floating_update_bucket: int = 0
var _anomaly_enemies: Array[Node3D] = []
var _anomaly_encounter_started: bool = false
var _dragon_intro_played: bool = false
var _dragon_fight_running: bool = false
var _dragon_arena_position: Vector3 = Vector3.ZERO
var _dragon_riding: bool = false
var _dragon_escape_running: bool = false
var _dragon_ride_velocity: Vector3 = Vector3.ZERO
var _dragon_flight_active: bool = false
var _dragon_space_prev: bool = false
var _dragon_ride_ready: bool = false
var _dragon_flight_cinematic_running: bool = false
var _dragon_ride_look_direction: Vector3 = Vector3.FORWARD
var _dragon_runtime_camera_anchor: Node3D
var _portal_transfer_running: bool = false
var _boots_item_id: String = "JumpBoots"
var _boots_jump_multiplier: float = 1.0
var _boots_unlocked: bool = false
var _dragon_arch_markers: Array[Node3D] = []
var _dragon_keycard_spawn_transform: Transform3D = Transform3D.IDENTITY

func _ready() -> void:
	GameState.current_level_index = 2
	GameState.set_rewind_disabled(false)
	GameState.recording_enabled = true
	GameState.axiom_unlocked = true
	GameState.axiom_equipped = true
	GameState.axiom_equipped_changed.emit()
	GameState.ui_updated.emit()
	_rng.randomize()
	if _player != null:
		_base_jump_power = _player.jump_power
		if _player.has_method("get"):
			_base_move_speed = float(_player.get("speed"))
			_base_sprint_speed = float(_player.get("sprint_speed"))
	if _boots != null and _boots.has_method("get"):
		var item_id_variant: Variant = _boots.get("item_id")
		if typeof(item_id_variant) == TYPE_STRING and String(item_id_variant) != "":
			_boots_item_id = String(item_id_variant)
	_spawn_surreal_field()
	_ensure_random_objects_have_collision()
	_collect_floaters()
	_set_bridge_enabled(false)
	_set_bridge_preview_visible(true)
	if _dragon_keycard != null and is_instance_valid(_dragon_keycard):
		_dragon_keycard_spawn_transform = _dragon_keycard.global_transform
	_collect_dragon_arch_markers()
	_set_dragon_keycard_pickup_enabled(false)
	if _dragon_guard != null and _dragon_guard.has_method("set_mount_enabled"):
		_dragon_guard.call("set_mount_enabled", false)
	if _dragon_guard != null:
		_dragon_arena_position = _dragon_guard.global_position
		if _dragon_guard.has_method("set_visual_yaw_offset_degrees"):
			_dragon_guard.call("set_visual_yaw_offset_degrees", dragon_ride_visual_yaw_offset_degrees)
		if _dragon_guard.has_method("set_arch_markers"):
			_dragon_guard.call("set_arch_markers", _dragon_arch_markers)
		if _dragon_guard.has_method("reset_dragon_state"):
			_dragon_guard.call("reset_dragon_state")
		if _dragon_guard.has_method("set_combat_enabled"):
			_dragon_guard.call("set_combat_enabled", false)
		else:
			_dragon_guard.visible = false
	if _level_gate != null and _level_gate.has_method("set_interactable_enabled"):
		_level_gate.call("set_interactable_enabled", false)
	if _boots != null and _boots.has_signal("collected"):
		_boots.collected.connect(_on_boots_collected)
	if _dragon_guard != null:
		if _dragon_guard.has_signal("defeated"):
			_dragon_guard.defeated.connect(_on_dragon_defeated)
		if _dragon_guard.has_signal("mount_requested"):
			_dragon_guard.mount_requested.connect(_on_dragon_mount_requested)
		if _dragon_guard.has_signal("health_changed"):
			_dragon_guard.health_changed.connect(_on_dragon_health_changed)
	if _level_gate != null and _level_gate.has_signal("gate_opened"):
		_level_gate.gate_opened.connect(_on_gate_opened)
	if _level_gate != null and _level_gate.has_signal("portal_activated"):
		_level_gate.portal_activated.connect(_on_gate_portal_activated)
	if not GameState.is_connected("rewind_mode_changed", Callable(self, "_on_rewind_mode_changed")):
		GameState.rewind_mode_changed.connect(_on_rewind_mode_changed)
	if not GameState.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
		GameState.inventory_changed.connect(_on_inventory_changed)
	_disable_anomaly_encounter()
	_setup_dragon_arena_encounter()
	_align_dragon_arena_trigger_to_center()
	_setup_dragon_ride_release_trigger()
	_setup_fall_death_zone()
	_set_bow_pickup_enabled(true)
	if _player != null and _player.has_method("set_bow_shot_cooldown"):
		_player.call("set_bow_shot_cooldown", 0.5)
	if _world != null and _world.get("player_hud") != null:
		var hud_variant: Variant = _world.get("player_hud")
		if hud_variant is CanvasLayer and (hud_variant as CanvasLayer).has_method("hide_boss_bar"):
			(hud_variant as CanvasLayer).call("hide_boss_bar")
	_apply_jump_boots_modifier_by_slot()
	_show_objective("Take the jumping boots")
	_show_subtitle("Find the boots and prepare for a long jump.", 2.0)

func _process(delta: float) -> void:
	_stabilize_dragon_keycard()
	if _dragon_riding:
		_update_portal_destination_trace()
	elif _stage == Stage.TAKE_BOOTS:
		_update_boots_objective_trace()
	elif _stage == Stage.FIGHT_DRAGON and not GameState.has_item("Bow"):
		_update_bow_objective_trace()
	elif _stage == Stage.USE_GATE:
		_update_gate_objective_trace()
	elif _stage == Stage.TRIGGER_REWIND or _stage == Stage.REACH_ARENA or _stage == Stage.TAKE_KEYCARD:
		_update_keycard_objective_trace()
	else:
		_clear_hint_marker()
	if GameState.is_time_blocked():
		return
	_time += delta
	var slices: int = maxi(1, floating_update_slices)
	for i in range(_floating_update_bucket, _floating_nodes.size(), slices):
		var node3d: Node3D = _floating_nodes[i]
		if node3d == null or not is_instance_valid(node3d):
			continue
		var base_position: Vector3 = _base_positions.get(node3d, node3d.position)
		var phase: float = float(_phase_map.get(node3d, 0.0))
		node3d.position = base_position + Vector3(0.0, sin(_time * bob_speed + phase) * bob_height, 0.0)
		node3d.rotate_y(delta * spin_speed)
	_floating_update_bucket = (_floating_update_bucket + 1) % slices

func _physics_process(delta: float) -> void:
	if _dragon_riding and not _dragon_flight_cinematic_running:
		_update_dragon_ride(delta)

func _collect_dragon_arch_markers() -> void:
	_dragon_arch_markers.clear()
	if _dragon_arch_markers_root == null or not is_instance_valid(_dragon_arch_markers_root):
		return
	for child in _dragon_arch_markers_root.get_children():
		var marker: Node3D = child as Node3D
		if marker == null:
			continue
		_dragon_arch_markers.append(marker)

func _stabilize_dragon_keycard() -> void:
	if _dragon_keycard == null or not is_instance_valid(_dragon_keycard):
		return
	if GameState.has_item("key_3"):
		return
	if _dragon_keycard_spawn_transform == Transform3D.IDENTITY:
		return
	_dragon_keycard.global_transform = _dragon_keycard_spawn_transform

func _collect_floaters() -> void:
	_floating_nodes.clear()
	_base_positions.clear()
	_phase_map.clear()
	if _bridge_root != null:
		for child in _bridge_root.get_children():
			_register_floater(child as Node3D)
	var group_nodes: Array[Node] = get_tree().get_nodes_in_group("surreal_float")
	for entry in group_nodes:
		_register_floater(entry as Node3D)

func _register_floater(node3d: Node3D) -> void:
	if node3d == null:
		return
	if _floating_nodes.has(node3d):
		return
	_floating_nodes.append(node3d)
	_base_positions[node3d] = node3d.position
	_phase_map[node3d] = randf_range(0.0, TAU)

func _spawn_surreal_field() -> void:
	if _surreal_shapes_root == null:
		return
	for i in range(extra_float_mesh_count):
		var mesh_node := MeshInstance3D.new()
		mesh_node.mesh = _make_random_mesh()
		mesh_node.material_override = _make_random_mesh_material()
		mesh_node.global_position = _random_surreal_position()
		mesh_node.rotation = Vector3(_rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI))
		var uniform_scale: float = _rng.randf_range(0.7, 2.8)
		mesh_node.scale = Vector3.ONE * uniform_scale
		mesh_node.add_to_group("surreal_float")
		_surreal_shapes_root.add_child(mesh_node)
		_ensure_collision_for_random_node(mesh_node)
	for i in range(extra_float_prop_count):
		var prop: Node3D = _instantiate_random_prop()
		if prop == null:
			continue
		prop.global_position = _random_surreal_position()
		prop.rotation = Vector3(_rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI))
		var prop_scale: float = _rng.randf_range(0.22, 1.08)
		prop.scale = Vector3.ONE * prop_scale
		_deactivate_runtime_nodes_recursive(prop)
		prop.add_to_group("surreal_float")
		_surreal_shapes_root.add_child(prop)
		_ensure_collision_for_random_node(prop)

func _ensure_random_objects_have_collision() -> void:
	var random_nodes: Array[Node] = get_tree().get_nodes_in_group("surreal_float")
	for entry in random_nodes:
		var node3d: Node3D = entry as Node3D
		if node3d == null:
			continue
		_ensure_collision_for_random_node(node3d)

func _ensure_collision_for_random_node(node3d: Node3D) -> void:
	if node3d == null or not is_instance_valid(node3d):
		return
	if _has_enabled_collision_shape(node3d):
		return
	var bounds: AABB = _compute_visual_bounds_local(node3d)
	if bounds.size.length_squared() <= 0.0001:
		return
	var collision_proxy := StaticBody3D.new()
	collision_proxy.name = "CollisionProxy"
	collision_proxy.collision_layer = 1
	collision_proxy.collision_mask = 1
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(bounds.size.x, 0.25),
		maxf(bounds.size.y, 0.25),
		maxf(bounds.size.z, 0.25)
	)
	collision_shape.shape = shape
	collision_shape.position = bounds.position + bounds.size * 0.5
	collision_proxy.add_child(collision_shape)
	node3d.add_child(collision_proxy)

func _has_enabled_collision_shape(node: Node) -> bool:
	if node is CollisionShape3D:
		var shape: CollisionShape3D = node as CollisionShape3D
		return shape.shape != null and not shape.disabled
	for child in node.get_children():
		if _has_enabled_collision_shape(child):
			return true
	return false

func _compute_visual_bounds_local(root: Node3D) -> AABB:
	var has_bounds: bool = false
	var min_v: Vector3 = Vector3.ZERO
	var max_v: Vector3 = Vector3.ZERO
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is VisualInstance3D):
			continue
		if not node.has_method("get_aabb"):
			continue
		var maybe_aabb: Variant = node.call("get_aabb")
		if typeof(maybe_aabb) != TYPE_AABB:
			continue
		var local_aabb: AABB = maybe_aabb
		if local_aabb.size.length_squared() <= 0.000001:
			continue
		var visual: Node3D = node as Node3D
		if visual == null:
			continue
		for ix in range(2):
			for iy in range(2):
				for iz in range(2):
					var corner := local_aabb.position + Vector3(
						local_aabb.size.x * float(ix),
						local_aabb.size.y * float(iy),
						local_aabb.size.z * float(iz)
					)
					var world_corner: Vector3 = visual.to_global(corner)
					var root_local_corner: Vector3 = root.to_local(world_corner)
					if not has_bounds:
						min_v = root_local_corner
						max_v = root_local_corner
						has_bounds = true
					else:
						min_v = min_v.min(root_local_corner)
						max_v = max_v.max(root_local_corner)
	if not has_bounds:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return AABB(min_v, max_v - min_v)

func _make_random_mesh() -> Mesh:
	var pick: int = _rng.randi_range(0, 4)
	if pick == 0:
		var sphere := SphereMesh.new()
		sphere.radius = _rng.randf_range(0.8, 3.6)
		sphere.height = sphere.radius * 2.0
		return sphere
	if pick == 1:
		var torus := TorusMesh.new()
		torus.inner_radius = _rng.randf_range(0.35, 1.5)
		torus.outer_radius = torus.inner_radius + _rng.randf_range(0.45, 2.2)
		torus.rings = 28
		torus.ring_segments = 22
		return torus
	if pick == 2:
		var prism := PrismMesh.new()
		prism.size = Vector3(_rng.randf_range(1.0, 4.5), _rng.randf_range(1.4, 6.4), _rng.randf_range(1.0, 4.5))
		return prism
	if pick == 3:
		var box := BoxMesh.new()
		box.size = Vector3(_rng.randf_range(0.9, 5.0), _rng.randf_range(0.9, 5.0), _rng.randf_range(0.9, 5.0))
		return box
	var capsule := CapsuleMesh.new()
	capsule.radius = _rng.randf_range(0.45, 1.9)
	capsule.height = _rng.randf_range(1.4, 5.8)
	return capsule

func _make_random_mesh_material() -> StandardMaterial3D:
	var palette: Array[Color] = [
		Color(0.82, 0.22, 0.18, 1.0),
		Color(0.12, 0.24, 0.72, 1.0),
		Color(0.2, 0.68, 0.32, 1.0),
		Color(0.92, 0.82, 0.18, 1.0),
		Color(0.95, 0.95, 0.95, 1.0),
		Color(0.76, 0.4, 0.16, 1.0)
	]
	var material := StandardMaterial3D.new()
	material.albedo_color = palette[_rng.randi_range(0, palette.size() - 1)]
	material.roughness = _rng.randf_range(0.3, 0.82)
	material.metallic = _rng.randf_range(0.02, 0.22)
	return material

func _random_surreal_position() -> Vector3:
	var attempts: int = 0
	while attempts < 28:
		var candidate: Vector3 = surreal_field_center + Vector3(
			_rng.randf_range(-surreal_field_extent.x, surreal_field_extent.x),
			_rng.randf_range(-surreal_field_extent.y, surreal_field_extent.y),
			_rng.randf_range(-surreal_field_extent.z, surreal_field_extent.z)
		)
		if _spawn_platform == null or not is_instance_valid(_spawn_platform):
			return candidate
		if candidate.distance_to(_spawn_platform.global_position) >= surreal_spawn_safe_radius:
			return candidate
		attempts += 1
	return surreal_field_center + Vector3(0.0, maxf(3.0, surreal_spawn_safe_radius * 0.35), 0.0)

func _instantiate_random_prop() -> Node3D:
	var pick: int = _rng.randi_range(0, 9)
	if pick == 0:
		return _make_car_prop()
	if pick == 1 and BROKEN_HOUSE_SCENE != null:
		return BROKEN_HOUSE_SCENE.instantiate() as Node3D
	if pick == 2 and HOUSE_SCENE != null:
		return HOUSE_SCENE.instantiate() as Node3D
	if pick == 3 and DRAGON_PROP_SCENE != null:
		return DRAGON_PROP_SCENE.instantiate() as Node3D
	if pick == 4 and DRAGON_ALT_PROP_SCENE != null:
		return DRAGON_ALT_PROP_SCENE.instantiate() as Node3D
	if pick == 5 and ENEMY_SCENE != null:
		return ENEMY_SCENE.instantiate() as Node3D
	if pick == 6 and ELECTRIC_ORB_SCENE != null:
		return ELECTRIC_ORB_SCENE.instantiate() as Node3D
	if pick == 7 and ROSE_SCENE != null:
		return ROSE_SCENE.instantiate() as Node3D
	if pick == 8 and HAZMAT_SCENE != null:
		return HAZMAT_SCENE.instantiate() as Node3D
	if pick == 9 and SHOVEL_SCENE != null:
		return SHOVEL_SCENE.instantiate() as Node3D
	return _make_car_prop()

func _make_car_prop() -> Node3D:
	var car_root := Node3D.new()
	car_root.name = "DreamCar"
	var body_colors: Array[Color] = [
		Color(0.78, 0.14, 0.12, 1.0),
		Color(0.92, 0.92, 0.9, 1.0),
		Color(0.1, 0.16, 0.38, 1.0),
		Color(0.84, 0.56, 0.12, 1.0)
	]
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_colors[_rng.randi_range(0, body_colors.size() - 1)]
	body_mat.roughness = 0.48
	body_mat.metallic = 0.1
	var cabin_mat := StandardMaterial3D.new()
	cabin_mat.albedo_color = Color(0.75, 0.86, 0.96, 1.0)
	cabin_mat.roughness = 0.22
	cabin_mat.metallic = 0.02
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.1, 0.1, 0.1, 1.0)
	wheel_mat.roughness = 0.96
	var body := CSGBox3D.new()
	body.size = Vector3(3.6, 0.9, 1.9)
	body.material = body_mat
	car_root.add_child(body)
	var cabin := CSGBox3D.new()
	cabin.position = Vector3(0.2, 0.72, 0.0)
	cabin.size = Vector3(1.85, 0.75, 1.65)
	cabin.material = cabin_mat
	car_root.add_child(cabin)
	var wheel_offsets: Array[Vector3] = [
		Vector3(-1.2, -0.62, 0.84),
		Vector3(1.2, -0.62, 0.84),
		Vector3(-1.2, -0.62, -0.84),
		Vector3(1.2, -0.62, -0.84)
	]
	for offset in wheel_offsets:
		var wheel := CSGCylinder3D.new()
		wheel.position = offset
		wheel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		wheel.radius = 0.4
		wheel.height = 0.33
		wheel.material = wheel_mat
		car_root.add_child(wheel)
	return car_root

func _disable_collisions_recursive(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is Area3D:
		var area := node as Area3D
		area.monitoring = false
		area.monitorable = false
	elif node is PhysicsBody3D:
		var body := node as PhysicsBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	for child in node.get_children():
		_disable_collisions_recursive(child)

func _deactivate_runtime_nodes_recursive(node: Node) -> void:
	if node == null:
		return
	if node is RigidBody3D:
		(node as RigidBody3D).freeze = true
	if node is CharacterBody3D:
		(node as CharacterBody3D).velocity = Vector3.ZERO
	if node is AnimationPlayer:
		(node as AnimationPlayer).active = false
	if node is GPUParticles3D:
		(node as GPUParticles3D).emitting = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_deactivate_runtime_nodes_recursive(child)

func _setup_anomaly_encounter() -> void:
	_anomaly_enemies.clear()
	if _anomaly_enemies_root != null:
		for child in _anomaly_enemies_root.get_children():
			var enemy_node: Node3D = child as Node3D
			if enemy_node == null:
				continue
			_anomaly_enemies.append(enemy_node)
			if enemy_node.has_method("reset_enemy_state"):
				enemy_node.call("reset_enemy_state")
			if enemy_node.has_method("set_encounter_enabled"):
				enemy_node.call("set_encounter_enabled", false)
			else:
				enemy_node.visible = false
	if _anomaly_trigger != null:
		var entered: Callable = Callable(self, "_on_anomaly_trigger_body_entered")
		if not _anomaly_trigger.is_connected("body_entered", entered):
			_anomaly_trigger.body_entered.connect(entered)
		_anomaly_trigger.monitoring = true
		_anomaly_trigger.monitorable = true

func _disable_anomaly_encounter() -> void:
	_anomaly_encounter_started = true
	_anomaly_enemies.clear()
	if _anomaly_trigger != null and is_instance_valid(_anomaly_trigger):
		_anomaly_trigger.monitoring = false
		_anomaly_trigger.monitorable = false
	if _anomaly_enemies_root != null and is_instance_valid(_anomaly_enemies_root):
		for child in _anomaly_enemies_root.get_children():
			var enemy_node: Node3D = child as Node3D
			if enemy_node == null:
				continue
			if enemy_node.has_method("set_encounter_enabled"):
				enemy_node.call("set_encounter_enabled", false)
			enemy_node.visible = false
	if _anomaly_encounter_root != null and is_instance_valid(_anomaly_encounter_root):
		_anomaly_encounter_root.queue_free()

func _on_anomaly_trigger_body_entered(body: Node) -> void:
	if _anomaly_encounter_started:
		return
	if body == null or not body.is_in_group("player"):
		return
	_anomaly_encounter_started = true
	if _anomaly_trigger != null:
		_anomaly_trigger.monitoring = false
	_activate_anomaly_enemies()

func _activate_anomaly_enemies() -> void:
	for enemy_node in _anomaly_enemies:
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if enemy_node.has_method("reset_enemy_state"):
			enemy_node.call("reset_enemy_state")
		if enemy_node.has_method("set_encounter_enabled"):
			enemy_node.call("set_encounter_enabled", true)
		else:
			enemy_node.visible = true

func _setup_dragon_arena_encounter() -> void:
	if _dragon_arena_trigger == null:
		return
	var entered: Callable = Callable(self, "_on_dragon_arena_body_entered")
	if not _dragon_arena_trigger.is_connected("body_entered", entered):
		_dragon_arena_trigger.body_entered.connect(entered)
	_dragon_arena_trigger.monitoring = true
	_dragon_arena_trigger.monitorable = true

func _align_dragon_arena_trigger_to_center() -> void:
	if _dragon_arena_trigger == null:
		return
	var center: Vector3 = _dragon_arena_position
	if _dragon_keycard != null and is_instance_valid(_dragon_keycard):
		center = _dragon_keycard.global_position
	if center == Vector3.ZERO:
		return
	_dragon_arena_trigger.global_position = Vector3(center.x, center.y + 0.9, center.z)

func _setup_dragon_ride_release_trigger() -> void:
	if _dragon_ride_release_area == null:
		return
	var entered: Callable = Callable(self, "_on_dragon_ride_release_area_body_entered")
	if not _dragon_ride_release_area.is_connected("body_entered", entered):
		_dragon_ride_release_area.body_entered.connect(entered)
	_dragon_ride_release_area.monitoring = true
	_dragon_ride_release_area.monitorable = true

func _setup_fall_death_zone() -> void:
	if _fall_death_zone == null:
		return
	var entered: Callable = Callable(self, "_on_fall_death_zone_body_entered")
	if not _fall_death_zone.is_connected("body_entered", entered):
		_fall_death_zone.body_entered.connect(entered)
	_fall_death_zone.monitoring = true
	_fall_death_zone.monitorable = true

func _on_fall_death_zone_body_entered(body: Node) -> void:
	if body == null or _player == null:
		return
	if body != _player and not body.is_in_group("player"):
		return
	if _player.has_method("take_damage"):
		_player.call("take_damage", 9999.0)

func _update_boots_objective_trace() -> void:
	if _world == null or _boots == null or not is_instance_valid(_boots):
		return
	if _boots.has_method("set_highlight_enabled"):
		_boots.call("set_highlight_enabled", true)
	if _boots.has_method("set_highlight_strength"):
		var pulse: float = 0.55 + (sin(_time * 1.35) * 0.5 + 0.5) * 0.7
		_boots.call("set_highlight_strength", pulse)
	if _world.has_method("_update_hint_marker"):
		var target_pos: Vector3 = _boots.global_position
		var marker_pos: Vector3 = target_pos + Vector3(0.0, 1.1, 0.0)
		if _boots_trace_marker != null:
			marker_pos = _boots_trace_marker.global_position
		_world.call("_update_hint_marker", marker_pos, "BOOTS", target_pos)

func _clear_hint_marker() -> void:
	if _world == null:
		return
	var marker_variant: Variant = _world.get("_hint_marker")
	if marker_variant is CanvasItem:
		(marker_variant as CanvasItem).visible = false
	var label_variant: Variant = _world.get("_hint_label")
	if label_variant is Label:
		(label_variant as Label).visible = false

func _set_dragon_keycard_pickup_enabled(enabled: bool) -> void:
	if _dragon_keycard == null:
		return
	_dragon_keycard.visible = true
	var shape: CollisionShape3D = _dragon_keycard.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.disabled = not enabled
	_dragon_keycard.set("prompt_text", "Press E to pick up Keycard" if enabled else "")
	if _dragon_keycard.has_method("set_highlight_enabled"):
		_dragon_keycard.call("set_highlight_enabled", enabled)
	if enabled and _dragon_keycard.has_method("set_highlight_strength"):
		_dragon_keycard.call("set_highlight_strength", 1.0)

func _update_keycard_objective_trace() -> void:
	if _world == null:
		return
	if _dragon_keycard != null and is_instance_valid(_dragon_keycard):
		if _dragon_keycard.has_method("set_highlight_enabled"):
			_dragon_keycard.call("set_highlight_enabled", true)
		if _dragon_keycard.has_method("set_highlight_strength"):
			var pulse: float = 0.6 + (sin(_time * 1.2) * 0.5 + 0.5) * 0.6
			_dragon_keycard.call("set_highlight_strength", pulse)
		if _world.has_method("_update_hint_marker"):
			var target_pos: Vector3 = _dragon_keycard.global_position
			_world.call("_update_hint_marker", target_pos + Vector3(0.0, 1.0, 0.0), "KEYCARD", target_pos)
		return
	if _dragon_arena_trigger != null and is_instance_valid(_dragon_arena_trigger) and _world.has_method("_update_hint_marker"):
		var arena_pos: Vector3 = _dragon_arena_trigger.global_position
		_world.call("_update_hint_marker", arena_pos + Vector3(0.0, 1.0, 0.0), "ARENA", arena_pos)

func _update_bow_objective_trace() -> void:
	if _world == null or _bow_pickup == null or not is_instance_valid(_bow_pickup):
		return
	if _bow_pickup.has_method("set_highlight_enabled"):
		_bow_pickup.call("set_highlight_enabled", true)
	if _bow_pickup.has_method("set_highlight_strength"):
		var pulse: float = 0.62 + (sin(_time * 1.45) * 0.5 + 0.5) * 0.62
		_bow_pickup.call("set_highlight_strength", pulse)
	if _world.has_method("_update_hint_marker"):
		var target_pos: Vector3 = _bow_pickup.global_position
		_world.call("_update_hint_marker", target_pos + Vector3(0.0, 1.2, 0.0), "BOW", target_pos)

func _update_gate_objective_trace() -> void:
	if _world == null or _level_gate == null or not is_instance_valid(_level_gate):
		return
	if _level_gate.has_method("set_highlight_enabled"):
		_level_gate.call("set_highlight_enabled", true)
	if _level_gate.has_method("set_highlight_strength"):
		var pulse: float = 0.64 + (sin(_time * 1.18) * 0.5 + 0.5) * 0.72
		_level_gate.call("set_highlight_strength", pulse)
	if _world.has_method("_update_hint_marker"):
		var target_pos: Vector3 = _level_gate.global_position
		_world.call("_update_hint_marker", target_pos + Vector3(0.0, 1.45, 0.0), "PORTAL BOX", target_pos)

func _update_portal_destination_trace() -> void:
	if _world == null or _level_gate == null or not is_instance_valid(_level_gate):
		return
	if _world.has_method("_update_hint_marker"):
		var target_pos: Vector3 = _level_gate.global_position
		_world.call("_update_hint_marker", target_pos + Vector3(0.0, 1.55, 0.0), "PORTAL", target_pos)

func _set_bow_pickup_enabled(enabled: bool) -> void:
	if _bow_pickup == null or not is_instance_valid(_bow_pickup):
		return
	if _bow_pickup.has_method("set_interactable_enabled"):
		_bow_pickup.call("set_interactable_enabled", enabled)
		return
	_bow_pickup.visible = enabled
	var shape: CollisionShape3D = _bow_pickup.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.disabled = not enabled

func _on_dragon_arena_body_entered(body: Node) -> void:
	if _dragon_intro_played or _dragon_fight_running:
		return
	if _stage != Stage.REACH_ARENA:
		return
	if body == null or not body.is_in_group("player"):
		return
	_dragon_intro_played = true
	_dragon_fight_running = true
	call_deferred("_play_dragon_arena_cinematic")

func _play_dragon_arena_cinematic() -> void:
	if _player == null or _dragon_guard == null:
		_dragon_fight_running = false
		return
	if GameState.rewind_mode_active:
		GameState.cancel_rewind_mode()
	_player.set_cinematic_lock(true)
	_player.set_mobility_lock(true)
	_player.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var player_camera: Camera3D = _get_player_camera()
	if player_camera != null:
		player_camera.make_current()
	if _dragon_guard.has_method("reset_dragon_state"):
		_dragon_guard.call("reset_dragon_state")
	if _dragon_guard.has_method("set_combat_enabled"):
		_dragon_guard.call("set_combat_enabled", false)
	else:
		_dragon_guard.visible = false
	if _dragon_spawn_marker != null:
		_dragon_guard.global_position = _dragon_spawn_marker.global_position
		_dragon_guard.global_rotation = _dragon_spawn_marker.global_rotation
		_dragon_guard.visible = false
		await _focus_player_camera_to_position(_dragon_spawn_marker.global_position + Vector3(0.0, 1.8, 0.0), 0.3)
		await get_tree().create_timer(0.35).timeout
	await _play_dragon_glitch_summon()
	await _play_dragon_intro_roar()
	if _dragon_guard.has_method("set_combat_enabled"):
		_dragon_guard.call("set_combat_enabled", true)
	if _world != null and _world.get("player_hud") != null:
		var hud_variant: Variant = _world.get("player_hud")
		if hud_variant is CanvasLayer and (hud_variant as CanvasLayer).has_method("show_boss_bar"):
			(hud_variant as CanvasLayer).call("show_boss_bar", "DRAGON", 1.0)
	_stage = Stage.FIGHT_DRAGON
	_set_bow_pickup_enabled(true)
	_show_objective("Defeat the dragon")
	_show_subtitle("Pick up the Bow first. Bow deals heavy damage.", 2.3)
	if player_camera != null:
		player_camera.make_current()
	_player.visible = true
	_player.set_cinematic_lock(false)
	_player.set_mobility_lock(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_dragon_fight_running = false

func _play_dragon_glitch_summon() -> void:
	if _dragon_guard == null:
		return
	_dragon_guard.visible = true
	if _world != null:
		var overlay_variant: Variant = _world.get("_glitch_overlay")
		if overlay_variant is CanvasItem:
			var overlay: CanvasItem = overlay_variant as CanvasItem
			overlay.visible = true
			overlay.modulate.a = 0.0
		if _world.has_method("_set_arrival_glitch_strength"):
			_world.call("_set_arrival_glitch_strength", 1.0)
	var summon: Tween = create_tween().set_parallel(true)
	if _world != null:
		var overlay_variant: Variant = _world.get("_glitch_overlay")
		if overlay_variant is CanvasItem:
			summon.tween_property(overlay_variant as CanvasItem, "modulate:a", 0.78, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await summon.finished
	var settle: Tween = create_tween()
	if _world != null:
		var overlay_variant: Variant = _world.get("_glitch_overlay")
		if overlay_variant is CanvasItem:
			settle.tween_property(overlay_variant as CanvasItem, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if _world.has_method("_set_arrival_glitch_strength"):
			settle.parallel().tween_method(Callable(_world, "_set_arrival_glitch_strength"), 1.0, 0.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await settle.finished
	if _world != null:
		var overlay_variant: Variant = _world.get("_glitch_overlay")
		if overlay_variant is CanvasItem:
			(overlay_variant as CanvasItem).visible = false
		if _world.has_method("_set_arrival_glitch_strength"):
			_world.call("_set_arrival_glitch_strength", 0.0)

func _play_dragon_intro_flight_path() -> void:
	if _dragon_guard == null:
		return
	if _dragon_guard.has_method("play_fly_animation"):
		_dragon_guard.call("play_fly_animation")
	var points: Array[Vector3] = []
	if _dragon_intro_orbit_a != null:
		points.append(_dragon_intro_orbit_a.global_position)
	if _dragon_intro_orbit_b != null:
		points.append(_dragon_intro_orbit_b.global_position)
	if _dragon_intro_orbit_c != null:
		points.append(_dragon_intro_orbit_c.global_position)
	var landing: Vector3 = _dragon_arena_position
	if _dragon_intro_landing_marker != null:
		landing = _dragon_intro_landing_marker.global_position
	elif _dragon_keycard != null and is_instance_valid(_dragon_keycard):
		landing = _dragon_keycard.global_position + Vector3(0.0, 0.8, 0.0)
	if points.is_empty():
		var spawn_pos: Vector3 = _dragon_guard.global_position
		points.append(spawn_pos + Vector3(-6.0, 2.4, -4.0))
		points.append(spawn_pos + Vector3(5.5, 3.0, -1.8))
		points.append(spawn_pos + Vector3(2.2, 1.9, 5.8))
	await _fly_dragon_segment(points[0], 0.95)
	await _fly_dragon_segment(points[1], 1.05)
	await _fly_dragon_segment(points[2], 1.0)
	await _fly_dragon_segment(landing, 1.15)
	if _dragon_guard.has_method("play_idle_animation"):
		_dragon_guard.call("play_idle_animation")
	_face_dragon_to_player()

func _focus_cinematic_camera_to_spawn() -> void:
	if _dragon_spawn_marker == null:
		return
	var target: Vector3 = _dragon_spawn_marker.global_position + Vector3(0.0, 1.8, 0.0)
	_set_player_look_at(target)

func _play_dragon_intro_roar() -> void:
	if _dragon_guard == null:
		return
	_focus_cinematic_camera_on_dragon()
	if _dragon_guard.has_method("play_roar_animation"):
		_dragon_guard.call("play_roar_animation")
	await get_tree().create_timer(1.5).timeout
	if _dragon_guard.has_method("play_idle_animation"):
		_dragon_guard.call("play_idle_animation")
	_face_dragon_to_player()

func _fly_dragon_segment(target_position: Vector3, duration: float) -> void:
	if _dragon_guard == null:
		return
	var start: Vector3 = _dragon_guard.global_position
	var elapsed: float = 0.0
	var total: float = maxf(0.05, duration)
	while elapsed < total:
		var delta: float = get_process_delta_time()
		elapsed += delta
		var t: float = clampf(elapsed / total, 0.0, 1.0)
		var eased: float = 0.5 - cos(t * PI) * 0.5
		var arc: float = sin(t * PI) * 1.05
		var next_pos: Vector3 = start.lerp(target_position, eased)
		next_pos.y += arc
		_set_dragon_fly_toward(next_pos)
		_focus_cinematic_camera_on_dragon()
		await get_tree().process_frame
	_set_dragon_fly_toward(target_position)
	_focus_cinematic_camera_on_dragon()

func _set_dragon_fly_toward(next_pos: Vector3) -> void:
	if _dragon_guard == null:
		return
	var previous: Vector3 = _dragon_guard.global_position
	_dragon_guard.global_position = next_pos
	var forward: Vector3 = next_pos - previous
	if forward.length_squared() > 0.0001:
		var look_target: Vector3 = next_pos + forward.normalized()
		look_target.y = next_pos.y
		if _dragon_guard.has_method("face_toward"):
			_dragon_guard.call("face_toward", look_target)
		else:
			_dragon_guard.look_at(look_target, Vector3.UP)

func _focus_cinematic_camera_on_dragon() -> void:
	if _dragon_guard == null:
		return
	var target: Vector3 = _dragon_guard.global_position + Vector3(0.0, 1.8, 0.0)
	_set_player_look_at(target)

func _get_player_camera() -> Camera3D:
	if _player == null:
		return null
	return _player.get_node_or_null("root/Skeleton3D/BoneAttachment3D/Head/Camera3D") as Camera3D

func _focus_player_camera_to_position(target: Vector3, duration: float) -> void:
	if _player == null:
		return
	var start_yaw: float = _player.rotation.y
	var start_pitch: float = float(_player.get("camera_x_rotation"))
	var yaw_pitch: Vector2 = _compute_player_look_angles(target)
	var end_yaw: float = yaw_pitch.x
	var end_pitch: float = yaw_pitch.y
	var start_position: Vector3 = _player.global_position
	var total: float = maxf(0.01, duration)
	var elapsed: float = 0.0
	while elapsed < total:
		var delta: float = get_process_delta_time()
		elapsed += delta
		var t: float = clampf(elapsed / total, 0.0, 1.0)
		var eased: float = 0.5 - cos(t * PI) * 0.5
		var yaw_value: float = lerp_angle(start_yaw, end_yaw, eased)
		var pitch_value: float = lerpf(start_pitch, end_pitch, eased)
		_player.call("set_cinematic_pose", start_position, yaw_value, pitch_value)
		await get_tree().process_frame

func _set_player_look_at(target: Vector3) -> void:
	if _player == null:
		return
	var look: Vector2 = _compute_player_look_angles(target)
	_player.call("set_cinematic_pose", _player.global_position, look.x, look.y)

func _compute_player_look_angles(target: Vector3) -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var origin: Vector3 = _player.global_position + Vector3(0.0, 1.55, 0.0)
	var to_target: Vector3 = target - origin
	if to_target.length_squared() <= 0.0001:
		return Vector2(_player.rotation.y, float(_player.get("camera_x_rotation")))
	var yaw: float = atan2(-to_target.x, -to_target.z)
	var horizontal: float = sqrt(to_target.x * to_target.x + to_target.z * to_target.z)
	var pitch_world: float = rad_to_deg(atan2(to_target.y, maxf(0.0001, horizontal)))
	var camera_pitch: float = -pitch_world
	return Vector2(yaw, clampf(camera_pitch, -89.0, 89.0))

func _face_dragon_to_player() -> void:
	if _dragon_guard == null or _player == null:
		return
	var target: Vector3 = _player.global_position
	target.y = _dragon_guard.global_position.y
	if _dragon_guard.has_method("face_toward"):
		_dragon_guard.call("face_toward", target)
	else:
		_dragon_guard.look_at(target, Vector3.UP)

func _on_dragon_ride_release_area_body_entered(body: Node) -> void:
	if not _dragon_riding:
		return
	if body == null or not body.is_in_group("player"):
		return
	if _stage == Stage.USE_GATE or _stage == Stage.DONE:
		return
	_dragon_flight_cinematic_running = false
	_release_dragon_ride()
	if not _dragon_escape_running:
		_dragon_escape_running = true
		call_deferred("_fly_dragon_away")

func _update_dragon_ride(delta: float) -> void:
	if _dragon_guard == null or _player == null:
		return
	var grounded_hit: Dictionary = _get_dragon_ground_hit()
	var grounded: bool = not grounded_hit.is_empty()
	var space_pressed: bool = Input.is_key_pressed(KEY_SPACE)
	var space_just_pressed: bool = space_pressed and not _dragon_space_prev
	_dragon_space_prev = space_pressed
	if space_just_pressed and grounded:
		_dragon_flight_active = true
		_dragon_ride_ready = true
		_dragon_ride_velocity.y = maxf(_dragon_ride_velocity.y, dragon_takeoff_impulse * 1.9)
	elif space_just_pressed and _dragon_flight_active and _dragon_ride_ready:
		_dragon_ride_velocity.y = maxf(_dragon_ride_velocity.y, dragon_takeoff_impulse)
	if grounded and _dragon_flight_active and _dragon_ride_velocity.y <= 0.0:
		_dragon_flight_active = false
		_dragon_ride_ready = false
		_dragon_ride_velocity.y = 0.0
		if grounded_hit.has("position"):
			var hit_pos: Vector3 = grounded_hit.get("position", _dragon_guard.global_position)
			_dragon_guard.global_position.y = hit_pos.y + dragon_ground_clearance
	var move_forward_pressed: bool = Input.is_key_pressed(KEY_W)
	var sprint_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
	var cursor_offset: Vector2 = _get_dragon_cursor_offset()
	var planar_direction: Vector3 = _get_dragon_cursor_direction(cursor_offset)
	if planar_direction.length_squared() <= 0.0001:
		var basis: Basis = _dragon_guard.global_transform.basis
		var forward: Vector3 = -basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.0001:
			planar_direction = forward.normalized()
		else:
			planar_direction = _dragon_ride_look_direction
	var planar_target_velocity: Vector3 = Vector3.ZERO
	if move_forward_pressed:
		var speed_scale: float = dragon_ride_boost_multiplier if sprint_pressed else 1.0
		planar_target_velocity = planar_direction * (dragon_ride_speed * speed_scale)
		if planar_direction.length_squared() > 0.0001:
			_dragon_ride_look_direction = planar_direction
	var target_vertical_velocity: float = 0.0
	if _dragon_flight_active:
		target_vertical_velocity = -dragon_idle_descent_speed
		if space_pressed:
			target_vertical_velocity = dragon_ride_vertical_speed
	if not _dragon_flight_active or not _dragon_ride_ready:
		planar_target_velocity = Vector3.ZERO
		target_vertical_velocity = 0.0
	var target_velocity: Vector3 = Vector3(planar_target_velocity.x, target_vertical_velocity, planar_target_velocity.z)
	_dragon_ride_velocity = _dragon_ride_velocity.lerp(target_velocity, clampf(dragon_ride_accel * delta, 0.0, 1.0))
	_dragon_guard.global_position += _dragon_ride_velocity * delta
	if planar_direction.length_squared() > 0.0001:
		var target_yaw: float = atan2(-planar_direction.x, -planar_direction.z)
		var turn_alpha: float = clampf(dragon_ride_turn_speed * delta, 0.0, 1.0)
		_dragon_guard.rotation.y = lerp_angle(_dragon_guard.rotation.y, target_yaw, turn_alpha)
	_update_dragon_ride_camera_anchor(delta)
	_sync_player_to_dragon_mount()

func _get_dragon_cursor_offset() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return Vector2.ZERO
	var center: Vector2 = viewport_size * 0.5
	var mouse_position: Vector2 = viewport.get_mouse_position()
	var offset: Vector2 = Vector2(
		(mouse_position.x - center.x) / maxf(1.0, center.x),
		(mouse_position.y - center.y) / maxf(1.0, center.y)
	)
	if offset.length_squared() > 1.0:
		offset = offset.normalized()
	if offset.length() < maxf(0.0, dragon_cursor_deadzone):
		return Vector2.ZERO
	return offset

func _get_dragon_cursor_direction(cursor_offset: Vector2 = Vector2.ZERO) -> Vector3:
	if _dragon_guard == null:
		return Vector3.ZERO
	var basis: Basis = _dragon_guard.global_transform.basis
	var forward: Vector3 = -basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = _dragon_ride_look_direction
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	if cursor_offset == Vector2.ZERO:
		cursor_offset = _get_dragon_cursor_offset()
	if cursor_offset == Vector2.ZERO:
		return forward
	var right: Vector3 = basis.x
	right.y = 0.0
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var steer_x: float = clampf(cursor_offset.x * dragon_cursor_horizontal_steer, -1.6, 1.6)
	var direction: Vector3 = (forward + right * steer_x).normalized()
	if direction.length_squared() <= 0.0001:
		return forward
	return direction

func _update_dragon_ride_camera_anchor(delta: float) -> void:
	if _dragon_runtime_camera_anchor == null or not is_instance_valid(_dragon_runtime_camera_anchor):
		return
	if _dragon_guard == null:
		return
	var desired_position: Vector3 = _dragon_guard.global_position + Vector3(0.0, 3.2, 0.0)
	if _dragon_camera_socket != null and is_instance_valid(_dragon_camera_socket):
		desired_position = _dragon_camera_socket.global_position
	var pos_alpha: float = clampf(dragon_camera_anchor_position_smooth * delta, 0.0, 1.0)
	_dragon_runtime_camera_anchor.global_position = _dragon_runtime_camera_anchor.global_position.lerp(desired_position, pos_alpha)
	var look_direction: Vector3 = _dragon_ride_look_direction
	if look_direction.length_squared() <= 0.0001:
		look_direction = _get_dragon_cursor_direction()
	look_direction.y = 0.0
	if look_direction.length_squared() <= 0.0001:
		var fallback_forward: Vector3 = -_dragon_guard.global_transform.basis.z
		fallback_forward.y = 0.0
		look_direction = fallback_forward if fallback_forward.length_squared() > 0.0001 else Vector3.FORWARD
	look_direction = look_direction.normalized()
	var look_target: Vector3 = _dragon_runtime_camera_anchor.global_position + look_direction * maxf(4.0, dragon_camera_look_distance)
	var desired_basis: Basis = _dragon_runtime_camera_anchor.global_transform.looking_at(look_target, Vector3.UP).basis
	var rot_alpha: float = clampf(dragon_camera_anchor_rotation_smooth * delta, 0.0, 1.0)
	var smooth_basis: Basis = _dragon_runtime_camera_anchor.global_transform.basis.slerp(desired_basis, rot_alpha)
	_dragon_runtime_camera_anchor.global_transform = Transform3D(smooth_basis.orthonormalized(), _dragon_runtime_camera_anchor.global_position)

func _get_dragon_ground_hit() -> Dictionary:
	if _dragon_guard == null:
		return {}
	var start: Vector3 = _dragon_guard.global_position + Vector3(0.0, dragon_ground_probe_height, 0.0)
	var finish: Vector3 = _dragon_guard.global_position + Vector3(0.0, -dragon_ground_probe_depth, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, finish)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = []
	if _dragon_guard is CollisionObject3D:
		query.exclude.append((_dragon_guard as CollisionObject3D).get_rid())
	if _player is CollisionObject3D:
		query.exclude.append((_player as CollisionObject3D).get_rid())
	return get_world_3d().direct_space_state.intersect_ray(query)

func _sync_player_to_dragon_mount() -> void:
	if _player == null:
		return
	if _dragon_mount_socket != null:
		_player.global_position = _dragon_mount_socket.global_position
	else:
		_player.global_position = _dragon_guard.global_position + Vector3(0.0, 2.2, -0.3)
	_player.rotation.y = _dragon_guard.global_rotation.y

func _on_boots_collected(multiplier: float) -> void:
	_boots_unlocked = true
	_boots_jump_multiplier = maxf(1.0, multiplier)
	_apply_jump_boots_modifier_by_slot()
	if _stage != Stage.TAKE_BOOTS:
		return
	_stage = Stage.TRIGGER_REWIND
	_clear_hint_marker()
	_show_objective("Take the keycard in the arena")
	_show_subtitle("Activate rewind now to reopen the route to the arena.", 2.1)
	_set_bridge_enabled(false)
	_set_bridge_preview_visible(false)

func _on_rewind_mode_changed(active: bool) -> void:
	if not active:
		return
	if _stage != Stage.TRIGGER_REWIND:
		return
	_stage = Stage.REACH_ARENA
	_set_bridge_enabled(true)
	_show_objective("Take the keycard in the arena")
	_show_subtitle("The route is back. Head to the arena and secure the keycard.", 1.9)

func _on_dragon_defeated(_dragon: Node3D) -> void:
	if _world != null and _world.get("player_hud") != null:
		var hud_variant: Variant = _world.get("player_hud")
		if hud_variant is CanvasLayer and (hud_variant as CanvasLayer).has_method("hide_boss_bar"):
			(hud_variant as CanvasLayer).call("hide_boss_bar")
	if _stage != Stage.FIGHT_DRAGON:
		return
	_stage = Stage.TAKE_KEYCARD
	_set_dragon_keycard_pickup_enabled(true)
	_show_objective("Take the keycard")
	_show_subtitle("Dragon is down. Grab the keycard in the arena center.", 2.0)

func _on_dragon_health_changed(current: float, maximum: float) -> void:
	if _world == null:
		return
	var hud_variant: Variant = _world.get("player_hud")
	if not (hud_variant is CanvasLayer):
		return
	var hud: CanvasLayer = hud_variant as CanvasLayer
	if maximum <= 0.001:
		if hud.has_method("set_boss_bar_ratio"):
			hud.call("set_boss_bar_ratio", 0.0)
		return
	var ratio: float = clampf(current / maximum, 0.0, 1.0)
	if hud.has_method("set_boss_bar_ratio"):
		hud.call("set_boss_bar_ratio", ratio)

func _on_inventory_changed() -> void:
	_apply_jump_boots_modifier_by_slot()
	if _stage == Stage.TAKE_KEYCARD and GameState.has_item("key_3"):
		_stage = Stage.TAME_DRAGON
		if _dragon_guard != null and _dragon_guard.has_method("set_mount_enabled"):
			_dragon_guard.call("set_mount_enabled", true)
		_show_objective("Ride the dragon")
		return
	if _stage == Stage.USE_GATE and _level_gate != null and _level_gate.has_method("set_highlight_strength"):
		_level_gate.call("set_highlight_strength", 0.95)
		if _has_any_inventory_items():
			_show_objective("Drop all slot items, then enter portal ring")
		else:
			_show_objective("Enter the dark portal ring")

func _on_gate_portal_activated() -> void:
	if _stage != Stage.USE_GATE:
		return
	if _has_any_inventory_items():
		_show_objective("Drop all slot items, then enter portal ring")
		_show_subtitle("Portal is active. Drop all items from every slot first.", 2.2)
	else:
		_show_objective("Enter the dark portal ring")
		_show_subtitle("Portal is active. Step into the ring to transfer.", 1.9)

func _is_jump_boots_selected() -> bool:
	if GameState.selected_slot < 0 or GameState.selected_slot >= GameState.slots.size():
		return false
	return GameState.slots[GameState.selected_slot] == _boots_item_id

func _apply_jump_boots_modifier_by_slot() -> void:
	if _player == null:
		return
	var boots_active: bool = _boots_unlocked and _is_jump_boots_selected()
	if boots_active:
		_player.jump_power = _base_jump_power * _boots_jump_multiplier
		_player.set("speed", _base_move_speed * boots_forward_speed_multiplier)
		_player.set("sprint_speed", _base_sprint_speed * boots_forward_speed_multiplier)
		return
	_player.jump_power = _base_jump_power
	_player.set("speed", _base_move_speed)
	_player.set("sprint_speed", _base_sprint_speed)

func _on_dragon_mount_requested(_dragon: Node3D) -> void:
	if _stage != Stage.TAME_DRAGON:
		return
	if _ride_running or _dragon_riding:
		return
	_start_dragon_ride()

func _start_dragon_ride() -> void:
	if _player == null or _dragon_guard == null:
		return
	if GameState.rewind_mode_active:
		GameState.cancel_rewind_mode()
	_ride_running = true
	_dragon_riding = true
	_dragon_flight_cinematic_running = true
	_dragon_ride_velocity = Vector3.ZERO
	_dragon_flight_active = false
	_dragon_space_prev = false
	_dragon_ride_ready = false
	_dragon_ride_look_direction = _get_dragon_cursor_direction()
	if _dragon_ride_look_direction.length_squared() <= 0.0001:
		var start_forward: Vector3 = -_dragon_guard.global_transform.basis.z
		start_forward.y = 0.0
		_dragon_ride_look_direction = start_forward.normalized() if start_forward.length_squared() > 0.0001 else Vector3.FORWARD
	if _dragon_runtime_camera_anchor == null or not is_instance_valid(_dragon_runtime_camera_anchor):
		_dragon_runtime_camera_anchor = Node3D.new()
		_dragon_runtime_camera_anchor.name = "DragonRideCameraAnchor"
		add_child(_dragon_runtime_camera_anchor)
	var initial_anchor_position: Vector3 = _dragon_guard.global_position + Vector3(0.0, 3.2, 0.0)
	if _dragon_camera_socket != null and is_instance_valid(_dragon_camera_socket):
		initial_anchor_position = _dragon_camera_socket.global_position
	_dragon_runtime_camera_anchor.global_position = initial_anchor_position
	_update_dragon_ride_camera_anchor(1.0 / 60.0)
	_player.set_cinematic_lock(true)
	_player.set_mobility_lock(true)
	_player.visible = false
	if _player.has_method("set_look_input_locked"):
		_player.call("set_look_input_locked", true)
	if _player.has_method("set_item_usage_locked"):
		_player.call("set_item_usage_locked", true)
	if _player.has_method("set_mount_riding"):
		_player.call("set_mount_riding", true)
	if _player.has_method("set_external_camera_anchor"):
		_player.call("set_external_camera_anchor", _dragon_runtime_camera_anchor)
	_sync_player_to_dragon_mount()
	_show_objective("Dragon flight in progress")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	call_deferred("_play_dragon_ride_cinematic_sequence")

func _play_dragon_ride_cinematic_sequence() -> void:
	if _player == null or _dragon_guard == null:
		_dragon_flight_cinematic_running = false
		_ride_running = false
		_release_dragon_ride()
		return
	await _set_world_cinematic_bars(true, 0.32)
	await _fade_world_black(1.0, 2.0)
	var marker_start: Vector3 = _dragon_guard.global_position
	if _dragon_ride_path_start != null and is_instance_valid(_dragon_ride_path_start):
		marker_start = _dragon_ride_path_start.global_position
	var marker_mid: Vector3 = marker_start + Vector3(14.0, 10.0, -10.0)
	if _dragon_ride_path_mid != null and is_instance_valid(_dragon_ride_path_mid):
		marker_mid = _dragon_ride_path_mid.global_position
	var marker_end: Vector3 = marker_mid + Vector3(14.0, -4.0, 8.0)
	if _dragon_ride_path_end != null and is_instance_valid(_dragon_ride_path_end):
		marker_end = _dragon_ride_path_end.global_position
	var release_target: Vector3 = marker_end
	if _dragon_ride_player_drop != null and is_instance_valid(_dragon_ride_player_drop):
		release_target = _dragon_ride_player_drop.global_position
	_teleport_dragon_to_position(marker_start, marker_mid)
	await _fade_world_black(0.0, 0.42)
	await _fly_dragon_cinematic_segment(marker_mid, 2.6, 1.5)
	await _fade_world_black(1.0, 2.0)
	_teleport_dragon_to_position(marker_end, release_target)
	await _fade_world_black(0.0, 0.42)
	await _fly_dragon_cinematic_segment(release_target, 2.2, 0.45)
	await _set_world_cinematic_bars(false, 0.26)
	if _dragon_riding and _player != null:
		_on_dragon_ride_release_area_body_entered(_player)
	_ride_running = false

func _teleport_dragon_to_position(position: Vector3, look_target: Vector3) -> void:
	if _dragon_guard == null:
		return
	_dragon_guard.global_position = position
	var flat_target: Vector3 = look_target
	flat_target.y = position.y
	if _dragon_guard.has_method("face_toward"):
		_dragon_guard.call("face_toward", flat_target)
	else:
		_dragon_guard.look_at(flat_target, Vector3.UP)
	var look_dir: Vector3 = flat_target - position
	look_dir.y = 0.0
	if look_dir.length_squared() > 0.0001:
		_dragon_ride_look_direction = look_dir.normalized()
	_sync_player_to_dragon_mount()
	_update_dragon_ride_camera_anchor(1.0 / 60.0)

func _fade_world_black(target_alpha: float, duration: float) -> void:
	if _world == null or not _world.has_method("_fade_black"):
		await get_tree().create_timer(maxf(0.01, duration)).timeout
		return
	await _world.call("_fade_black", target_alpha, duration)

func _set_world_cinematic_bars(visible: bool, duration: float) -> void:
	if _world == null or not _world.has_method("_set_cinematic_bars"):
		return
	await _world.call("_set_cinematic_bars", visible, duration)

func _fly_dragon_cinematic_segment(target_position: Vector3, duration: float, arc_height: float = 0.0) -> void:
	if _dragon_guard == null:
		return
	var start: Vector3 = _dragon_guard.global_position
	var previous: Vector3 = start
	var elapsed: float = 0.0
	var total: float = maxf(0.05, duration)
	while elapsed < total:
		var delta: float = get_process_delta_time()
		elapsed += delta
		var t: float = clampf(elapsed / total, 0.0, 1.0)
		var eased: float = 0.5 - cos(t * PI) * 0.5
		var next_pos: Vector3 = start.lerp(target_position, eased)
		if arc_height > 0.0:
			next_pos.y += sin(t * PI) * arc_height
		_set_dragon_fly_toward(next_pos)
		var look_dir: Vector3 = next_pos - previous
		look_dir.y = 0.0
		if look_dir.length_squared() > 0.0001:
			_dragon_ride_look_direction = look_dir.normalized()
		_update_dragon_ride_camera_anchor(delta)
		_sync_player_to_dragon_mount()
		previous = next_pos
		await get_tree().process_frame
	_set_dragon_fly_toward(target_position)
	_update_dragon_ride_camera_anchor(1.0 / 60.0)
	_sync_player_to_dragon_mount()

func _release_dragon_ride() -> void:
	if not _dragon_riding:
		return
	_dragon_riding = false
	_dragon_flight_cinematic_running = false
	_dragon_ride_velocity = Vector3.ZERO
	_dragon_flight_active = false
	_dragon_ride_ready = false
	if _player != null:
		_player.set_cinematic_lock(false)
		_player.set_mobility_lock(false)
		_player.visible = true
		if _player.has_method("set_look_input_locked"):
			_player.call("set_look_input_locked", false)
		if _player.has_method("set_item_usage_locked"):
			_player.call("set_item_usage_locked", false)
		if _player.has_method("set_mount_riding"):
			_player.call("set_mount_riding", false)
		if _player.has_method("set_external_camera_anchor"):
			_player.call("set_external_camera_anchor", null)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _stage != Stage.USE_GATE:
		_stage = Stage.USE_GATE
		if _level_gate != null and _level_gate.has_method("set_interactable_enabled"):
			_level_gate.call("set_interactable_enabled", true)
	_show_objective("Insert the keycard into the portal box")
	_show_subtitle("Use the keycard on the center box to activate the portal ring.", 2.4)

func _fly_dragon_away() -> void:
	if _dragon_guard == null:
		_dragon_escape_running = false
		return
	if _dragon_escape_target == null:
		_dragon_guard.visible = false
		_dragon_escape_running = false
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_dragon_guard, "global_position", _dragon_escape_target.global_position, 2.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_dragon_guard, "rotation_degrees", _dragon_guard.rotation_degrees + Vector3(-8.0, 220.0, 0.0), 2.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if _dragon_guard.has_method("set_combat_enabled"):
		_dragon_guard.call("set_combat_enabled", false)
	else:
		_dragon_guard.visible = false
	_dragon_escape_running = false

func _grant_dragon_keycard() -> void:
	if _dragon_keycard != null:
		_dragon_keycard.visible = false
	if GameState.has_item("key_3"):
		GameState.select_item("key_3")
		return
	if GameState.add_item_first_free_slot("key_3"):
		GameState.select_item("key_3")
		return
	if GameState.selected_slot >= 0 and GameState.selected_slot < GameState.slots.size():
		GameState.slots[GameState.selected_slot] = "key_3"
		GameState.inventory_changed.emit()
		GameState.select_item("key_3")

func _on_gate_opened() -> void:
	if _stage != Stage.USE_GATE or _portal_transfer_running:
		return
	_portal_transfer_running = true
	_dragon_riding = false
	_dragon_flight_active = false
	_dragon_ride_ready = false
	_dragon_ride_velocity = Vector3.ZERO
	if GameState.rewind_mode_active:
		GameState.cancel_rewind_mode()
	if _player != null and _player.has_method("set_item_usage_locked"):
		_player.call("set_item_usage_locked", true)
	if _player != null:
		_player.set_cinematic_lock(true)
		_player.set_mobility_lock(true)
		_player.visible = true
		if _player.has_method("set_look_input_locked"):
			_player.call("set_look_input_locked", true)
		if _player.has_method("set_mount_riding"):
			_player.call("set_mount_riding", false)
		if _player.has_method("set_external_camera_anchor"):
			_player.call("set_external_camera_anchor", null)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_stage = Stage.DONE
	_show_objective("")
	var focus_target: Vector3 = _level_gate.global_position + Vector3(0.0, 1.15, 0.0) if _level_gate != null else _player.global_position + Vector3(0.0, 1.0, -2.0)
	await _focus_player_camera_to_position(focus_target, 0.42)
	_show_subtitle("Spatial transfer slot synced... moving to another world.", 1.55)
	await get_tree().create_timer(0.62).timeout
	await _transition_to_level_four()
	_portal_transfer_running = false

func _has_any_inventory_items() -> bool:
	for slot in GameState.slots:
		if String(slot) != "":
			return true
	return false

func _transition_to_level_four() -> void:
	var screen_fx: CanvasLayer = get_node_or_null("/root/ScreenFX") as CanvasLayer
	if _world != null and _world.get("player_hud") != null:
		var hud_variant: Variant = _world.get("player_hud")
		if hud_variant is CanvasLayer and (hud_variant as CanvasLayer).has_method("hide_boss_bar"):
			(hud_variant as CanvasLayer).call("hide_boss_bar")
	GameState.current_level_index = 3
	if screen_fx != null and screen_fx.has_method("fade_to_scene"):
		await screen_fx.fade_to_scene(LEVEL_FOUR_SCENE_PATH, true, 0.34, 0.36, 0.08, Color(1.0, 1.0, 1.0, 1.0))
	elif screen_fx != null and screen_fx.has_method("reboot_to_scene"):
		await screen_fx.reboot_to_scene(LEVEL_FOUR_SCENE_PATH, true)
	else:
		get_tree().change_scene_to_file(LEVEL_FOUR_SCENE_PATH)

func _set_bridge_enabled(enabled: bool) -> void:
	if _bridge_root == null:
		return
	for child in _bridge_root.get_children():
		var platform: Node3D = child as Node3D
		if platform == null:
			continue
		_set_platform_walkable(platform, enabled)

func _set_bridge_preview_visible(visible: bool) -> void:
	if _bridge_root == null:
		return
	for child in _bridge_root.get_children():
		var platform: Node3D = child as Node3D
		if platform == null:
			continue
		_set_platform_preview(platform, visible)

func _set_platform_walkable(platform: Node3D, enabled: bool) -> void:
	if platform == null:
		return
	platform.visible = enabled
	for node in platform.get_children():
		if node is CollisionShape3D:
			(node as CollisionShape3D).disabled = not enabled
		elif node is MeshInstance3D:
			(node as MeshInstance3D).visible = enabled
		elif node is Area3D:
			(node as Area3D).monitoring = enabled
			(node as Area3D).monitorable = enabled
			for area_child in node.get_children():
				if area_child is CollisionShape3D:
					(area_child as CollisionShape3D).disabled = not enabled

func _set_collisions_recursive_enabled(node: Node, enabled: bool) -> void:
	if node == null:
		return
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enabled
	elif node is Area3D:
		(node as Area3D).monitoring = enabled
		(node as Area3D).monitorable = enabled
	elif node is PhysicsBody3D:
		var body: PhysicsBody3D = node as PhysicsBody3D
		if not enabled:
			body.collision_layer = 0
			body.collision_mask = 0
	for child in node.get_children():
		_set_collisions_recursive_enabled(child, enabled)

func _set_physics_disabled_recursive(node: Node) -> void:
	if node == null:
		return
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is Area3D:
		(node as Area3D).monitoring = false
		(node as Area3D).monitorable = false
	elif node is PhysicsBody3D:
		var body: PhysicsBody3D = node as PhysicsBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	for child in node.get_children():
		_set_physics_disabled_recursive(child)

func _set_platform_preview(platform: Node3D, enabled: bool) -> void:
	if platform == null:
		return
	platform.visible = true
	for node in platform.get_children():
		if node is CollisionShape3D:
			(node as CollisionShape3D).disabled = true
		elif node is MeshInstance3D:
			(node as MeshInstance3D).visible = enabled
		elif node is Area3D:
			(node as Area3D).monitoring = false
			(node as Area3D).monitorable = false
			for area_child in node.get_children():
				if area_child is CollisionShape3D:
					(area_child as CollisionShape3D).disabled = true

func _show_objective(text: String) -> void:
	if _world != null and _world.has_method("_show_objective"):
		if text.is_empty():
			_world.call("_hide_objective", false)
		else:
			_world.call("_show_objective", text)

func _show_subtitle(text: String, duration: float) -> void:
	if _world != null and _world.has_method("_show_subtitle"):
		_world.call_deferred("_show_subtitle", text, duration, "")
