extends SceneTree

# T13b headless checks: mine placement, collision and interaction markers, MineVista.set_state(),
# MineSite.set_open(), vegetation clearing, terrain fit and a real walk to the camp.
# The walk needs about 4,000 physics frames. Run with --fixed-fps 60 to finish in seconds:
#   Godot --headless --path . --fixed-fps 60 --script res://tests/test_mine.gd

const COLLISION_NAMES := [
	"Adit_Closed", "Cart", "Dispatch_Desk", "Dispatch_Front_-1", "Dispatch_Front_1", "Dispatch_Rear",
	"Dispatch_Side_-1", "Dispatch_Side_1", "FrontFence_-1", "FrontFence_1", "FuelDrums", "Gate_Leaf_-1",
	"Gate_Leaf_1", "Generator", "Ground", "RearRock_-1", "RearRock_1", "Winch", "WinchHouse_Front_-1",
	"WinchHouse_Front_1", "WinchHouse_Rear", "WinchHouse_Side_-1", "WinchHouse_Side_1"]
const INTERACT_NAMES := ["Adit", "Computer", "Gate", "Generator", "MineCart", "TornSeal", "WarningSign", "WinchControl"]

var failures := 0
var world: Node3D
var player: CharacterBody3D
var vista: MineVista
var site: MineSite
var outdoor: Node3D

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle(frames: int = 2) -> void:
	for i in frames:
		await physics_frame

func site_point(local: Vector3) -> Vector3:
	return site.to_global(local)

func put_player(local: Vector3) -> void:
	player.global_position = site_point(local)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO

func lamp_energies() -> Array:
	var values := []
	for material in vista.lamp_materials:
		values.append(material.emission_energy_multiplier)
	return values

func check_structure() -> void:
	check(vista != null and site != null, "MineVista or MineSite node missing")
	var collision_nodes := site.model.find_children("MN_Collision_*", "Node3D", true, false)
	var interact_nodes := site.model.find_children("MN_Interact_*", "Node3D", true, false)
	check(collision_nodes.size() == COLLISION_NAMES.size(), "Expected 23 MN_Collision_* nodes, got %d" % collision_nodes.size())
	check(interact_nodes.size() == INTERACT_NAMES.size(), "Expected 8 MN_Interact_* nodes, got %d" % interact_nodes.size())
	for name in COLLISION_NAMES:
		var marker := site.model.find_child("MN_Collision_" + name, true, false) as Node3D
		var shape_node := site.get_node_or_null("Collisions/MN_Collision_" + name) as CollisionShape3D
		check(marker != null, "Missing marker MN_Collision_" + name)
		check(shape_node != null, "Missing collision shape MN_Collision_" + name)
		if marker != null and shape_node != null:
			var size: Vector3 = (shape_node.shape as BoxShape3D).size
			check(size.is_equal_approx(marker.global_transform.basis.get_scale().abs() * 2.0), "Wrong box size: " + name)
			check(shape_node.global_position.is_equal_approx(marker.global_position), "Wrong box position: " + name)
			check(shape_node.scale.is_equal_approx(Vector3.ONE), "Box node scaled twice: " + name)
	check(site.get_node("Collisions").collision_layer == 1, "Camp collisions must be on the environment layer")
	for name in INTERACT_NAMES:
		var marker := site.model.find_child("MN_Interact_" + name, true, false) as Node3D
		var area := site.get_node_or_null("Interactables/" + name) as Interactable
		check(marker != null and area != null, "Missing interaction marker or area: " + name)
		if marker != null and area != null:
			check(area.global_position.is_equal_approx(marker.global_position), "Interaction area off its marker: " + name)
			check(area.collision_layer == 2 and not area.prompt_text.is_empty() and area.enabled, "Bad interaction area: " + name)
			check(area.get_node("Target") is CollisionShape3D, "Interaction area has no shape: " + name)
	check(vista.lamp_materials.size() == 4 and vista.halos.size() == 4, "Vista needs four lamps")
	check(site.lamp_materials.size() == 4 and site.lamp_lights.size() == 4, "Site needs four lamps and lights")
	var lamp_meshes := vista.find_children("*Lamp_Emitter*", "MeshInstance3D", true, false).size() + site.find_children("*Lamp_Emitter*", "MeshInstance3D", true, false).size()
	check(lamp_meshes == 8, "Expected eight lamp emitter meshes")

