class_name EnemyBrain
extends RefCounted
## Bounded, live algorithms. All positions are in arena-local coordinates.
var stage := 1
var bounds := Rect2()
var walls: Array[Rect2] = []
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var sense_timer := 0.0
var plan_timer := 0.0
var fire_timer := 1.0
var radar_age := 99.0
var radar_cells: Array[Vector2] = []
var radar_distances: Array[float] = []
var radar_lookup: Dictionary = {}
var radar_origin := Vector2.ZERO
var radar_committed := false
var fix := Vector2.ZERO
var has_fix := false
var path: Array[Vector2] = []
var nodes: Array[Vector2] = []
var parents: Array[int] = []
var costs: Array[float] = []
var explored: Array[Vector2] = []
var particles: Array[Vector2] = []
var weights: Array[float] = []
var estimate := Vector2.ZERO
var estimate_velocity := Vector2.ZERO
var uncertainty := 0.0
var status := "Waiting"
var debug_aim_target := Vector2.ZERO
var expansions := 0
var goal_index := -1
var tree_start := Vector2.ZERO
var seen_player := Vector2.ZERO
var last_seen := Vector2.ZERO
var player_sample := Vector2.ZERO
var sample_timer := 0.0
var habits := Vector3.ZERO # measured strafe, aggression, and dodging
var action_scores: Array[float] = []
var search_branches := 0
var minimax_terms: Dictionary = {}
var minimax_action := Vector2.ZERO
var previous_tactical_move := Vector2.ZERO
# EKF-SLAM state: own x,y followed by unknown landmark x,y coordinates.
# Heading is observed directly in this top-down world; motion is noisy odometry.
var slam_state: Array[float] = []
var covariance: Array = []
var landmark_ids: Dictionary = {}
var landmarks: Array[Vector2] = []
var previous_enemy := Vector2.ZERO
var slam_ready := false
var measurement_timer := 0.0
var explore_timer := 0.0
var explore_goal := Vector2.ZERO
var sight_age := 99.0
var pursuit_timer := 0.0
var pursuit_goal := Vector2.ZERO
var last_player_aim := Vector2.RIGHT
var belief_plan_timer := 0.0
var belief_scores: Array[float] = []
var last_belief_observation := Vector2.ZERO
var has_belief_observation := false
var belief_observation_age := 0.0
var observed_bullets: Array[Dictionary] = []

func setup(number: int, arena: Rect2, obstacles: Array[Rect2], rng_seed: int = 1) -> void:
	stage = clampi(number, 1, 12)
	bounds = arena.grow(-22.0)
	walls = obstacles.duplicate()
	rng.seed = rng_seed
	for wall in walls:
		landmarks.append(wall.position)
		landmarks.append(wall.end)

