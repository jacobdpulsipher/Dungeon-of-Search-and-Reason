extends RefCounted
class_name GameLevels

const ARENA_SIZE := Vector2(1000, 600)

static func all() -> Array[Dictionary]:
	var rooms: Array[Array] = [
		[Rect2(420, 180, 160, 70), Rect2(420, 350, 160, 70)],
		[Rect2(280, 160, 110, 140), Rect2(610, 300, 110, 140)],
		[Rect2(240, 140, 120, 70), Rect2(440, 275, 120, 70), Rect2(650, 390, 120, 70)],
		[Rect2(285, 125, 85, 250), Rect2(510, 225, 85, 250), Rect2(730, 125, 85, 250)],
		[Rect2(350, 150, 95, 130), Rect2(570, 320, 95, 130), Rect2(450, 450, 100, 55)],
		[Rect2(285, 130, 120, 95), Rect2(590, 130, 120, 95), Rect2(300, 380, 120, 95), Rect2(580, 380, 120, 95)],
		[Rect2(410, 140, 180, 70), Rect2(410, 390, 180, 70), Rect2(245, 270, 95, 65), Rect2(660, 270, 95, 65)],
		[Rect2(250, 145, 100, 100), Rect2(650, 145, 100, 100), Rect2(250, 355, 100, 100), Rect2(650, 355, 100, 100), Rect2(455, 260, 90, 80)]
	]
	# Reuse familiar rooms so the added decision rules are easy to compare.
	rooms.append(rooms[0].duplicate())
	rooms.append(rooms[0].duplicate())
	rooms.append(rooms[7].duplicate())
	rooms.append(rooms[7].duplicate())
	var titles := ["The Turret", "Breadth First Search", "RRT: Random Trees", "RRT*", "Particle Filter", "EKF SLAM", "Minimax", "Adaptive Heuristics", "Projectile Dodge", "Aim Anticipation", "Escape Routes", "Belief Minimax"]
	var lessons := [
		"The enemy stands still, aims at your current position, and fires. Cover blocks bullets, but the enemy does not account for it.",
		"A radar pulse travels around cover and records your position. Breadth first search explores a grid evenly to find a route to that last fix. Move between pulses to mislead it.",
		"The radar still gives only occasional fixes. A rapidly exploring random tree (RRT) samples collision free moves and selects a route toward your last known position.",
		"RRT* improves on RRT by reconnecting nearby branches when a shorter route appears. It only has a small time budget before acting.",
		"Now observations are intermittent and noisy. A particle filter keeps many possible player positions, updating their weights when a new observation arrives.",
		"The enemy starts with an uncertain map. EKF SLAM uses noisy landmarks and movement estimates to refine its own position and the locations of cover.",
		"Minimax scores clear shots, useful range, trapping you near walls, and moving behind your aim. It penalizes getting too close or trapping itself, then chooses a move against your strongest reply. When sight is blocked, it routes to an intercept.",
		"The enemy observes your strafing, rushing, and direction reversals. It adjusts spacing and shot lead, and searches for a flank when it loses sight. Change your movement to disrupt its predictions.",
		"The enemy predicts the path of bullets already in flight and sidesteps likely hits. This danger score gets extra weight here; later levels keep it at a balanced weight.",
		"The enemy also watches where your gun points. It avoids standing in that firing lane before you shoot, while retaining its projectile dodge from the last lesson.",
		"The enemy values nearby escape routes. It avoids positions where cover or the border leave too few safe moves, alongside its previous danger scores.",
		"A particle filter tracks several possible locations when you disappear behind cover. Minimax scores moves against those possibilities, while keeping the earlier defensive heuristics."
	]
	var result: Array[Dictionary] = []
	for i in range(titles.size()):
		result.append({
			"index": i + 1,
			"title": titles[i],
			"lesson": lessons[i],
			"cover": rooms[i],
			"player_spawn": Vector2(110, 300),
			"enemy_spawn": Vector2(890, 300),
			"enemy_speed": 150.0 + i * 3.0,
			"enemy_fire_interval": maxf(0.48, 0.9 - i * 0.04),
			"enemy_hp": 5
		})
	return result