func check_vista_states() -> void:
	var seen: Array = []
	vista.state_changed.connect(func(value: String) -> void: seen.append(value))
	vista.set_process(false) # Step the lamps by hand.
	vista.apply_distance(200.0)
	check(vista.state == "off" and not vista.visible, "Vista should start off and hidden")
	check(lamp_energies().all(func(value: float) -> bool: return value == 0.0), "Lamps lit while off")
	check(not site.visible, "Site must be hidden while the player is far away")
	check(vista.set_state("on") and vista.state == "on" and vista.visible, "State on rejected or vista hidden")
	check(lamp_energies().all(func(value: float) -> bool: return is_equal_approx(value, vista.lamp_energy)), "Lamps not at full energy in state on")
	check(site.lamp_lights.all(func(light: OmniLight3D) -> bool: return light.visible and is_equal_approx(light.light_energy, site.LAMP_LIGHT_ENERGY)), "Site lights do not follow state on")
	check(vista.halos.all(func(halo: MeshInstance3D) -> bool: return halo.visible), "Halos hidden while on")
	check(vista.set_state("rain"), "State rain rejected")
	var rain_energy: float = lamp_energies()[0]
	check(rain_energy > 0.0 and rain_energy < vista.lamp_energy, "Rain lamps should be dim but lit")
	check(site.lamp_materials[0].emission_energy_multiplier < site.lamp_energy and site.lamp_lights[0].visible, "Site lamps do not follow state rain")
	check(vista.set_state("off") and not vista.visible, "State off must hide the vista")
	check(site.lamp_lights.all(func(light: OmniLight3D) -> bool: return not light.visible), "Site lights burn while off")
	var before := vista.state
	check(not vista.set_state("bogus") and not vista.set_state("") and vista.state == before, "Invalid state accepted")
	check(seen == ["on", "rain", "off"], "state_changed sequence wrong: " + str(seen))
	# Flicker: dropouts, weak glow and full glow. Lamps are independent. Same seed gives the same pattern.
	var traces: Array = []
	for run in 2:
		vista.rng.seed = 424242
		check(vista.set_state("flicker") and vista.visible, "State flicker rejected")
		var low := 1.0
		var high := 0.0
		var changes := 0
		var apart := 0
		var last := vista.levels.duplicate()
		var trace := 0.0
		for step in 2400: # Two minutes in 0.05 s steps.
			vista.advance(0.05)
			vista._apply_levels()
			for i in 4:
				low = minf(low, vista.levels[i])
				high = maxf(high, vista.levels[i])
				trace += vista.levels[i] * (step + 1) * (i + 1)
			if vista.levels != last:
				changes += 1
			if not (is_equal_approx(vista.levels[0], vista.levels[1]) and is_equal_approx(vista.levels[1], vista.levels[2])):
				apart += 1
			last = vista.levels.duplicate()
		check(low == 0.0 and high == 1.0, "Flicker never reached full dropout or full glow")
		check(changes > 100 and apart > 100, "Flicker too calm: %d changes, %d divergent" % [changes, apart])
		check(site.lamp_levels == vista.levels, "Site lamps lag behind the far view")
		traces.append(trace)
	check(is_equal_approx(traces[0], traces[1]), "Same seed gave different flicker")
	vista.set_state("on")
	vista.advance(10.0)
	check(vista.levels == PackedFloat32Array([1, 1, 1, 1]), "State on must not flicker")
	# Hand-over between the far view and the detailed camp.
	vista.apply_distance(200.0)
	check(vista.visible and not site.visible, "Far: vista should show, site hide")
	vista.apply_distance(87.0)
	check(vista.visible and not site.visible, "Dead band flipped while far")
	vista.apply_distance(70.0)
	check(not vista.visible and site.visible, "Near: site should show, vista hide")
	vista.apply_distance(87.0)
	check(not vista.visible and site.visible, "Dead band flipped while near")
	vista.apply_distance(95.0)
	check(vista.visible and not site.visible, "Far again: vista should show")
	vista.apply_distance(10.0)
	vista.set_state("off")
	check(not vista.visible and site.visible, "Off must hide the vista, site stays")
	vista.set_state("on")
	player.global_position = Vector3(0, 0.04, 2.1)
	check(vista._camera_distance() > 100.0, "Station should be far from the camp: %f" % vista._camera_distance())
	put_player(Vector3(0, 0, 8))
	check(vista._camera_distance() < 30.0, "Gate should be near the camp: %f" % vista._camera_distance())
	vista.apply_distance(200.0)
	vista.set_state("off")

