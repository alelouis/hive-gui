extends Control
signal human_vs_human
signal human_vs_ai
signal back

func _on_human_vs_human_pressed():
	emit_signal("human_vs_human")


func _on_human_vs_ai_pressed():
	emit_signal("human_vs_ai")
	
	
func _on_back_pressed():
	emit_signal("back")
