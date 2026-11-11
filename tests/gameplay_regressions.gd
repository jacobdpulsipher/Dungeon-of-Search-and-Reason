extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_primary_pressed()
	_check(not main.arena.position_clear(Vector2(20, 300)), "fighters can move into the room's left border")
	_check(not main.arena.position_clear(Vector2(500, 25)), "fighters can move into the room's top border")
	main.arena.enemy.position = Vector2(660, 215)
	_check(not main.arena.has_line_of_sight(main.arena.player.position, main.arena.enemy.position), "visibility fixture does not put cover between fighters")
	await physics_frame
	_check(main.arena.enemy.visible, "cover made the enemy sprite disappear")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	main.arena._input(tab)
	_check(main.arena.reveal_enabled, "logical Tab did not enable planning reveal")
	main.arena._input(tab)
	_check(not main.arena.reveal_enabled, "second Tab did not hide planning reveal")
	main.unlocked = 2
	main.open_level(2)
	main._on_primary_pressed()
	await create_timer(2.0).timeout
	_check(main.arena.brain.has_fix, "level 2 radar never found stationary player")
	_check(main.arena.brain.path.size() > 0, "level 2 has no route to visualize")
	main.arena._input(tab)
	_check(main.arena.reveal_enabled, "level 2 planning reveal did not activate")
	main.unlocked = 8
	main.open_level(8)
	main._on_primary_pressed()
	main.arena.player.max_hp = 100
	main.arena.player.hp = 100
	var spawn: Vector2 = main.arena.enemy.position
	main.arena._input(tab)
	await create_timer(3.0).timeout
	_check(main.arena.enemy.position.distance_to(spawn) > 80.0, "level 8 enemy stood still at spawn behind cover")
	await create_timer(2.2).timeout
	_check(main.arena.reveal_enabled, "planning reveal turned off without a second Tab")
	main.arena._input(tab)
	_check(not main.arena.reveal_enabled, "second Tab did not turn planning reveal off")
	if failures.is_empty():
		print("PASS: gameplay regressions")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
