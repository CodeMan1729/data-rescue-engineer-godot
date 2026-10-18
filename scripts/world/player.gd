extends CharacterBody3D

@export var walk_speed: float = 3.6
@export var slow_speed: float = 1.2
@export var mouse_sensitivity: float = 0.002
@export var interaction_distance: float = 2.5
@export var capture_on_start: bool = true

@onready var camera: Camera3D = $Camera3D
@onready var prompt: Label = $HUD/Prompt
@onready var status: Label = $HUD/Status
var controls_enabled: bool = true
var target: Interactable
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	if capture_on_start and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	velocity = Vector3.ZERO
	if not value:
		target = null
		prompt.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_controls_enabled(not controls_enabled)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if controls_enabled else Input.MOUSE_MODE_VISIBLE
		status.text = "" if controls_enabled else "已暂停操作 · 按 Esc 继续"
		get_viewport().set_input_as_handled()
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, -1.45, 1.45)
	if event.is_action_pressed("interact"):
		update_interaction()
		if is_instance_valid(target):
			target.interact(self)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controls_enabled else Vector2.ZERO
	var direction := global_basis * Vector3(axis.x, 0, axis.y)
	var speed := slow_speed if Input.is_action_pressed("move_slow") else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	update_interaction()

func find_interactable() -> Interactable:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * interaction_distance, 3, [get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is Interactable and hit.collider.enabled:
		return hit.collider
	return null

func update_interaction() -> void:
	target = find_interactable() if controls_enabled else null
	prompt.text = target.prompt_text if is_instance_valid(target) else ""
