extends SceneTree

const Brain = preload("res://scripts/enemy_brain.gd")
const ARENA := Rect2(0, 0, 960, 640)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_radar_commit_delay()
	_test_detour_arrival()
	_test_fix_freezes_until_pulse()
	_test_disconnected_radar()
	_test_tree_integrity(3)
	_test_tree_integrity(4)
	_test_corner_navigation()
	_test_stationary_cover_fire()
	_test_slam_mapping()
	_test_adaptive_habits()
	_test_hidden_reasoning_pursuit()
	_test_minimax_heuristics()
	_test_new_heuristics()
	_test_belief_minimax()
	if failures.is_empty():
		print("PASS: brain algorithm checks")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _make_brain(stage: int, obstacles: Array[Rect2] = [], seed: int = 17) -> EnemyBrain:
	var brain := Brain.new()
	brain.setup(stage, ARENA, obstacles, seed)
	return brain

func _tick(brain: EnemyBrain, seconds: float, enemy: Vector2, player: Vector2) -> void:
	brain.tick(seconds, enemy, player, Vector2.ZERO)

func _test_radar_commit_delay() -> void:
	for stage in [2, 3, 4]:
		var brain := _make_brain(stage)
		var enemy := Vector2(140, 320)
		var player := Vector2(740, 320)
		_tick(brain, 0.01, enemy, player)
		_check(not brain.has_fix, "stage %d radar committed on its first tick" % stage)

func _test_detour_arrival() -> void:
	var enemy := Vector2(140, 320)
	var straight_player := Vector2(620, 320)
	var detour_player := Vector2(620, 320)
	var clear_brain := _make_brain(2)
	var blocked_brain := _make_brain(2, [Rect2(340, 260, 90, 120)])
	_tick(clear_brain, 0.01, enemy, straight_player)
	_tick(blocked_brain, 0.01, enemy, detour_player)
	var target_cell := Vector2i((straight_player - clear_brain.bounds.position) / 32.0)
	_check(clear_brain.radar_lookup.has(target_cell), "unobstructed equal-range target missing from radar")
	_check(blocked_brain.radar_lookup.has(target_cell), "detour equal-range target missing from radar")
	if clear_brain.radar_lookup.has(target_cell) and blocked_brain.radar_lookup.has(target_cell):
		var clear_distance: float = clear_brain.radar_lookup[target_cell]
		var detour_distance: float = blocked_brain.radar_lookup[target_cell]
		_check(detour_distance > clear_distance, "radar detour did not increase arrival distance (%s vs %s)" % [detour_distance, clear_distance])

func _test_fix_freezes_until_pulse() -> void:
	var brain := _make_brain(2)
	var enemy := Vector2(140, 320)
	var player := Vector2(300, 320)
	_tick(brain, 0.01, enemy, player)
	var guard := 0
	while not brain.has_fix and guard < 100:
		_tick(brain, 0.05, enemy, player)
		guard += 1
	_check(brain.has_fix, "stage 2 radar never committed a reachable player")
	if brain.has_fix:
		var committed := brain.fix
		var moved_player := Vector2(440, 320)
		_tick(brain, 0.25, enemy, moved_player)
		_check(brain.fix == committed, "committed radar fix changed before next pulse")
		var pulse_guard := 0
		while brain.fix == committed and pulse_guard < 100:
			_tick(brain, 0.05, enemy, moved_player)
			pulse_guard += 1
		_check(brain.fix != committed, "radar fix did not update on the next pulse")

func _test_disconnected_radar() -> void:
	var barrier := Rect2(470, 0, 20, 640)
	var brain := _make_brain(2, [barrier])
	var enemy := Vector2(250, 320)
	var player := Vector2(720, 320)
	_tick(brain, 0.01, enemy, player)
	var player_cell := Vector2i((player - brain.bounds.position) / 32.0)
	_check(not brain.radar_lookup.has(player_cell), "full wall barrier left player cell in radar component")
	for i in range(65):
		_tick(brain, 0.05, enemy, player)
	_check(not brain.has_fix, "radar revealed player across disconnected wall")

