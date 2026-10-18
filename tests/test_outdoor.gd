extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func check_lighting_and_materials(controller, outdoor, player) -> void:
	check(player.floor_max_angle >= deg_to_rad(55.0) - 0.001, "Player cannot climb 50 degree slopes")
	# Grass and soil must not mirror the sun, moon or sky, dry or wet.
	for state in ["sunny", "storm"]:
		controller.set_preset(state)
		var shiny := 0
		for material in outdoor.terrain_materials:
			if material.metallic_specular > 0.0 or material.roughness < 1.0:
				shiny += 1
		check(outdoor.terrain_materials.size() > 0 and shiny == 0, "Terrain reflects light in " + state)
	controller.set_preset("storm")
	check(outdoor.terrain_materials[0].albedo_color.v < outdoor.terrain_colors[0].v, "Wet terrain is not darker")
	check(outdoor.wet_materials[0].roughness < 0.3, "Hard surface does not turn glossy when wet")
	controller.set_preset("sunny")
	check(outdoor.terrain_materials[0].albedo_color.is_equal_approx(outdoor.terrain_colors[0]), "Dry terrain colour not restored")
	var kinds := {}
	for species in outdoor.manifest.species:
		kinds["Species%d" % int(species.id)] = species.kind
	var shiny_plants := 0
	for node in outdoor.get_children():
		if node is MultiMeshInstance3D and kinds[str(node.name).get_slice("_", 0)] != "rock":
			for surface in node.multimesh.mesh.get_surface_count():
				if (node.multimesh.mesh.surface_get_material(surface) as StandardMaterial3D).metallic_specular > 0.0:
					shiny_plants += 1
	check(shiny_plants == 0, "Plants reflect light")
	controller.set_preset("day")
	check(controller.sun.visible and not controller.moon.visible, "Daylight should come from the sun only")
	check(controller.sun.rotation_degrees.x < -20.0, "Sun does not point downward at noon")
	controller.set_preset("night")
	check(controller.moon.visible and not controller.sun.visible, "Night light should come from the moon only")
	check(controller.moon.rotation_degrees.x < -20.0, "Moon does not point downward at midnight")
	controller.set_preset("day")

func simulate(controller, seed_value: int, steps: int) -> Dictionary:
	# Steps the automatic weather and clock by hand: 0.5 real seconds per step.
	controller.reseed(seed_value)
	controller.set_preset("sunny")
	controller.set_preset("day")
	var result := {"transitions": [], "illegal": 0, "jumps": 0, "bad_hour": 0, "max_rain": 0.0, "min_rain": 1.0}
	var last_weather: String = controller.weather
	var last_cloud: float = controller.cloud
	var last_rain: float = controller.rain_level
	var last_wet: float = controller.wetness
	for step in steps:
		controller.advance(0.5)
		if controller.weather != last_weather:
			var pair: String = last_weather + ">" + controller.weather
			result.transitions.append("%d %s" % [step, pair])
			if pair == "sunny>storm" or pair == "storm>sunny":
				result.illegal += 1
			last_weather = controller.weather
		# Nothing may jump: cloud, rain and wetness only move at their set speeds.
		if absf(controller.cloud - last_cloud) > controller.CLOUD_RISE * 0.5 + 0.0001:
			result.jumps += 1
		if absf(controller.rain_level - last_rain) > 0.03:
			result.jumps += 1
		if absf(controller.wetness - last_wet) > controller.WET_RATE * 0.5 + 0.0001:
			result.jumps += 1
		if controller.hour < 0.0 or controller.hour >= 24.0:
			result.bad_hour += 1
		result.max_rain = maxf(result.max_rain, controller.rain_level)
		result.min_rain = minf(result.min_rain, controller.rain_level)
		last_cloud = controller.cloud
		last_rain = controller.rain_level
		last_wet = controller.wetness
	return result

func check_automatic_climate(controller) -> void:
	check(absf(controller.sun_elevation(controller.SUNRISE)) < 0.01 and absf(controller.sun_elevation(controller.SUNSET)) < 0.01, "Sun height jumps at sunrise or sunset")
	check(controller.sun_elevation(12.25) > 45.0 and controller.sun_elevation(0.0) < -35.0, "Sun path is wrong")
	# Rain builds up gradually: drizzle first, then full storm. The sound swells with it.
	controller.set_preset("overcast")
	controller.weather = "storm"
	controller.weather_timer = 10000.0
	var rain_after_10 := 0.0
	var volume_after_10 := 0.0
	for second in 130:
		controller.advance(1.0)
		if second == 9:
			rain_after_10 = controller.rain_level
			controller._apply_rain()
			volume_after_10 = controller.rain_audio.volume_db
	controller._apply_rain()
	check(rain_after_10 > 0.0 and rain_after_10 < 0.1, "Rain does not start as drizzle: %f" % rain_after_10)
	check(controller.rain_level > 0.75, "Storm never reaches heavy rain")
	check(controller.rain_audio.volume_db > volume_after_10 + 10.0, "Rain sound does not swell")
	check(is_equal_approx(controller.rain_material.get_shader_parameter("density"), controller.rain_level), "Rain density not applied")
	check(controller.wetness > 0.9, "Ground did not get wet")
	# Clearing: the rain stops first, the ground dries much more slowly.
	controller.weather = "overcast"
	for second in 100:
		controller.advance(1.0)
	check(controller.rain_level == 0.0, "Rain did not stop after clearing")
	check(controller.wetness > 0.5 and controller.wetness < 0.95, "Ground dried too fast or not at all: %f" % controller.wetness)
	# Eight game days with a fixed seed.
	var first := simulate(controller, 20260607, 28800)
	check(first.illegal == 0, "Weather skipped overcast")
	check(first.jumps == 0, "Weather or rain jumped: %d" % first.jumps)
	check(first.bad_hour == 0, "Clock left 0 to 24")
	check(first.max_rain > 0.75 and first.min_rain == 0.0, "Eight days had no storm or no dry spell")
	for pair in ["sunny>overcast", "overcast>storm", "storm>overcast", "overcast>sunny"]:
		var found := false
		for item in first.transitions:
			found = found or item.ends_with(pair)
		check(found, "Never saw transition " + pair)
	var second := simulate(controller, 20260607, 28800)
	check(first.transitions == second.transitions, "Same seed gave a different weather sequence")
	var other := simulate(controller, 99, 28800)
	check(first.transitions != other.transitions, "Different seeds gave the same weather sequence")

