extends SceneTree

const Arena = preload("res://scripts/arena.gd")
const Bullet = preload("res://scripts/bullet.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena = Arena.new()
	root.add_child(arena)
	arena.configure({"index": 1, "cover": [], "player_spawn": Vector2(100, 300), "enemy_spawn": Vector2(400, 300)})
	arena.player.set_aim(Vector2.RIGHT)
	arena.fire(arena.player)
	_check(absf(arena.bullets[0].position.y - 276.0) < 0.1, "shot did not start at gun height")
	arena.update_bullets(0.5)
	_check(arena.enemy.hp == 4, "straight shot missed the enemy's body")
	_fire_segment(arena, 258.0)
	_check(arena.enemy.hp == 3, "upper body shot did not register")
	_fire_segment(arena, 310.0)
	_check(arena.enemy.hp == 2, "lower body shot did not register")
	_fire_segment(arena, 230.0)
	_check(arena.enemy.hp == 2, "shot above the sprite registered as a hit")
	if failures.is_empty():
		print("PASS: body hit detection")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _fire_segment(arena: Node2D, y: float) -> void:
	var bullet = Bullet.new()
	bullet.position = Vector2(350, y)
	bullet.velocity = Vector2(620, 0)
	bullet.from_player = true
	arena.add_child(bullet)
	arena.bullets.append(bullet)
	arena.update_bullets(0.1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
