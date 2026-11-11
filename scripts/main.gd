extends Control

const ArenaScript = preload("res://scripts/arena.gd")
const LevelsScript = preload("res://scripts/levels.gd")
const PlanningPanelScript = preload("res://art/planning_panel.gd")
const PROGRESS_FILE := "user://progress.cfg"
const PLAN_HINTS := [
	"Aims directly at your current position.",
	"Checks grid cells for a route to its radar fix.",
	"Samples random branches through free space.",
	"Rewires branches to shorten its route.",
	"Tracks many possible player positions.",
	"Maps cover and estimates its own pose.",
	"Scores moves against your best replies.",
	"Adjusts tactics to your movement habits.",
	"Scores the closest approach of incoming bullets.",
	"Anticipates shots along your current aim line.",
	"Keeps enough room for its next move.",
	"Plans against several plausible hidden positions."
]

var levels: Array[Dictionary] = []
var unlocked := 1
var current_level := 1
var arena: Node2D
var status: Label
var overlay: ColorRect
var menu_card: ColorRect
var menu_box: VBoxContainer
var card_title: Label
var card_text: Label
var primary_button: Button
var level_buttons: GridContainer
var controls_heading: Label
var controls_label: Label
var levels_heading: Label
var versus_selectors: VBoxContainer
var left_selector: OptionButton
var right_selector: OptionButton
var menu_actions: HBoxContainer
var versus_button: Button
var menu_button: Button
var card_mode := "intro"
var versus_left_level := 7
var versus_right_level := 12
var planning_panel

func _ready() -> void:
	Input.emulate_mouse_from_touch = true
	levels = LevelsScript.all()
	_load_progress()
	build_ui()
	open_level(1)

func _load_progress() -> void:
	var save := ConfigFile.new()
	if save.load(PROGRESS_FILE) == OK:
		unlocked = clampi(int(save.get_value("progress", "unlocked", 1)), 1, levels.size())

func _save_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("progress", "unlocked", unlocked)
	save.save(PROGRESS_FILE)

func build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101820")
	background.z_index = -100
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	status = Label.new()
	status.position = Vector2(100, 27)
	status.size = Vector2(850, 32)
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color("c5cfca"))
	status.text = "YOU 5/5     ENEMY 5/5     LEAP READY"
	add_child(status)
	menu_button = Button.new()
	menu_button.text = "MENU"
	menu_button.position = Vector2(1000, 20)
	menu_button.custom_minimum_size = Vector2(100, 38)
	style_button(menu_button)
	menu_button.pressed.connect(_open_pause_menu)
	add_child(menu_button)
	build_overlay()
	planning_panel = PlanningPanelScript.new()
	planning_panel.position = Vector2(100, 700)
	add_child(planning_panel)

func _process(_delta: float) -> void:
	if overlay.visible:
		_fit_menu_card()
	if not is_instance_valid(arena) or not is_instance_valid(planning_panel):
		return
	var brain_instance = arena.get("brain")
	var showing := bool(arena.get("reveal_enabled")) and not overlay.visible
	if brain_instance != null:
		if arena.versus_mode:
			planning_panel.set_versus_state("CYAN · LEVEL %d · %s" % [versus_left_level, levels[versus_left_level - 1]["title"]], str(arena.left_brain.get("status")), "CORAL · LEVEL %d · %s" % [versus_right_level, levels[versus_right_level - 1]["title"]], str(brain_instance.get("status")), showing)
		elif current_level == 7 or current_level >= 9:
			planning_panel.set_planning_state(str(brain_instance.get("status")), PLAN_HINTS[current_level - 1], showing, "TAB: HIDE PLAN")
			planning_panel.set_heuristic_lines(brain_instance.get("minimax_terms"), brain_instance.get("minimax_action"))
		else:
			planning_panel.set_planning_state(str(brain_instance.get("status")), PLAN_HINTS[current_level - 1], showing, "TAB: HIDE PLAN")
			planning_panel.set_heuristic_lines({}, Vector2.ZERO)
		planning_panel.position = Vector2(100, 700)