func run() -> void:
	var world = load("res://scenes/world/world.tscn").instantiate()
	world.get_node("Player").capture_on_start = false
	root.add_child(world)
	var player = world.get_node("Player")
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	var outdoor = world.get_node("Outdoor")
	var controller = world.get_node("Environment")
	controller.auto_progress = false # Presets are checked in a frozen state. The simulation is stepped by hand below.
	check(controller.has_method("set_preset"), "Environment interface missing")
	if not controller.has_method("set_preset"):
		quit(1)
		return
	for time in ["day", "night"]:
		check(controller.set_preset(time), "Time preset rejected")
		for weather in ["sunny", "overcast", "storm"]:
			check(controller.set_preset(weather), "Weather preset rejected")
			await process_frame
			check(controller.weather == weather and controller.time_of_day == time, "Preset state mismatch")
			check(controller.rain.emitting == (weather == "storm"), "Rain state mismatch")
			check(controller.rain_audio.playing == (weather == "storm"), "Audio state mismatch")
			check(is_equal_approx(outdoor.wet_materials[0].roughness, 0.23 if weather == "storm" else 0.9), "Wetness state mismatch")
	check(not controller.set_preset("invalid"), "Invalid preset accepted")
	check(controller.weather == "storm" and controller.time_of_day == "night", "Invalid preset changed state")
	controller.set_preset("sunny")
	controller.set_preset("day")
	check_lighting_and_materials(controller, outdoor, player)
	check_automatic_climate(controller)
	controller.auto_progress = true
	var hour_before: float = controller.hour
	await process_frame
	await process_frame
	check(controller.hour != hour_before, "Clock does not run on its own")
	controller.auto_progress = false
	controller.set_preset("sunny")
	controller.set_preset("day")
	var near_count := 0
	var far_count := 0
	for node in outdoor.get_children():
		if node is MultiMeshInstance3D:
			check(node.visibility_range_end > node.visibility_range_begin, "Invalid LOD range")
			if str(node.name).ends_with("Near"):
				near_count += node.multimesh.instance_count
			else:
				far_count += node.multimesh.instance_count
	check(near_count == outdoor.manifest.instance_count and far_count == near_count, "Missing vegetation instances")
	check(outdoor.get_node("Boundary").get_child_count() == 4, "Boundary missing")
	check(outdoor.get_node("Trunks").get_child_count() > 0, "Tree collisions missing")
	check(outdoor.get_node("Rocks").get_child_count() > 0, "Rock collisions missing")
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var bounds: Array = outdoor.manifest.bounds_xz
	for ix in range(1, 12):
		for iz in range(1, 12):
			var x := lerpf(bounds[0], bounds[2], ix / 12.0)
			var z := lerpf(bounds[1], bounds[3], iz / 12.0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -20, z), 1))
			check(not hit.is_empty(), "Terrain collision hole at %s" % Vector2(x, z))
	for z in [4.4, 5.0, 6.0, 6.6, 8.0]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-1.135, 1, z), Vector3(-1.135, -2, z), 1))
		check(not hit.is_empty(), "Porch transition has a hole")
		if not hit.is_empty():
			print("Porch ground at z=", z, ": ", hit.position.y)
	# Exercise the same CharacterBody path through the door and down the ramp.
	player.position = Vector3(-1.135, 0.035, 2.7)
	player.rotation = Vector3.ZERO
	player.set_physics_process(true)
	Input.action_press("move_back")
	for i in 155:
		await physics_frame
	Input.action_release("move_back")
	check(player.position.z > 8.0, "Player could not leave porch: " + str(player.position))
	check(player.is_on_floor(), "Player fell off outdoor transition")
	Input.action_press("move_forward")
	for i in 155:
		await physics_frame
	Input.action_release("move_forward")
	check(player.position.z < 3.0 and player.position.y > 0.0, "Player could not return inside: " + str(player.position))
	player.set_physics_process(false)
	for point in [Vector3(bounds[0] + 1, 0, 0), Vector3(bounds[2] - 1, 0, 0), Vector3(0, 0, bounds[1] + 1), Vector3(0, 0, bounds[3] - 1)]:
		player.position = point
		var direction := Vector3(-2, 0, 0) if point.x < 0 else Vector3(2, 0, 0)
		if point.x == 0:
			direction = Vector3(0, 0, -2 if point.z < 0 else 2)
		check(player.test_move(player.global_transform, direction), "Map boundary not blocking")
	world.queue_free()
	await process_frame
	print("T06 outdoor logic: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
