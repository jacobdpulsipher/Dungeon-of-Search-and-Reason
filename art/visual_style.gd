class_name VisualStyle
extends RefCounted
## Shared, resolution independent visual language for SIGNAL / COVER.

const BACKGROUND := Color("101820")
const FLOOR := Color("303a40")
const FLOOR_GRID := Color("1b2a3d")
const WALL := Color("34495f")
const COVER := Color("273c50")
const COVER_TOP := Color("3c566b")
const TEXT := Color("e8f1f7")
const MUTED := Color("91a8bb")
const PLAYER := Color("80c6be")
const ENEMY := Color("ee7960")
const PLAN := Color("deb879")
const SUCCESS := Color("92dbac")

static func draw_actor(canvas: CanvasItem, position: Vector2, aim: Vector2, is_player: bool, health_ratio: float = 1.0) -> void:
	var texture: Texture2D = load("res://art/characters/rogue.png" if is_player else "res://art/characters/robot.png")
	if texture == null: return
	var facing := posmod(posmod(roundi(aim.angle() / (TAU / 8.0)), 8) + 6, 8)
	canvas.draw_texture_rect_region(texture, Rect2(position + Vector2(-40, -68), Vector2(80, 96)), Rect2(facing * 40, 0, 40, 48))
	if health_ratio < 1.0:
		canvas.draw_rect(Rect2(position + Vector2(-16, -72), Vector2(32, 4)), WALL)
		canvas.draw_rect(Rect2(position + Vector2(-16, -72), Vector2(32 * clampf(health_ratio, 0, 1), 4)), PLAYER if is_player else ENEMY)

static func draw_radar(canvas: CanvasItem, origin: Vector2, radius: float, angle: float, strength: float = 1.0) -> void:
	var alpha := clampf(strength, 0.0, 1.0)
	for fraction in [0.33, 0.66, 1.0]:
		canvas.draw_arc(origin, radius * fraction, 0, TAU, 96, Color(PLAYER, 0.12 * alpha), 1, true)
	var wedge := PackedVector2Array([origin])
	for step in range(17):
		wedge.append(origin + Vector2.from_angle(angle - 0.5 + step * 0.5 / 16.0) * radius)
	canvas.draw_colored_polygon(wedge, Color(PLAYER, 0.065 * alpha))
	canvas.draw_line(origin, origin + Vector2.from_angle(angle) * radius, Color(PLAYER, 0.65 * alpha), 1.5, true)

static func draw_route(canvas: CanvasItem, route: PackedVector2Array, phase: float = 0.0) -> void:
	if route.size() < 2:
		return
	canvas.draw_polyline(route, Color(PLAN, 0.18), 7, true)
	for index in range(route.size() - 1):
		var start := route[index]
		var finish := route[index + 1]
		var distance := start.distance_to(finish)
		var direction := start.direction_to(finish)
		var offset := fposmod(phase * 25, 15.0)
		while offset < distance:
			canvas.draw_line(start + direction * offset, start + direction * minf(offset + 7, distance), Color(PLAN, 0.8), 2, true)
			offset += 15
	canvas.draw_arc(route[route.size() - 1], 8, 0, TAU, 24, PLAN, 2, true)
