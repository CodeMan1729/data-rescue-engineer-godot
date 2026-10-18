extends SceneTree

# Load GLBs directly: no world integration or editor-generated import files.
func _init() -> void:
	for asset in ["mine_site", "mine_vista"]:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var result := document.append_from_file("res://assets/mine/" + asset + ".glb", state)
		if result != OK:
			push_error("GLB load failed: " + asset)
			quit(1)
			return
		var instance := document.generate_scene(state)
		if instance == null:
			push_error("GLB scene generation failed: " + asset)
			quit(1)
			return
		root.add_child(instance)
		var lamps := instance.find_children("*Lamp*Emitter*", "MeshInstance3D", true, false)
		if lamps.size() != 4:
			push_error("Expected four lamp emitters: " + asset)
			quit(1)
			return
		if asset == "mine_site":
			var computer := instance.find_child("MN_Interact_Computer", true, false) as Node3D
			if computer == null or not computer.position.is_equal_approx(Vector3(-8, 1.35, -8.85)):
				push_error("Computer marker or Y-up conversion mismatch")
				quit(1)
				return
			if instance.find_children("MN_Collision_*", "", true, false).is_empty():
				push_error("Collision markers missing")
				quit(1)
				return
		print("T13A_GODOT_LOAD_OK: ", asset)
		instance.free()
	quit(0)
