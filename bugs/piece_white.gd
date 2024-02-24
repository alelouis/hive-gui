extends Node3D

var whoami: String
signal piece_selected
signal piece_highlighted
signal piece_leaved


func _on_area_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("piece_selected", whoami)


func _on_area_3d_mouse_entered():
	emit_signal("piece_highlighted", whoami)


func _on_area_3d_mouse_exited():
	emit_signal("piece_leaved", whoami)