func tick(dt: float, enemy_pos: Vector2, player_pos: Vector2, player_velocity: Vector2, player_aim: Vector2 = Vector2.RIGHT, incoming: Array[Dictionary] = [], enemy_speed: float = 180.0) -> Dictionary:
	elapsed += dt
	sense_timer -= dt
	plan_timer -= dt
	fire_timer -= dt
	radar_age += dt
	measurement_timer -= dt
	explore_timer -= dt
	pursuit_timer -= dt
	belief_plan_timer -= dt
	observed_bullets = incoming
	var move := Vector2.ZERO
	var aim_target := player_pos
	var visible := _clear(enemy_pos, player_pos, 0.0)
	match stage:
		1:
			status = "Direct aim · stationary sentry"
			move = Vector2.ZERO
		2, 3, 4:
			# Each pulse propagates through free-space cells at finite speed.
			# Commit exactly one observation when the wave physically reaches it.
			if sense_timer <= 0.0:
				sense_timer = 3.2
				radar_age = 0.0
				_start_radar(enemy_pos)
			if not radar_committed and radar_age < 2.5:
				var player_cell := Vector2i((player_pos - bounds.position) / 32.0)
				if radar_lookup.has(player_cell):
					var arrival: float = float(radar_lookup[player_cell]) / 600.0
					if radar_age >= arrival and radar_age < arrival + 0.18:
						fix = player_pos
						has_fix = true
						radar_committed = true
						plan_timer = 0.0
			if has_fix:
				aim_target = fix
				if plan_timer <= 0.0:
					plan_timer = 1.2 if stage == 2 else 2.8
					if stage == 2:
						path = _bfs(enemy_pos, fix, true)
					else:
						_start_tree(enemy_pos)
				if stage >= 3 and nodes.size() < 520:
					_grow_tree(fix, stage == 4, 18)
				move = _follow(enemy_pos)
				status = ["", "", "BFS · shortest grid route", "RRT · sampled tree", "RRT* · rewiring lower-cost routes"][stage]
			else:
				aim_target = enemy_pos + Vector2.LEFT
				status = "Radar searching · no reachable fix"
		5:
			_particle_tick(dt, enemy_pos, player_pos, player_velocity, visible)
			aim_target = estimate + estimate_velocity * 0.23
			move = _navigate(enemy_pos, estimate if has_fix else _exploration_target(enemy_pos))
			status = "Particle filter · %d hypotheses" % particles.size()
		6:
			_slam_tick(dt, enemy_pos, player_pos, visible)
			aim_target = estimate + estimate_velocity * 0.18
			move = _slam_navigate(enemy_pos)
			status = "EKF-SLAM · %d mapped landmarks" % landmark_ids.size()
		7:
			if visible:
				estimate = player_pos
				estimate_velocity = player_velocity
				has_fix = true
				sight_age = 0.0
				path.clear()
				if plan_timer <= 0.0:
					plan_timer = 0.32
					seen_player = _minimax(enemy_pos, estimate, estimate_velocity, player_aim)
				move = seen_player
				status = "Minimax · %d adversarial leaves" % search_branches
			else:
				sight_age += dt
				move = _pursue_hidden(enemy_pos)
				status = "Minimax · intercepting last sighting" if has_fix and sight_age < 4.0 else "Minimax · searching for contact"
			aim_target = estimate + estimate_velocity * 0.26
		8:
			if visible:
				estimate = player_pos
				estimate_velocity = player_velocity
				has_fix = true
				sight_age = 0.0
				path.clear()
				_adapt(dt, enemy_pos, player_pos, player_velocity, true)
				move = seen_player
				status = "Adaptive · strafe %.0f%% / rush %.0f%%" % [habits.x * 100.0, habits.y * 100.0]
			else:
				sight_age += dt
				move = _pursue_hidden(enemy_pos)
				status = "Adaptive · flanking predicted position" if has_fix and sight_age < 4.0 else "Adaptive · searching for contact"
			aim_target = estimate + estimate_velocity * lerpf(0.12, 0.40, habits.x)
		9, 10, 11, 12:
			if stage == 12:
				_belief_tick(dt, enemy_pos, player_pos, visible)
			if visible:
				estimate = player_pos
				estimate_velocity = player_velocity
				has_fix = true
				sight_age = 0.0
				last_player_aim = player_aim
				path.clear()
				if plan_timer <= 0.0:
					plan_timer = 0.32
					seen_player = _minimax(enemy_pos, estimate, estimate_velocity, player_aim)
				move = seen_player
			else:
				sight_age += dt
				move = _belief_pursue_hidden(enemy_pos) if stage == 12 else _pursue_hidden(enemy_pos)
			move = _tactical_move(enemy_pos, player_pos if visible else estimate, last_player_aim, move, incoming, enemy_speed, visible)
			aim_target = estimate + estimate_velocity * 0.22
			status = ["", "", "", "", "", "", "", "", "", "Projectile dodge · tracking incoming shots", "Aim anticipation · watching your barrel", "Escape routes · keeping exits open", "Belief minimax · %d hypotheses" % particles.size()][stage]
	var aim := (aim_target - enemy_pos).normalized()
	debug_aim_target = aim_target
	# Aiming is imperfect, attacks have a shared cadence, and cover always blocks shots.
	var allowed := stage == 1 or has_fix
	var can_shoot := allowed and (stage == 1 or (_clear(enemy_pos, aim_target, 3.0) and enemy_pos.distance_to(aim_target) < 760.0))
	var shoot := can_shoot and fire_timer <= 0.0
	if shoot:
		fire_timer = 0.92 if stage < 5 else 0.78
		aim = aim.rotated(rng.randf_range(-0.045, 0.045))
	var leap := stage >= 7 and visible and enemy_pos.distance_to(player_pos) < 165.0 and rng.randf() < dt * 0.26
	return {"move": move, "aim": aim, "shoot": shoot, "leap": leap, "radar": maxf(0.0, 1.0 - radar_age / 2.5)}

func _start_radar(origin: Vector2) -> void:
	radar_origin = origin
	radar_committed = false
	radar_cells.clear()
	radar_distances.clear()
	radar_lookup.clear()
	var dims := Vector2i(ceili(bounds.size.x / 32.0), ceili(bounds.size.y / 32.0))
	var source := Vector2i((origin-bounds.position)/32.0).clamp(Vector2i.ZERO, dims-Vector2i.ONE)
	var queue: Array[Vector2i] = [source]
	radar_lookup[source] = 0.0
	var head := 0
	while head < queue.size() and head < 1100:
		var cell := queue[head]
		head += 1
		var cp := bounds.position+(Vector2(cell)+Vector2(0.5,0.5))*32.0
		var distance: float = radar_lookup[cell]
		radar_cells.append(cp)
		radar_distances.append(distance)
		if distance >= 1450.0:
			continue
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+direction
			if next.x < 0 or next.y < 0 or next.x >= dims.x or next.y >= dims.y or radar_lookup.has(next):
				continue
			var np := bounds.position+(Vector2(next)+Vector2(0.5,0.5))*32.0
			if _point_ok(np, 4.0) and _clear(origin if cell == source else cp, np, 4.0):
				radar_lookup[next] = distance+32.0
				queue.append(next)

func draw_radar(canvas: CanvasItem, _enemy_pos: Vector2) -> void:
	if stage < 2 or stage > 4 or radar_age > 2.6:
		return
	var front := radar_age*600.0
	for i in range(radar_cells.size()):
		var behind := front-radar_distances[i]
		if behind >= 0.0 and behind < 130.0:
			var alpha := (1.0-behind/130.0)*0.25
			canvas.draw_rect(Rect2(radar_cells[i]-Vector2(14,14),Vector2(28,28)),Color(0.2,0.85,1.0,alpha))

func _point_ok(p: Vector2, clearance: float = 19.0) -> bool:
	if not bounds.has_point(p):
		return false
	for wall in walls:
		if wall.grow(clearance).has_point(p):
			return false
	return true

func _clear(a: Vector2, b: Vector2, clearance: float = 19.0) -> bool:
	for wall in walls:
		var r := wall.grow(clearance)
		if r.has_point(a) or r.has_point(b):
			return false
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
				return false
	return true