func in_rect(rect: Rect2, point: Vector3) -> bool:
	return rect.has_point(Vector2(point.x, point.z))

func check_clearing() -> void:
	check(outdoor.clearings.size() == 1, "Outdoor should know exactly one clearing")
	var rect: Rect2 = outdoor.clearings[0]
	var expected := Rect2(site.global_position.x - 21.0, site.global_position.z - 33.0, 42.0, 41.0)
	check(rect.position.is_equal_approx(expected.position) and rect.size.is_equal_approx(expected.size), "Clearing rect is wrong: " + str(rect))
	check(outdoor.cleared_instances > 0 and outdoor.cleared_instances < 400, "Implausible cleared count: %d" % outdoor.cleared_instances)
	# The cleared count must equal the source instances inside the rect, and the rest must all be built.
	var inside := 0
	for species_id in outdoor.manifest.instances:
		for values in outdoor.manifest.instances[species_id]:
			if rect.has_point(Vector2(values[9], values[11])):
				inside += 1
	check(inside == outdoor.cleared_instances, "Cleared %d instances, source has %d inside the rect" % [outdoor.cleared_instances, inside])
	var built := 0
	for node in outdoor.get_children():
		if node is MultiMeshInstance3D and str(node.name).ends_with("Near"):
			built += node.multimesh.instance_count
	check(built == outdoor.manifest.instance_count - inside, "Vegetation built: %d, expected %d" % [built, outdoor.manifest.instance_count - inside])
	print("Clearing %s removed %d of %d vegetation instances" % [str(rect), inside, outdoor.manifest.instance_count])
	var colliders := 0
	for body_name in ["Trunks", "Rocks"]:
		for collider in outdoor.get_node(body_name).get_children():
			if in_rect(rect, collider.position):
				colliders += 1
	check(colliders == 0, "%d tree or rock colliders remain inside the camp clearing" % colliders)

func terrain_y(space: PhysicsDirectSpaceState3D, point: Vector3, exclude: Array[RID]) -> float:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 60.0, point + Vector3.DOWN * 30.0, 1, exclude)
	var hit := space.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else NAN

func ground_exclusions() -> Array[RID]:
	var rids: Array[RID] = [site.get_node("Collisions").get_rid(), site.closure.get_rid()]
	for body_name in ["Trunks", "Rocks", "Boundary"]:
		rids.append(outdoor.get_node(body_name).get_rid())
	return rids

func check_terrain_fit(space: PhysicsDirectSpaceState3D) -> void:
	# The pad must sit flush on the plain: no terrain through the floor, no gap under it.
	var pad_y := site.global_position.y
	var worst_gap := 0.0
	var worst_poke := -99.0
	var floor_misses := 0
	for ix in range(-16, 17, 2):
		for iz in range(2, -27, -2):
			var local := Vector3(ix, 0, iz)
			var ground := terrain_y(space, site_point(local), ground_exclusions())
			var top := terrain_y(space, site_point(local), [] as Array[RID])
			worst_gap = maxf(worst_gap, pad_y - ground)
			worst_poke = maxf(worst_poke, ground - pad_y)
			# Props (desk, generator, cart) may stand above the pad. Nothing may leave it without a floor.
			if iz <= 0 and (is_nan(top) or top < pad_y - 0.02):
				floor_misses += 1
	check(worst_gap < 0.15, "Pad floats %f m above the terrain" % worst_gap)
	check(worst_poke < 0.02, "Terrain pokes %f m through the pad" % worst_poke)
	check(floor_misses == 0, "%d camp points have no pad floor under them" % floor_misses)
	for ix in range(-18, 19, 4):
		var rear := terrain_y(space, site_point(Vector3(ix, 0, -31)), ground_exclusions())
		check(rear - pad_y < 4.5, "Hill behind the rear rock is too high at x=%d" % ix)
	print("Pad y %.2f, terrain gap up to %.3f m, poke up to %.3f m" % [pad_y, worst_gap, maxf(worst_poke, 0.0)])

