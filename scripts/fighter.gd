extends Node2D

var is_player := true
var use_enemy_sprite := false
var show_team_ring := false
var hp := 5
var max_hp := 5
var speed := 220.0
var velocity := Vector2.ZERO
var aim := Vector2.RIGHT
var fire_cooldown := 0.0
var leap_cooldown := 0.0
var leap_time := 0.0
var leap_direction := Vector2.RIGHT
var hit_flash := 0.0
var trail: Array[Vector2] = []

const RADIUS := 16.0
const CELL_SIZE := Vector2(40.0, 48.0)
const WALK_FPS := 9.0
const IDLE_FPS := 2.0
const LEAP_DURATION := 0.23
const LEAP_COOLDOWN := 1.6

var _rogue_sheet: Texture2D
var _robot_sheet: Texture2D
var _anim_time := 0.0
var _leap_elapsed := 0.0
var _landing_time := 0.0
var _fire_pose_time := 0.0
var _facing := 6 # eight facings, clockwise from down
var _anim_row := 0
var _anim_frame := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rogue_sheet = load("res://art/characters/rogue.png") as Texture2D
	_robot_sheet = load("res://art/characters/robot.png") as Texture2D
	_update_animation()

func update_timers(dt: float) -> void:
	_anim_time += dt
	fire_cooldown = maxf(0.0, fire_cooldown - dt)
	leap_cooldown = maxf(0.0, leap_cooldown - dt)
	var was_leaping := leap_time > 0.0
	if leap_time > 0.0:
		_leap_elapsed += dt
		leap_time = maxf(0.0, leap_time - dt)
		trail.push_front(position)
		if trail.size() > 8:
			trail.pop_back()
	elif not trail.is_empty():
		trail.pop_back()
	if was_leaping and leap_time <= 0.0:
		_landing_time = 0.12
	_landing_time = maxf(0.0, _landing_time - dt)
	hit_flash = maxf(0.0, hit_flash - dt)
	_fire_pose_time = maxf(0.0, _fire_pose_time - dt)
	_update_animation()
	queue_redraw()

func mark_fired() -> void:
	_fire_pose_time = 0.13
	_update_animation()
	queue_redraw()

func set_aim(direction: Vector2) -> void:
	if direction.length_squared() < 0.001:
		return
	aim = direction.normalized()
	_update_animation()
	queue_redraw()

func leap(direction: Vector2) -> bool:
	if leap_cooldown > 0.0:
		return false
	leap_direction = direction.normalized() if direction.length() > 0.1 else aim.normalized()
	leap_time = LEAP_DURATION
	_leap_elapsed = 0.0
	leap_cooldown = LEAP_COOLDOWN
	_update_animation()
	queue_redraw()
	return true

func _update_animation() -> void:
	var facing_vector := aim
	if leap_time > 0.0 and aim.length_squared() < 0.001:
		facing_vector = leap_direction
	if facing_vector.length_squared() > 0.001:
		_facing = _vector_to_facing(facing_vector)
	if leap_time > 0.0:
		var progress := _leap_elapsed / LEAP_DURATION
		if progress < 0.20:
			_anim_row = 2 # anticipation crouch
			_anim_frame = 0
		elif progress > 0.82:
			_anim_row = 4 # impact and recovery
			_anim_frame = clampi(int((progress - 0.82) * 18.0), 0, 3)
		else:
			_anim_row = 3 # airborne tuck
			_anim_frame = clampi(int(progress * 8.0) % 4, 0, 3)
	elif _landing_time > 0.0:
		_anim_row = 4
		_anim_frame = clampi(int((0.12 - _landing_time) * 30.0), 0, 3)
	elif _fire_pose_time > 0.0:
		_anim_row = 5
		_anim_frame = 0 if _fire_pose_time > 0.065 else 1
	elif velocity.length_squared() > 625.0:
		_anim_row = 1
		_anim_frame = int(_anim_time * WALK_FPS) % 4
	else:
		_anim_row = 0
		_anim_frame = int(_anim_time * IDLE_FPS) % 2

func _vector_to_facing(vector: Vector2) -> int:
	# Sprite sheets run down, down-left, left, up-left, up, up-right, right, down-right.
	var angle := atan2(vector.y, vector.x)
	var sector := posmod(roundi(angle / (TAU / 8.0)), 8)
	return posmod(sector + 6, 8)

func _draw() -> void:
	var color := Color("65e7d4") if is_player else Color("ff876c")
	if show_team_ring:
		draw_circle(Vector2(0, -20), 31.0, Color(color, 0.10))
		draw_arc(Vector2(0, -20), 32.0, 0.0, TAU, 32, Color(color, 0.82), 2.5)
	for i in range(trail.size()):
		draw_rect(Rect2(trail[i] - position + Vector2(-9, -10), Vector2(18, 20)), Color(color, 0.12 * (1.0 - float(i) / 8.0)))
	draw_rect(Rect2(-16.0, 12.0, 32.0, 5.0), Color(0.02, 0.03, 0.06, 0.38))
	if leap_time > 0.0:
		draw_arc(Vector2(0, 0), 24.0, 0.0, TAU, 24, Color(color, 0.58), 2.0)
	var sheet := _rogue_sheet if is_player and not use_enemy_sprite else _robot_sheet
	var hp_position_y := -72.0
	if sheet != null:
		var atlas_x := (_anim_frame * 8 + _facing) * int(CELL_SIZE.x)
		var source := Rect2(Vector2(atlas_x, _anim_row * int(CELL_SIZE.y)), CELL_SIZE)
		var destination := Rect2(-40.0, -68.0, 80.0, 96.0)
		if leap_time > 0.0:
			var leap_progress := clampf(_leap_elapsed / LEAP_DURATION, 0.0, 1.0)
			var lift := sin(leap_progress * PI) * 22.0
			destination.position.y -= lift
			if leap_progress < 0.20 or leap_progress > 0.82:
				var squash := 80.0
				destination.size.y = squash
				destination.position.y = 12.0 - 40.0 / 48.0 * squash - lift
		elif _landing_time > 0.0:
			var recovery := clampf(1.0 - _landing_time / 0.12, 0.0, 1.0)
			destination.size.y = lerpf(80.0, 96.0, recovery)
			destination.position.y = 12.0 - 40.0 / 48.0 * destination.size.y
		hp_position_y = destination.position.y + 2.0
		draw_texture_rect_region(sheet, destination, source, Color.WHITE)
		# A brief white edge flash preserves clear hit feedback without washing out the sprite.
		if hit_flash > 0.0:
			draw_rect(Rect2(-41, destination.position.y - 1.0, 82, destination.size.y + 2.0), Color.WHITE, false, 2.0)
	else:
		# Keep a clearly visible silhouette if assets are unavailable during development.
		draw_rect(Rect2(-11, -16, 22, 31), color)
	# The eight-way body frame and this rotating barrel make aim readable before firing.
	var barrel_angle := aim.angle() if aim.length_squared() > 0.001 else 0.0
	draw_set_transform(Vector2(0, -21), barrel_angle, Vector2.ONE)
	draw_rect(Rect2(7, -5, 29, 10), Color("1b2431"))
	draw_rect(Rect2(10, -3, 22, 6), Color("b8a575") if is_player else Color("9cb2c5"))
	draw_rect(Rect2(32, -4, 5, 8), Color("f0c970") if is_player else Color("ff7773"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in range(max_hp):
		draw_rect(Rect2(-17 + i * 8, hp_position_y, 5, 3), color if i < hp else Color("34424f"))
