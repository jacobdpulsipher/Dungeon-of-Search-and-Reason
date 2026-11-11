class_name PlanningPanel
extends Control
## Compact legend for the live planning overlay. Position this over a quiet arena corner.

const PANEL_BG := Color("152129")
const PANEL_EDGE := Color("465a5c")
const TEXT_MAIN := Color("e8f1f7")
const TEXT_MUTED := Color("9bb1c0")
const COLOR_CYAN := Color(0.2, 0.95, 1.0, 0.9)
const COLOR_AMBER := Color(1.0, 0.7, 0.2, 0.9)
const COLOR_GREEN := Color(0.25, 1.0, 0.55, 0.9)
const COLOR_CORAL := Color(1.0, 0.4, 0.3, 0.9)
const COLOR_VIOLET := Color(0.9, 0.5, 1.0, 0.9)
const COLOR_MINT := Color(0.4, 1.0, 0.7, 0.9)
const COLOR_GOLD := Color(1.0, 0.8, 0.2, 0.9)
const COLOR_SCORE := Color(1.0, 0.45, 0.3, 0.9)

const PANEL_SIZE := Vector2(1000, 154)
const HEURISTIC_PANEL_SIZE := Vector2(1000, 154)
const PAD := 12.0

var _active := false
var _method_name := "Planning"
var _explanation := "Tab reveals the enemy's live decision traces."
var _detail := ""
var _heuristics: Dictionary = {}
var _chosen_action := Vector2.ZERO
var _versus_mode := false
var _versus_left_title := ""
var _versus_left_status := ""
var _versus_right_title := ""
var _versus_right_status := ""
var _versus_reveal := false

func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true

## Update the method card and reveal visibility. Call with the enemy's active algorithm.
func set_planning_state(method_name: String, explanation: String, active: bool, detail: String = "") -> void:
	_versus_mode = false
	_method_name = method_name.strip_edges() if not method_name.strip_edges().is_empty() else "Planning"
	_explanation = explanation.strip_edges()
	_detail = detail.strip_edges()
	_active = active
	visible = true
	queue_redraw()

func set_versus_state(left_title: String, left_status: String, right_title: String, right_status: String, reveal: bool) -> void:
	_versus_mode = true
	_versus_left_title = left_title
	_versus_left_status = left_status
	_versus_right_title = right_title
	_versus_right_status = right_status
	_versus_reveal = reveal
	_heuristics.clear()
	visible = true
	queue_redraw()