func blocked(motion: Vector3) -> bool:
	return player.test_move(player.global_transform, motion)

func check_closure() -> void:
	var events: Array = []
	site.open_changed.connect(func(value: bool) -> void: events.append(value))
	# Until T07 sets the flag, world.tscn starts the camp open so the player can look round.
	check(site.is_open(), "World scene should start with the camp open")
	for toggle in 2: # Close again after opening: the gate must work both ways.
		site.set_open(false)
		await settle()
		put_player(Vector3(0, 0.03, 3.0))
		check(blocked(Vector3(0, 0, -6)), "Closed camp: the gate path is open")
		put_player(Vector3(-5, 0.03, 3.0))
		check(blocked(Vector3(0, 0, -6)), "Closed camp: the fence line is open")
		put_player(Vector3(22, 0.03, -10))
		check(blocked(Vector3(-6, 0, 0)), "Closed camp: the east side is open")
		put_player(Vector3(-22, 0.03, -10))
		check(blocked(Vector3(6, 0, 0)), "Closed camp: the west side is open")
		put_player(Vector3(22, 0.03, 3))
		check(blocked(Vector3(-6, 0, -6)), "Closed camp: cannot slip round the east fence end")
		site.set_open(true)
		await settle()
		put_player(Vector3(0, 0.03, 3.0))
		check(not blocked(Vector3(0, 0, -6)), "Open camp: the gate path is still blocked")
		put_player(Vector3(22, 0.03, -10))
		check(not blocked(Vector3(-6, 0, 0)), "Open camp: the east side is still blocked")
	site.set_open(false)
	await settle()
	check(events == [false, true, false, true, false], "open_changed sequence wrong: " + str(events))

func aim(local_from: Vector3, local_target: Vector3) -> void:
	put_player(local_from)
	player.camera.look_at(site_point(local_target))

func check_interactions(space: PhysicsDirectSpaceState3D) -> void:
	# Every area can be hit by a ray from above. Occlusion is checked with real camera views below.
	for name in INTERACT_NAMES:
		var area := site.get_node("Interactables/" + name) as Interactable
		var query := PhysicsRayQueryParameters3D.create(area.global_position + Vector3.UP * 4.0, area.global_position, 2)
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		check(not hit.is_empty() and hit.collider == area, "Ray from above misses area: " + name)
	var gate := site.get_node("Interactables/Gate") as Interactable
	var seal := site.get_node("Interactables/TornSeal") as Interactable
	var computer := site.get_node("Interactables/Computer") as Interactable
	# Closed camp: the gate and the seal work from the nearest spot outside. The interior stays out of reach.
	site.set_open(false)
	await settle()
	aim(Vector3(0, 0.03, 1.75), Vector3(0, 1.2, 0))
	check(player.find_interactable() == gate, "Closed camp: gate not usable at the wall")
	player.update_interaction()
	check(player.prompt.text == site.PROMPTS["Gate"], "Gate prompt mismatch")
	aim(Vector3(0, 0.03, 4.0), Vector3(0, 1.2, 0))
	check(player.find_interactable() == gate, "Closed camp: gate not usable from 4 m")
	aim(Vector3(-2.8, 0.03, 2.0), Vector3(-2.8, 1.35, -0.3))
	check(player.find_interactable() == seal, "Closed camp: torn seal not usable at the wall")
	aim(Vector3(-8, 0.03, 2.0), Vector3(-8, 1.35, -8.85))
	check(player.find_interactable() != computer, "Closed camp: computer usable through the wall")
	# Open camp: step inside the dispatch hut and use the computer.
	site.set_open(true)
	await settle()
	var events: Array = []
	site.interacted.connect(func(key: String, who: Node3D) -> void: events.append([key, who]))
	aim(Vector3(-8, 0.03, -7.0), Vector3(-8, 1.35, -8.85))
	check(player.find_interactable() == computer, "Open camp: computer not usable from inside the hut")
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	player._unhandled_input(press)
	check(events.size() == 1 and events[0][0] == "Computer" and events[0][1] == player, "interacted signal wrong: " + str(events))
	check("Computer" in player.status.text, "Placeholder feedback missing")
	computer.enabled = false
	player.update_interaction()
	check(player.target == null, "Disabled mine area still shown")
	computer.enabled = true
	site.set_open(false)
	await settle()

