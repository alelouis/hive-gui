extends Node

const HOST: String = "127.0.0.1"
const PORT: int = 8181
const RECONNECT_TIMEOUT: float = 3.0

const Client = preload("res://scripts/client.gd")
var _client: Client = Client.new()

var pid

signal server_response

func _ready() -> void:
	pid = OS.create_process("/Users/alelouis/Projects/hive-rust/target/release/server", [])
	OS.delay_msec(500)	
	_client.connected.connect(_handle_client_connected)
	_client.disconnected.connect(_handle_client_disconnected)
	_client.error.connect(_handle_client_error)
	_client.data.connect(_handle_client_data)
	add_child(_client)
	_client.connect_to_host(HOST, PORT)
	pass

func _connect_after_timeout(timeout: float) -> void:
	await get_tree().create_timer(timeout).timeout # Delay for timeout
	_client.connect_to_host(HOST, PORT)

func _handle_client_connected() -> void:
	print("Client connected to server.")

func _handle_client_data(data: PackedByteArray) -> void:
	var client_data = data.get_string_from_utf8()
	$"../Control/GridContainer/response".text = client_data
	emit_signal("server_response", client_data)

func _handle_client_disconnected() -> void:
	print("Client disconnected from server.")
	_connect_after_timeout(RECONNECT_TIMEOUT) # Try to reconnect after 3 seconds

func _handle_client_error() -> void:
	print("Client error.")
	_connect_after_timeout(RECONNECT_TIMEOUT) # Try to reconnect after 3 seconds

func _on_client_request_text_set():
	var commands = $"../Control/GridContainer/client_request".text.split("\n")
	var last_command = "%s\n"%commands[-2]
	_client.send(last_command)
