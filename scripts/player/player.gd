extends CharacterBody3D

@export var speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.0
@export var acceleration: float = 4.0
@export var gravity: float = 9.8
@export var jump_power: float = 4.5
@export var mouse_sensitivity: float = 0.3
@export var normal_height: float = 1.68
@export var crouch_height: float = 0.9
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 26.0
@export var stamina_recover_rate: float = 18.0
@export var stamina_recover_delay: float = 0.7

@onready var head: Node3D = $"root/Skeleton3D/BoneAttachment3D/Head"
@onready var camera: Camera3D = $"root/Skeleton3D/BoneAttachment3D/Head/Camera3D"
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interaction_ray: RayCast3D = $"root/Skeleton3D/BoneAttachment3D/Head/Camera3D/InteractionRay"
@onready var hud: CanvasLayer = $PlayerHUD
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var skeleton: Skeleton3D = $"root/Skeleton3D"

var _hitbox_pairs: Array = []
var _camera_collision_shape: SphereShape3D
var _camera_collision_query: PhysicsShapeQueryParameters3D

var camera_x_rotation: float = 0.0
var _smoothed_head_y: float = 0.0
var _camera_origin_offset: Vector3 = Vector3.ZERO
var is_crouching: bool = false
var is_sprinting: bool = false
var last_interactable: Node3D = null
var _rewind_scroll_hold_time: float = 0.0
var cinematic_locked: bool = false
var health: float = 100.0
var stamina: float = 100.0
var _stamina_recover_cooldown: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("time_actor")
	health = max_health
	stamina = max_stamina
	_camera_origin_offset = to_local(camera.global_position)
	_smoothed_head_y = camera.global_position.y
	camera.set_as_top_level(true)
	_camera_collision_shape = SphereShape3D.new()
	_camera_collision_shape.radius = 0.15
	_camera_collision_query = PhysicsShapeQueryParameters3D.new()
	_camera_collision_query.shape = _camera_collision_shape
	_camera_collision_query.exclude = [self.get_rid()]
	_update_hud_status()
	
	_hitbox_pairs.clear()
	for child in skeleton.get_children():
		if child is BoneAttachment3D:
			for subchild in child.get_children():
				if subchild is Area3D and subchild.name.begins_with("Hitbox"):
					subchild.set_as_top_level(true)
					_hitbox_pairs.append([child, subchild])

func _sync_hitboxes(delta: float) -> void:
	for pair in _hitbox_pairs:
		var attach: BoneAttachment3D = pair[0]
		var hitbox: Area3D = pair[1]
		var bone_pose = skeleton.get_bone_global_pose(attach.bone_idx)
		var t: Transform3D = skeleton.global_transform * bone_pose
		hitbox.global_transform = Transform3D(t.basis.orthonormalized(), t.origin)
	# Advanced anti-clip camera logic using Sphere Cast (thick ray)
	# Decouple raw target from raw bone to completely negate side-to-side animation jitter tracking
	var current_offset = _camera_origin_offset
	current_offset.z -= 0.22
	current_offset.y += 0.00
	
	# if is_crouching:
	# 	current_offset.y -= (normal_height - crouch_height)
	var raw_target_pos = to_global(current_offset)
	
	# Stabilize the camera's Y axis depending on the movement state
	var is_walking = is_on_floor() and velocity.length_squared() > 1.0 and not is_sprinting
	if is_walking:
		# Heavy stabilization for smooth aiming while walking
		_smoothed_head_y = lerpf(_smoothed_head_y, raw_target_pos.y, 5.0 * delta)
	else:
		# Natural bone following for running/jumping
		_smoothed_head_y = lerpf(_smoothed_head_y, raw_target_pos.y, 25.0 * delta)
		
	var target_pos = Vector3(raw_target_pos.x, _smoothed_head_y, raw_target_pos.z)
	var center_pos = global_position
	center_pos.y = target_pos.y
	
	var space_state = get_world_3d().direct_space_state
	_camera_collision_query.transform = Transform3D(Basis(), center_pos)
	_camera_collision_query.motion = target_pos - center_pos
	
	var result = space_state.cast_motion(_camera_collision_query)
	if result.size() == 2:
		var safe_fraction = result[0]
		camera.global_position = center_pos + _camera_collision_query.motion * safe_fraction
	else:
		camera.global_position = target_pos
		
	# Synchronize absolute rotations manually to avoid bone roll/pitch jitter
	camera.global_rotation.y = global_rotation.y
	camera.global_rotation.x = deg_to_rad(-camera_x_rotation)
	camera.global_rotation.z = 0.0



