extends Node2D

var velocity := Vector2.ZERO
var from_player := true
var life := 2.0
var previous := Vector2.ZERO

func _draw() -> void:
	var color := Color("98ffee") if from_player else Color("ffae85")
	var direction := velocity.normalized()
	# Hard-edged tracer and square core keep the projectile readable against pixel scenery.
	draw_line(-direction * 15.0, Vector2.ZERO, Color(color, 0.30), 5.0, false)
	draw_line(-direction * 9.0, -direction * 1.0, color.darkened(0.16), 3.0, false)
	draw_rect(Rect2(-2.5, -2.5, 5.0, 5.0), color)
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color.WHITE)