func check_sightlines(space: PhysicsDirectSpaceState3D) -> void:
	# Terrain only. Real trees are taller than their 2.5 m collision stubs, so they are not judged here.
	var eyes := {"front window": Vector3(0.95, 1.48, 3.2), "doorway": Vector3(-1.135, 1.5, 3.3)}
	var trunk_blocked := 0
	for label in eyes:
		for halo in vista.halos:
			var target := halo.global_position
			var query := PhysicsRayQueryParameters3D.create(eyes[label], target, 1, ground_exclusions())
			var terrain_hit := space.intersect_ray(query)
			check(terrain_hit.is_empty(), "Terrain hides a lamp from the %s at %s" % [label, str(terrain_hit.get("position", ""))])
			var without_trunks := ground_exclusions()
			without_trunks.erase(outdoor.get_node("Trunks").get_rid())
			var trunk_query := PhysicsRayQueryParameters3D.create(eyes[label], target, 1, without_trunks)
			if not space.intersect_ray(trunk_query).is_empty():
				trunk_blocked += 1
	print("Sight lines from the station to the four lamps blocked only by tree-trunk stubs: %d of 8" % trunk_blocked)
	var window_eye: Vector3 = eyes["front window"]
	var distance: float = (vista.halos[0].global_position - window_eye).length()
	print("Distance from the front window to the first lamp: %.0f m" % distance)

func mark_box(grid: AStarGrid2D, center: Vector2, half: Vector2) -> void:
	for x in range(floori(center.x - half.x), ceili(center.x + half.x) + 1):
		for z in range(floori(center.y - half.y), ceili(center.y + half.y) + 1):
			if grid.is_in_boundsv(Vector2i(x, z)):
				grid.set_point_solid(Vector2i(x, z), true)

