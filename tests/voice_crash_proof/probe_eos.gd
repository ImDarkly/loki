extends SceneTree

func _init() -> void:
	await process_frame
	if Engine.has_singleton("IEOS"):
		var eos: Object = Engine.get_singleton("IEOS")
		for s in eos.get_signal_list():
			var name: StringName = s.name
			if "rtc_audio" in name or "rtc" in name:
				print("SIGNAL: ", name)
	else:
		print("NO IEOS SINGLETON")
	quit()