func _input(event: InputEvent) -> void:
	if cinematic_locked:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if GameState.rewind_mode_active:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE:
				GameState.deactivate_rewind_mode(true)
			elif event.keycode == KEY_X and _can_use_axiom():
				GameState.cancel_rewind_mode()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			if not _can_use_axiom():
				return
			if GameState.world_history.size() > 0:
				GameState.activate_rewind_mode()
			return
		elif event.keycode == KEY_X:
			if _can_use_axiom():
				GameState.add_mark_current()
				hud.show_mark_screenshot_effect()

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if GameState.time_direction == 1 and GameState.is_scrubbing_past:
			GameState.prune_timeline()
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		var x_delta = event.relative.y * mouse_sensitivity
		camera_x_rotation = clamp(camera_x_rotation + x_delta, -90.0, 90.0)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			GameState.select_slot(0)
		elif event.keycode == KEY_2:
			GameState.select_slot(1)
		elif event.keycode == KEY_3:
			GameState.select_slot(2)

func _physics_process(delta: float) -> void:
	if cinematic_locked:
		velocity = Vector3.ZERO
		_sync_hitboxes(delta)
		_update_hud_status()
		return
	if GameState.rewind_mode_active:
		var r_held = Input.is_key_pressed(KEY_R)
		var f_held = Input.is_key_pressed(KEY_F)
		if r_held or f_held:
			_rewind_scroll_hold_time += delta
			var speed = 1.0 + _rewind_scroll_hold_time * 6.0
			var steps_per_frame = int(speed * delta * 60.0)
			if steps_per_frame < 1:
				steps_per_frame = 1
			var dir_val = -1 if r_held else 1
			for _i in range(steps_per_frame):
				GameState.move_rewind_pointer(dir_val)
			hud.trigger_pointer_glitch()
		else:
			_rewind_scroll_hold_time = 0.0
		_sync_hitboxes(delta)
		_update_hud_status()
		return

	var dir = GameState.time_direction
	if dir == 1 and not GameState.is_scrubbing_past:
		var has_input = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_SPACE)
		if has_input and GameState.is_scrubbing_past:
			GameState.prune_timeline()
		_handle_movement(delta)
	_handle_interaction(delta)