func plan_route(from_xz: Vector2, to_xz: Vector2) -> Array:
	# Grid search round every trunk, rock and the whole camp. Only plans; the walk below is real physics.
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-10, 0, 135, 125)
	grid.cell_size = Vector2.ONE
	grid.offset = Vector2(0.5, 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for collider in outdoor.get_node("Trunks").get_children():
		var reach: float = (collider.shape as CylinderShape3D).radius + 0.22 + 0.4
		mark_box(grid, Vector2(collider.position.x, collider.position.z), Vector2.ONE * reach)
	for collider in outdoor.get_node("Rocks").get_children():
		var half: Vector3 = (collider.shape as BoxShape3D).size * 0.5
		mark_box(grid, Vector2(collider.position.x, collider.position.z), Vector2(half.x, half.z) + Vector2.ONE * 0.65)
	mark_box(grid, Vector2(site.global_position.x, site.global_position.z - 14.0), Vector2(19.0, 17.0))
	var start := Vector2i(floori(from_xz.x), floori(from_xz.y))
	var goal := Vector2i(floori(to_xz.x), floori(to_xz.y))
	# The ends are known to be open, so free a small patch round each. The inflated margins may seal them.
	for end in [start, goal]:
		for x in range(end.x - 1, end.x + 2):
			for z in range(end.y - 1, end.y + 2):
				if grid.is_in_boundsv(Vector2i(x, z)):
					grid.set_point_solid(Vector2i(x, z), false)
	var raw := grid.get_point_path(start, goal)
	var route: Array = []
	for i in raw.size():
		if i == 0 or i == raw.size() - 1:
			route.append(raw[i])
		else:
			var before := (raw[i] - raw[i - 1]).normalized()
			var after := (raw[i + 1] - raw[i]).normalized()
			if not before.is_equal_approx(after):
				route.append(raw[i])
	return route

func walk(route: Array, label: String) -> bool:
	# Drives the real Player through the waypoints: yaw towards the next one, forward key held.
	player.set_physics_process(true)
	var frames := 0
	var lowest := 99.0
	var ok := true
	for target: Vector2 in route:
		var mark := player.global_position
		var mark_frame := frames
		while ok:
			var flat := Vector2(target.x - player.global_position.x, target.y - player.global_position.z)
			if flat.length() < 0.5:
				break
			player.rotation.y = atan2(-flat.x, -flat.y)
			Input.action_press("move_forward")
			await physics_frame
			frames += 1
			lowest = minf(lowest, player.global_position.y)
			if player.global_position.y < -3.5:
				check(false, "%s: player fell to y=%f near %s" % [label, player.global_position.y, str(target)])
				ok = false
			elif frames - mark_frame >= 120:
				if player.global_position.distance_to(mark) < 0.6:
					check(false, "%s: player stuck at %s heading for %s" % [label, str(player.global_position), str(target)])
					ok = false
				mark = player.global_position
				mark_frame = frames
		if not ok:
			break
	Input.action_release("move_forward")
	player.set_physics_process(false)
	print("%s: %d frames (%.0f s), lowest y %.2f, end %s" % [label, frames, frames / 60.0, lowest, str(player.global_position)])
	return ok

func push_forward(frames: int) -> void:
	player.set_physics_process(true)
	player.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	for i in frames:
		await physics_frame
	Input.action_release("move_forward")
	player.set_physics_process(false)

func local_route(points: Array) -> Array:
	var route: Array = []
	for point: Vector2 in points:
		var world_point := site_point(Vector3(point.x, 0, point.y))
		route.append(Vector2(world_point.x, world_point.z))
	return route

func check_walk() -> void:
	site.set_open(false)
	await settle()
	player.global_position = Vector3(-1.135, 0.04, 8.0)
	player.velocity = Vector3.ZERO
	var gate_approach := site_point(Vector3(0, 0, 4.0))
	var route := plan_route(Vector2(-1.135, 8.0), Vector2(gate_approach.x, gate_approach.z))
	check(route.size() >= 2, "No route from the porch to the camp gate")
	if route.size() < 2:
		return
	if not await walk(route, "Closed camp, porch to gate"):
		return
	var arrival := site.to_local(player.global_position)
	check(Vector2(arrival.x, arrival.z).distance_to(Vector2(0, 4.0)) < 1.0, "Did not reach the gate approach: " + str(arrival))
	check(player.is_on_floor(), "Player not on the floor at the gate")
	await push_forward(150) # Walk straight at the gate. The closed camp must stop the player.
	arrival = site.to_local(player.global_position)
	check(arrival.z > 1.6 and arrival.z < 4.0, "Closed camp did not stop the player at the gate: " + str(arrival))
	site.set_open(true)
	await settle()
	await push_forward(240)
	arrival = site.to_local(player.global_position)
	check(arrival.z < -1.5 and absf(arrival.x) < 1.0, "Open camp: player did not pass the gate: " + str(arrival))
	check(player.is_on_floor() and absf(player.global_position.y - site.global_position.y) < 0.1, "Player left the camp floor at the gate")
	# Inside: round the mine cart to the adit, then back out and into the dispatch hut.
	if not await walk(local_route([Vector2(0, -2), Vector2(2.5, -10), Vector2(2.5, -24), Vector2(0, -25.0)]), "Gate to adit"):
		return
	arrival = site.to_local(player.global_position)
	check(Vector2(arrival.x, arrival.z).distance_to(Vector2(0, -25.0)) < 1.0 and arrival.z > -27.0, "Did not reach the adit front: " + str(arrival))
	if not await walk(local_route([Vector2(2.5, -24), Vector2(2.5, -10), Vector2(0, -2), Vector2(-8, -3.5), Vector2(-8, -7.0)]), "Adit to dispatch hut"):
		return
	arrival = site.to_local(player.global_position)
	check(Vector2(arrival.x, arrival.z).distance_to(Vector2(-8, -7.0)) < 1.0, "Did not reach the hut interior: " + str(arrival))
	check(player.is_on_floor() and absf(player.global_position.y - site.global_position.y) < 0.1, "Player not on the hut floor")
	site.set_open(false)

func run() -> void:
	world = load("res://scenes/world/world.tscn").instantiate()
	world.get_node("Player").capture_on_start = false
	root.add_child(world)
	player = world.get_node("Player")
	player.set_physics_process(false)
	world.get_node("Environment").auto_progress = false
	await settle()
	vista = world.get_node("Mine/MineVista")
	site = world.get_node("Mine/MineSite")
	outdoor = world.get_node("Outdoor")
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	check_structure()
	check_vista_states()
	check_clearing()
	check_terrain_fit(space)
	await check_closure()
	await check_interactions(space)
	check_sightlines(space)
	await check_walk()
	world.queue_free()
	await process_frame
	print("T13b mine checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
