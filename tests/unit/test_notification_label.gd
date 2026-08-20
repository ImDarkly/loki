extends GutTest

var notif: NotificationLabel


func before_each() -> void:
	notif = autofree(load("res://ui/notification_label.tscn").instantiate())
	add_child(notif)
	await get_tree().process_frame


func test_show_message_sets_text() -> void:
	notif.show_message("Hello")
	var label := notif.get_node("Label") as Label
	assert_eq(label.text, "Hello", "Label text should be set")


func test_show_message_makes_label_visible() -> void:
	notif.show_message("Hello")
	var label := notif.get_node("Label") as Label
	assert_true(label.visible, "Label should be visible after show_message")


func test_repeated_show_message_overwrites_text() -> void:
	notif.show_message("First")
	notif.show_message("Second")
	var label := notif.get_node("Label") as Label
	assert_eq(label.text, "Second", "Latest message should replace the previous one")