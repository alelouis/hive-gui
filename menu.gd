extends Control
signal new_game
signal quit
signal resume

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_resume_pressed():
	emit_signal("resume")

func _on_newgame_pressed():
	emit_signal("new_game")

func _on_quit_pressed():
	emit_signal("quit")

func set_label(string):
	$MarginContainer/VBoxContainer/label.text = string
	
func disable_resume(state):
	$MarginContainer/VBoxContainer/resume.disabled = state