func _bfs(start: Vector2, goal: Vector2, record: bool) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var cell := 32.0
	var dims := Vector2i(ceili(bounds.size.x / cell), ceili(bounds.size.y / cell))
	var source := Vector2i((start - bounds.position) / cell)
	var target := Vector2i((goal - bounds.position) / cell)
	source = source.clamp(Vector2i.ZERO, dims - Vector2i.ONE)
	target = target.clamp(Vector2i.ZERO, dims - Vector2i.ONE)
	var queue: Array[Vector2i] = [source]
	var came := {source: source}
	var head := 0
	var reached := false
	if record:
		explored.clear()
	while head < queue.size() and head < 1100:
		var current := queue[head]
		head += 1
		var cp := bounds.position + (Vector2(current) + Vector2(0.5, 0.5)) * cell
		if record:
			explored.append(cp)
		if current == target:
			reached = true
			break
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= dims.x or next.y >= dims.y or came.has(next):
				continue
			var np := bounds.position + (Vector2(next) + Vector2(0.5, 0.5)) * cell
			if _point_ok(np) and _clear(cp if current != source else start, np):
				came[next] = current
				queue.append(next)
	if record:
		expansions = head
	if not reached:
		return result
	var cursor := target
	while cursor != source:
		result.push_front(bounds.position + (Vector2(cursor) + Vector2(0.5, 0.5)) * cell)
		cursor = came[cursor]
	if result.is_empty() or _clear(result.back(), goal):
		result.append(goal)
	return result

func _start_tree(start: Vector2) -> void:
	nodes = [start]
	parents = [-1]
	costs = [0.0]
	path.clear()
	goal_index = -1
	tree_start = start

func _grow_tree(goal: Vector2, optimal: bool, budget: int) -> void:
	for iteration in range(budget):
		if nodes.size() >= 520:
			break
		var sample := goal if rng.randf() < 0.22 else Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		var nearest := 0
		var distance := INF
		for i in range(nodes.size()):
			var d := nodes[i].distance_squared_to(sample)
			if d < distance:
				nearest = i
				distance = d
		var next := nodes[nearest].move_toward(sample, 42.0)
		if not _point_ok(next) or not _clear(nodes[nearest], next) or distance < 16.0:
			continue
		var parent := nearest
		var cost := costs[parent] + nodes[parent].distance_to(next)
		var neighbors: Array[int] = []
		if optimal:
			for i in range(nodes.size()):
				if nodes[i].distance_to(next) < 100.0 and _clear(nodes[i], next):
					neighbors.append(i)
					var candidate := costs[i] + nodes[i].distance_to(next)
					if candidate < cost:
						cost = candidate
						parent = i
		var index := nodes.size()
		nodes.append(next)
		parents.append(parent)
		costs.append(cost)
		if optimal:
			for neighbor in neighbors:
				var new_cost := cost + next.distance_to(nodes[neighbor])
				if neighbor != 0 and new_cost + 0.01 < costs[neighbor]:
					parents[neighbor] = index
					costs[neighbor] = new_cost
					# Propagate costs so subsequent rewires use valid tree costs.
					var pending: Array[int] = [neighbor]
					while not pending.is_empty():
						var ancestor: int = pending.pop_back()
						for child in range(nodes.size()):
							if parents[child] == ancestor:
								costs[child] = costs[ancestor] + nodes[child].distance_to(nodes[ancestor])
								pending.append(child)
		if next.distance_to(goal) < 60.0 and _clear(next, goal):
			if goal_index < 0 or cost + next.distance_to(goal) < costs[goal_index] + nodes[goal_index].distance_to(goal):
				goal_index = index
	if goal_index >= 0:
		path.clear()
		path.append(goal)
		var cursor := goal_index
		while cursor > 0:
			path.push_front(nodes[cursor])
			cursor = parents[cursor]
	expansions = nodes.size()

func _follow(position: Vector2) -> Vector2:
	while not path.is_empty() and position.distance_to(path[0]) < 5.0:
		path.pop_front()
	# Safely shortcut old waypoints as the tree improves.
	while path.size() > 1 and _clear(position, path[1]):
		path.pop_front()
	if path.is_empty():
		return Vector2.ZERO
	if not _clear(position, path[0]):
		plan_timer = 0.0
		return Vector2.ZERO
	return position.direction_to(path[0])

func _exploration_target(position: Vector2) -> Vector2:
	if explore_timer <= 0.0 or position.distance_to(explore_goal) < 70.0:
		explore_timer = 5.0
		# Search independent of hidden player position until first contact.
		var best_distance := 0.0
		for attempt in range(24):
			var candidate := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
			if _point_ok(candidate) and position.distance_to(candidate) > best_distance and not _bfs(position, candidate, false).is_empty():
				explore_goal = candidate
				best_distance = position.distance_to(candidate)
		plan_timer = 0.0
	return explore_goal

func _pursue_hidden(position: Vector2) -> Vector2:
	if pursuit_timer <= 0.0 or path.is_empty() or position.distance_to(pursuit_goal) < 45.0:
		pursuit_timer = 0.65
		if has_fix and sight_age < 4.0:
			var predicted := estimate + estimate_velocity.limit_length(220.0) * minf(sight_age, 1.4)
			predicted = predicted.clamp(bounds.position + Vector2(20, 20), bounds.end - Vector2(20, 20))
			pursuit_goal = _choose_intercept(position, predicted)
		else:
			pursuit_goal = _exploration_target(position)
		path = _bfs(position, pursuit_goal, true)
		if path.is_empty() and (not has_fix or sight_age >= 4.0):
			explore_timer = 0.0
	var direction := _follow(position)
	if direction == Vector2.ZERO:
		pursuit_timer = 0.0
	return direction

