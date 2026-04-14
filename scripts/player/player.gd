extends CharacterBody3D

@export var speed: float = 7.5
@export var sprint_speed: float = 10.0
@export var crouch_speed: float = 4.0
@export var acceleration: float = 5.0
@export var gravity: float = 9.8
@export var jump_power: float = 5.0
@export var mouse_sensitivity: float = 0.3
@export var normal_height: float = 1.0
@export var crouch_height: float = 0.4

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var hud: CanvasLayer = $PlayerHUD

var camera_x_rotation: float = 0.0
var is_crouching: bool = false
var is_sprinting: bool = false

var last_interactable: Node3D = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("time_actor")

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if GameState.time_direction == 1 and GameState.is_scrubbing_past:
			GameState.prune_timeline()
		
		head.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		var x_delta = event.relative.y * mouse_sensitivity
		camera_x_rotation = clamp(camera_x_rotation + x_delta, -90.0, 90.0)
		camera.rotation_degrees.x = -camera_x_rotation

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			GameState.select_slot(0)
		elif event.keycode == KEY_2:
			GameState.select_slot(1)
		elif event.keycode == KEY_3:
			GameState.select_slot(2)
		elif event.keycode == KEY_G:
			# Drop or consume selected item
			var dropped = GameState.consume_selected()
			if dropped != "":
				print("Dropped item: ", dropped)

func _physics_process(delta: float) -> void:
	var dir = GameState.time_direction
	
	if dir == 1 and not GameState.is_scrubbing_past:
		var has_input = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_SPACE)
		
		if has_input and GameState.is_scrubbing_past:
			GameState.prune_timeline()
			
		_handle_movement(delta)
		
	_handle_interaction()

func _handle_movement(delta: float) -> void:
	var movement_vector = Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		movement_vector -= head.basis.z
	if Input.is_key_pressed(KEY_S):
		movement_vector += head.basis.z
	if Input.is_key_pressed(KEY_A):
		movement_vector -= head.basis.x
	if Input.is_key_pressed(KEY_D):
		movement_vector += head.basis.x

	movement_vector = movement_vector.normalized()

	var wants_crouch = Input.is_key_pressed(KEY_CTRL)
	var wants_sprint = Input.is_key_pressed(KEY_SHIFT) and not wants_crouch

	if wants_crouch and not is_crouching:
		is_crouching = true
		is_sprinting = false
		collision_shape.shape.height = crouch_height
		head.position.y = 0.0
	elif not wants_crouch and is_crouching:
		is_crouching = false
		collision_shape.shape.height = normal_height * 2.0
		position.y += (normal_height * 2.0 - crouch_height) / 2.0
		head.position.y = 0.5

	if wants_sprint and not is_crouching:
		is_sprinting = true
	elif is_sprinting and not wants_sprint:
		is_sprinting = false

	var current_speed: float
	if is_crouching:
		current_speed = crouch_speed
	elif is_sprinting:
		current_speed = sprint_speed
	else:
		current_speed = speed

	velocity.x = lerpf(velocity.x, movement_vector.x * current_speed, acceleration * delta)
	velocity.z = lerpf(velocity.z, movement_vector.z * current_speed, acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not is_crouching:
		velocity.y = jump_power

	move_and_slide()

func _handle_interaction() -> void:
	var collider = interaction_ray.get_collider()
	if collider is Interactable:
		var is_dig = collider.has_method("get_equip_hint") and collider.get_equip_hint() == GameState.slots[GameState.selected_slot]
		
		if last_interactable != collider:
			last_interactable = collider
			hud.show_prompt(collider.prompt_text)
			
		hud.set_crosshair_active(true, is_dig)
			
		if Input.is_key_pressed(KEY_E):
			collider.interact()
	else:
		if last_interactable != null:
			last_interactable = null
			hud.hide_prompt()
		hud.set_crosshair_active(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			GameState.select_slot(0)
		elif event.keycode == KEY_2:
			GameState.select_slot(1)
		elif event.keycode == KEY_3:
			GameState.select_slot(2)
		elif event.keycode == KEY_Q:
			_drop_item()

func _drop_item() -> void:
	var item_name = GameState.slots[GameState.selected_slot]
	if item_name == "": return
	
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
