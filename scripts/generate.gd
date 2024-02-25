extends Node

signal new_piece

var cursor = load("res://png/cursor.png")
var pointer = load("res://png/pointer.png")

var piece_sound = preload("res://sounds/piece.wav")
var tick_sound = preload("res://sounds/tick.wav")
var pick_sound = preload("res://sounds/pick.wav")

var current_turn_color
var name_to_tiles = {}
var name_to_instances = {}
var waiting_pieces = {}
var bugs = {}
var last_command_sent
var last_command_status
var queued_commands = []
var valid_moves = {}
var valid_movestrings = []
var candidate_scene
var candidate_instances = []
var tiles_to_moves = {}
var last_selected_piece = null
var selected_piece = null
var menu_visible = true
var playing_vs_ia = false

var SELECT_GROW = 0.09
var DEFAULT_GROW = 0.03

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			menu_visible = !menu_visible
			$"../menu".set_visible(menu_visible)
			$"../menu_newgame".set_visible(false)

func _ready():
	var color_bug
	var colors = {"w": "white", "b": "black"}
	for bug in ["A", "B", "Q", "G", "S"]:
		for color in ["w", "b"]:
			color_bug = "%s%s"%[color, bug]
			bugs[color_bug] = load("res://bugs//%s//%s.tscn"%[colors[color], color_bug])
	candidate_scene = preload("res://bugs//piece_candidate.tscn")
	current_turn_color = "w"
	$"../menu".disable_resume(true)
	$"../menu_newgame".set_visible(false)
	Input.set_custom_mouse_cursor(pointer)
	$"../AudioPlayerPiece".stream = piece_sound
	$"../AudioPlayerTick".stream = tick_sound
	$"../AudioPlayerPick".stream = pick_sound
	
	
func process_move_string(move_string: String, name_to_tiles: Dictionary):
	var final_tile
	move_string = move_string.rstrip("\n")
	if move_string.contains(" "):
		var parsed_move = move_string.split(" ")
		var source = parsed_move[0]
		var target = parsed_move[1]
		var target_without_dir
		var target_tile
		var color = source[0]
		var found_dir = false
		var direction_char
		var direction_pos
		var direction
		for dir_char in ["/", "\\", "-"]:
			if target.contains(dir_char):
				found_dir = true
				direction_char = dir_char
				direction_pos = target.find(dir_char)
				target_without_dir = target.replace(direction_char, "")
				if direction_pos != 0:
					match direction_char:
						"/": direction = "NE"
						"-": direction = "E"
						"\\": direction = "SE"
				else:
					match direction_char:
						"/": direction = "SW"
						"-": direction = "W"
						"\\": direction = "NW"
				break
		if found_dir:
			target_tile = name_to_tiles[target_without_dir]
			final_tile = move_towards(target_tile, direction)
			return [source, final_tile]
		else:
			final_tile = name_to_tiles[target]
			return [source, final_tile]
	else:
		var color = move_string[0]
		final_tile = Vector3i(0, 0, 0)
		return [move_string, final_tile]
		
		
func move_towards(tile, direction):
	var target_tile = tile
	match direction:
		"W": target_tile += Vector3i(-1, 0, 1)
		"E": target_tile += Vector3i(1, 0, -1)
		"NW": target_tile += Vector3i(0, -1, 1)
		"NE": target_tile += Vector3i(1, -1, 0)
		"SW": target_tile += Vector3i(-1, 1, 0)
		"SE": target_tile += Vector3i(0, 1, -1)
	return target_tile

func hex_to_xy(tile):
	var count = count_bugs_on_tile(tile)
	var size = 1.1
	var x = size * (sqrt(3) * tile[0] + sqrt(3)/2 * tile[1])
	var y = size * (3./2 * tile[1])
	return Vector3(x, -0.3 + count * 0.5, y)


