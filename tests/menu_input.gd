extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_check(Input.emulate_mouse_from_touch, "touch-to-mouse emulation is disabled")
	_check(main.primary_button.has_focus(), "start button did not get controller focus")
	var touch := InputEventScreenTouch.new()
	touch.position = main.primary_button.get_global_rect().get_center()
	touch.pressed = true
	root.push_input(touch, true)
	await process_frame
	_check(not main.overlay.visible and main.arena.active, "touch on Start button did not start level")
	main.open_level(1)
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	root.push_input(trigger)
	await process_frame
	_check(main.overlay.visible, "right trigger unexpectedly dismissed the menu")
	var controller_a := InputEventJoypadButton.new()
	controller_a.button_index = JOY_BUTTON_A
	controller_a.pressed = true
	root.push_input(controller_a)
	await process_frame
	_check(not main.overlay.visible and main.arena.active, "controller A did not start level")
	main.open_level(1)
	var controller_start := InputEventJoypadButton.new()
	controller_start.button_index = JOY_BUTTON_START
	controller_start.pressed = true
	root.push_input(controller_start)
	await process_frame
	_check(not main.overlay.visible and main.arena.active, "controller Start did not start level")
	main.unlocked = main.levels.size()
	_check(main.level_buttons.get_child_count() == 12, "new levels are missing from the menu")
	for level in range(1, main.levels.size() + 1):
		main.open_level(level)
		await process_frame
		await process_frame
		_check(main.primary_button.get_global_rect().end.y <= main.menu_card.get_global_rect().end.y - 20.0, "level %d lesson overflows the menu card" % level)
	if failures.is_empty():
		print("PASS: menu touch and controller input")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
