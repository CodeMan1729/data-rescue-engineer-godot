class_name MineVista
extends Node3D

signal state_changed(state: String)
signal levels_changed(levels: PackedFloat32Array)

# Far view of the mine camp: a low-poly silhouette with four lamps.
# T07 calls set_state() from story flags. "off" hides the whole view.
# The other states only change the lamps.
# Close to the camp the detailed MineSite replaces this view (apply_distance).
const MODEL := preload("res://assets/mine/mine_vista.glb")
const STATES := ["off", "on", "flicker", "rain"]
const RAIN_LEVEL := 0.6 # Lamps look dim through rain.
const HALO_ALPHA := 0.9

@export_enum("off", "on", "flicker", "rain") var start_state := "off"
@export var site_path: NodePath = ^"../MineSite"
@export var handover_distance := 85.0 # Metres from the camp centre where the site takes over.
@export var handover_margin := 5.0 # Dead band on both sides, so the switch does not flip back and forth.
@export var halo_size := 6.0 # Metres. The lamp bodies are too small to see from the station.
@export var flicker_seed := 0 # 0 gives a different pattern every run.

var state := "off"
var levels := PackedFloat32Array() # Lamp brightness, 0 to 1, one entry per lamp.
var site_active := false
var rng := RandomNumberGenerator.new()
var site: Node3D
var lamp_energy := 4.0
var lamp_materials: Array[StandardMaterial3D] = []
var halo_materials: Array[StandardMaterial3D] = []
var halos: Array[MeshInstance3D] = []
var holds := PackedFloat32Array()

func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	site = get_node_or_null(site_path) as Node3D
	if flicker_seed == 0:
		rng.randomize()
	else:
		rng.seed = flicker_seed
	_build_lamps(model)
	var requested := start_state
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mine="):
			requested = argument.trim_prefix("--mine=")
	if not set_state(requested):
		set_state("off")
	apply_distance(INF)

func _process(delta: float) -> void:
	if state == "flicker":
		advance(delta)
		_apply_levels()
	apply_distance(_camera_distance())

func set_state(new_state: String) -> bool:
	# T07 passes the story flag value. Unknown names change nothing.
	if not new_state in STATES:
		return false
	state = new_state
	_retarget()
	if is_node_ready():
		_apply_levels()
		_apply_visibility()
		state_changed.emit(state)
	return true

func advance(delta: float) -> void:
	# Moves the flicker pattern. Other states hold a fixed level. Does not touch any node.
	if state != "flicker":
		return
	for i in levels.size():
		holds[i] -= delta
		if holds[i] > 0.0:
			continue
		var roll := rng.randf()
		if roll < 0.35: # Dropout.
			levels[i] = 0.0
			holds[i] = rng.randf_range(0.05, 0.6)
		elif roll < 0.55: # Weak glow.
			levels[i] = rng.randf_range(0.2, 0.7)
			holds[i] = rng.randf_range(0.05, 0.25)
		else:
			levels[i] = 1.0
			holds[i] = rng.randf_range(0.2, 1.5)

func apply_distance(distance: float) -> void:
	# Hysteresis: the site shows below handover - margin and hides above handover + margin.
	if site_active and distance > handover_distance + handover_margin:
		site_active = false
	elif not site_active and distance < handover_distance - handover_margin:
		site_active = true
	_apply_visibility()

func _retarget() -> void:
	var fixed := {"off": 0.0, "on": 1.0, "rain": RAIN_LEVEL, "flicker": 1.0}[state] as float
	for i in levels.size():
		levels[i] = fixed
		holds[i] = rng.randf_range(0.0, 1.0)

func _camera_distance() -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null or site == null:
		return INF
	var offset := camera.global_position - site.global_transform * Vector3(0, 0, -14)
	return Vector2(offset.x, offset.z).length()

func _apply_visibility() -> void:
	visible = state != "off" and not site_active
	if site != null:
		site.visible = site_active

func _apply_levels() -> void:
	for i in lamp_materials.size():
		lamp_materials[i].emission_energy_multiplier = lamp_energy * levels[i]
		var tint := halo_materials[i].albedo_color
		tint.a = HALO_ALPHA * levels[i]
		halo_materials[i].albedo_color = tint
		halos[i].visible = levels[i] > 0.01
	levels_changed.emit(levels)

func _build_lamps(model: Node3D) -> void:
	var glow := Gradient.new()
	glow.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	glow.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = glow
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	var emitters := model.find_children("*Lamp_Emitter*", "MeshInstance3D", true, false)
	emitters.sort_custom(func(a: Node, b: Node) -> bool: return str(a.name) < str(b.name))
	for emitter: MeshInstance3D in emitters:
		var material := (emitter.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		emitter.set_surface_override_material(0, material)
		lamp_materials.append(material)
		lamp_energy = material.emission_energy_multiplier
		# Additive glow quad that always faces the camera and ignores fog, so lights show through haze.
		var halo_material := StandardMaterial3D.new()
		halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		halo_material.albedo_texture = texture
		halo_material.albedo_color = Color(1.0, 0.8, 0.5, 0.0)
		halo_material.disable_fog = true
		halo_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var quad := QuadMesh.new()
		quad.size = Vector2(halo_size, halo_size)
		var halo := MeshInstance3D.new()
		halo.name = "Halo"
		halo.mesh = quad
		halo.material_override = halo_material
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		emitter.add_child(halo)
		halo_materials.append(halo_material)
		halos.append(halo)
	levels.resize(lamp_materials.size())
	holds.resize(lamp_materials.size())