func _handle_movement(delta: float) -> void:
	var movement_vector = Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		movement_vector -= global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		movement_vector += global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		movement_vector -= global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		movement_vector += global_transform.basis.x

	movement_vector = movement_vector.normalized()

	if anim_player:
		var current_anim = "idle"
		if is_on_floor():
			if movement_vector.length() > 0:
				current_anim = "run"
				# Differentiate walk vs run natively by animation speed
				if is_sprinting:
					anim_player.speed_scale = 1.0
				else:
					anim_player.speed_scale = 0.55
			else:
				current_anim = "idle"
				anim_player.speed_scale = 1.0
		else:
			if velocity.y > 0:
				current_anim = "air_jump"
			else:
				current_anim = "air_land"
			anim_player.speed_scale = 1.0
			
		if anim_player.has_animation(current_anim):
			if anim_player.current_animation != current_anim:
				anim_player.play(current_anim, 0.2)

	# var wants_crouch = Input.is_key_pressed(KEY_CTRL)
	var wants_sprint = Input.is_key_pressed(KEY_SHIFT) # and not wants_crouch
	var is_moving := movement_vector.length_squared() > 0.001

	# if wants_crouch and not is_crouching:
	# 	is_crouching = true
	# 	is_sprinting = false
	# 	collision_shape.shape.height = crouch_height
	# 	collision_shape.position.y = crouch_height * 0.5
	# elif not wants_crouch and is_crouching:
	# 	is_crouching = false
	# 	collision_shape.shape.height = normal_height
	# 	collision_shape.position.y = normal_height * 0.5

	var can_sprint := wants_sprint and is_moving and stamina > 0.0 and is_on_floor()
	is_sprinting = can_sprint
	if is_sprinting:
		stamina = maxf(0.0, stamina - stamina_drain_rate * delta)
		_stamina_recover_cooldown = stamina_recover_delay
	else:
		_stamina_recover_cooldown = maxf(0.0, _stamina_recover_cooldown - delta)
		if _stamina_recover_cooldown <= 0.0:
			stamina = minf(max_stamina, stamina + stamina_recover_rate * delta)

	var current_speed: float
	# if is_crouching:
	# 	current_speed = crouch_speed
	if is_sprinting:
		current_speed = sprint_speed
	else:
		current_speed = speed

	velocity.x = lerpf(velocity.x, movement_vector.x * current_speed, acceleration * delta)
	velocity.z = lerpf(velocity.z, movement_vector.z * current_speed, acceleration * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = max(velocity.y - gravity * delta, -30.0)

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not is_crouching:
		velocity.y = jump_power

	move_and_slide()
	
	# Keep hitboxes in sync at all times
	_sync_hitboxes(delta)
	_update_hud_status()

func _handle_interaction(delta: float) -> void:
	if not interaction_ray:
		return
	var collider = interaction_ray.get_collider()
	if collider and collider.has_method("interact"):
		var p_text = collider.get("prompt_text")
		if typeof(p_text) == TYPE_STRING:
			var is_dig = collider.has_method("get_equip_hint") and collider.get_equip_hint() == GameState.slots[GameState.selected_slot]
			if last_interactable != null and last_interactable != collider:
				if last_interactable.has_method("reset_minigame"):
					last_interactable.reset_minigame()
					hud.set_dig_progress(0, false)
				if last_interactable.has_method("set_highlight_enabled"):
					last_interactable.set_highlight_enabled(false)
			last_interactable = collider
			if collider.has_method("set_highlight_enabled"):
				collider.set_highlight_enabled(true)
			if collider.has_method("set_highlight_strength"):
				collider.set_highlight_strength(1.0)
			
			# Handle Continuous Hold Mechanic (like digging)
			if collider.has_method("progress_minigame"):
				if Input.is_key_pressed(KEY_E):
					var prog = collider.progress_minigame(delta)
					if prog >= 0:
						hud.set_dig_progress(prog, true)
					if prog >= 100.0:
						hud.set_dig_progress(0, false)
						hud.set_crosshair_active(false, false)
						p_text = ""
				else:
					collider.reset_minigame()
					hud.set_dig_progress(0, false)
					
			if p_text == "":
				hud.hide_prompt()
			else:
				hud.show_prompt(p_text)
			hud.set_crosshair_active(true, is_dig)
		else:
			if last_interactable != null:
				if is_instance_valid(last_interactable):
					if last_interactable.has_method("reset_minigame"):
						last_interactable.reset_minigame()
					if last_interactable.has_method("set_highlight_enabled"):
						last_interactable.set_highlight_enabled(false)
				last_interactable = null
			hud.hide_prompt()
			hud.set_dig_progress(0, false)
			hud.set_crosshair_active(false)
	else:
		if last_interactable != null:
			if is_instance_valid(last_interactable):
				if last_interactable.has_method("reset_minigame"):
					last_interactable.reset_minigame()
				if last_interactable.has_method("set_highlight_enabled"):
					last_interactable.set_highlight_enabled(false)
			last_interactable = null
		hud.hide_prompt()
		hud.set_dig_progress(0, false)
		hud.set_crosshair_active(false)

func _update_hud_status() -> void:
	if hud == null:
		return
	hud.set_health(health, max_health)
	hud.set_stamina(stamina, max_stamina)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			GameState.select_slot(0)
		elif event.keycode == KEY_2:
			GameState.select_slot(1)
		elif event.keycode == KEY_3:
			GameState.select_slot(2)
		elif event.keycode == KEY_Q:
			_drop_item()
		elif event.keycode == KEY_E:
			if last_interactable:
				if not last_interactable.has_method("progress_minigame"):
					last_interactable.interact()

func _drop_item() -> void:
	var item_name = GameState.slots[GameState.selected_slot]
	if item_name == "":
		return
	GameState.consume_selected()
	if item_name == "key_1" or item_name.begins_with("key"):
		var key_scene = load("res://scenes/objects/key_item.tscn")
		var k = key_scene.instantiate()
		get_tree().root.add_child(k)
		k.global_position = head.global_position - head.global_transform.basis.z * 1.5
	elif item_name == "Shovel":
		var shovel_scene = load("res://scenes/objects/shovel.tscn")
		var s = shovel_scene.instantiate()
		get_tree().root.add_child(s)
		s.global_position = head.global_position - head.global_transform.basis.z * 1.5
	elif item_name == "Axiom":
		var axiom_scene = load("res://scenes/objects/axiom_item.tscn")
		var a = axiom_scene.instantiate()
		get_tree().root.add_child(a)
		a.global_position = head.global_position - head.global_transform.basis.z * 1.5

func _can_use_axiom() -> bool:
	return GameState.axiom_equipped

func set_cinematic_lock(active: bool) -> void:
	cinematic_locked = active
	if active:
		velocity = Vector3.ZERO

func set_cinematic_pose(target_position: Vector3, target_yaw: float, target_pitch: float) -> void:
	global_position = target_position
	rotation.y = target_yaw
	camera_x_rotation = target_pitch
	velocity = Vector3.ZERO
	_sync_hitboxes(1.0 / 60.0)

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	_update_hud_status()
	if health <= 0.0:
		var world := get_parent()
		if world != null and world.has_method("restart_current_level"):
			world.call_deferred("restart_current_level")
