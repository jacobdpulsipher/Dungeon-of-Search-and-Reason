extends SceneTree

const Arena = preload("res://scripts/arena.gd")
const Levels = preload("res://scripts/levels.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var levels = Levels.all()
	for stage in [1, 9, 10]:
		var arena = Arena.new()
		root.add_child(arena)
		arena.configure(levels[stage - 1])
		arena.mouse_aim_active = false
		arena.player.set_aim(Vector2.RIGHT)
		arena.player.max_hp = 100
		arena.player.hp = 100
		Input.action_press("fire")
		for frame in range(600):
			arena._physics_process(1.0 / 60.0)
			if arena.ended:
				break
		Input.action_release("fire")
		if stage == 1:
			_check(arena.enemy.hp <= 0, "stationary control enemy survived straight-line fire")
		else:
			_check(arena.enemy.hp > 0, "level %d lost to standing still and firing straight" % stage)
			_check(absf(arena.enemy.position.y - 300.0) > 50.0, "level %d did not leave the firing lane" % stage)
		arena.queue_free()
		await process_frame
	if failures.is_empty():
		print("PASS: projectile gameplay")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
