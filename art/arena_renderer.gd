class_name ArenaRenderer
extends Node2D
## Salvage hangar, drawn on an intentional four-pixel grid.
var room: Dictionary = {"size": Vector2(1000, 600), "obstacles": []}

func set_room(value: Dictionary) -> void:
	room = value
	queue_redraw()

func draw_arena(value: Dictionary) -> void:
	set_room(value)

func _draw() -> void:
	var extent: Vector2 = room.get("size", Vector2(1000, 600))
	draw_rect(Rect2(Vector2(-12, -12), extent + Vector2(24, 24)), Color("101820"))
	draw_rect(Rect2(Vector2.ZERO, extent), Color("303a40"))
	# Offset deck plates, rivets and sparse wear; deterministic so the room stays quiet.
	for y in range(0, int(extent.y), 40):
		for x in range(0, int(extent.x), 80):
			var offset := 40 if (y / 40) % 2 else 0
			var at := Vector2(x + offset, y)
			if at.x >= extent.x: continue
			var plate_width := minf(78, extent.x - at.x)
			draw_rect(Rect2(at + Vector2(2, 2), Vector2(plate_width - 2, 36)), Color("354046") if (x + y) % 120 else Color("323d43"))
			draw_rect(Rect2(at + Vector2(4, 4), Vector2(plate_width - 6, 2)), Color("404a4d"))
			draw_rect(Rect2(at + Vector2(4, 32), Vector2(4, 4)), Color("242e34"))
			if (x * 7 + y) % 160 == 0:
				draw_rect(Rect2(at + Vector2(24, 18), Vector2(20, 2)), Color("29363c"))
	# Recessed perimeter with hazard-stripe loading edges.
	for top in [true, false]:
		var edge_y := 0.0 if top else extent.y - 12
		draw_rect(Rect2(0, edge_y, extent.x, 12), Color("1b272f"))
		for x in range(16, int(extent.x)-16, 24):
			draw_rect(Rect2(x, edge_y + 4, 12, 4), Color("aa8950"))
	for edge_x in [0.0, extent.x - 12]:
		draw_rect(Rect2(edge_x, 12, 12, extent.y - 24), Color("1d2b33"))
		for y in range(36, int(extent.y)-20, 88):
			draw_rect(Rect2(edge_x + 4, y, 4, 20), Color("6aa0a4"))
	# Painted landing marks retain the duel's open sightlines.
	for mark in [Vector2(80, 80), Vector2(extent.x-80, extent.y-80)]:
		draw_rect(Rect2(mark-Vector2(24, 2), Vector2(48, 4)), Color("777d6a"))
		draw_rect(Rect2(mark-Vector2(2, 24), Vector2(4, 48)), Color("777d6a"))
	for obstacle in room.get("obstacles", []):
		var rect: Rect2 = obstacle
		_draw_crate(rect)

func _draw_crate(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 8), rect.size), Color("1b252b"))
	draw_rect(rect, Color("17272f"))
	draw_rect(Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), Color("65716a"))
	draw_rect(Rect2(rect.position + Vector2(4, rect.size.y-12), Vector2(rect.size.x-8, 8)), Color("384c4d"))
	draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x-8, 4)), Color("8b9480"))
	for x in [8.0, rect.size.x - 16]:
		draw_rect(Rect2(rect.position + Vector2(x, 8), Vector2(8, rect.size.y-20)), Color("344b4f"))
		draw_rect(Rect2(rect.position + Vector2(x+2, 10), Vector2(2, rect.size.y-24)), Color("9a9f83"))
	var center := rect.get_center()
	draw_rect(Rect2(center-Vector2(14, 8), Vector2(28, 16)), Color("2a3a3e"))
	draw_rect(Rect2(center-Vector2(10, 4), Vector2(12, 4)), Color("c1a360"))
	draw_rect(Rect2(center+Vector2(4, -4), Vector2(4, 8)), Color("849c89"))
