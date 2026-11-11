extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_primary_pressed()
	var arena = main.arena
	var start: Vector2 = arena.player.position
	Input.action_press("move_right")
	Input.action_press("aim_up")
	arena._physics_process(1.0 / 60.0)
	_check(arena.player.position.x > start.x, "movement action did not move the player")
	_check(arena.player.aim.y < -0.9, "aim action did not rotate the player")
	_check(arena.player._facing == 4, "sprite did not turn toward upward aim")
	Input.action_release("move_right")
	Input.action_release("aim_up")
	Input.action_press("fire")
	arena._physics_process(1.0 / 60.0)
	_check(arena.bullets.size() > 0, "fire action did not create a bullet")
	for frame in range(59):
		arena._physics_process(1.0 / 60.0)
	_check(arena.player_shots_fired == 4, "held fire did not use the slower four-shot cadence")
	Input.action_release("fire")
	var left_shift := InputEventKey.new()
	left_shift.physical_keycode = KEY_SHIFT
	left_shift.location = KEY_LOCATION_LEFT
	left_shift.pressed = true
	var right_shift := InputEventKey.new()
	right_shift.physical_keycode = KEY_SHIFT
	right_shift.location = KEY_LOCATION_RIGHT
	right_shift.pressed = true
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	_check(InputMap.event_is_action(left_shift, "leap"), "Left Shift is not bound to leap")
	_check(not InputMap.event_is_action(right_shift, "leap"), "Right Shift still triggers leap")
	_check(not InputMap.event_is_action(right_click, "leap"), "right-click still triggers leap")
	Input.parse_input_event(left_shift)
	await physics_frame
	await process_frame
	_check(arena.player.leap_time > 0.0, "Left Shift did not start leap")
	left_shift.pressed = false
	Input.parse_input_event(left_shift)
	await process_frame
	await process_frame
	for frame in range(110):
		arena._physics_process(1.0 / 60.0)
	var y_button := InputEventJoypadButton.new()
	y_button.button_index = JOY_BUTTON_Y
	y_button.pressed = true
	arena._input(y_button)
	_check(arena.reveal_enabled, "controller Y did not toggle planning")
	var right_trigger := InputEventJoypadMotion.new()
	right_trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	right_trigger.axis_value = 1.0
	arena.player.hp = 100
	arena.player.max_hp = 100
	var shots_before: int = arena.player_shots_fired
	arena._input(right_trigger)
	arena._physics_process(1.0 / 60.0)
	_check(arena.player_shots_fired == shots_before + 1, "right trigger press did not fire exactly once")
	for frame in range(60):
		arena._physics_process(1.0 / 60.0)
	_check(arena.player_shots_fired == shots_before + 1, "right trigger kept firing without a new press")
	arena._input(right_trigger) # The handheld may omit the release event.
	arena._physics_process(1.0 / 60.0)
	_check(arena.player_shots_fired == shots_before + 2, "second right trigger press did not fire")
	# Two taps during the gun's cooldown must be remembered and fired in order.
	var quick_taps_start: int = arena.player_shots_fired
	right_trigger.axis_value = 0.0
	arena._input(right_trigger)
	right_trigger.axis_value = 1.0
	arena._input(right_trigger)
	arena._physics_process(1.0 / 60.0)
	right_trigger.axis_value = 0.0
	arena._input(right_trigger)
	right_trigger.axis_value = 1.0
	arena._input(right_trigger)
	for frame in range(10):
		arena._physics_process(1.0 / 60.0)
	_check(arena.player_shots_fired == quick_taps_start, "queued taps fired before the gun cooldown ended")
	for frame in range(30):
		arena._physics_process(1.0 / 60.0)
	_check(arena.player_shots_fired == quick_taps_start + 2, "quick trigger taps were dropped during cooldown")
	_check(arena.fire_requests.is_empty(), "quick trigger taps remained queued after firing")
	for frame in range(20):
		arena._physics_process(1.0 / 60.0)
	_check(arena.player_shots_fired == quick_taps_start + 2, "trigger kept firing after queued taps finished")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	arena._input(click)
	var click_start: int = arena.player_shots_fired
	arena._physics_process(1.0 / 60.0)
	_check(arena.player_shots_fired == click_start + 1, "short mouse click did not fire")
	var missing_release_start: int = arena.player_shots_fired
	right_trigger.axis_value = 1.0
	arena._input(right_trigger)
	for frame in range(4):
		arena._physics_process(1.0 / 60.0)
	arena._input(right_trigger) # A repeated high value inside 0.08 seconds is input noise.
	for frame in range(6):
		arena._physics_process(1.0 / 60.0)
	arena._input(right_trigger) # A new press can arrive without a release event.
	for frame in range(35):
		arena._physics_process(1.0 / 60.0)
	_check(arena.player_shots_fired == missing_release_start + 2, "fast presses without release events were lost or repeated")
	for frame in range(15):
		arena._physics_process(1.0 / 60.0)
	right_trigger.axis_value = 0.0
	arena._input(right_trigger)
	right_trigger.axis_value = 0.35
	arena._input(right_trigger)
	var light_press_start: int = arena.player_shots_fired
	arena._physics_process(1.0 / 60.0)
	_check(arena.player_shots_fired == light_press_start + 1, "light trigger press did not fire")
	var left_trigger := InputEventJoypadMotion.new()
	left_trigger.axis = JOY_AXIS_TRIGGER_LEFT
	left_trigger.axis_value = 1.0
	arena._input(left_trigger)
	arena._physics_process(1.0 / 60.0)
	_check(arena.player.leap_time > 0.0, "first left trigger press did not leap")
	for frame in range(100):
		arena._physics_process(1.0 / 60.0)
	_check(arena.player.leap_time == 0.0 and arena.player.leap_cooldown == 0.0, "leap repeated without a new press")
	arena._input(left_trigger) # A fresh high event must work without a low event.
	arena._physics_process(1.0 / 60.0)
	_check(arena.player.leap_time > 0.0 and arena.player.leap_cooldown > 0.0, "second left trigger press did not leap after cooldown")
	arena.player.set_aim(Vector2.LEFT)
	_check(arena.player._facing == 2, "sprite did not turn toward left aim")
	if failures.is_empty():
		print("PASS: input controls")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
