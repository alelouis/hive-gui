extends Node


func _ready():
	var scene
	var result
	var error
	var node = Node3D.new()
	add_child(node)
	
	var bugs = ["ant", "bee", "beetle", "grasshopper", "spider"]
	var piece_scene = load("res://bugs/piece_black.tscn").instantiate()
	var names = {
		"ant": "A",
		"bee": "Q",
		"beetle": "B",
		"grasshopper": "G",
		"spider": "S"}
	
	node.add_child(piece_scene)
	piece_scene.owner = node
	
	var bugs_scenes = {}
	var bug_scene
	for bug in bugs:
		bug_scene = load("res://bugs/%s.tscn"%bug).instantiate()
		bug_scene.set_position(Vector3(0, 0.470, 0))
		bug_scene.set_scale(Vector3(1.2, 1.2, 1.2))
		print(bug_scene.get_children()[0])
		
		bugs_scenes[bug] = bug_scene
		node.add_child(bugs_scenes[bug])
	
	
	for bug in bugs:
		bugs_scenes[bug].owner = node
		scene = PackedScene.new()
		result = scene.pack(node)
		if result == OK:
			error = ResourceSaver.save(scene, "res://bugs/black/b%s.tscn"%names[bug])  # Or "user://..."
			if error != OK:
				push_error("An error occurred while saving the scene to disk.")
		bugs_scenes[bug].owner = null
