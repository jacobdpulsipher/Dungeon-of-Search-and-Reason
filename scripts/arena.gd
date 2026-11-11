extends Node2D
signal round_finished(won: bool)
signal status_changed(data: Dictionary)
const Fighter = preload("res://scripts/fighter.gd")
const Bullet = preload("res://scripts/bullet.gd")
const Brain = preload("res://scripts/enemy_brain.gd")
const SHOT_ORIGIN_OFFSET := Vector2(0, -24)
const BODY_HITBOX_OFFSET := Vector2(-24, -58)
const BODY_HITBOX_SIZE := Vector2(48, 76)
const PLAYER_FIRE_INTERVAL := 0.27
const FIRE_REQUEST_LIFETIME := 0.85
const MAX_FIRE_REQUESTS := 3
const TRIGGER_PRESS_THRESHOLD := 0.28
const TRIGGER_RELEASE_THRESHOLD := 0.12
const ADVANCED_AI_ACCELERATION := 850.0
const ADVANCED_AI_LEAP_SPEED := 450.0
var player: Node2D
var enemy: Node2D
var brain: RefCounted
var left_brain: RefCounted
var versus_mode := false
var left_fire_interval := 0.48
var renderer: Node2D
var cover: Array[Rect2] = []
var bullets: Array[Node2D] = []
var bounds := Rect2(0, 0, 1000, 600)
var playable_bounds := Rect2(48, 72, 904, 456)
var active := false
var elapsed := 0.0
var reveal_enabled := false
var radar_strength := 0.0
var enemy_fire_interval := 0.48
var player_shots_fired := 0
var enemy_shots_fired := 0
var ended := false
var debug_enabled := false
var impacts: Array[Dictionary] = []
var mouse_aim_active := not OS.has_feature("android")
var right_trigger_last_event: Dictionary = {}
var left_trigger_last_event: Dictionary = {}
var trigger_clock := 0.0
var fire_requests: Array[float] = []
var leap_request_timer := 0.0

func configure(data: Dictionary) -> void:
	versus_mode = false
	left_brain = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	bullets.clear()
	player_shots_fired = 0
	enemy_shots_fired = 0
	right_trigger_last_event.clear()
	left_trigger_last_event.clear()
	trigger_clock = 0.0
	fire_requests.clear()
	leap_request_timer = 0.0
	impacts.clear()
	cover.clear()
	for rect in data.get("cover", []): cover.append(rect)
	var renderer_script = load("res://art/arena_renderer.gd")
	if renderer_script:
		renderer = Node2D.new()
		renderer.set_script(renderer_script)
		renderer.z_index = -10
		add_child(renderer)
		if renderer.has_method("set_room"):
			renderer.set_room({"size": bounds.size, "obstacles": cover})
	player = Fighter.new()
	player.position = data.get("player_spawn", Vector2(130, 300))
	add_child(player)
	enemy = Fighter.new()
	enemy.is_player = false
	enemy.speed = float(data.get("enemy_speed", 190.0))
	enemy.max_hp = int(data.get("enemy_hp", 5))
	enemy.hp = enemy.max_hp
	enemy.position = data.get("enemy_spawn", Vector2(870, 300))
	enemy.aim = Vector2.LEFT
	add_child(enemy)
	enemy_fire_interval = float(data.get("enemy_fire_interval", 0.48))
	brain = Brain.new()
	brain.setup(int(data.get("index", 1)), playable_bounds.grow(22.0), cover, int(data.get("index", 1)) * 193)
	elapsed = 0.0
	reveal_enabled = false
	ended = false
	active = true
	publish_status()

