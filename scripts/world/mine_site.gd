class_name MineSite
extends Node3D

signal open_changed(is_open: bool)
signal interacted(key: String, player: Node3D)

# Entrance camp of the closed mine. Builds physics from the markers in the GLB:
# MN_Collision_* become hidden boxes, MN_Interact_* become Interactable areas.
# Closed: invisible walls keep the player out of the camp. set_open(true) removes them.
# Site space: X right, -Z into the camp, origin at the gate centre, Y up.
const MODEL := preload("res://assets/mine/mine_site.glb")
const INTERACTABLE_SCRIPT := preload("res://scripts/world/interactable.gd")
const CLEARING := Rect2(-21.0, -33.0, 42.0, 41.0) # Site-space X and Z. No vegetation here.
const WALL_X := 17.5 # Inner face of the closed-camp walls.
const WALL_Z_FRONT := 1.0
const WALL_Z_REAR := -31.5
const WALL_THICKNESS := 0.5
const LAMP_LIGHT_ENERGY := 1.6
const LAMP_LIGHT_RANGE := 11.0
const LAMP_LIGHT_COLOR := Color(1.0, 0.8, 0.5)
const PROMPTS := {
	"Gate": "按 E 查看入口", "TornSeal": "按 E 查看封条", "Computer": "按 E 使用调度电脑",
	"WinchControl": "按 E 查看绞车操作箱", "MineCart": "按 E 查看矿车", "Adit": "按 E 查看平硐口",
	"Generator": "按 E 查看发电机", "WarningSign": "按 E 阅读警示牌"
}
# Trigger box sizes (m). The Z size of the OUTWARD keys is computed, see _build_interactions.
const TARGET_SIZES := {
	"Gate": Vector3(4.0, 2.4, 0.0), "TornSeal": Vector3(1.0, 1.2, 0.0),
	"Computer": Vector3(1.0, 1.0, 1.0), "WinchControl": Vector3(1.0, 1.2, 1.0),
	"MineCart": Vector3(1.8, 1.6, 2.4), "Adit": Vector3(4.0, 3.0, 1.0),
	"Generator": Vector3(1.4, 1.2, 1.4), "WarningSign": Vector3(1.6, 1.4, 0.8)
}
# The gate and the seal must work from outside the closed camp. The interaction ray stops at the
# first collider, so their boxes reach out past the front wall (outer face at WALL_Z_FRONT + thickness)
# and stop short of the nearest spot where the player camera can stand (wall face plus capsule radius).
const OUTWARD_KEYS := ["Gate", "TornSeal"]
const OUTWARD_FACE_Z := 1.7

@export var start_open := false

var open := false
var model: Node3D
var closure: StaticBody3D
var lamp_energy := 4.0
var lamp_materials: Array[StandardMaterial3D] = []
var lamp_lights: Array[OmniLight3D] = []
var lamp_levels := PackedFloat32Array()

func _enter_tree() -> void:
	add_to_group("outdoor_clearing")

func _ready() -> void:
	model = MODEL.instantiate()
	add_child(model)
	_build_collisions()
	_build_interactions()
	_build_closure()
	_build_lamps()
	var requested := start_open or open
	var arguments := OS.get_cmdline_user_args()
	if "--mine-open" in arguments:
		requested = true
	elif "--mine-closed" in arguments:
		requested = false
	set_open(requested)

func get_clearing_rect() -> Rect2:
	# World-space XZ bounds of the camp plus margin. Outdoor skips vegetation inside it.
	var rect := Rect2()
	var first := true
	for corner in [CLEARING.position, Vector2(CLEARING.end.x, CLEARING.position.y), CLEARING.end, Vector2(CLEARING.position.x, CLEARING.end.y)]:
		var world_point := global_transform * Vector3(corner.x, 0.0, corner.y)
		var point := Vector2(world_point.x, world_point.z)
		rect = Rect2(point, Vector2.ZERO) if first else rect.expand(point)
		first = false
	return rect

func set_open(value: bool) -> void:
	# T07 calls this from the story flag. Closed: invisible walls block every way into the camp.
	open = value
	if closure != null:
		closure.collision_layer = 0 if open else 1
		open_changed.emit(open)

func is_open() -> bool:
	return open

func apply_lamp_levels(levels: PackedFloat32Array) -> void:
	# The world copies the brightness of the far view, so near and far show the same lights.
	lamp_levels = levels.duplicate()
	for i in mini(lamp_materials.size(), lamp_levels.size()):
		lamp_materials[i].emission_energy_multiplier = lamp_energy * lamp_levels[i]
		lamp_lights[i].light_energy = LAMP_LIGHT_ENERGY * lamp_levels[i]
		lamp_lights[i].visible = lamp_levels[i] > 0.01

