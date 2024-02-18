extends Node3D

var dragging = false
var rotation_sensitivity = 0.005 
var scroll_sensitivity = 0.05

var scroll_level = 0

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
	
		
