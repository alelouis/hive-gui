extends Node3D

var move: String
signal move_selected
signal move_highlighted
signal move_leaved


func _on_area_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("move_selected", move)


func _on_area_3d_mouse_entered():
	emit_signal("move_highlighted", move)


func _on_area_3d_mouse_exited():
	emit_signal("move_leaved", move)