func _choose_intercept(position: Vector2, predicted: Vector2) -> Vector2:
	var best := INF
	var choice := predicted
	# Candidate firing positions surround the predicted target. Their routes are
	# measured through free space, so the agent can deliberately round cover.
	for radius in [85.0, 150.0, 220.0]:
		for sector in range(12):
			var candidate: Vector2 = predicted + Vector2.from_angle(float(sector) * TAU / 12.0) * float(radius)
			if not _point_ok(candidate) or not _clear(candidate, predicted, 3.0):
				continue
			if position.distance_to(candidate) < 55.0:
				continue
			var route := _bfs(position, candidate, false)
			if route.is_empty():
				continue
			var route_length := 0.0
			var previous := position
			for waypoint in route:
				route_length += previous.distance_to(waypoint)
				previous = waypoint
			var score: float = route_length + float(radius) * 0.18
			if score < best:
				best = score
				choice = candidate
	if best == INF and not _point_ok(choice):
		choice = _exploration_target(position)
	return choice

func _navigate(position: Vector2, goal: Vector2) -> Vector2:
	if position.distance_to(goal) < 210.0 and _clear(position, goal):
		var tangent := position.direction_to(goal).orthogonal() * (1.0 if sin(elapsed * 0.4) > 0 else -1.0)
		return tangent if _point_ok(position + tangent * 45.0) else Vector2.ZERO
	if plan_timer <= 0.0:
		plan_timer = 0.7
		path = _bfs(position, goal, true)
	return _follow(position)

func _particle_tick(dt: float, enemy: Vector2, player: Vector2, velocity: Vector2, visible: bool) -> void:
	if particles.is_empty():
		for i in range(100):
			particles.append(Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y)))
			weights.append(0.01)
	for i in range(particles.size()):
		var next := particles[i] + estimate_velocity * dt + Vector2(rng.randfn(0.0, 28.0), rng.randfn(0.0, 28.0)) * sqrt(dt)
		if _point_ok(next, 2.0) and _clear(particles[i], next, 2.0):
			particles[i] = next
	if visible and measurement_timer <= 0.0:
		measurement_timer = 0.25
		has_fix = true
		var observation := player + Vector2(rng.randfn(0.0, 13.0), rng.randfn(0.0, 13.0))
		var total := 0.0
		for i in range(particles.size()):
			weights[i] = exp(-particles[i].distance_squared_to(observation) / (2.0 * 42.0 * 42.0)) + 0.000001
			total += weights[i]
		for i in range(weights.size()):
			weights[i] /= total
		var resampled: Array[Vector2] = []
		var offset := rng.randf() / particles.size()
		var cumulative := weights[0]
		var index := 0
		for j in range(particles.size()):
			var u := offset + float(j) / particles.size()
			while u > cumulative and index < weights.size() - 1:
				index += 1
				cumulative += weights[index]
			var point := particles[index] + Vector2(rng.randfn(0.0, 8.0), rng.randfn(0.0, 8.0))
			# A few proposals around measurement prevent particle impoverishment.
			if j < 12:
				point = observation + Vector2(rng.randfn(0.0, 20.0), rng.randfn(0.0, 20.0))
			resampled.append(point if _point_ok(point, 2.0) else observation)
		particles = resampled
		estimate_velocity = estimate_velocity.lerp(velocity, 0.45)
	var center := Vector2.ZERO
	for point in particles:
		center += point
	estimate = center / particles.size()
	uncertainty = 0.0
	for point in particles:
		uncertainty += point.distance_squared_to(estimate)
	uncertainty = sqrt(uncertainty / particles.size())

func _slam_tick(dt: float, enemy: Vector2, player: Vector2, visible: bool) -> void:
	if not slam_ready:
		slam_ready = true
		previous_enemy = enemy
		slam_state = [enemy.x + rng.randfn(0, 3), enemy.y + rng.randfn(0, 3)]
		covariance = [[16.0, 0.0], [0.0, 16.0]]
		estimate = bounds.get_center()
	var odometry := enemy - previous_enemy
	previous_enemy = enemy
	slam_state[0] += odometry.x + rng.randfn(0, 0.3) * sqrt(dt)
	slam_state[1] += odometry.y + rng.randfn(0, 0.3) * sqrt(dt)
	covariance[0][0] += dt * 4.0
	covariance[1][1] += dt * 4.0
	if measurement_timer <= 0.0:
		measurement_timer = 0.22
		var observed := 0
		for id in range(landmarks.size()):
			var landmark := landmarks[id]
			# Corners are observed from nearby free space. Endpoint offset avoids
			# classifying the wall corner itself as an occluder.
			var toward := enemy.direction_to(landmark)
			if enemy.distance_to(landmark) > 460.0 or not _clear(enemy, landmark - toward * 3.0, -1.0):
				continue
			var relative := landmark - enemy
			var measured_range := maxf(1.0, relative.length() + rng.randfn(0, 2.0))
			var bearing := relative.angle() + rng.randfn(0, 0.012)
			if not landmark_ids.has(id):
				_slam_add_landmark(id, measured_range, bearing)
			else:
				_slam_correct(int(landmark_ids[id]), measured_range, bearing)
			observed += 1
			if observed >= 4:
				break
		if visible:
			var self_estimate := Vector2(slam_state[0], slam_state[1])
			var relative_player := player - enemy
			var observation := self_estimate + relative_player + Vector2(rng.randfn(0, 4.0), rng.randfn(0, 4.0))
			if has_fix:
				estimate_velocity = estimate_velocity.lerp((observation - last_seen) / 0.22, 0.25).limit_length(240.0)
			last_seen = observation
			estimate = observation
			has_fix = true
	else:
		estimate += estimate_velocity * dt
	uncertainty = sqrt(maxf(0.0, covariance[0][0] + covariance[1][1]))

func _estimated_walls() -> Array[Rect2]:
	var mapped: Array[Rect2] = []
	for wall_id in range(landmarks.size() / 2):
		var first := wall_id*2
		if landmark_ids.has(first) and landmark_ids.has(first+1):
			var a: int = landmark_ids[first]
			var b: int = landmark_ids[first+1]
			var p := Vector2(slam_state[a],slam_state[a+1])
			var q := Vector2(slam_state[b],slam_state[b+1])
			mapped.append(Rect2(p,q-p).abs())
	return mapped

