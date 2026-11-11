extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena = load("res://scripts/arena.gd").new()
	root.add_child(arena)
	arena.configure(load("res://scripts/levels.gd").all()[8])
	arena.set_active(false)
	var enemy = arena.enemy
	var dt := 1.0 / 60.0
	arena.move_fighter(enemy, Vector2.LEFT, dt)
	_check(enemy.velocity.length() < 20.0, "advanced AI reached full speed in one frame")
	for frame in range(24):
		arena.move_fighter(enemy, Vector2.LEFT, dt)
	var before: Vector2 = enemy.velocity
	arena.move_fighter(enemy, Vector2.RIGHT, dt)
	_check(enemy.velocity.distance_to(before) <= 850.0 * dt + 0.5, "advanced AI reversed faster than its acceleration limit")
	_check(enemy.velocity.length() <= enemy.speed + 0.5, "advanced AI exceeded its movement speed")
	enemy.leap_cooldown = 0.0
	enemy.leap(Vector2.LEFT)
	arena.move_fighter(enemy, Vector2.LEFT, dt)
	_check(enemy.velocity.length() <= 450.5, "advanced AI leap exceeded its speed limit")
	if failures.is_empty():
		print("PASS: advanced AI movement")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