func configure_versus(left_data: Dictionary, right_data: Dictionary) -> void:
	# A shared, symmetric room makes the selected behaviors the main difference.
	configure({
		"index": int(right_data["index"]),
		"cover": [Rect2(420, 180, 160, 70), Rect2(420, 350, 160, 70)],
		"player_spawn": Vector2(110, 300),
		"enemy_spawn": Vector2(890, 300),
		"enemy_speed": float(right_data["enemy_speed"]),
		"enemy_fire_interval": float(right_data["enemy_fire_interval"]),
		"enemy_hp": int(right_data["enemy_hp"])
	})
	versus_mode = true
	player.use_enemy_sprite = true
	player.show_team_ring = true
	enemy.show_team_ring = true
	player.speed = float(left_data["enemy_speed"])
	player.max_hp = int(left_data["enemy_hp"])
	player.hp = player.max_hp
	left_fire_interval = float(left_data["enemy_fire_interval"])
	left_brain = Brain.new()
	left_brain.setup(int(left_data["index"]), playable_bounds.grow(22.0), cover, int(left_data["index"]) * 193 + 97)
	publish_status()

func set_active(value: bool) -> void:
	active = value
	if not value:
		right_trigger_last_event.clear()
		left_trigger_last_event.clear()
		fire_requests.clear()
		leap_request_timer = 0.0

func _physics_process(dt: float) -> void:
	if not active or ended or not is_instance_valid(player): return
	elapsed += dt
	trigger_clock += dt
	player.update_timers(dt)
	enemy.update_timers(dt)
	while not fire_requests.is_empty() and trigger_clock - fire_requests[0] > FIRE_REQUEST_LIFETIME:
		fire_requests.pop_front()
	leap_request_timer = maxf(0.0, leap_request_timer - dt)
	if versus_mode:
		_tick_versus(dt)
		return
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var aiming := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if aiming.length_squared() > 0.0:
		mouse_aim_active = false
	elif mouse_aim_active:
		aiming = get_local_mouse_position() - player.position
	if aiming.length_squared() > 0.01:
		player.set_aim(aiming)
	if player.fire_cooldown <= 0.0:
		if not fire_requests.is_empty():
			fire_requests.pop_front()
			fire(player)
		elif Input.is_action_pressed("fire"):
			fire(player)
	if Input.is_action_just_pressed("leap"):
		leap_request_timer = 0.18
	if leap_request_timer > 0.0 and player.leap(movement):
		leap_request_timer = 0.0
	move_fighter(player, movement, dt)
	var incoming: Array[Dictionary] = []
	for bullet in bullets:
		if bullet.from_player:
			incoming.append({"position": bullet.position, "velocity": bullet.velocity, "life": bullet.life})
	var command: Dictionary = brain.tick(dt, enemy.position, player.position, player.velocity, player.aim, incoming, enemy.speed)
	var enemy_aim: Vector2 = command.get("aim", player.position - enemy.position)
	if enemy_aim.length_squared() > 0.01: enemy.set_aim(enemy_aim)
	var enemy_move: Vector2 = command.get("move", Vector2.ZERO)
	if command.get("leap", false): enemy.leap(enemy_move)
	radar_strength = float(command.get("radar", 0.0))
	if command.get("shoot", false): fire(enemy)
	move_fighter(enemy, enemy_move, dt)
	update_bullets(dt)
	# The entire room is visible to the player. Cover affects bullets and enemy sensing,
	# but never makes the opponent's sprite disappear.
	enemy.visible = true
	enemy.modulate.a = 1.0
	for i in range(impacts.size() - 1, -1, -1):
		impacts[i]["time"] -= dt
		if impacts[i]["time"] <= 0: impacts.remove_at(i)
	queue_redraw()
	publish_status()

func _tick_versus(dt: float) -> void:
	var left_incoming: Array[Dictionary] = []
	var right_incoming: Array[Dictionary] = []
	for bullet in bullets:
		var shot := {"position": bullet.position, "velocity": bullet.velocity, "life": bullet.life}
		if bullet.from_player:
			right_incoming.append(shot)
		else:
			left_incoming.append(shot)
	var left_command: Dictionary = left_brain.tick(dt, player.position, enemy.position, enemy.velocity, enemy.aim, left_incoming, player.speed)
	var right_command: Dictionary = brain.tick(dt, enemy.position, player.position, player.velocity, player.aim, right_incoming, enemy.speed)
	_apply_brain_command(player, left_command, dt)
	_apply_brain_command(enemy, right_command, dt)
	radar_strength = float(right_command.get("radar", 0.0))
	update_bullets(dt)
	for i in range(impacts.size() - 1, -1, -1):
		impacts[i]["time"] -= dt
		if impacts[i]["time"] <= 0: impacts.remove_at(i)
	queue_redraw()
	publish_status()