func _slam_navigate(position: Vector2) -> Vector2:
	# Plan using only cover reconstructed from observed landmark pairs.
	# Collision sensing remains local and never supplies an unseen global map.
	var physical_walls := walls
	walls = _estimated_walls()
	var target := estimate if has_fix else _exploration_target(position)
	var command := _navigate(position,target)
	walls = physical_walls
	if command != Vector2.ZERO and not _clear(position,position+command*26.0):
		var left := command.orthogonal()
		var right := -left
		var left_clear := _point_ok(position+left*26.0) and _clear(position,position+left*26.0)
		var right_clear := _point_ok(position+right*26.0) and _clear(position,position+right*26.0)
		if left_clear and right_clear:
			command = left if (position+left*26.0).distance_to(target) < (position+right*26.0).distance_to(target) else right
		elif left_clear:
			command = left
		elif right_clear:
			command = right
		else:
			command = Vector2.ZERO
		plan_timer = 0.0
	return command

func _slam_add_landmark(id: int, distance: float, bearing: float) -> void:
	var old_n := slam_state.size()
	landmark_ids[id] = old_n
	slam_state.append(slam_state[0] + distance * cos(bearing))
	slam_state.append(slam_state[1] + distance * sin(bearing))
	# Correlate each new landmark with the pose and every existing landmark.
	for row in range(old_n):
		covariance[row].append(covariance[row][0])
		covariance[row].append(covariance[row][1])
	var xrow: Array[float] = []
	var yrow: Array[float] = []
	for col in range(old_n):
		xrow.append(float(covariance[0][col]))
		yrow.append(float(covariance[1][col]))
	var c := cos(bearing)
	var s := sin(bearing)
	var radial_noise := 4.0
	var angular_noise := distance * distance * 0.000144
	xrow.append(float(covariance[0][0]) + c*c*radial_noise + s*s*angular_noise)
	xrow.append(float(covariance[0][1]) + c*s*(radial_noise-angular_noise))
	yrow.append(float(covariance[1][0]) + c*s*(radial_noise-angular_noise))
	yrow.append(float(covariance[1][1]) + s*s*radial_noise + c*c*angular_noise)
	covariance.append(xrow)
	covariance.append(yrow)

func _slam_correct(index: int, distance: float, bearing: float) -> void:
	var delta := Vector2(slam_state[index] - slam_state[0], slam_state[index+1] - slam_state[1])
	var q := maxf(1.0, delta.length_squared())
	var r := sqrt(q)
	var n := slam_state.size()
	var h0: Array[float] = []
	var h1: Array[float] = []
	h0.resize(n)
	h1.resize(n)
	h0.fill(0.0)
	h1.fill(0.0)
	h0[0] = -delta.x / r
	h0[1] = -delta.y / r
	h0[index] = delta.x / r
	h0[index+1] = delta.y / r
	h1[0] = delta.y / q
	h1[1] = -delta.x / q
	h1[index] = -delta.y / q
	h1[index+1] = delta.x / q
	var ph0: Array[float] = []
	var ph1: Array[float] = []
	for row in range(n):
		var a := 0.0
		var b := 0.0
		for col in range(n):
			a += float(covariance[row][col]) * h0[col]
			b += float(covariance[row][col]) * h1[col]
		ph0.append(a)
		ph1.append(b)
	var s00 := 4.0
	var s01 := 0.0
	var s11 := 0.000144
	for i in range(n):
		s00 += h0[i] * ph0[i]
		s01 += h0[i] * ph1[i]
		s11 += h1[i] * ph1[i]
	var determinant := s00*s11-s01*s01
	if determinant <= 0.00000001:
		return
	var innovation := Vector2(distance-r, wrapf(bearing-delta.angle(), -PI, PI))
	var gain0: Array[float] = []
	var gain1: Array[float] = []
	for i in range(n):
		gain0.append((ph0[i]*s11-ph1[i]*s01)/determinant)
		gain1.append((ph1[i]*s00-ph0[i]*s01)/determinant)
		slam_state[i] += gain0[i]*innovation.x+gain1[i]*innovation.y
	for row in range(n):
		for col in range(row, n):
			var value: float = float(covariance[row][col])-gain0[row]*ph0[col]-gain1[row]*ph1[col]
			if row == col:
				value = maxf(value, 0.000001)
			covariance[row][col] = value
			covariance[col][row] = value

func _actions() -> Array[Vector2]:
	return [Vector2.ZERO, Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
		Vector2(-1,-1).normalized(), Vector2(1,-1).normalized(), Vector2(-1,1).normalized(), Vector2(1,1).normalized()]

func _simulate(position: Vector2, direction: Vector2, distance: float) -> Vector2:
	var next := position + direction * distance
	return next if _point_ok(next) and _clear(position, next) else position

func _utility_terms(enemy: Vector2, player: Vector2, player_aim: Vector2) -> Dictionary:
	var distance := enemy.distance_to(player)
	var firing_lane := _clear(enemy, player, 3.0)
	var blocked_player := 0
	var blocked_enemy := 0
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		if not _point_ok(player + direction * 72.0) or not _clear(player, player + direction * 72.0):
			blocked_player += 1
		if not _point_ok(enemy + direction * 44.0) or not _clear(enemy, enemy + direction * 44.0):
			blocked_enemy += 1
	var facing := player_aim.normalized() if player_aim.length_squared() > 0.01 else Vector2.RIGHT
	var behind := distance < 450.0 and (enemy - player).normalized().dot(facing) < -0.45
	return {
		"range": -absf(distance - 280.0) * 0.025,
		"shot": 5.0 if firing_lane else 0.0,
		"corner": float(blocked_player) * 1.1,
		"behind": 2.2 if behind else 0.0,
		"close": -4.0 if distance < 120.0 else 0.0,
		"mobility": -float(blocked_enemy) * 0.6
	}

