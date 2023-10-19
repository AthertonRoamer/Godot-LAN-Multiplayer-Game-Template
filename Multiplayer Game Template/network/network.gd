extends Node

signal server_failed
signal player_info_updated

const PORT = 3000

var peer : ENetMultiplayerPeer
var is_server := false
var server_browser : Node
var client_count := 0

func _ready():
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.server_disconnected.connect(server_disconnected)
	server_browser = $ServerBrowser


func initiate_server() -> void:
	kill_peer()
	is_server = true
	peer = ENetMultiplayerPeer.new()
	var ok = peer.create_server(PORT)
	if ok != OK:
		print("Failed to create server. Error " + str(ok))
		server_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	print("Created server")
	server_browser.start_broadcast()
	
	GameState.add_player(1, GameState.get_my_player_info())
	
	
func initiate_client(ip : String) -> void:
	kill_peer()
	is_server = false
	peer = ENetMultiplayerPeer.new()
	var ok = peer.create_client(ip, PORT)
	if ok != OK:
		print("Failed to create client. Error " + str(ok))
		return
	multiplayer.multiplayer_peer = peer
	print("Created client")
	
	
@rpc("any_peer")
func register_player(id : int, player_info : Dictionary):
	GameState.add_player(id, player_info)
	update_player_info.rpc(GameState.players_info)
	print("Server recieved info: " + str(player_info))
	
	
@rpc("call_local")
func update_player_info(info : Dictionary):
	if is_server:
		player_info_updated.emit()
	else:
		GameState.players_info = info
		print("New player info: " + str(info))
	
	
func kill_peer():
	multiplayer.multiplayer_peer.close()
	is_server = false
	client_count = 0
	GameState.clear()
	
	
func connected_to_server() -> void:
	print("Connected to server")
	register_player.rpc_id(1, multiplayer.get_unique_id(), GameState.get_my_player_info())
	

func connection_failed() -> void:
	print("Connection to server failed")
	
	
func peer_connected(id) -> void:
	print("Peer connected with id: " + str(id))
	if is_server:
		client_count += 1
	
	
func peer_disconnected(id) -> void:
	print("Peer " + str(id) + " disconnected")
	if is_server:
		client_count -= 1
		GameState.remove_player(id)
		update_player_info.rpc(GameState.players_info)
		print("Lost player; New info is: " + str(GameState.players_info))
	
	
func server_disconnected():
	print("Disconnected with server")
	
	