func place_or_move(move_string):
	var out
	var source
	var tile
	var kind
	var piece
	out = process_move_string(move_string, name_to_tiles)
	source = out[0]
	tile = out[1]
	if source not in name_to_instances:
		kind = source.substr(0, 2)
		piece = bugs[kind].instantiate()
		piece.get_node("piece").whoami = source
		piece.get_node("piece").piece_selected.connect(_on_piece_selected)
		name_to_instances[source] = piece
		add_child(piece)
	
	var tween = get_tree().create_tween().set_parallel(true)
	var target_position = hex_to_xy(tile)
	name_to_instances[source].set_position(Vector3(target_position.x, target_position.y + 0.3, target_position.z))
	tween.tween_property(name_to_instances[source], "position", target_position, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	name_to_tiles[source] = tile
	emit_signal("new_piece", name_to_instances)
	if current_turn_color == "w":
		current_turn_color = "b"
	else:
		current_turn_color = "w"

func _on_piece_selected(item):
	clear_candidates()
	$"../AudioPlayerPick".play()
	var instance
	if item != selected_piece:
		last_selected_piece = selected_piece
		selected_piece = item
		
	if last_selected_piece != null:
		if name_to_instances.has(last_selected_piece):
			change_piece_color_highlight(last_selected_piece, Color(1, 1, 1), DEFAULT_GROW, name_to_instances)
		if waiting_pieces.has(last_selected_piece):
			change_piece_color_highlight(last_selected_piece, Color(1, 1, 1), DEFAULT_GROW, waiting_pieces)
		
	if name_to_instances.has(selected_piece) and current_turn_color == selected_piece.substr(0, 1):
		change_piece_color_highlight(selected_piece, Color(0, 1, 0), SELECT_GROW, name_to_instances)
		
	if waiting_pieces.has(selected_piece):
		change_piece_color_highlight(selected_piece, Color(0, 1, 0), SELECT_GROW, waiting_pieces)
			
	if valid_moves.has(selected_piece):
		var idx_candidate = 0
		for position in valid_moves[selected_piece]:
			idx_candidate += 1
			instance = candidate_scene.instantiate()
			candidate_instances.append(instance)
			instance.move = tiles_to_moves[position][selected_piece][0]
			instance.theo_position = hex_to_xy(position)
			instance.move_selected.connect(_on_move_selected)
			instance.move_highlighted.connect(_on_move_highlighted)
			instance.move_leaved.connect(_on_move_leaved)
			
			var target_position = hex_to_xy(position)
			var tween = get_tree().create_tween().set_parallel(true)
			instance.set_position(Vector3(target_position.x, target_position.y - 0.3, target_position.z))
			tween.tween_property(instance, "position", target_position, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			
			add_child(instance)

func push_command(command: String):
	var old_client_requests = $"../Control/GridContainer/client_request".text
	$"../Control/GridContainer/client_request".text = "%s%s"%[old_client_requests, command]
	last_command_sent = command

func queue_command(command: String):
	queued_commands.append(command)

func _on_command_text_changed():
	pass
	"""
	if $"../Control/GridContainer/command".text.ends_with("\n"):
		var move_string = $"../Control/GridContainer/command".text
		$"../Control/GridContainer/command".text = ""
		if valid_movestrings.has(move_string.rstrip("\n")):
			place_or_move(move_string)
			push_command("play %s"%move_string)
			queue_command("validmoves\n")
		else:
			print("Illegal move")
	"""

func _on_server_server_response(response: String):
	var split_response = response.split("\n")
	if split_response[-1] == "ok":
		var fmt_cmd
		if last_command_sent == null:
			fmt_cmd = "auto"
		else:
			fmt_cmd = last_command_sent.rstrip("\n")
			
		print("Last command: %s"%fmt_cmd)
		print("Response: %s"%split_response[0].rstrip("\n"))
		
		# Handle data received from server
		handle_server_response(split_response[0].rstrip("\n"))
		
		# Queue commands if needed
		if queued_commands.size() > 0:
			var command = queued_commands.pop_back()
			push_command(command)
			
func handle_server_response(response_string: String):
	if last_command_sent.substr(0, 4) == "play":
		var game_state = response_string.split(";")[1]
		match game_state:
			"WhiteWins": 
				menu_visible = true
				$"../menu".set_visible(menu_visible)
				$"../menu".set_label("White Wins !")
				$"../menu".disable_resume(true)
			"BlackWins": 
				menu_visible = true
				$"../menu".set_visible(menu_visible)
				$"../menu".set_label("Black Wins !")
				$"../menu".disable_resume(true)
			"InProgress": 
				$"../menu".set_label("In Progress")
	
	if last_command_sent == "bestmove\n":
		place_or_move(response_string)
		clear_waiting_pieces()
		clear_candidates()
		queue_command("validmoves\n")
		queue_command("play %s\n"%response_string)
	
	if last_command_sent == "validmoves\n":
		valid_moves = {}
		tiles_to_moves = {}
		var out
		var source
		var target
		var candidate_moves = response_string.split(";")
		valid_movestrings = candidate_moves
		for c_move in candidate_moves:
			out = process_move_string(c_move, name_to_tiles)
			source = out[0]
			target = out[1]
			if tiles_to_moves.has(target):
				if tiles_to_moves[target].has(source):
					tiles_to_moves[target][source].append(c_move)
				else:
					tiles_to_moves[target][source] = [c_move]
			else:
				tiles_to_moves[target] = {source: [c_move]} 
			if valid_moves.has(source):
				if !valid_moves[source].has(target):
					valid_moves[source].append(target)
			else:
				valid_moves[source] = [target]
		
		$"../Control/HFlowContainer/ItemList".clear()
		var waiting_piece
		var idx = 0
		
		var waiting_moves = []
		for playable_piece in valid_moves:
			if !name_to_instances.has(playable_piece):
				waiting_moves.append(playable_piece)
				
		var waiting_count = waiting_moves.size() * 1.0
		for available_piece in waiting_moves:
			if !name_to_instances.has(available_piece):
				#$"../Control/HFlowContainer/ItemList".add_item(available_piece)
				waiting_piece = bugs[available_piece.substr(0, 2)].instantiate()
				
				waiting_pieces[available_piece] = waiting_piece
				waiting_piece.get_node("piece").whoami = available_piece
				waiting_piece.get_node("piece").piece_selected.connect(_on_piece_selected)
				waiting_piece.get_node("piece").piece_highlighted.connect(_on_waiting_piece_highlighted)
				waiting_piece.get_node("piece").piece_leaved.connect(_on_waiting_piece_leaved)
				waiting_piece.set_rotation_degrees(Vector3(60, 0, 0))
				waiting_piece.set_position(Vector3((idx - waiting_count / 2.0 + 0.5)*0.1, -0.4, -5))
				waiting_piece.set_scale(Vector3(0.05, 0.05, 0.05))
				idx += 1
				get_tree().get_root().get_node("Node3D").get_node("Origin").get_node("Camera3D").add_child(waiting_piece)


func _on_waiting_piece_highlighted(piece):
	var tween = get_tree().create_tween()
	tween.tween_property(waiting_pieces[piece], "rotation_degrees", Vector3(75, 0, 0), 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	$"../AudioPlayerTick".play()
	
func _on_waiting_piece_leaved(piece):
	var tween = get_tree().create_tween()
	tween.tween_property(waiting_pieces[piece], "rotation_degrees", Vector3(60, 0, 0), 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func clear_candidates():
	if candidate_instances.size() > 0:
		for existing_instance in candidate_instances:
			existing_instance.queue_free()
	candidate_instances = []

func clear_waiting_pieces():
	if waiting_pieces.size() > 0:
		for existing_instance in waiting_pieces:
			waiting_pieces[existing_instance].queue_free()
	waiting_pieces = {}

func _on_item_list_item_selected(index):
	clear_candidates()
	var item = $"../Control/HFlowContainer/ItemList".get_item_text(index)
	var instance
	if item != selected_piece:
		last_selected_piece = selected_piece
		selected_piece = item
	
	for position in valid_moves[item]:
		instance = candidate_scene.instantiate()
		candidate_instances.append(instance)
		instance.move = tiles_to_moves[position][item][0]
		instance.theo_position = hex_to_xy(position)
		instance.move_selected.connect(_on_move_selected)
		instance.move_highlighted.connect(_on_move_highlighted)
		instance.move_leaved.connect(_on_move_leaved)
		instance.set_position(hex_to_xy(position))
		add_child(instance)
		
	if name_to_instances.has(selected_piece):
		print("Changing color of %s to green."%selected_piece)
		change_piece_color_highlight(selected_piece, Color(0, 1, 0), SELECT_GROW, name_to_instances)
		
	if last_selected_piece != null and name_to_instances.has(last_selected_piece):
		print("Changing color of %s to white."%last_selected_piece)
		change_piece_color_highlight(last_selected_piece, Color(1, 1, 1), DEFAULT_GROW, name_to_instances)

func change_piece_color_highlight(piece, color, target_grow, piece_set):
	var selected_instance = piece_set[piece]
	var mesh3D = selected_instance.get_node("piece").get_node("Circle")
	var material = mesh3D.get_surface_override_material(0)
	var next_pass_material = material.get_next_pass().duplicate()
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(next_pass_material, "albedo_color", color, 0.2).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(next_pass_material, "grow_amount", target_grow, 0.3).set_trans(Tween.TRANS_BACK)
	material.set_next_pass(next_pass_material)
	mesh3D.set_surface_override_material(0, material)
	

func _on_move_selected(move):
	if valid_movestrings.has(move):
		place_or_move(move)
		clear_waiting_pieces()
		clear_candidates()
		push_command("play %s\n"%move)
		if playing_vs_ia:
			queue_command("bestmove\n")
		else:
			queue_command("validmoves\n")
		$"../AudioPlayerPiece".play()
		last_selected_piece = selected_piece
		selected_piece = null
		print("Resetting color of %s to white."%last_selected_piece)
		change_piece_color_highlight(last_selected_piece, Color(1, 1, 1), DEFAULT_GROW, name_to_instances)
	else:
		print("INVALID CLICK MOVE: %s"%move)


func _on_move_highlighted(move):
	for instance in candidate_instances:
		if instance.move == move:
			var mesh3D = instance.get_node("Circle")
			var material = mesh3D.get_surface_override_material(0).duplicate()
			var tween = get_tree().create_tween().set_parallel(true);
			var pos = instance.position
			var th_pos = instance.theo_position
			tween.tween_property(instance, "position", Vector3(th_pos.x, th_pos.y + 0.25 , th_pos.z ), 0.1).set_trans(Tween.TRANS_LINEAR)
			var high_color
			if current_turn_color == "b":
				high_color = Color(0, 0, 1)
			else:
				high_color = Color(1, 0, 0)
			var set_shader_value = (func set_shader_value(value):
				material.set_shader_parameter("emission_color", value))
			tween.tween_method(set_shader_value, Color(0, 0, 0), high_color, 0.3).set_trans(Tween.TRANS_LINEAR)
			mesh3D.set_surface_override_material(0, material)

func _on_move_leaved(move):
	for instance in candidate_instances:
		if instance.move == move:
			var mesh3D = instance.get_node("Circle")
			var material = mesh3D.get_surface_override_material(0).duplicate()
			var tween = get_tree().create_tween().set_parallel(true);
			var pos = instance.position
			var th_pos = instance.theo_position
			tween.tween_property(instance, "position", Vector3(th_pos.x, th_pos.y, th_pos.z ), 0.1).set_trans(Tween.TRANS_LINEAR)
			var high_color
			if current_turn_color == "b":
				high_color = Color(0, 0, 1)
			else:
				high_color = Color(1, 0, 0)
			var set_shader_value = (func set_shader_value(value):
				material.set_shader_parameter("emission_color", value))
			tween.tween_method(set_shader_value, high_color, Color(0, 0, 0), 0.3).set_trans(Tween.TRANS_LINEAR)
			mesh3D.set_surface_override_material(0, material)		

func count_bugs_on_tile(tile):
	var found_bugs = 0
	for name in name_to_tiles:
		if name_to_tiles[name] == tile:
			found_bugs += 1
	return found_bugs

func newgame():
	for inst in name_to_instances.values():
		inst.queue_free()
	name_to_tiles = {}
	name_to_instances = {}
	push_command("newgame\n")
	queue_command("validmoves\n")
	clear_candidates()
	clear_waiting_pieces()
	$"../menu_newgame".set_visible(false)
	$"../menu".disable_resume(false)

func _on_menu_newgame_human_vs_human():
	playing_vs_ia = false
	newgame()
	
func _on_menu_newgame_human_vs_ai():
	playing_vs_ia = true
	newgame()

func _on_menu_new_game():
	menu_visible = false
	$"../menu".set_visible(menu_visible)
	$"../menu_newgame".set_visible(true)

func _on_menu_newgame_back():
	menu_visible = true
	$"../menu".set_visible(menu_visible)
	$"../menu_newgame".set_visible(false)

func _on_menu_quit():
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()

func _on_menu_resume():
	menu_visible = false
	$"../menu".set_visible(menu_visible)

func _on_home_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			menu_visible = !menu_visible
			$"../menu".set_visible(menu_visible)
			







