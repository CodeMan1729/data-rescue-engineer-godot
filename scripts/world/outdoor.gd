extends Node3D

const DATA_PATH := "res://assets/outdoor/"
var manifest: Dictionary
var wet_materials: Array[StandardMaterial3D] = [] # Hard surfaces that turn glossy in rain.
var terrain_materials: Array[StandardMaterial3D] = [] # Soil and meadow: no specular, only darken when wet.
var terrain_colors: Array[Color] = []

func _ready() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH + "manifest.json"))
	for region in manifest.chunks:
		var scene: Node3D = load(DATA_PATH + region + ".glb").instantiate()
		scene.name = region
		add_child(scene)
		for mesh in scene.find_children("*", "MeshInstance3D", true, false):
			if str(mesh.name).begins_with("OD_Ground"):
				mesh.create_trimesh_collision()
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
				# Grass and soil never mirror the sun, moon or sky, wet or dry.
				material.roughness = 1.0
				material.metallic_specular = 0.0
				mesh.set_surface_override_material(surface, material)
				terrain_materials.append(material)
				terrain_colors.append(material.albedo_color)
	_build_vegetation()
	_build_boundary()
	_build_porch_ramp()

func _build_vegetation() -> void:
	var library: Node3D = load(DATA_PATH + "vegetation.glb").instantiate()
	var trunks := StaticBody3D.new()
	trunks.name = "Trunks"
	add_child(trunks)
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	add_child(rocks)
	for species in manifest.species:
		var near_mesh := library.find_child("OD_%03d_Near" % species.id, true, false) as MeshInstance3D
		if species.kind != "rock":
			for lod in ["Near", "Far"]:
				var plant := library.find_child("OD_%03d_%s" % [species.id, lod], true, false) as MeshInstance3D
				for surface in plant.mesh.get_surface_count():
					var leaf := plant.mesh.surface_get_material(surface) as StandardMaterial3D
					if leaf != null:
						leaf.roughness = 1.0
						leaf.metallic_specular = 0.0
		var groups: Dictionary = {}
		for values in manifest.instances[str(int(species.id))]:
			var transform := Transform3D(Basis(Vector3(values[0], values[1], values[2]), Vector3(values[3], values[4], values[5]), Vector3(values[6], values[7], values[8])), Vector3(values[9], values[10], values[11]))
			var cell := Vector2i(floori(transform.origin.x / 32), floori(transform.origin.z / 32))
			if not groups.has(cell):
				groups[cell] = []
			groups[cell].append(transform)
			if species.kind == "tree":
				var shape := CylinderShape3D.new()
				shape.height = 2.5
				shape.radius = clampf(transform.basis.get_scale().x * 0.22, 0.12, 0.65)
				var collider := CollisionShape3D.new()
				collider.shape = shape
				collider.position = transform.origin + Vector3.UP * 1.25
				trunks.add_child(collider)
			elif species.kind == "rock":
				var bounds: AABB = transform * near_mesh.transform * near_mesh.get_aabb()
				_add_box(rocks, bounds.get_center(), bounds.size.max(Vector3.ONE * 0.02))
		for cell in groups:
			for lod in ["Near", "Far"]:
				var prototype := library.find_child("OD_%03d_%s" % [species.id, lod], true, false) as MeshInstance3D
				assert(prototype != null, "Missing vegetation prototype")
				var batch := MultiMeshInstance3D.new()
				batch.name = "Species%d_%d_%d_%s" % [species.id, cell.x, cell.y, lod]
				batch.position = Vector3(cell.x * 32 + 16, 0, cell.y * 32 + 16)
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.mesh = prototype.mesh
				multi.instance_count = groups[cell].size()
				for i in groups[cell].size():
					var transform: Transform3D = groups[cell][i]
					transform.origin -= batch.position
					# glTF keeps the mesh axis conversion on its node.
					multi.set_instance_transform(i, transform * prototype.transform)
				batch.multimesh = multi
				var split := 55.0 if species.kind == "tree" else 28.0
				var limit := 140.0 if species.kind == "tree" else 55.0
				batch.visibility_range_begin = 0.0 if lod == "Near" else split
				batch.visibility_range_end = split if lod == "Near" else limit
				batch.visibility_range_begin_margin = 2.0
				batch.visibility_range_end_margin = 2.0
				batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(batch)
	library.free()

func _build_boundary() -> void:
	var b: Array = manifest.bounds_xz
	var body := StaticBody3D.new()
	body.name = "Boundary"
	add_child(body)
	for x in [float(b[0]) + 0.3, float(b[2]) - 0.3]:
		_add_box(body, Vector3(x, 35, (b[1] + b[3]) * 0.5), Vector3(0.6, 100, b[3] - b[1]))
	for z in [float(b[1]) + 0.3, float(b[3]) - 0.3]:
		_add_box(body, Vector3((b[0] + b[2]) * 0.5, 35, z), Vector3(b[2] - b[0], 100, 0.6))

func _add_box(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = center
	body.add_child(collider)

func _build_porch_ramp() -> void:
	# Join the level T04 porch to the clearing, with a visible shallow ramp.
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-2.1, 0.03, 4.25), Vector3(1.4, 0.03, 4.25), Vector3(-2.1, -0.32, 6.5),
		Vector3(1.4, 0.03, 4.25), Vector3(1.4, -0.32, 6.5), Vector3(-2.1, -0.32, 6.5)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.21, 0.17)
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	wet_materials.append(material)
	var ramp := MeshInstance3D.new()
	ramp.name = "PorchRamp"
	ramp.mesh = mesh
	add_child(ramp)
	ramp.create_trimesh_collision()

func set_wetness(amount: float) -> void:
	for i in terrain_materials.size():
		terrain_materials[i].albedo_color = terrain_colors[i].darkened(0.3 * amount)
	for material in wet_materials:
		material.roughness = lerpf(0.9, 0.23, amount)
		material.metallic_specular = lerpf(0.5, 0.8, amount)

func set_wet(enabled: bool) -> void:
	set_wetness(1.0 if enabled else 0.0)