func _test_tree_integrity(stage: int) -> void:
	var wall := Rect2(450, 220, 55, 190)
	var brain := _make_brain(stage, [wall], 91 + stage)
	var enemy := Vector2(140, 320)
	var player := Vector2(730, 320)
	_tick(brain, 0.01, enemy, player)
	var guard := 0
	while not brain.has_fix and guard < 100:
		_tick(brain, 0.05, enemy, player)
		guard += 1
	_check(brain.has_fix, "stage %d tree test never acquired radar fix" % stage)
	for i in range(36):
		_tick(brain, 0.05, enemy, player)
	_check(brain.nodes.size() <= 520, "stage %d tree unexpectedly exceeded 520-node cap: %d" % [stage, brain.nodes.size()])
	if brain.nodes.size() > 520:
		print("INFO: stage %d tree cap overshoot observed: %d nodes (allowed report range through 537)" % [stage, brain.nodes.size()])
	for i in range(brain.nodes.size()):
		var seen: Dictionary = {}
		var cursor := i
		var steps := 0
		while cursor >= 0:
			_check(cursor < brain.nodes.size(), "stage %d parent index out of range" % stage)
			if cursor >= brain.nodes.size():
				break
			_check(not seen.has(cursor), "stage %d parent cycle at node %d" % [stage, i])
			if seen.has(cursor):
				break
			seen[cursor] = true
			var parent: int = brain.parents[cursor]
			if cursor == 0:
				_check(parent == -1, "stage %d root parent is not -1" % stage)
				break
			_check(parent >= 0 and parent < brain.nodes.size(), "stage %d node %d has invalid parent %d" % [stage, cursor, parent])
			if parent < 0 or parent >= brain.nodes.size():
				break
			_check(brain._clear(brain.nodes[cursor], brain.nodes[parent]), "stage %d node %d parent edge collides" % [stage, cursor])
			cursor = parent
			steps += 1
			_check(steps <= brain.nodes.size(), "stage %d parent chain failed to terminate" % stage)

func _test_corner_navigation() -> void:
	var brain := Brain.new()
	var walls: Array[Rect2] = [Rect2(280,160,110,140), Rect2(610,300,110,140)]
	brain.setup(2, Rect2(0,0,1000,600), walls, 386)
	var enemy := Vector2(870,300)
	var player := Vector2(110,300)
	for frame in range(600):
		var command: Dictionary = brain.tick(1.0/60.0,enemy,player,Vector2.ZERO)
		var next: Vector2 = enemy+command.move*190.0/60.0
		if brain._point_ok(next,17):
			enemy=next
	_check(enemy.distance_to(player) < 20.0, "BFS follower stalled at a corner: %s" % enemy)

func _test_stationary_cover_fire() -> void:
	var brain := _make_brain(1,[Rect2(430,150,90,300)])
	var enemy := Vector2(870,300)
	var fired := false
	for frame in range(120):
		var command: Dictionary = brain.tick(1.0/60,enemy,Vector2(90,300),Vector2.ZERO)
		_check(command.move == Vector2.ZERO,"stationary stage moved")
		fired = fired or command.shoot
	_check(fired,"stationary stage failed to fire at full room range through cover")

func _test_hidden_reasoning_pursuit() -> void:
	var cover: Array[Rect2] = [Rect2(450, 220, 100, 160)]
	for reasoning_stage in [7, 8]:
		var searching := _make_brain(reasoning_stage, cover, 92)
		var search_command: Dictionary = searching.tick(1.0 / 30.0, Vector2(760, 300), Vector2(240, 300), Vector2.ZERO)
		_check(search_command.move != Vector2.ZERO and not searching.path.is_empty(), "stage %d did not search before its first sighting" % reasoning_stage)
		var brain := _make_brain(reasoning_stage, cover, 91)
		var enemy := Vector2(760, 480)
		var player := Vector2(240, 480)
		brain.tick(1.0 / 60.0, enemy, player, Vector2(0, -180))
		_check(brain.has_fix, "stage %d did not remember visible player" % reasoning_stage)
		enemy = Vector2(760, 300)
		player = Vector2(240, 300)
		_check(not brain._clear(enemy, player, 0.0), "stage %d hidden pursuit fixture has clear sight" % reasoning_stage)
		var start := enemy
		var moved := false
		var reacquired := false
		for frame in range(180):
			var command: Dictionary = brain.tick(1.0 / 30.0, enemy, player, Vector2.ZERO)
			var next: Vector2 = enemy + command.move * 150.0 / 30.0
			if brain._point_ok(next) and brain._clear(enemy, next):
				enemy = next
			moved = moved or enemy.distance_to(start) > 100.0
			reacquired = reacquired or brain._clear(enemy, player, 0.0)
		_check(moved, "stage %d stood still behind cover instead of pursuing" % reasoning_stage)
		_check(reacquired, "stage %d failed to round cover and regain sight" % reasoning_stage)
		_check(brain.pursuit_goal != Vector2.ZERO, "stage %d chose no pursuit goal" % reasoning_stage)

func _test_slam_mapping() -> void:
	var brain := _make_brain(6,[Rect2(430,220,90,160)])
	_check(brain._estimated_walls().is_empty(),"SLAM planner knew unobserved walls")
	brain.has_fix = true
	brain.estimate = Vector2(760,320)
	brain._slam_navigate(Vector2(150,320))
	_check(not brain.path.is_empty(),"SLAM initial unknown-map planner produced no route")
	if not brain.path.is_empty():
		_check(not brain._clear(Vector2(150,320),brain.path[0]),"SLAM initial planner secretly routed around unobserved cover")
	_check(brain.walls.size() == 1,"SLAM planning failed to restore physical collision geometry")
	brain.has_fix = false

	for frame in range(240):
		var enemy := Vector2(330,180) if frame < 120 else Vector2(620,440)
		brain.tick(1.0/60,enemy,Vector2(180,450),Vector2.ZERO)
	_check(brain.landmark_ids.size() >= 2,"SLAM failed to initialize visible landmarks")
	_check(not brain._estimated_walls().is_empty(),"SLAM failed to construct cover from observed landmark pairs")
	for row in range(brain.covariance.size()):
		_check(is_finite(brain.covariance[row][row]) and brain.covariance[row][row] > 0,"EKF covariance lost finite positive diagonal")
		for col in range(brain.covariance.size()):
			_check(absf(brain.covariance[row][col]-brain.covariance[col][row]) < 0.00001,"EKF covariance lost symmetry")

