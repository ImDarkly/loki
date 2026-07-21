class_name EOSInit
extends Node

signal eos_ready()
signal eos_failed(reason: String)

var product_user_id: EOSProductUserId
var is_available: bool = false
var is_initialized: bool = false

var _product_name: String
var _product_version: String
var _product_id: String
var _sandbox_id: String
var _deployment_id: String
var _client_id: String
var _client_secret: String
var _encryption_key: String
func initialize() -> void:
	if is_initialized:
		eos_ready.emit()
		return

	if not _load_credentials():
		eos_failed.emit("Missing or incomplete .env — see .env.template")
		return
	if not _init_eos():
		eos_failed.emit("EOS.initialize failed")
		return
	if not _create_platform():
		eos_failed.emit("EOSPlatform.platform_create failed")
		return
	await _login_device_id()


func _load_credentials() -> bool:
	var env_path: String = "res://.env"
	if not FileAccess.file_exists(env_path):
		push_warning("eos_init: .env not found at ", env_path, " — EOS unavailable")
		return false

	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(env_path) != OK:
		push_warning("eos_init: failed to load .env — EOS unavailable")
		return false

	for key in ["PRODUCT_NAME", "PRODUCT_VERSION", "PRODUCT_ID", "SANDBOX_ID", "DEPLOYMENT_ID", "CLIENT_ID", "CLIENT_SECRET", "ENCRYPTION_KEY"]:
		if not cfg.has_section_key("", key) or cfg.get_value("", key).is_empty():
			push_warning("eos_init: missing or empty key %s in .env" % key)
			return false

	_product_name = cfg.get_value("", "PRODUCT_NAME")
	_product_version = cfg.get_value("", "PRODUCT_VERSION")
	_product_id = cfg.get_value("", "PRODUCT_ID")
	_sandbox_id = cfg.get_value("", "SANDBOX_ID")
	_deployment_id = cfg.get_value("", "DEPLOYMENT_ID")
	_client_id = cfg.get_value("", "CLIENT_ID")
	_client_secret = cfg.get_value("", "CLIENT_SECRET")
	_encryption_key = cfg.get_value("", "ENCRYPTION_KEY")
	return true


func _init_eos() -> bool:
	var init_options: EOSInitializeOptions = EOSInitializeOptions.new()
	init_options.product_name = _product_name
	init_options.product_version = _product_version
	var result_code: EOS.Result = EOS.initialize(init_options)
	if result_code == EOS.AlreadyConfigured:
		is_initialized = true
		return true
	if result_code != EOS.Success:
		push_error("eos_init: EOS.initialize failed: ", EOS.result_to_string(result_code))
		return false
	is_initialized = true
	return true


func _create_platform() -> bool:
	var create_options := EOSPlatform_Options.new()
	create_options.product_id = _product_id
	create_options.sandbox_id = _sandbox_id
	create_options.deployment_id = _deployment_id
	create_options.client_credentials = EOSPlatform_ClientCredentials.new()
	create_options.client_credentials.client_id = _client_id
	create_options.client_credentials.client_secret = _client_secret
	create_options.rtc_options = EOSPlatform_RTCOptions.new()
	create_options.encryption_key = _encryption_key
	if OS.get_name() == "Windows":
		create_options.flags |= EOSPlatform.PF_DISABLE_OVERLAY
	else:
		create_options.flags = EOSPlatform.PF_DISABLE_OVERLAY
	EOSPlatform.platform_create(create_options)
	return true


func _login_device_id() -> void:
	var device_id: String = OS.get_name() + ":" + OS.get_model_name()
	var cdidr: EOS.Result = await EOSConnect.create_device_id(device_id)
	if cdidr not in [EOS.Success, EOS.DuplicateNotAllowed]:
		push_error("eos_init: create_device_id failed: ", EOS.result_to_string(cdidr))
		eos_failed.emit("create_device_id failed")
		return

	var connect_credentials := EOSConnect_Credentials.new()
	connect_credentials.type = EOS.ECT_DEVICEID_ACCESS_TOKEN

	var user_login_info := EOSConnect_UserLoginInfo.new()
	var display_name := OS.get_unique_id()
	if display_name.length() > EOSConnect.CONNECT_USERLOGININFO_DISPLAYNAME_MAX_LENGTH:
		display_name = display_name.substr(0, EOSConnect.CONNECT_USERLOGININFO_DISPLAYNAME_MAX_LENGTH)
	user_login_info.display_name = display_name

	var login_result: EOSConnect_LoginCallbackInfo = await EOSConnect.login(connect_credentials, user_login_info)
	if login_result.result_code == EOS.InvalidUser:
		var create_result: EOSConnect_CreateUserCallbackInfo = await EOSConnect.create_user(login_result.continuance_token)
		if create_result.result_code != EOS.Success:
			push_error("eos_init: create_user failed: ", EOS.result_to_string(create_result.result_code))
			eos_failed.emit("create_user failed")
			return
		product_user_id = create_result.local_user_id
	elif login_result.result_code != EOS.Success:
		push_error("eos_init: connect login failed: ", EOS.result_to_string(login_result.result_code))
		eos_failed.emit("connect login failed")
		return
	else:
		product_user_id = login_result.local_user_id

	is_available = true
	eos_ready.emit()