func build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.04, 0.08, 0.10, 0.86)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	menu_card = ColorRect.new()
	menu_card.color = Color("18262b")
	menu_card.position = Vector2(250, 110)
	menu_card.size = Vector2(700, 680)
	menu_card.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(menu_card)
	var trim := ColorRect.new()
	trim.color = Color("b78649")
	trim.size = Vector2(700, 4)
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_card.add_child(trim)
	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(36, 27)
	menu_box.size = Vector2(628, 586)
	menu_box.add_theme_constant_override("separation", 8)
	menu_card.add_child(menu_box)
	card_title = Label.new()
	card_title.add_theme_font_size_override("font_size", 25)
	card_title.add_theme_color_override("font_color", Color("deb879"))
	menu_box.add_child(card_title)
	card_text = Label.new()
	card_text.custom_minimum_size = Vector2(0, 110)
	card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_text.add_theme_font_size_override("font_size", 18)
	card_text.add_theme_color_override("font_color", Color("e5e5d7"))
	menu_box.add_child(card_text)
	controls_heading = Label.new()
	controls_heading.text = "CONTROLS"
	controls_heading.add_theme_font_size_override("font_size", 14)
	controls_heading.add_theme_color_override("font_color", Color("deb879"))
	menu_box.add_child(controls_heading)
	controls_label = Label.new()
	controls_label.text = "WASD / left stick move    Mouse / right stick aim\nLeft click / Space hold fire    RT single shot    Left Shift / LT leap\nTab / Y plan    Esc / Start menu"
	controls_label.add_theme_font_size_override("font_size", 13)
	controls_label.add_theme_color_override("font_color", Color("c5cfca"))
	menu_box.add_child(controls_label)
	levels_heading = Label.new()
	levels_heading.text = "LEVELS"
	levels_heading.add_theme_font_size_override("font_size", 14)
	levels_heading.add_theme_color_override("font_color", Color("deb879"))
	menu_box.add_child(levels_heading)
	level_buttons = GridContainer.new()
	level_buttons.columns = 6
	level_buttons.add_theme_constant_override("h_separation", 8)
	level_buttons.add_theme_constant_override("v_separation", 8)
	menu_box.add_child(level_buttons)
	for i in range(levels.size()):
		var button := Button.new()
		button.text = str(i + 1)
		button.custom_minimum_size = Vector2(48, 34)
		style_button(button)
		button.pressed.connect(_on_level_selected.bind(i + 1))
		level_buttons.add_child(button)
	versus_selectors = VBoxContainer.new()
	versus_selectors.add_theme_constant_override("separation", 12)
	versus_selectors.hide()
	menu_box.add_child(versus_selectors)
	var left_heading := Label.new()
	left_heading.text = "CYAN FIGHTER · LEFT"
	left_heading.add_theme_color_override("font_color", Color("65e7d4"))
	versus_selectors.add_child(left_heading)
	left_selector = OptionButton.new()
	left_selector.custom_minimum_size = Vector2(0, 44)
	style_button(left_selector)
	versus_selectors.add_child(left_selector)
	var right_heading := Label.new()
	right_heading.text = "CORAL FIGHTER · RIGHT"
	right_heading.add_theme_color_override("font_color", Color("ff876c"))
	versus_selectors.add_child(right_heading)
	right_selector = OptionButton.new()
	right_selector.custom_minimum_size = Vector2(0, 44)
	style_button(right_selector)
	versus_selectors.add_child(right_selector)
	for i in range(levels.size()):
		var choice := "%d · %s" % [i + 1, levels[i]["title"]]
		left_selector.add_item(choice, i + 1)
		right_selector.add_item(choice, i + 1)
	left_selector.select(versus_left_level - 1)
	right_selector.select(versus_right_level - 1)
	left_selector.item_selected.connect(_on_versus_choice_changed.bind(true))
	right_selector.item_selected.connect(_on_versus_choice_changed.bind(false))
	menu_actions = HBoxContainer.new()
	menu_actions.add_theme_constant_override("separation", 8)
	menu_box.add_child(menu_actions)
	primary_button = Button.new()
	primary_button.custom_minimum_size = Vector2(0, 48)
	primary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_button(primary_button)
	primary_button.pressed.connect(_on_primary_pressed)
	menu_actions.add_child(primary_button)
	versus_button = Button.new()
	versus_button.text = "Versus"
	versus_button.custom_minimum_size = Vector2(150, 48)
	style_button(versus_button)
	versus_button.pressed.connect(_on_versus_button_pressed)
	menu_actions.add_child(versus_button)
	primary_button.focus_neighbor_right = versus_button.get_path()
	versus_button.focus_neighbor_left = primary_button.get_path()
	right_selector.focus_neighbor_bottom = primary_button.get_path()
	right_selector.focus_neighbor_top = left_selector.get_path()
	left_selector.focus_neighbor_bottom = right_selector.get_path()