func _sum_terms(terms: Dictionary) -> float:
	var total := 0.0
	for value in terms.values():
		total += float(value)
	return total

func _utility(enemy: Vector2, player: Vector2, player_aim: Vector2) -> float:
	return _sum_terms(_utility_terms(enemy, player, player_aim))

func _minimax(enemy: Vector2, player: Vector2, velocity: Vector2, player_aim: Vector2) -> Vector2:
	var actions := _actions()
	var best := -INF
	var chosen := Vector2.ZERO
	search_branches = 0
	action_scores.clear()
	# Two enemy plies separated by adversarial player response: max/min/max.
	# 9 x 9 x 9 = 729 leaves, evaluated on a fixed decision clock.
	for action in actions:
		var e1 := _simulate(enemy, action, 62.0)
		var worst := INF
		var worst_terms: Dictionary = {}
		for reply in actions:
			var p1 := _simulate(player, reply, 72.0)
			var continuation := -INF
			var continuation_terms: Dictionary = {}
			for future in actions:
				var e2 := _simulate(e1, future, 50.0)
				var p2 := _simulate(p1, reply, 58.0)
				var terms := _utility_terms(e2, p2, player_aim)
				var near_term := 0.12 * _utility(e1, p1, player_aim)
				# Small observed momentum tie-breaker, not a privileged future sample.
				var momentum := -e2.distance_to(player + velocity * 0.3) * 0.0005
				var score := _sum_terms(terms) + near_term + momentum
				if score > continuation:
					continuation = score
					continuation_terms = terms.duplicate()
					continuation_terms["lookahead"] = near_term
					continuation_terms["momentum"] = momentum
				search_branches += 1
			if continuation < worst:
				worst = continuation
				worst_terms = continuation_terms
		action_scores.append(worst)
		if worst > best:
			best = worst
			chosen = action
			minimax_terms = worst_terms.duplicate()
			minimax_terms["total"] = worst
			minimax_action = action
	return chosen

func _adapt(dt: float, enemy: Vector2, player: Vector2, velocity: Vector2, visible: bool) -> void:
	sample_timer += dt
	if visible:
		var radial := enemy.direction_to(player)
		var speed_fraction := clampf(velocity.length() / 220.0, 0.0, 1.0)
		var strafe := absf(velocity.normalized().dot(radial.orthogonal())) * speed_fraction
		var rush := clampf(-velocity.dot(radial) / 220.0, 0.0, 1.0)
		var reversal := 0.0
		if player_sample.length() > 20 and velocity.dot(player_sample) < 0:
			reversal = 1.0
		habits = habits.lerp(Vector3(strafe, rush, reversal), 1.0-exp(-dt*0.9))
		player_sample = velocity
	if plan_timer > 0.0:
		return
	plan_timer = 0.3
	var best := -INF
	seen_player = Vector2.ZERO
	action_scores.clear()
	var preferred_range := lerpf(250.0, 390.0, habits.y)
	for action in _actions():
		var next := _simulate(enemy, action, 70.0)
		var distance := next.distance_to(estimate)
		var score := -absf(distance-preferred_range)*0.025
		if _clear(next, estimate, 3.0):
			score += 4.0 + habits.x*2.0
		else:
			# Navigate toward the last sensed fix if no candidate has a firing lane.
			score -= 2.0
		score += absf(action.dot(enemy.direction_to(estimate).orthogonal())) * (0.8+habits.x*2.0)
		if next == enemy and action != Vector2.ZERO:
			score -= 5.0
		action_scores.append(score)
		if score > best:
			best = score
			seen_player = action
	if not _clear(enemy, estimate, 3.0):
		path = _bfs(enemy, estimate, true)
		seen_player = _follow(enemy)

func _lesson_weight(introduced_at: int) -> float:
	if stage < introduced_at:
		return 0.0
	return 1.45 if stage == introduced_at else 1.0

func _tactical_move(enemy: Vector2, target: Vector2, player_aim: Vector2, base_move: Vector2, incoming: Array[Dictionary], enemy_speed: float, visible: bool) -> Vector2:
	var actions := _actions()
	if base_move.length_squared() > 0.01 and not actions.has(base_move):
		actions.append(base_move.normalized())
	var best_score := -INF
	var chosen := base_move
	var chosen_terms: Dictionary = {}
	action_scores.clear()
	for action in actions:
		var forecast := enemy + action * enemy_speed * 0.35
		if action != Vector2.ZERO and (not _point_ok(forecast) or not _clear(enemy, forecast)):
			action_scores.append(-100.0)
			continue
		var base_value := 1.0 if action == base_move else (0.65 * maxf(0.0, action.dot(base_move.normalized())) if base_move != Vector2.ZERO else 0.0)
		var projectile := -3.0 * _lesson_weight(9) * _projectile_danger(enemy, action, incoming, enemy_speed)
		var aim_safety := -1.7 * _lesson_weight(10) * (_aim_line_danger(forecast, target, player_aim) if visible else 0.0)
		var escape := 0.85 * _lesson_weight(11) * _escape_score(forecast)
		var belief := 0.0
		if stage == 12 and not visible and belief_scores.size() > 0:
			var index := _actions().find(action)
			if index >= 0 and index < belief_scores.size():
				belief = 1.25 * _lesson_weight(12) * belief_scores[index]
		# Favor a committed dodge unless a new threat has a clearly better response.
		var continuity := 0.55 * action.dot(previous_tactical_move)
		var total := base_value + projectile + aim_safety + escape + belief + continuity
		action_scores.append(total)
		if total > best_score:
			best_score = total
			chosen = action
			chosen_terms = {"base": base_value, "projectile": projectile, "aim_safety": aim_safety, "escape": escape, "belief": belief, "total": total}
	minimax_terms = chosen_terms
	minimax_action = chosen
	previous_tactical_move = chosen
	return chosen