func _build_collisions() -> void:
	# Marker scale holds the half extents. Each box is created in site space with scale 1.
	var body := StaticBody3D.new()
	body.name = "Collisions"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for marker in model.find_children("MN_Collision_*", "Node3D", true, false):
		var extras: Dictionary = marker.get_meta("extras", {})
		assert(extras.get("shape", "") == "box", "Unsupported collision marker: " + str(marker.name))
		var local := global_transform.affine_inverse() * (marker as Node3D).global_transform
		var shape := BoxShape3D.new()
		shape.size = local.basis.get_scale().abs() * 2.0
		var collider := CollisionShape3D.new()
		collider.name = marker.name
		collider.shape = shape
		collider.transform = Transform3D(local.basis.orthonormalized(), local.origin)
		body.add_child(collider)

func _build_interactions() -> void:
	var holder := Node3D.new()
	holder.name = "Interactables"
	add_child(holder)
	for marker in model.find_children("MN_Interact_*", "Node3D", true, false):
		var key := str(marker.name).trim_prefix("MN_Interact_")
		var area := Area3D.new()
		area.set_script(INTERACTABLE_SCRIPT)
		area.name = key
		area.collision_layer = 2
		area.collision_mask = 0
		area.monitoring = false
		area.prompt_text = PROMPTS.get(key, "按 E 交互")
		holder.add_child(area)
		area.position = (global_transform.affine_inverse() * (marker as Node3D).global_transform).origin
		var box_size: Vector3 = TARGET_SIZES.get(key, Vector3.ONE * 1.2)
		var centre := Vector3.ZERO
		if key in OUTWARD_KEYS:
			# Box spans 0.3 m behind the marker to OUTWARD_FACE_Z in front of it.
			var reach := OUTWARD_FACE_Z - area.position.z
			box_size.z = reach + 0.3
			centre.z = (reach - 0.3) * 0.5
		var shape := BoxShape3D.new()
		shape.size = box_size
		var target := CollisionShape3D.new()
		target.name = "Target"
		target.shape = shape
		target.position = centre
		area.add_child(target)
		area.interacted.connect(func(player: Node3D) -> void: interacted.emit(key, player))

func _build_closure() -> void:
	# Four thin walls round the whole camp. Tall and deep, so nothing slips over or under.
	closure = StaticBody3D.new()
	closure.name = "ClosureBarrier"
	closure.collision_layer = 1
	closure.collision_mask = 0
	add_child(closure)
	var depth := WALL_Z_FRONT - WALL_Z_REAR + WALL_THICKNESS * 2.0
	var width := WALL_X * 2.0 + WALL_THICKNESS * 2.0
	var middle_z := (WALL_Z_FRONT + WALL_Z_REAR) * 0.5
	_add_wall("Front", Vector3(0, 2.5, WALL_Z_FRONT + WALL_THICKNESS * 0.5), Vector3(width, 11.0, WALL_THICKNESS))
	_add_wall("Rear", Vector3(0, 2.5, WALL_Z_REAR - WALL_THICKNESS * 0.5), Vector3(width, 11.0, WALL_THICKNESS))
	_add_wall("Left", Vector3(-WALL_X - WALL_THICKNESS * 0.5, 2.5, middle_z), Vector3(WALL_THICKNESS, 11.0, depth))
	_add_wall("Right", Vector3(WALL_X + WALL_THICKNESS * 0.5, 2.5, middle_z), Vector3(WALL_THICKNESS, 11.0, depth))

func _add_wall(wall_name: String, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.name = wall_name
	collider.shape = shape
	collider.position = center
	closure.add_child(collider)

func _build_lamps() -> void:
	var emitters := model.find_children("*Lamp_Emitter*", "MeshInstance3D", true, false)
	emitters.sort_custom(func(a: Node, b: Node) -> bool: return str(a.name) < str(b.name))
	for emitter: MeshInstance3D in emitters:
		# One material per lamp, so each can dim on its own.
		var material := (emitter.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		emitter.set_surface_override_material(0, material)
		lamp_materials.append(material)
		lamp_energy = material.emission_energy_multiplier
		var light := OmniLight3D.new()
		light.name = "Light"
		light.light_color = LAMP_LIGHT_COLOR
		light.omni_range = LAMP_LIGHT_RANGE
		light.shadow_enabled = false
		light.position = Vector3(0, -0.3, 0)
		emitter.add_child(light)
		lamp_lights.append(light)
	if lamp_levels.is_empty():
		lamp_levels.resize(lamp_materials.size())
	apply_lamp_levels(lamp_levels)
