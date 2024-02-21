extends Node3D

var dragging = false
var rotation_sensitivity = 0.005 
var scroll_sensitivity = 0.05

var scroll_level = 0
var camera_init_position

func _ready():
	camera_init_position = %Camera3D.position

func _input(event):

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		dragging = event.pressed

	if event is InputEventMouseMotion and dragging:
		rotation.y -= event.relative.x*rotation_sensitivity
		rotation.x -= event.relative.y*rotation_sensitivity
		rotation.x = clamp(rotation.x,0,PI/2.0)

	if event is InputEventMouseButton:
		var pos = %Camera3D.position
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			%Camera3D.position -= scroll_sensitivity * pos
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			%Camera3D.position += scroll_sensitivity * pos


func compute_mean_position(name_to_instances):
	var mean_x = 0.0
	var mean_z = 0.0
	var total = 0.0
	for instance in name_to_instances.values():
		mean_x += instance.position.x
		mean_z += instance.position.z
		total += 1
	return Vector3(mean_x / total, 0.0, mean_z / total)

func compute_max_dist(name_to_instances):
	var total_inst = name_to_instances.keys().size()
	var names = name_to_instances.keys()
	var pos1
	var pos2
	var diff
	var biggest_diff = 0
	for inst1_idx in range(total_inst):
		for inst2_idx in range(total_inst/2):
			pos1 = name_to_instances[names[inst1_idx]].position
			pos2 = name_to_instances[names[inst2_idx]].position
			diff = (pos1 - pos2).length()
			if diff > biggest_diff:
				biggest_diff = diff
	return max(biggest_diff, 1)
	

func _on_generate_new_piece(name_to_instances):
	var tween = get_tree().create_tween().set_parallel(true)
	var mean_pos = compute_mean_position(name_to_instances)
	var biggest_distance = compute_max_dist(name_to_instances)
	tween.tween_property(%Camera3D, "position", camera_init_position * sqrt(biggest_distance), 1).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "position", mean_pos, 1).set_trans(Tween.TRANS_QUINT)
