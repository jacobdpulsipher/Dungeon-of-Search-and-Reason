extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.open_versus_setup()
	await process_frame
	_check(main.versus_selectors.visible, "versus fighter selectors are hidden")
	_check(main.left_selector.item_count == 12 and main.right_selector.item_count == 12, "versus does not list every level enemy")
	_check(main.primary_button.get_global_rect().end.y <= main.menu_card.get_global_rect().end.y - 20.0, "versus setup overflows the menu card")
	main.left_selector.grab_focus()
	var select_event := InputEventJoypadButton.new()
	select_event.button_index = JOY_BUTTON_A
	select_event.pressed = true
	main._input(select_event)
	_check(main.card_mode == "versus_setup", "controller A bypassed the focused fighter selector")
	main._on_versus_choice_changed(0, true)
	main._on_versus_choice_changed(0, false)
	_check(main.versus_left_level != main.versus_right_level, "versus allowed identical level enemies")
	main.left_selector.select(0)
	main._on_versus_choice_changed(0, true)
	main.right_selector.select(6)
	main._on_versus_choice_changed(6, false)
	var old_unlocked: int = main.unlocked
	main._on_primary_pressed()
	_check(main.arena.versus_mode and main.arena.active, "versus match did not start")
	_check(main.arena.left_brain.stage == 1 and main.arena.brain.stage == 7, "selected AI levels were not applied to both fighters")
	_check(main.arena.player.use_enemy_sprite, "left fighter is not displayed as an enemy")
	var plan_toggle := InputEventJoypadButton.new()
	plan_toggle.button_index = JOY_BUTTON_Y
	plan_toggle.pressed = true
	main.arena._input(plan_toggle)
	await process_frame
	_check(main.arena.reveal_enabled and main.planning_panel._versus_reveal, "Y did not show the versus algorithm visuals")
	main.arena._input(plan_toggle)
	await process_frame
	_check(not main.arena.reveal_enabled and not main.planning_panel._versus_reveal, "Y did not hide the versus algorithm visuals")
	await create_timer(3.0).timeout
	_check(main.arena.left_brain.elapsed > 1.0 and main.arena.brain.elapsed > 1.0, "both enemy brains did not run")
	_check(main.arena.player_shots_fired > 0 and main.arena.enemy_shots_fired > 0, "both enemy brains did not shoot")
	main.arena.set_active(false)
	main.arena.player.fire_cooldown = 0.0
	main.arena.player.position = Vector2(100, 300)
	main.arena.enemy.position = Vector2(300, 300)
	main.arena.enemy.hp = 1
	main.arena.player.set_aim(Vector2.RIGHT)
	main.arena.fire(main.arena.player)
	main.arena.update_bullets(0.3)
	_check(main.card_mode == "versus_result", "versus result was not shown")
	_check(main.unlocked == old_unlocked, "versus result changed campaign progress")
	main._on_primary_pressed()
	_check(main.arena.versus_mode and main.arena.active, "rematch did not restart")
	main.open_versus_setup()
	main._on_versus_button_pressed()
	_check(not main.arena.versus_mode and main.card_mode == "intro", "Levels button did not return to the campaign menu")
	if failures.is_empty():
		print("PASS: versus mode")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
