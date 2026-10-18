extends SceneTree

var failures: int = 0
var signal_count: int = 0
var signal_player: Node3D

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/world/world.tscn").instantiate()
	world.get_node("Player").capture_on_start = false
	root.add_child(world)
	var player = world.get_node("Player")
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(world.get_node("Station").get_child_count() > 0, "Station missing")
	var collisions = world.get_node("Collisions")
	check(collisions.get_child_count() < 50, "Too many collision shapes")
	for key in ["Floor", "Threshold", "WallWest", "WallEast", "WallBack", "Workbench", "Bed", "Rack", "OpenDoor", "MS_Chair_Wood", "MS_Chair_Folding"]:
		check(collisions.has_node(key), "Missing collision: " + key)
	for action in ["move_forward", "move_back", "move_left", "move_right", "move_slow", "interact", "pause", "look_left", "look_right", "look_up", "look_down"]:
		check(InputMap.has_action(action), "Missing action: " + action)
	var prompts := {
		"Computer": "按 E 使用电脑", "Fax": "按 E 查看传真机",
		"Radio": "按 E 使用电台", "Map": "按 E 查看地图", "Manual": "按 E 阅读手册"
	}
	check(world.get_node("Interactables").get_child_count() == 5, "Expected five targets")
	for key in prompts:
		var target = world.get_node("Interactables/" + key)
		var center: Vector3 = target.get_node("Target").global_position
		player.position = Vector3(0, 0.03, center.z)
		player.camera.look_at(center)
		check(player.find_interactable() == target, "Ray failed: " + key)
		player.update_interaction()
		check(player.prompt.text == prompts[key], "Prompt mismatch: " + key)
		target.interacted.connect(on_interacted)
		var previous := signal_count
		var event := InputEventAction.new()
		event.action = "interact"
		event.pressed = true
		player._unhandled_input(event)
		check(signal_count == previous + 1 and signal_player == player, "Signal failed: " + key)
		check(key in player.status.text, "Placeholder feedback failed: " + key)
		target.enabled = false
		player.update_interaction()
		target.interact(player)
		check(player.target == null and player.prompt.text.is_empty(), "Disabled target still shown: " + key)
		check(signal_count == previous + 1, "Disabled target emitted signal")
		target.enabled = true
		player.position.x = 5
		player.camera.look_at(center)
		check(player.find_interactable() == null, "Out-of-range interaction: " + key)
		# Place an actual physics wall between the camera and the target.
		player.position = Vector3(0, 0.03, center.z)
		player.camera.look_at(center)
		var blocker := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.1, 3, 0.5)
		shape_node.shape = shape
		blocker.add_child(shape_node)
		world.add_child(blocker)
		blocker.position = Vector3(-0.3, 1, center.z)
		await physics_frame
		await physics_frame
		check(player.find_interactable() == null, "Interaction through wall: " + key)
		blocker.queue_free()
		await physics_frame
		await physics_frame
	player.position = Vector3(0, 0.03, 0)
	check(player.test_move(player.global_transform, Vector3(4, 0, 0)), "East wall not blocking")
	check(player.test_move(player.global_transform, Vector3(0, 0, -4)), "Back wall not blocking")
	check(player.test_move(player.global_transform, Vector3(0, -1, 0)), "Floor not blocking")
	player.position = Vector3(-1.135, 0.035, 2.7)
	check(not player.test_move(player.global_transform, Vector3(0, 0, 1.2)), "Doorway/threshold blocks exit")
	player.position.z = 3.9
	check(not player.test_move(player.global_transform, Vector3(0, 0, -1.2)), "Doorway/threshold blocks entry")
	check(player.test_move(player.global_transform, Vector3(0, 0, 1)), "Porch boundary missing")
	player.position = Vector3(0, 0.5, 0)
	player.set_physics_process(true)
	for i in 60:
		await physics_frame
	check(player.is_on_floor() and absf(player.position.y - 0.03) < 0.02, "Player did not settle on floor")
	player.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	for i in 10:
		await physics_frame
	check(player.position.z < -0.2 and is_equal_approx(player.velocity.length(), player.walk_speed), "Forward walking failed")
	Input.action_press("move_slow")
	for i in 3:
		await physics_frame
	check(is_equal_approx(player.velocity.length(), player.slow_speed), "Slow walking failed")
	Input.action_release("move_forward")
	Input.action_release("move_slow")
	var pause_event := InputEventAction.new()
	pause_event.action = "pause"
	pause_event.pressed = true
	player._unhandled_input(pause_event)
	check(not player.controls_enabled and player.target == null, "Pause did not disable controls")
	player._unhandled_input(pause_event)
	check(player.controls_enabled, "Resume did not restore controls")
	world.queue_free()
	await process_frame
	print("T04 physics and interaction checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func on_interacted(player: Node3D) -> void:
	signal_count += 1
	signal_player = player