func _apply_brain_command(actor: Node2D, command: Dictionary, dt: float) -> void:
	var target = enemy if actor == player else player
	var aim: Vector2 = command.get("aim", target.position - actor.position)
	if aim.length_squared() > 0.01:
		actor.set_aim(aim)
	var movement: Vector2 = command.get("move", Vector2.ZERO)
	if command.get("leap", false):
		actor.leap(movement)
	if command.get("shoot", false):
		fire(actor)
	move_fighter(actor, movement, dt)

func _input(event: InputEvent) -> void:
	if not active or ended or not is_instance_valid(player): return
	var logical_tab: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB
	if event.is_action_pressed("toggle_planning") or logical_tab:
		reveal_enabled = not reveal_enabled
		queue_redraw()
		publish_status()
		get_viewport().set_input_as_handled()
	if versus_mode:
		return
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_TRIGGER_RIGHT:
			_register_trigger_event(right_trigger_last_event, event.device, event.axis_value, true)
		elif event.axis == JOY_AXIS_TRIGGER_LEFT:
			_register_trigger_event(left_trigger_last_event, event.device, event.axis_value, false)
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		mouse_aim_active = true
	if event.is_action_pressed("fire") and not (event is InputEventKey and event.echo):
		_queue_fire_request()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3 or event.keycode == KEY_F3: debug_enabled = not debug_enabled

func _register_trigger_event(last_events: Dictionary, device: int, value: float, is_fire: bool) -> void:
	if value <= TRIGGER_RELEASE_THRESHOLD:
		last_events.erase(device)
	elif value >= TRIGGER_PRESS_THRESHOLD:
		var last_time := float(last_events.get(device, -100.0))
		if trigger_clock - last_time >= 0.08:
			if is_fire:
				_queue_fire_request()
			else:
				leap_request_timer = 0.2
		last_events[device] = trigger_clock

func _queue_fire_request() -> void:
	if fire_requests.size() < MAX_FIRE_REQUESTS:
		fire_requests.append(trigger_clock)

func move_fighter(actor: Node2D, direction: Vector2, dt: float) -> void:
	var stage := 0
	if actor == enemy:
		stage = brain.stage
	elif versus_mode and actor == player:
		stage = left_brain.stage
	var v: Vector2
	if actor.leap_time > 0:
		v = actor.leap_direction * (ADVANCED_AI_LEAP_SPEED if stage >= 7 else 570.0)
	elif stage >= 7:
		var desired: Vector2 = direction.limit_length() * actor.speed
		v = actor.velocity.limit_length(actor.speed).move_toward(desired, ADVANCED_AI_ACCELERATION * dt)
	else:
		v = direction.limit_length() * actor.speed
	var start: Vector2 = actor.position
	var steps := maxi(1, ceili(v.length() * dt / 7.0))
	for i in range(steps):
		var next: Vector2 = actor.position + Vector2(v.x * dt / steps, 0)
		if fighter_position_clear(actor, next): actor.position.x = next.x
		next = actor.position + Vector2(0, v.y * dt / steps)
		if fighter_position_clear(actor, next): actor.position.y = next.y
	actor.velocity = (actor.position - start) / maxf(dt, 0.001)

func fighter_position_clear(actor: Node2D, point: Vector2) -> bool:
	if not position_clear(point): return false
	var other = enemy if actor == player else player
	return not is_instance_valid(other) or point.distance_to(other.position) >= 34.0

