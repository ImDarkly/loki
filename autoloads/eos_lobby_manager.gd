extends Node

const ROOM_CODE_LENGTH := 6

func _generate_room_code() -> String:
	var chars := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
	var code := ""
	for i in range(ROOM_CODE_LENGTH):
		code += chars[randi() % chars.length()]
	return code

func create_lobby(max_players: int, host_ip: String, host_port: int) -> String:
	if not EOSManager.is_initialized: return ""

	var room_code := _generate_room_code()
	
	var create_options := EOSLobby_CreateLobbyOptions.new()
	create_options.local_user_id = EOSManager.product_user_id
	create_options.max_lobby_members = max_players
	create_options.permission_level = EOS.LPL_PUBLICADVERTISED
	create_options.bucket_id = "LobbyBucket" 
	
	var signal_result: Signal = EOSLobby.get_singleton().create_lobby(create_options)
	var callback_result = await signal_result
	
	if callback_result.result_code != EOS.Success:
		return ""
	
	var lobby_id = callback_result.lobby_id
	var modification := EOSLobby.get_singleton().update_lobby_modification(EOSManager.product_user_id, lobby_id)
	modification.add_attribute("ROOM_CODE", room_code, EOS.ATTR_PUBLIC)
	modification.add_attribute("HOST_IP", host_ip, EOS.ATTR_PUBLIC)
	modification.add_attribute("HOST_PORT", str(host_port), EOS.ATTR_PUBLIC)
	
	var update_signal: Signal = EOSLobby.get_singleton().update_lobby(modification)
	var update_result = await update_signal
	
	return room_code if update_result.result_code == EOS.Success else ""

func search_lobby(room_code: String) -> Dictionary:
	var search := EOSLobby.get_singleton().create_lobby_search(1)
	search.set_parameter("ROOM_CODE", room_code, EOS.CMP_EQUAL)
	
	# Actual API would require searching
	return {}