func _projectile_danger(enemy: Vector2, action: Vector2, incoming: Array[Dictionary], enemy_speed: float) -> float:
	var danger := 0.0
	var horizon := 0.8
	for bullet in incoming:
		var bullet_pos: Vector2 = bullet.get("position", Vector2.ZERO)
		var bullet_velocity: Vector2 = bullet.get("velocity", Vector2.ZERO)
		var life: float = float(bullet.get("life", 0.0))
		if life <= 0.0 or bullet_velocity.length_squared() < 1.0:
			continue
		var relative := bullet_pos - (enemy + Vector2(0, -24))
		var relative_velocity := bullet_velocity - action * enemy_speed
		var duration := minf(horizon, life)
		var time := clampf(-relative.dot(relative_velocity) / maxf(relative_velocity.length_squared(), 1.0), 0.0, duration)
		if not _clear(bullet_pos, bullet_pos + bullet_velocity * time, 2.0):
			continue
		var miss_distance := (relative + relative_velocity * time).length()
		var risk := clampf((58.0 - miss_distance) / 58.0, 0.0, 1.0) * (1.0 - 0.3 * time / horizon)
		danger = maxf(danger, risk)
	return danger

func _aim_line_danger(candidate: Vector2, player: Vector2, player_aim: Vector2) -> float:
	if player_aim.length_squared() < 0.01 or not _clear(player, candidate, 3.0):
		return 0.0
	var direction := player_aim.normalized()
	var offset := candidate - player
	var forward := offset.dot(direction)
	if forward < 0.0 or forward > 760.0:
		return 0.0
	return clampf((75.0 - absf(offset.cross(direction))) / 75.0, 0.0, 1.0)

func _escape_score(candidate: Vector2) -> float:
	var exits := 0
	for direction in _actions():
		if direction == Vector2.ZERO:
			continue
		var next := candidate + direction * 100.0
		if _point_ok(next) and _clear(candidate, next):
			exits += 1
	return float(exits) / 8.0

func _belief_tick(dt: float, enemy: Vector2, player: Vector2, visible: bool) -> void:
	belief_observation_age += dt
	if particles.is_empty():
		for i in range(100):
			particles.append(_sample_hidden_position(enemy, bounds.get_center(), 400.0))
	if visible and measurement_timer <= 0.0:
		measurement_timer = 0.25
		var observation := player + Vector2(rng.randfn(0.0, 12.0), rng.randfn(0.0, 12.0))
		if has_belief_observation:
			var measured_velocity := (observation - last_belief_observation) / maxf(belief_observation_age, 0.1)
			estimate_velocity = estimate_velocity.lerp(measured_velocity.limit_length(230.0), 0.4)
		last_belief_observation = observation
		has_belief_observation = true
		belief_observation_age = 0.0
		has_fix = true
		for i in range(particles.size()):
			var candidate := observation + Vector2(rng.randfn(0.0, 19.0), rng.randfn(0.0, 19.0))
			particles[i] = candidate if _point_ok(candidate, 2.0) else observation
	else:
		if not visible:
			estimate_velocity = estimate_velocity.lerp(Vector2.ZERO, minf(1.0, dt * 0.12))
		for i in range(particles.size()):
			var prior := particles[i]
			var candidate := prior + estimate_velocity * dt + Vector2(rng.randfn(0.0, 38.0), rng.randfn(0.0, 38.0)) * sqrt(dt)
			if not _point_ok(candidate, 2.0) or not _clear(prior, candidate, 2.0) or (not visible and _clear(enemy, candidate, 0.0)):
				candidate = _sample_hidden_position(enemy, prior, 120.0) if not visible else prior
			particles[i] = candidate
	var cells: Dictionary = {}
	var sums: Dictionary = {}
	var best_cell := Vector2i.ZERO
	var best_count := 0
	for point in particles:
		var cell := Vector2i((point - bounds.position) / 80.0)
		cells[cell] = int(cells.get(cell, 0)) + 1
		sums[cell] = sums.get(cell, Vector2.ZERO) + point
		if int(cells[cell]) > best_count:
			best_count = int(cells[cell])
			best_cell = cell
	if best_count > 0:
		estimate = sums[best_cell] / float(best_count)
	uncertainty = 0.0
	for point in particles:
		uncertainty += point.distance_squared_to(estimate)
	uncertainty = sqrt(uncertainty / maxf(1.0, float(particles.size())))

func _sample_hidden_position(enemy: Vector2, around: Vector2, spread: float) -> Vector2:
	for attempt in range(50):
		var candidate := around + Vector2(rng.randfn(0.0, spread), rng.randfn(0.0, spread))
		if attempt > 25:
			candidate = Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if _point_ok(candidate, 2.0) and not _clear(enemy, candidate, 0.0):
			return candidate
	return around.clamp(bounds.position, bounds.end)

func _belief_pursue_hidden(position: Vector2) -> Vector2:
	if belief_plan_timer <= 0.0:
		belief_plan_timer = 0.4
		belief_scores = _belief_minimax_scores(position)
	if pursuit_timer <= 0.0 or path.is_empty() or position.distance_to(pursuit_goal) < 45.0:
		pursuit_timer = 0.65
		pursuit_goal = estimate
		path = _bfs(position, pursuit_goal, true)
		if path.is_empty():
			pursuit_goal = _choose_intercept(position, estimate)
			path = _bfs(position, pursuit_goal, true)
	return _follow(position)

