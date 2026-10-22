extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var world = load("res://world/world_setup.gd").new()
	root.add_child(world)
	world.set_process(false)
	for layer in world.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.5, -5)
	camera.look_at(Vector3(0, 1.5, -100))
	camera.fov = 70
	camera.make_current()
	var passed := true
	for phase in ["day", "night"]:
		world._directional_light.rotation.x = world.DAY_PITCH if phase == "day" else world.NIGHT_PITCH
		world._process(0.0)
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		screenshot.save_png("res://docs/334-horizon-%s.png" % phase)
		var largest_jump := 0.0
		for y in range(screenshot.get_height() / 2 - 1, int(screenshot.get_height() * 0.60)):
			var above := Vector3.ZERO
			var below := Vector3.ZERO
			var count := 0
			for x in range(screenshot.get_width() / 3, screenshot.get_width() * 2 / 3):
				var a := screenshot.get_pixel(x, y)
				var b := screenshot.get_pixel(x, y + 1)
				above += Vector3(a.r, a.g, a.b)
				below += Vector3(b.r, b.g, b.b)
				count += 1
			largest_jump = maxf(largest_jump, (above - below).length() / float(count))
		print("HORIZON_CHECK %s: largest adjacent-row RGB jump %.6f; limit 0.08" % [phase, largest_jump])
		passed = passed and largest_jump < 0.08
	quit(0 if passed else 1)
