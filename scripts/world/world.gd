extends Node3D

const INTERACTABLE_SCRIPT = preload("res://scripts/world/interactable.gd")
@onready var station: Node3D = $Station
@onready var mine_vista: MineVista = %MineVista
@onready var mine_site: MineSite = %MineSite

func _ready() -> void:
	# Open the existing hinge only in this instance. Never rewrite the GLB.
	var hinge := station.find_child("MS_Door_Hinge", true, false) as Node3D
	assert(hinge != null, "Missing station door hinge")
	hinge.rotation.y = deg_to_rad(-100.0)
	_build_collisions()
	_build_interactions()
	_connect_mine()

func _bounds(prefixes: Array[String]) -> AABB:
	var bounds := AABB()
	var found := false
	for node in station.find_children("*", "MeshInstance3D", true, false):
		for prefix in prefixes:
			if str(node.name).begins_with(prefix):
				var box: AABB = global_transform.affine_inverse() * node.global_transform * node.get_aabb()
				bounds = bounds.merge(box) if found else box
				found = true
				break
	assert(found, "Missing station meshes: " + str(prefixes))
	return bounds

func _box(parent: Node3D, node_name: String, bounds: AABB) -> void:
	var shape := BoxShape3D.new()
	shape.size = bounds.size.max(Vector3.ONE * 0.02)
	var collider := CollisionShape3D.new()
	collider.name = node_name
	collider.shape = shape
	collider.position = bounds.get_center()
	parent.add_child(collider)

func _build_collisions() -> void:
	var body: StaticBody3D = $Collisions
	_box(body, "Floor", AABB(Vector3(-2.25, -0.17, -3.1), Vector3(4.5, 0.2, 6.2)))
	# Level porch proxy and a shallow threshold keep the capsule from snagging.
	_box(body, "Porch", AABB(Vector3(-2.1, -0.17, 3.1), Vector3(3.5, 0.2, 1.2)))
	_box(body, "Threshold", AABB(Vector3(-1.62, -0.17, 2.85), Vector3(0.98, 0.2, 0.4)))
	for side in ["Back", "East", "West"]:
		_box(body, "Wall" + side, _bounds(["MS_Wall_" + side]))
	# Preserve the front door opening, while closing the window to player movement.
	for node in station.find_children("MS_Wall_Front*", "MeshInstance3D", true, false):
		_box(body, str(node.name), global_transform.affine_inverse() * node.global_transform * node.get_aabb())
	for mesh in station.find_children("MS_Frame_Front*", "MeshInstance3D", true, false):
		_box(body, str(mesh.name), global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb())
	_box(body, "FrontWindow", _bounds(["MS_Glass_Front"]))
	var furniture := {
		"Workbench": ["MS_Workbench"],
		"Bed": ["MS_Red_Bed", "MS_Red_Mattress"],
		"Stove": ["MS_Stove_Body", "MS_Stove_Hearth"],
		"Rack": ["MS_Telecom_Rack"], "Toolbox": ["MS_Toolbox"],
		"Bookshelf": ["MS_Bookshelf"], "Bench": ["MS_Porch_Bench_Seat", "MS_Bench_Leg"],
		"OpenDoor": ["MS_Door_Leaf", "MS_Door_Top", "MS_Door_Window_Stile"]
	}
	# Chair group names belong to empty parents. Gather their mesh descendants separately.
	for key in furniture:
		var prefixes: Array[String] = []
		prefixes.assign(furniture[key])
		_box(body, key, _bounds(prefixes))
	for group_name in ["MS_Chair_Folding", "MS_Chair_Wood"]:
		var group := station.find_child(group_name, true, false)
		assert(group != null)
		var box := AABB()
		var first := true
		for mesh in group.find_children("*", "MeshInstance3D", true, false):
			var part: AABB = global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		_box(body, group_name, box)
	# T06 supplies the outdoor terrain, porch ramp and map boundary.

func _build_interactions() -> void:
	var definitions := {
		"Computer": ["MS_CRT_Case", "按 E 使用电脑"],
		"Fax": ["MS_Fax_Machine", "按 E 查看传真机"],
		"Radio": ["MS_Radio_Housing", "按 E 使用电台"],
		"Map": ["MS_Map_Paper", "按 E 查看地图"],
		"Manual": ["MS_Repair_Manual", "按 E 阅读手册"]
	}
	for key in definitions:
		var area := Area3D.new()
		area.set_script(INTERACTABLE_SCRIPT)
		area.name = key
		area.collision_layer = 2
		area.collision_mask = 0
		area.monitoring = false
		area.prompt_text = definitions[key][1]
		$Interactables.add_child(area)
		_box(area, "Target", _bounds([definitions[key][0]]).grow(0.025))
		area.interacted.connect(_on_interacted.bind(key))

func _on_interacted(player: Node3D, key: String) -> void:
	player.get_node("HUD/Status").text = "%s：交互已触发（占位）" % key

func _connect_mine() -> void:
	# T07 drives mine_vista.set_state() and mine_site.set_open(). The site lamps copy the far view.
	mine_vista.levels_changed.connect(mine_site.apply_lamp_levels)
	mine_site.apply_lamp_levels(mine_vista.levels)
	mine_site.interacted.connect(_on_mine_interacted)
	# Development aid: `-- --at-mine` starts the player in front of the camp gate.
	if "--at-mine" in OS.get_cmdline_user_args():
		$Player.global_position = mine_site.to_global(Vector3(0.0, 0.05, 8.0))

func _on_mine_interacted(key: String, player: Node3D) -> void:
	player.get_node("HUD/Status").text = "矿场·%s：交互已触发（占位）" % key