func position_clear(point: Vector2) -> bool:
	if not playable_bounds.has_point(point): return false
	for rect in cover:
		if rect.grow(17).has_point(point): return false
	return true

func fire(actor: Node2D) -> void:
	if actor.fire_cooldown > 0: return
	actor.fire_cooldown = (left_fire_interval if versus_mode else PLAYER_FIRE_INTERVAL) if actor.is_player else enemy_fire_interval
	if actor.is_player:
		player_shots_fired += 1
	else:
		enemy_shots_fired += 1
	if actor.has_method("mark_fired"):
		actor.mark_fired()
	var bullet := Bullet.new()
	bullet.position = actor.position + SHOT_ORIGIN_OFFSET + actor.aim * 29
	bullet.previous = actor.position + SHOT_ORIGIN_OFFSET
	bullet.velocity = actor.aim * 620
	bullet.from_player = actor.is_player
	add_child(bullet)
	bullets.append(bullet)

func update_bullets(dt: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet = bullets[i]
		var start: Vector2 = bullet.position
		var finish: Vector2 = start + bullet.velocity * dt
		bullet.life -= dt
		var destroyed: bool = bullet.life <= 0 or not bounds.has_point(finish)
		for rect in cover:
			if segment_hits_rect(start, finish, rect.grow(4)): destroyed = true
		var target = enemy if bullet.from_player else player
		var body_hitbox := Rect2(target.position + BODY_HITBOX_OFFSET, BODY_HITBOX_SIZE)
		if not destroyed and target.leap_time <= 0 and segment_hits_rect(start, finish, body_hitbox):
			target.hp -= 1
			target.hit_flash = 0.12
			destroyed = true
			impacts.append({"position": target.position + SHOT_ORIGIN_OFFSET, "time": 0.22, "hit": true})
			if target.hp <= 0:
				ended = true
				active = false
				round_finished.emit(bullet.from_player)
		bullet.position = finish
		if destroyed:
			impacts.append({"position": finish, "time": 0.16, "hit": false})
			bullet.queue_free()
			bullets.remove_at(i)
		if ended: break

func segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b): return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null: return true
	return false

func has_line_of_sight(a: Vector2, b: Vector2) -> bool:
	for rect in cover:
		if segment_hits_rect(a, b, rect): return false
	return true

func publish_status() -> void:
	status_changed.emit({"player_hp": player.hp, "enemy_hp": enemy.hp, "max_hp": player.max_hp, "enemy_max_hp": enemy.max_hp, "leap_cooldown": player.leap_cooldown, "reveal_enabled": reveal_enabled, "elapsed": elapsed})

func _draw() -> void:
	for impact in impacts:
		var t: float = impact["time"]
		draw_arc(impact["position"], 8 + (0.22 - t) * 70, 0, TAU, 16, Color(1, 0.85, 0.5, minf(1, t * 5)), 2)
	var show_radar := not versus_mode or debug_enabled or reveal_enabled
	if show_radar and brain and is_instance_valid(enemy) and brain.has_method("draw_radar"):
		brain.draw_radar(self, enemy.position)
	if show_radar and versus_mode and left_brain and is_instance_valid(player) and left_brain.has_method("draw_radar"):
		left_brain.draw_radar(self, player.position)
	if (debug_enabled or reveal_enabled) and brain and is_instance_valid(enemy) and brain.has_method("draw_debug"):
		brain.draw_debug(self, enemy.position)
	if versus_mode and (debug_enabled or reveal_enabled) and left_brain and is_instance_valid(player) and left_brain.has_method("draw_debug"):
		left_brain.draw_debug(self, player.position)
	if versus_mode and (debug_enabled or reveal_enabled):
		if left_brain and left_brain.stage >= 7:
			draw_line(player.position, player.position + left_brain.minimax_action * 76.0, Color("65e7d4"), 4.0)
		if brain and brain.stage >= 7:
			draw_line(enemy.position, enemy.position + brain.minimax_action * 76.0, Color("ff876c"), 4.0)