func set_heuristic_lines(terms: Dictionary, action: Vector2) -> void:
	_heuristics = terms
	_chosen_action = action
	size = HEURISTIC_PANEL_SIZE if not terms.is_empty() else PANEL_SIZE
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_BG)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 3)), Color("b78649"))
	var font := get_theme_default_font()
	if font == null: return
	if _versus_mode:
		draw_string(font, Vector2(18, 28), "VERSUS · LIVE DECISIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("deb879"))
		draw_line(Vector2(500, 18), Vector2(500, 136), PANEL_EDGE, 2)
		draw_string(font, Vector2(18, 60), _fit_text(font, _versus_left_title, 455, 18), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_CYAN)
		draw_string(font, Vector2(18, 93), _fit_text(font, _versus_left_status, 455, 16), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_MAIN)
		draw_string(font, Vector2(518, 60), _fit_text(font, _versus_right_title, 455, 18), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_CORAL)
		draw_string(font, Vector2(518, 93), _fit_text(font, _versus_right_status, 455, 16), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_MAIN)
		draw_string(font, Vector2(18, 132), "TAB / Y  HIDE ALGORITHM VISUALS" if _versus_reveal else "TAB / Y  SHOW ALGORITHM VISUALS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT_MUTED)
		return
	if not _active:
		draw_string(font, Vector2(18, 31), "TACTICAL TELEMETRY / STANDBY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("deb879"))
		draw_string(font, Vector2(18, 63), "TAB / Y  Show enemy planning", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT_MAIN)
		draw_string(font, Vector2(18, 90), "Read its search, route and decision scores while the duel continues.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT_MUTED)
		draw_string(font, Vector2(18, 123), _explanation, HORIZONTAL_ALIGNMENT_LEFT, 950, 12, TEXT_MUTED)
		return
	draw_string(font, Vector2(18, 26), "TACTICAL TELEMETRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("deb879"))
	draw_string(font, Vector2(18, 51), _fit_text(font, _method_name, 280, 19), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, TEXT_MAIN)
	draw_multiline_string(font, Vector2(18, 76), _explanation, HORIZONTAL_ALIGNMENT_LEFT, 300, 12, 3, TEXT_MUTED)
	if not _detail.is_empty():
		draw_string(font, Vector2(18, 137), _fit_text(font, _detail, 300, 12), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_MAIN)
	draw_line(Vector2(336, 18), Vector2(336, 135), PANEL_EDGE, 2)
	var entries := _legend_for_method(_method_name)
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		_draw_legend_item(font, Vector2(354, 35 + i * 26), entry["color"], entry["text"], bool(entry.get("score", false)))
	if not _heuristics.is_empty():
		var rows := [["Shot", "shot"], ["Range", "range"], ["Pressure", "corner"], ["Flank", "behind"], ["Proximity", "close"], ["Escape", "mobility"], ["Forecast", "lookahead"], ["Motion", "momentum"], ["TOTAL", "total"]]
		var tactical := _heuristics.has("projectile")
		if tactical:
			rows = [["Base", "base"], ["Bullet", "projectile"], ["Aim", "aim_safety"], ["Exits", "escape"], ["Belief", "belief"], ["TOTAL", "total"]]
		draw_string(font, Vector2(354, 86 if tactical else 68), "MOVE: " + _action_name(_chosen_action).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_MAIN)
		for i in range(rows.size()):
			var row: Array = rows[i]
			var value := float(_heuristics.get(row[1], 0.0))
			var pos := Vector2(354 + i * 105, 109) if tactical else Vector2(354 + (i % 5) * 125, 96 + (i / 5) * 34)
			draw_string(font, pos, str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT_MUTED)
			draw_string(font, pos + Vector2(0, 15), "%+.1f" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_GREEN if value > 0.01 else (COLOR_CORAL if value < -0.01 else TEXT_MUTED))

func _action_name(action: Vector2) -> String:
	if action.length_squared() < 0.01:
		return "hold position"
	var vertical := "up" if action.y < -0.2 else ("down" if action.y > 0.2 else "")
	var horizontal := "left" if action.x < -0.2 else ("right" if action.x > 0.2 else "")
	return (vertical + " " + horizontal).strip_edges()

func _legend_for_method(method_name: String) -> Array[Dictionary]:
	var method := method_name.to_lower()
	var items: Array[Dictionary] = []
	if method.contains("direct") or method.contains("stationary") or method.contains("sentry"):
		items.append({"color": TEXT_MUTED, "text": "Direct aim at your current position"})
		items.append({"color": TEXT_MUTED, "text": "No search tree or route in this lesson"})
	elif method.contains("bfs") or method.contains("breadth first"):
		items.append({"color": COLOR_CYAN, "text": "Cyan squares: explored BFS cells"})
		items.append({"color": COLOR_CYAN, "text": "Cyan line: shortest route"})
		items.append({"color": COLOR_CORAL, "text": "Coral ring: last observed target fix"})
	elif method.contains("rrt*") or method.contains("rrt star"):
		items.append({"color": COLOR_GREEN, "text": "Green branches: rewired RRT* tree"})
		items.append({"color": COLOR_CYAN, "text": "Cyan line: selected route"})
		items.append({"color": COLOR_CORAL, "text": "Coral ring: last observed target fix"})
	elif method.contains("rrt"):
		items.append({"color": COLOR_AMBER, "text": "Amber branches: sampled RRT tree"})
		items.append({"color": COLOR_CYAN, "text": "Cyan line: selected route"})
		items.append({"color": COLOR_CORAL, "text": "Coral ring: last observed target fix"})
	elif method.contains("particle"):
		items.append({"color": COLOR_VIOLET, "text": "Purple dots: particle hypotheses"})
		items.append({"color": COLOR_VIOLET, "text": "Purple ring: estimate + uncertainty"})
		items.append({"color": COLOR_CYAN, "text": "Cyan line: navigation route"})
	elif method.contains("slam"):
		items.append({"color": COLOR_MINT, "text": "Mint marks: pose + mapped landmarks"})
		items.append({"color": COLOR_GOLD, "text": "Gold ring: player estimate"})
		items.append({"color": COLOR_CYAN, "text": "Cyan line: navigation route"})
	elif method.contains("belief minimax"):
		items.append({"color": COLOR_VIOLET, "text": "Purple dots: possible hidden positions"})
		items.append({"color": COLOR_SCORE, "text": "NEW: belief score ×1.45; prior scores ×1.0", "score": true})
	elif method.contains("projectile"):
		items.append({"color": COLOR_CORAL, "text": "Coral lines: incoming bullet paths"})
		items.append({"color": COLOR_SCORE, "text": "NEW: bullet danger ×1.45", "score": true})
	elif method.contains("aim anticipation"):
		items.append({"color": COLOR_CORAL, "text": "Avoids your current firing lane"})
		items.append({"color": COLOR_SCORE, "text": "NEW: aim danger ×1.45; bullet ×1.0", "score": true})
	elif method.contains("escape routes"):
		items.append({"color": COLOR_GREEN, "text": "Rewards several clear next moves"})
		items.append({"color": COLOR_SCORE, "text": "NEW: escape space ×1.45; prior scores ×1.0", "score": true})
	elif method.contains("minimax") or method.contains("adaptive"):
		items.append({"color": COLOR_SCORE, "text": "Action rays: red low → green high score", "score": true})
	else:
		items.append({"color": TEXT_MUTED, "text": "No search trace for this method"})
	return items

func _draw_legend_item(font: Font, origin: Vector2, swatch: Color, text: String, score: bool = false) -> void:
	if score:
		draw_circle(origin + Vector2(3, -4), 3.0, Color("ff6d5c"))
		draw_circle(origin + Vector2(9, -4), 3.0, Color("e3c75b"))
		draw_circle(origin + Vector2(15, -4), 3.0, Color("72d98e"))
		draw_string(font, origin + Vector2(24, 0), _fit_text(font, text, PANEL_SIZE.x - 24 - PAD, 13), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT_MUTED)
	else:
		draw_rect(Rect2(origin + Vector2(0, -8), Vector2(8, 8)), swatch)
		draw_string(font, origin + Vector2(14, 0), _fit_text(font, text, PANEL_SIZE.x - 14 - PAD, 13), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT_MUTED)

func _fit_text(font: Font, value: String, max_width: float, font_size: int) -> String:
	var result := value
	while not result.is_empty() and font.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
		result = result.left(result.length() - 1)
	if result != value and result.length() > 3:
		result = result.left(result.length() - 1) + "…"
	return result
