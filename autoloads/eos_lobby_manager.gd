extends Node

const ROOM_CODE_LENGTH := 6

func _generate_room_code() -> String:
	var chars := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
	var code := ""
	for i in range(ROOM_CODE_LENGTH):
		code += chars[randi() % chars.length()]
	return code

func create_lobby(max_players: int, host_ip: String, host_port: int) -> String:
	if not EOSManager.is_initialized:
		return ""

	var room_code := _generate_room_code()

	var create_options := EOSLobby_CreateLobbyOptions.new()
	create_options.local_user_id = EOSManager.product_user_id
	create_options.max_lobby_members = max_players
	create_options.permission_level = EOSLobby.LPL_PUBLICADVERTISED
	create_options.bucket_id = "LobbyBucket"

	var create_result: EOSLobby_CreateLobbyCallbackInfo = await EOSLobby.create_lobby(create_options)
	if create_result.result_code != EOS.Success:
		push_error("EOSLobbyManager: create_lobby failed: ", EOS.result_to_string(create_result.result_code))
		return ""

	var lobby_id := create_result.lobby_id
	var modification := EOSLobby.update_lobby_modification(EOSManager.product_user_id, lobby_id)
	if not is_instance_valid(modification):
		return ""

	var room_attr := EOSLobby_AttributeData.new()
	room_attr.key = "ROOM_CODE"
	room_attr.value = room_code
	modification.add_attribute(room_attr, EOSLobby.LAT_PUBLIC)

	var ip_attr := EOSLobby_AttributeData.new()
	ip_attr.key = "HOST_IP"
	ip_attr.value = host_ip
	modification.add_attribute(ip_attr, EOSLobby.LAT_PUBLIC)

	var port_attr := EOSLobby_AttributeData.new()
	port_attr.key = "HOST_PORT"
	port_attr.value = host_port
	modification.add_attribute(port_attr, EOSLobby.LAT_PUBLIC)

	var update_result: EOSLobby_UpdateLobbyCallbackInfo = await EOSLobby.update_lobby(modification)
	return room_code if update_result.result_code == EOS.Success else ""

func search_lobby(room_code: String) -> Dictionary:
	if not EOSManager.is_initialized:
		return {}

	var search := EOSLobby.create_lobby_search(1)
	if not is_instance_valid(search):
		return {}

	var param := EOSLobby_AttributeData.new()
	param.key = "ROOM_CODE"
	param.value = room_code
	search.set_parameter(param, EOS.CO_EQUAL)

	var find_result: EOS.Result = await search.find(EOSManager.product_user_id)
	if find_result != EOS.Success:
		return {}

	if search.get_search_result_count() == 0:
		return {}

	var details: EOSLobbyDetails = search.copy_search_result_by_index(0)
	if not is_instance_valid(details):
		return {}

	var host_ip_attr := details.copy_attribute_by_key("HOST_IP")
	var host_port_attr := details.copy_attribute_by_key("HOST_PORT")
	if not is_instance_valid(host_ip_attr) or not is_instance_valid(host_port_attr):
		return {}

	return {
		"HOST_IP": host_ip_attr.data.value,
		"HOST_PORT": str(host_port_attr.data.value),
	}