func _fit_menu_card() -> void:
	var content_height := menu_box.position.y + menu_actions.position.y + menu_actions.size.y + 25.0
	var target_height := clampf(content_height, 530.0, 780.0)
	if absf(menu_card.size.y - target_height) > 1.0:
		menu_card.size.y = target_height
		menu_card.position.y = (900.0 - target_height) * 0.5
		menu_box.size.y = target_height - 54.0

func open_level(index: int) -> void:
	current_level = index
	_set_versus_setup_visible(false)
	versus_button.text = "Versus"
	if is_instance_valid(arena):
		arena.queue_free()
	arena = ArenaScript.new()
	arena.position = Vector2(100, 80)
	add_child(arena)
	move_child(arena, 1)
	arena.round_finished.connect(_on_round_finished)
	arena.status_changed.connect(_on_status_changed)
	arena.configure(levels[index - 1])
	arena.set_active(false)
	card_mode = "intro"
	card_title.text = "Level %d: %s" % [index, levels[index - 1]["title"]]
	card_text.text = levels[index - 1]["lesson"]
	primary_button.text = "Start level  ·  Tap / A / Start"
	overlay.show()
	menu_button.disabled = true
	primary_button.grab_focus.call_deferred()
	_fit_menu_card.call_deferred()
	update_level_buttons()

func open_versus_setup() -> void:
	if is_instance_valid(arena):
		arena.set_active(false)
	card_mode = "versus_setup"
	card_title.text = "Versus · AI against AI"
	card_text.text = "Pick two different level enemies. Watch them fight with their own sensing, movement, aiming, and firing rules in a shared arena."
	primary_button.text = "Start match  ·  Tap / A / Start"
	versus_button.text = "Levels"
	_set_versus_setup_visible(true)
	overlay.show()
	menu_button.disabled = true
	primary_button.grab_focus.call_deferred()
	_fit_menu_card.call_deferred()

func _set_versus_setup_visible(value: bool) -> void:
	controls_heading.visible = not value
	controls_label.visible = not value
	levels_heading.visible = not value
	level_buttons.visible = not value
	versus_selectors.visible = value
	primary_button.focus_neighbor_top = right_selector.get_path() if value else NodePath()

func _on_versus_choice_changed(index: int, changed_left: bool) -> void:
	if changed_left:
		versus_left_level = index + 1
		if versus_left_level == versus_right_level:
			versus_right_level = versus_right_level % levels.size() + 1
			right_selector.select(versus_right_level - 1)
	else:
		versus_right_level = index + 1
		if versus_right_level == versus_left_level:
			versus_left_level = versus_left_level % levels.size() + 1
			left_selector.select(versus_left_level - 1)

func _on_versus_button_pressed() -> void:
	if card_mode == "versus_setup":
		open_level(current_level)
	else:
		open_versus_setup()

func _start_versus_match() -> void:
	if is_instance_valid(arena):
		arena.queue_free()
	arena = ArenaScript.new()
	arena.position = Vector2(100, 80)
	add_child(arena)
	move_child(arena, 1)
	arena.round_finished.connect(_on_round_finished)
	arena.status_changed.connect(_on_status_changed)
	arena.configure_versus(levels[versus_left_level - 1], levels[versus_right_level - 1])
	card_mode = "versus_running"
	overlay.hide()
	menu_button.disabled = false
	primary_button.release_focus()

func update_level_buttons() -> void:
	for i in range(level_buttons.get_child_count()):
		var button := level_buttons.get_child(i) as Button
		button.disabled = not _level_available(i + 1)
		button.text = "%d%s" % [i + 1, " ●" if i + 1 == current_level else ""]

func _level_available(index: int) -> bool:
	return index <= unlocked or OS.has_feature("debug")

func _on_level_selected(index: int) -> void:
	if _level_available(index):
		open_level(index)

func _on_primary_pressed() -> void:
	if card_mode == "versus_setup" or card_mode == "versus_result":
		_start_versus_match()
		return
	if card_mode == "won":
		open_level(current_level + 1 if current_level < levels.size() else levels.size())
		return
	if card_mode == "lost":
		open_level(current_level)
		return
	overlay.hide()
	menu_button.disabled = false
	primary_button.release_focus()
	arena.set_active(true)

