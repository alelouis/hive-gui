extends Camera3D

var dragging = false
var sensitivity = 0.01 

func _input(event):
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed

	if event is InputEventMouseMotion and dragging:
		rotation.y -= event.relative.x*sensitivity
		rotation.x -= event.relative.y*sensitivity
		rotation.x = clamp(rotation.x,-PI/2.0,PI/2.0)
