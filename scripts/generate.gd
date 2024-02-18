extends Node


var scene = preload("res://piece.tscn")

var name_to_tiles = {}
var name_to_instances = {}

func _ready():
	var bugs = {}
	var color_bug
	for bug in ["A", "B", "Q", "G", "S"]:
		for color in ["w", "b"]:
			color_bug = "%s%s"%[color, bug]
			bugs[color_bug] = load("res://bugs/%s.tscn"%color_bug)
		
	var tile
	var out
	var source
	var kind
	var moves = ["wQ", "bQ wQ/", "wS1 -wQ", "bQ wQ-"]
	for move in moves:
		var piece
		out = process_move(move, name_to_tiles)
		source = out[0]
		tile = out[1]
		if source not in name_to_instances:
			kind = source.substr(0, 2)
			piece = bugs[kind].instantiate()
			name_to_instances[source] = piece
		
		name_to_instances[source].set_position(hex_to_xy(tile))
		print(name_to_tiles)
		print(name_to_instances)
		add_child(piece)
	
	
func process_move(move: String, name_to_tiles: Dictionary):
	var final_tile
	if move.contains(" "):
		var parsed_move = move.split(" ")
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
		target_tile = name_to_tiles[target_without_dir]
		final_tile = move_towards(target_tile, direction)
		name_to_tiles[source] = final_tile
		return [source, final_tile]
	else:
		var color = move[0]
		final_tile = Vector3i(0, 0, 0)
		name_to_tiles[move] = final_tile
		return [move, final_tile]
		
		
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
	var size = 0.95
	var x = size * (sqrt(3) * tile[0] + sqrt(3)/2 * tile[1])
	var y = size * (3./2 * tile[1])
	return Vector3(x, 0, y)

