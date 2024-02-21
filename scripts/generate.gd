extends Node

signal new_piece

var name_to_tiles = {}
var name_to_instances = {}
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


func _ready():
	var color_bug
	var colors = {"w": "white", "b": "black"}
	for bug in ["A", "B", "Q", "G", "S"]:
		for color in ["w", "b"]:
			color_bug = "%s%s"%[color, bug]
			bugs[color_bug] = load("res://bugs//%s//%s.tscn"%[colors[color], color_bug])
	candidate_scene = preload("res://bugs//piece_candidate.tscn")
	
	
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
	name_to_instances[source].set_position(hex_to_xy(tile))
	name_to_tiles[source] = tile
	emit_signal("new_piece", name_to_instances)

func _on_piece_selected(item):
	clear_candidates()
	var instance
	if item != selected_piece:
		last_selected_piece = selected_piece
		selected_piece = item
	if last_selected_piece != null and name_to_instances.has(last_selected_piece):
		change_piece_color_highlight(last_selected_piece, Color(1, 1, 1))
		
	if name_to_instances.has(selected_piece):
		change_piece_color_highlight(selected_piece, Color(0, 1, 0))
			
	if valid_moves.has(selected_piece):
		for position in valid_moves[selected_piece]:
			instance = candidate_scene.instantiate()
			candidate_instances.append(instance)
			instance.move = tiles_to_moves[position][selected_piece][0]
			instance.move_selected.connect(_on_move_selected)
			instance.set_position(hex_to_xy(position))
			add_child(instance)

func push_command(command: String):
	var old_client_requests = $"../Control/GridContainer/client_request".text
	$"../Control/GridContainer/client_request".text = "%s%s"%[old_client_requests, command]
	last_command_sent = command

func queue_command(command: String):
	queued_commands.append(command)
	

func _on_command_text_changed():
	if $"../Control/GridContainer/command".text.ends_with("\n"):
		var move_string = $"../Control/GridContainer/command".text
		$"../Control/GridContainer/command".text = ""
		if valid_movestrings.has(move_string.rstrip("\n")):
			place_or_move(move_string)
			push_command("play %s"%move_string)
			queue_command("validmoves\n")
		else:
			print("Illegal move")

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
		for available_piece in valid_moves:
			$"../Control/HFlowContainer/ItemList".add_item(available_piece)


func _on_button_pressed():
	for inst in name_to_instances.values():
		inst.queue_free()
	name_to_tiles = {}
	name_to_instances = {}
	push_command("newgame\n")
	queue_command("validmoves\n")

func clear_candidates():
	if candidate_instances.size() > 0:
		for existing_instance in candidate_instances:
			existing_instance.queue_free()
	candidate_instances = []

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
		instance.move_selected.connect(_on_move_selected)
		instance.set_position(hex_to_xy(position))
		add_child(instance)
		
	if name_to_instances.has(selected_piece):
		print("Changing color of %s to green."%selected_piece)
		change_piece_color_highlight(selected_piece, Color(0, 1, 0))
		
	if last_selected_piece != null and name_to_instances.has(last_selected_piece):
		print("Changing color of %s to white."%last_selected_piece)
		change_piece_color_highlight(last_selected_piece, Color(1, 1, 1))

func change_piece_color_highlight(piece, color):
	var selected_instance = name_to_instances[piece]
	var mesh3D = selected_instance.get_node("piece").get_node("Circle")
	var material = mesh3D.get_surface_override_material(0)
	var next_pass_material = material.get_next_pass().duplicate()
	next_pass_material.albedo_color = color
	material.set_next_pass(next_pass_material)
	mesh3D.set_surface_override_material(0, material)

func _on_move_selected(move):
	if valid_movestrings.has(move):
		place_or_move(move)
		clear_candidates()
		push_command("play %s\n"%move)
		queue_command("validmoves\n")
		last_selected_piece = selected_piece
		selected_piece = null
		print("Resetting color of %s to white."%last_selected_piece)
		change_piece_color_highlight(last_selected_piece, Color(1, 1, 1))
	else:
		print("INVALID CLICK MOVE: %s"%move)

func count_bugs_on_tile(tile):
	var found_bugs = 0
	for name in name_to_tiles:
		if name_to_tiles[name] == tile:
			found_bugs += 1
	return found_bugs