func _belief_minimax_scores(enemy: Vector2) -> Array[float]:
	var result: Array[float] = []
	var actions := _actions()
	var sample_count := mini(6, particles.size())
	if sample_count == 0:
		return result
	var replies: Array[Array] = []
	for sample in range(sample_count):
		var possible_player := particles[(sample * 17) % particles.size()]
		var options: Array[Vector2] = []
		for reply in [Vector2.ZERO, Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			options.append(_simulate(possible_player, reply, 72.0))
		replies.append(options)
	for action in actions:
		var future_enemy := _simulate(enemy, action, 62.0)
		var expected := 0.0
		for options in replies:
			var worst := INF
			for future_player in options:
				worst = minf(worst, _belief_utility(future_enemy, future_player))
			expected += worst / float(sample_count)
		result.append(expected)
	var low: float = result.min()
	var high: float = result.max()
	for i in range(result.size()):
		result[i] = (result[i] - low) / maxf(0.01, high - low)
	return result

func _belief_utility(enemy: Vector2, player: Vector2) -> float:
	var distance := enemy.distance_to(player)
	var shot := 3.0 if _clear(enemy, player, 3.0) else -1.0
	var range_value := -absf(distance - 280.0) * 0.025
	var behind := 1.0 if (enemy - player).normalized().dot(last_player_aim) < -0.45 else 0.0
	return shot + range_value + behind

func debug_state() -> Dictionary:
	return {"stage":stage, "status":status, "fix":fix, "has_fix":has_fix,
		"estimate":estimate, "uncertainty":uncertainty, "expanded":expansions,
		"tree_nodes":nodes.size(), "particles":particles.size(), "landmarks":landmark_ids.size(),
		"branches":search_branches, "habits":habits, "radar_age":radar_age, "radar_cells":radar_cells.size(), "radar_committed":radar_committed,
		"sight_age":sight_age, "pursuit_goal":pursuit_goal}

func draw_debug(canvas: CanvasItem, enemy_pos: Vector2) -> void:
	if stage == 1:
		canvas.draw_line(enemy_pos, debug_aim_target, Color(1.0, 0.75, 0.35, 0.85), 3.0)
		canvas.draw_circle(debug_aim_target, 10.0, Color(1.0, 0.75, 0.35, 0.9), false, 2.0)
	if stage == 2:
		for point in explored:
			canvas.draw_rect(Rect2(point-Vector2(4,4), Vector2(8,8)), Color(0.2,0.8,1,0.27))
	if stage == 3 or stage == 4:
		for i in range(1, nodes.size()):
			canvas.draw_line(nodes[i], nodes[parents[i]], Color(0.25,1.0,0.55,0.22) if stage == 4 else Color(1,0.7,0.2,0.22), 1.0)
	var prev := enemy_pos
	for point in path:
		canvas.draw_line(prev, point, Color(0.2,0.95,1,0.95), 4.0)
		prev = point
	if stage >= 2 and stage <= 4 and has_fix:
		canvas.draw_circle(fix, 9.0, Color(1,0.4,0.3,0.6), false, 2.0)
	if stage == 5 or stage == 12:
		for point in particles:
			canvas.draw_circle(point, 2.0, Color(0.85,0.45,1,0.42))
		canvas.draw_circle(estimate, 7, Color(0.9,0.5,1), false, 2.0)
		canvas.draw_arc(estimate, clampf(uncertainty, 10, 180), 0, TAU, 48, Color(0.9,0.5,1,0.3), 1.0)
	if stage == 6 and slam_ready:
		for mapped in _estimated_walls():
			canvas.draw_rect(mapped, Color(0.4,1,0.7,0.4), false, 2.0)
		var pose := Vector2(slam_state[0], slam_state[1])
		canvas.draw_circle(pose, maxf(5, uncertainty*2), Color(0.4,1,0.7,0.5), false, 1.0)
		for id in landmark_ids:
			var index: int = landmark_ids[id]
			var point := Vector2(slam_state[index], slam_state[index+1])
			canvas.draw_line(pose, point, Color(0.4,1,0.7,0.12), 1)
			canvas.draw_rect(Rect2(point-Vector2(4,4), Vector2(8,8)), Color(0.4,1,0.7,0.8), false, 1.0)
		canvas.draw_circle(estimate, 8, Color(1,0.8,0.2), false, 2)
	if stage >= 7:
		if stage >= 9:
			for bullet in observed_bullets:
				var bullet_pos: Vector2 = bullet.get("position", Vector2.ZERO)
				var bullet_velocity: Vector2 = bullet.get("velocity", Vector2.ZERO)
				canvas.draw_line(bullet_pos, bullet_pos + bullet_velocity.limit_length(260.0), Color(1.0, 0.42, 0.28, 0.45), 2.0)
		if sight_age > 0.0 and sight_age < 4.0 and has_fix:
			canvas.draw_circle(pursuit_goal, 11.0, Color(1.0, 0.78, 0.25, 0.9), false, 2.0)
			canvas.draw_line(estimate, pursuit_goal, Color(1.0, 0.78, 0.25, 0.35), 1.0)
		var actions := _actions()
		for i in range(mini(actions.size(), action_scores.size())):
			var strength := clampf((action_scores[i]+15.0)/22.0, 0.1, 1.0)
			canvas.draw_line(enemy_pos, enemy_pos+actions[i]*50, Color(1-strength,strength,0.3,0.65), 2)