func _test_adaptive_habits() -> void:
	var brain := _make_brain(8)
	for frame in range(240):
		brain.tick(1.0/60,Vector2(600,320),Vector2(300,320),Vector2(0,220))
	_check(brain.habits.x > 0.8,"adaptive stage failed to learn sustained strafe habit")
	for frame in range(240):
		brain.tick(1.0/60,Vector2(600,320),Vector2(300,320),Vector2(220,0))
	_check(brain.habits.y > 0.8 and brain.habits.x < 0.2,"adaptive stage failed to update habits after tactic changed")

func _test_minimax_heuristics() -> void:
	var brain := _make_brain(7)
	var open_terms := brain._utility_terms(Vector2(440, 300), Vector2(300, 300), Vector2.RIGHT)
	var corner_terms := brain._utility_terms(Vector2(250, 250), Vector2(90, 90), Vector2.RIGHT)
	_check(float(corner_terms["corner"]) > float(open_terms["corner"]), "minimax did not reward corner pressure")
	var behind_terms := brain._utility_terms(Vector2(180, 300), Vector2(400, 300), Vector2.RIGHT)
	var front_terms := brain._utility_terms(Vector2(620, 300), Vector2(400, 300), Vector2.RIGHT)
	_check(float(behind_terms["behind"]) > 0.0 and float(front_terms["behind"]) == 0.0, "minimax did not distinguish behind player's aim")
	brain.tick(1.0 / 60.0, Vector2(600, 300), Vector2(300, 300), Vector2.ZERO, Vector2.LEFT)
	_check(brain.minimax_terms.has("total"), "minimax did not expose its chosen score breakdown")
	if brain.minimax_terms.has("total"):
		var components := 0.0
		for key in brain.minimax_terms:
			if key != "total":
				components += float(brain.minimax_terms[key])
		_check(absf(components - float(brain.minimax_terms["total"])) < 0.0001, "displayed minimax terms do not sum to the chosen score")

func _test_new_heuristics() -> void:
	var brain := _make_brain(9)
	var incoming: Array[Dictionary] = [{"position": Vector2(450, 300), "velocity": Vector2(620, 0), "life": 1.0}]
	_check(brain._projectile_danger(Vector2(600, 300), Vector2.ZERO, incoming, 175.0) > brain._projectile_danger(Vector2(600, 300), Vector2.UP, incoming, 175.0), "sidestep did not reduce incoming bullet danger")
	var command: Dictionary = brain.tick(1.0 / 60.0, Vector2(600, 300), Vector2(300, 300), Vector2.ZERO, Vector2.RIGHT, incoming, 175.0)
	_check(absf(command.move.y) > 0.2, "projectile lesson did not sidestep a direct shot")
	_check(brain._lesson_weight(9) > 1.0, "new projectile heuristic was not emphasized")
	brain = _make_brain(10)
	_check(brain._lesson_weight(9) == 1.0 and brain._lesson_weight(10) > 1.0, "heuristic weights did not settle in the next level")
	_check(brain._aim_line_danger(Vector2(600, 300), Vector2(300, 300), Vector2.RIGHT) > brain._aim_line_danger(Vector2(600, 430), Vector2(300, 300), Vector2.RIGHT), "aim anticipation did not detect the firing lane")
	brain = _make_brain(11)
	_check(brain._escape_score(Vector2(480, 320)) > brain._escape_score(Vector2(50, 50)), "escape score did not favor open space")
	_check(brain._lesson_weight(9) == 1.0 and brain._lesson_weight(10) == 1.0 and brain._lesson_weight(11) > 1.0, "escape lesson did not retain balanced earlier scores")

func _test_belief_minimax() -> void:
	var wall := Rect2(450, 220, 100, 160)
	var brain := _make_brain(12, [wall])
	brain.tick(1.0 / 60.0, Vector2(700, 480), Vector2(300, 480), Vector2.ZERO)
	_check(brain.has_fix and brain.particles.size() == 100, "belief lesson did not initialize from a sighting")
	var command: Dictionary = brain.tick(1.0 / 30.0, Vector2(700, 300), Vector2(300, 300), Vector2.ZERO)
	_check(brain.belief_scores.size() == 9, "hidden minimax did not score particle hypotheses")
	_check(command.move.length_squared() > 0.01, "hidden belief planner chose no movement")
	_check(brain._lesson_weight(9) == 1.0 and brain._lesson_weight(12) > 1.0, "final lesson did not retain earlier heuristics")