func style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("e5e5d7"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("34464b") if state == "normal" else (Color("5c6d66") if state == "hover" else (Color("b78649") if state == "pressed" else Color("223036")))
		box.border_color = Color("b78649") if state == "focus" else Color("596660")
		box.set_border_width_all(2)
		box.set_content_margin_all(5)
		button.add_theme_stylebox_override(state, box)

func _on_round_finished(won: bool) -> void:
	arena.set_active(false)
	if arena.versus_mode:
		card_mode = "versus_result"
		card_title.text = "Cyan wins!" if won else "Coral wins!"
		var winner := versus_left_level if won else versus_right_level
		card_text.text = "Level %d · %s wins the match. Cyan used level %d; coral used level %d." % [winner, levels[winner - 1]["title"], versus_left_level, versus_right_level]
		primary_button.text = "Rematch  ·  Tap / A / Start"
		versus_button.text = "Change fighters"
		_set_versus_setup_visible(false)
		overlay.show()
		menu_button.disabled = true
		primary_button.grab_focus.call_deferred()
		_fit_menu_card.call_deferred()
		return
	card_mode = "won" if won else "lost"
	if won:
		unlocked = maxi(unlocked, mini(levels.size(), current_level + 1))
		_save_progress()
		card_title.text = "Level complete"
		card_text.text = "You beat %s. The next lesson is unlocked." % levels[current_level - 1]["title"]
		primary_button.text = "Next level  ·  Tap / A / Start" if current_level < levels.size() else "Play again  ·  Tap / A / Start"
	else:
		card_title.text = "Try again"
		card_text.text = "Watch the enemy's timing, use cover, and press Tab to see what it is planning."
		primary_button.text = "Retry level  ·  Tap / A / Start"
	update_level_buttons()
	overlay.show()
	menu_button.disabled = true
	primary_button.grab_focus.call_deferred()
	_fit_menu_card.call_deferred()

func _on_status_changed(data: Dictionary) -> void:
	var player_hp := int(data.get("player_hp", 5))
	var enemy_hp := int(data.get("enemy_hp", 5))
	var reveal_enabled := bool(data.get("reveal_enabled", false))
	var leap_cooldown := float(data.get("leap_cooldown", 0.0))
	var reveal_label := "PLAN ON" if reveal_enabled else "PLAN OFF"
	var leap_label := "LEAP %.1fs" % leap_cooldown if leap_cooldown > 0.0 else "LEAP READY"
	if is_instance_valid(arena) and arena.versus_mode:
		status.text = "CYAN L%d  %d/%d     CORAL L%d  %d/%d" % [versus_left_level, player_hp, int(data.get("max_hp", 5)), versus_right_level, enemy_hp, int(data.get("enemy_max_hp", 5))]
	else:
		status.text = "YOU %d/%d     ENEMY %d/%d     %s     %s" % [player_hp, int(data.get("max_hp", 5)), enemy_hp, int(data.get("enemy_max_hp", 5)), leap_label, reveal_label]

func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if event is InputEventScreenTouch and event.pressed and primary_button.get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		_on_primary_pressed()
		return
	var accept_on_controller: bool = event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_START or (event.button_index == JOY_BUTTON_A and primary_button.has_focus()))
	if accept_on_controller:
		get_viewport().set_input_as_handled()
		_on_primary_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if overlay.visible:
			return
		_open_pause_menu()

func _open_pause_menu() -> void:
	if overlay.visible:
		return
	arena.set_active(false)
	if arena.versus_mode:
		card_mode = "versus_pause"
		card_title.text = "Versus paused"
		card_text.text = "Cyan: level %d · %s\nCoral: level %d · %s" % [versus_left_level, levels[versus_left_level - 1]["title"], versus_right_level, levels[versus_right_level - 1]["title"]]
		primary_button.text = "Resume match  ·  Tap / A / Start"
		versus_button.text = "Change fighters"
		_set_versus_setup_visible(false)
		overlay.show()
		menu_button.disabled = true
		primary_button.grab_focus.call_deferred()
		_fit_menu_card.call_deferred()
		return
	card_mode = "pause"
	card_title.text = "Paused · Level %d: %s" % [current_level, levels[current_level - 1]["title"]]
	card_text.text = levels[current_level - 1]["lesson"]
	primary_button.text = "Resume  ·  Tap / A / Start"
	overlay.show()
	menu_button.disabled = true
	primary_button.grab_focus.call_deferred()
	_fit_menu_card.call_deferred()
