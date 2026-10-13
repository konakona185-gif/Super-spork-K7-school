extends Node3D

const CombatManagerScript = preload("res://scripts/combat_manager.gd")

var party_data: Array = []
var enemies_data: Array = []

var battle_over: bool = false
var waiting_for_hero_turn: bool = false
var waiting_for_enemy_turn: bool = false
var active_hero_id: String = ""
var active_enemy_id: String = ""
var selected_enemy_id: String = ""

var pending_turns: Array[Dictionary] = []

var rng := RandomNumberGenerator.new()
var combat_manager

var status_label: Label
var turn_label: Label
var turn_indicator_label: Label
var target_option: OptionButton
var attack_button: Button
var restart_button: Button

var hero_action_bar: ProgressBar
var enemy_action_bar: ProgressBar
var hero_bar_label: Label
var enemy_bar_label: Label

var hero_mesh: MeshInstance3D
var enemy_mesh: MeshInstance3D


func _ready() -> void:
	rng.randomize()

	if not _load_character_data():
		_show_data_error()
		set_process(false)
		return

	_reset_battle()
	_build_arena()
	_build_ui()
	_update_ui()


func _process(delta: float) -> void:
	if battle_over or waiting_for_hero_turn or waiting_for_enemy_turn:
		return

	if pending_turns.is_empty():
		pending_turns = combat_manager.advance_time(delta)

	_update_action_bars()

	while not pending_turns.is_empty():
		var fighter: Dictionary = pending_turns.pop_front()

		if not bool(fighter["alive"]):
			continue

		if float(fighter["action_bar"]) < CombatManagerScript.ACTION_BAR_MAX:
			continue

		if str(fighter["team"]) == "hero":
			active_hero_id = str(fighter["id"])
			waiting_for_hero_turn = true
			turn_indicator_label.text = "▶ TURNO DEL GIOCATORE"
			turn_indicator_label.add_theme_color_override(
				"font_color",
				Color(0.3, 0.85, 1.0)
			)
			turn_label.text = "%s è pronto. Seleziona un nemico e attacca." % str(fighter["name"])
			_refresh_target_options()
			_update_ui()
			return

		waiting_for_enemy_turn = true
		active_enemy_id = str(fighter["id"])
		_enemy_turn(fighter)
		return


func _load_character_data() -> bool:
	var file_path := "res://data/characters.json"

	if not FileAccess.file_exists(file_path):
		push_error("File non trovato: " + file_path)
		return false

	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		push_error("Impossibile aprire characters.json")
		return false

	var json := JSON.new()

	if json.parse(file.get_as_text()) != OK:
		push_error("Errore JSON: " + json.get_error_message())
		return false

	var content = json.data

	if not content is Dictionary:
		push_error("Il contenuto JSON deve essere un oggetto.")
		return false

	if not content.has("party") or not content.has("enemies"):
		push_error("Il JSON deve contenere party ed enemies.")
		return false

	if not content["party"] is Array or not content["enemies"] is Array:
		push_error("Party ed enemies devono essere elenchi.")
		return false

	party_data = content["party"]
	enemies_data = content["enemies"]

	if party_data.is_empty() or enemies_data.is_empty():
		push_error("Serve almeno un alleato e un nemico.")
		return false

	if party_data.size() > 4 or enemies_data.size() > 4:
		push_error("Sono consentiti al massimo quattro alleati e quattro nemici.")
		return false

	var used_ids: Dictionary = {}

	for group in [party_data, enemies_data]:
		for fighter_data in group:
			if not fighter_data is Dictionary:
				push_error("Un combattente non è un oggetto valido.")
				return false

			for key in ["id", "name", "stats"]:
				if not fighter_data.has(key):
					push_error("Manca il campo obbligatorio: " + key)
					return false

			var fighter_id: String = str(fighter_data["id"])

			if used_ids.has(fighter_id):
				push_error("ID duplicato: " + fighter_id)
				return false

			used_ids[fighter_id] = true

			if not fighter_data["stats"] is Dictionary:
				push_error("Il campo stats deve essere un oggetto.")
				return false

			var stats: Dictionary = fighter_data["stats"]

			for key in ["hp", "atk", "def", "speed"]:
				if not stats.has(key):
					push_error("Statistica mancante: " + key)
					return false

			if int(stats["hp"]) <= 0:
				push_error("Gli HP devono essere maggiori di zero.")
				return false

			if int(stats["atk"]) < 0 or int(stats["def"]) < 0:
				push_error("ATK e DEF non possono essere negativi.")
				return false

			if float(stats["speed"]) <= 0.0:
				push_error("La Velocità deve essere maggiore di zero.")
				return false

			if fighter_data.has("role"):
				if not str(fighter_data["role"]) in ["DPS", "Support", "Tank"]:
					push_error("Ruolo non valido: " + str(fighter_data["role"]))
					return false

			if fighter_data.has("scaling"):
				if not fighter_data["scaling"] is Array:
					push_error("Scaling deve essere un elenco.")
					return false

	return true


func _reset_battle() -> void:
	battle_over = false
	waiting_for_hero_turn = false
	waiting_for_enemy_turn = false
	active_hero_id = ""
	active_enemy_id = ""
	selected_enemy_id = ""
	pending_turns.clear()

	combat_manager = CombatManagerScript.new()
	combat_manager.setup(party_data, enemies_data)

	if is_instance_valid(attack_button):
		attack_button.text = "Attacca"
		attack_button.disabled = true

	if is_instance_valid(target_option):
		_refresh_target_options()


func _show_data_error() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var message := Label.new()
	message.text = "Errore nei dati dei personaggi.\nControlla data/characters.json."
	message.position = Vector2(20, 20)
	layer.add_child(message)


func _build_arena() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.1

	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.16, 0.20, 0.25)
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 7, 10)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.current = true
	add_child(camera)

	hero_mesh = _create_fighter(
		Vector3(-2, 0.8, 0),
		Color(0.2, 0.55, 1.0)
	)

	enemy_mesh = _create_fighter(
		Vector3(2, 0.8, 0),
		Color(1.0, 0.25, 0.2)
	)


func _create_fighter(pos: Vector3, tint: Color) -> MeshInstance3D:
	var fighter := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.45
	mesh.height = 1.6
	fighter.mesh = mesh
	fighter.position = pos

	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	fighter.material_override = material

	add_child(fighter)
	return fighter


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(420, 0)
	layer.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "ENDLESS ARENA"
	title.add_theme_font_size_override("font_size", 28)
	layout.add_child(title)

	status_label = Label.new()
	layout.add_child(status_label)

	layout.add_child(HSeparator.new())

	var hero_title := Label.new()
	hero_title.text = "ALLEATO ATTIVO — BARRA D'AZIONE"
	layout.add_child(hero_title)

	hero_action_bar = ProgressBar.new()
	hero_action_bar.min_value = 0.0
	hero_action_bar.max_value = 100.0
	hero_action_bar.show_percentage = false
	hero_action_bar.custom_minimum_size = Vector2(320, 26)
	layout.add_child(hero_action_bar)

	hero_bar_label = Label.new()
	layout.add_child(hero_bar_label)

	var enemy_title := Label.new()
	enemy_title.text = "NEMICO ATTIVO — BARRA D'AZIONE"
	layout.add_child(enemy_title)

	enemy_action_bar = ProgressBar.new()
	enemy_action_bar.min_value = 0.0
	enemy_action_bar.max_value = 100.0
	enemy_action_bar.show_percentage = false
	enemy_action_bar.custom_minimum_size = Vector2(320, 26)
	layout.add_child(enemy_action_bar)

	enemy_bar_label = Label.new()
	layout.add_child(enemy_bar_label)

	layout.add_child(HSeparator.new())

	var target_label := Label.new()
	target_label.text = "BERSAGLIO"
	layout.add_child(target_label)

	target_option = OptionButton.new()
	target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_option.item_selected.connect(_on_target_selected)
	layout.add_child(target_option)

	turn_indicator_label = Label.new()
	turn_indicator_label.text = "COMBATTIMENTO IN CORSO"
	turn_indicator_label.add_theme_font_size_override("font_size", 18)
	turn_indicator_label.add_theme_color_override(
		"font_color",
		Color(0.8, 0.85, 0.95)
	)
	layout.add_child(turn_indicator_label)

	turn_label = Label.new()
	turn_label.text = "Le barre si stanno riempiendo..."
	turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(turn_label)

	attack_button = Button.new()
	attack_button.text = "Attacca"
	attack_button.disabled = true
	attack_button.pressed.connect(_on_attack_pressed)
	layout.add_child(attack_button)

	restart_button = Button.new()
	restart_button.text = "Ricomincia"
	restart_button.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	layout.add_child(restart_button)


func _update_ui() -> void:
	if combat_manager == null:
		return

	status_label.text = "ALLEATI\n" + _format_team_status("hero")
	status_label.text += "\n\nNEMICI\n" + _format_team_status("enemy")

	attack_button.visible = not battle_over
	attack_button.disabled = not waiting_for_hero_turn
	target_option.disabled = not waiting_for_hero_turn or _get_alive_count("enemy") == 0
	restart_button.visible = battle_over

	if battle_over:
		if _get_alive_count("hero") == 0:
			turn_indicator_label.text = "SCONFITTA"
			turn_indicator_label.add_theme_color_override(
				"font_color",
				Color(1.0, 0.3, 0.3)
			)
		else:
			turn_indicator_label.text = "VITTORIA"
			turn_indicator_label.add_theme_color_override(
				"font_color",
				Color(0.3, 1.0, 0.5)
			)

	_update_action_bars()


func _format_team_status(team: String) -> String:
	var lines: PackedStringArray = []

	for fighter in combat_manager.get_combatants():
		if str(fighter["team"]) != team:
			continue

		lines.append(
			"%s — %d/%d HP | ATK %d | DEF %d | SPD %d" % [
				str(fighter["name"]),
				int(fighter["hp"]),
				int(fighter["max_hp"]),
				int(fighter["atk"]),
				int(fighter["def"]),
				int(fighter["speed"])
			]
		)

	return "\n".join(lines)


func _update_action_bars() -> void:
	if combat_manager == null:
		return

	var hero: Dictionary = combat_manager.get_combatant(active_hero_id)
	if hero.is_empty():
		hero = _get_first_alive_combatant("hero")

	var enemy: Dictionary = combat_manager.get_combatant(active_enemy_id)
	if enemy.is_empty():
		enemy = _get_first_alive_combatant("enemy")

	if not hero.is_empty():
		var hero_progress: float = float(hero["action_bar"])
		hero_action_bar.value = hero_progress
		hero_bar_label.text = "%s: %d%%" % [
			str(hero["name"]),
			int(round(hero_progress))
		]
		hero_action_bar.modulate = (
			Color(1.0, 0.85, 0.35)
			if waiting_for_hero_turn
			else Color.WHITE
		)

	if not enemy.is_empty():
		var enemy_progress: float = float(enemy["action_bar"])
		enemy_action_bar.value = enemy_progress
		enemy_bar_label.text = "%s: %d%%" % [
			str(enemy["name"]),
			int(round(enemy_progress))
		]
		enemy_action_bar.modulate = (
			Color(1.0, 0.75, 0.65)
			if waiting_for_enemy_turn
			else Color.WHITE
		)


func _refresh_target_options() -> void:
	if not is_instance_valid(target_option) or combat_manager == null:
		return

	target_option.clear()
	var selected_index: int = -1
	var index: int = 0

	for fighter in combat_manager.get_combatants():
		if str(fighter["team"]) != "enemy":
			continue

		if not bool(fighter["alive"]):
			continue

		target_option.add_item(
			"%s (%d/%d HP)" % [
				str(fighter["name"]),
				int(fighter["hp"]),
				int(fighter["max_hp"])
			]
		)
		target_option.set_item_metadata(index, str(fighter["id"]))

		if str(fighter["id"]) == selected_enemy_id:
			selected_index = index

		index += 1

	if selected_index == -1 and target_option.item_count > 0:
		selected_index = 0

	if selected_index >= 0:
		target_option.select(selected_index)
		selected_enemy_id = str(target_option.get_item_metadata(selected_index))
	else:
		selected_enemy_id = ""

	target_option.disabled = not waiting_for_hero_turn or target_option.item_count == 0


func _on_target_selected(index: int) -> void:
	if index < 0 or index >= target_option.item_count:
		return

	selected_enemy_id = str(target_option.get_item_metadata(index))


func _get_first_alive_combatant(team: String) -> Dictionary:
	for fighter in combat_manager.get_combatants():
		if str(fighter["team"]) == team and bool(fighter["alive"]):
			return fighter

	return {}


func _get_alive_count(team: String) -> int:
	var count: int = 0

	for fighter in combat_manager.get_combatants():
		if str(fighter["team"]) == team and bool(fighter["alive"]):
			count += 1

	return count


func _on_attack_pressed() -> void:
	if battle_over or not waiting_for_hero_turn:
		return

	var hero: Dictionary = combat_manager.get_combatant(active_hero_id)
	var enemy: Dictionary = combat_manager.get_combatant(selected_enemy_id)

	if hero.is_empty() or enemy.is_empty():
		turn_label.text = "Seleziona un bersaglio valido."
		return

	if not bool(hero["alive"]) or not bool(enemy["alive"]):
		_refresh_target_options()
		turn_label.text = "Il bersaglio non è più disponibile. Selezionane un altro."
		return

	var damage: int = maxi(1, int(hero["atk"]) - int(enemy["def"]))
	var new_hp: int = maxi(0, int(enemy["hp"]) - damage)

	combat_manager.set_hp(str(enemy["id"]), new_hp)
	turn_label.text = "%s infligge %d danni a %s!" % [
		str(hero["name"]),
		damage,
		str(enemy["name"])
	]

	combat_manager.reset_action_bar(active_hero_id)
	waiting_for_hero_turn = false
	active_hero_id = ""

	if _get_alive_count("enemy") == 0:
		battle_over = true
		pending_turns.clear()
		turn_label.text += "\nTutti i nemici sono stati sconfitti!"
	else:
		_refresh_target_options()
		turn_indicator_label.text = "COMBATTIMENTO IN CORSO"
		turn_indicator_label.add_theme_color_override(
			"font_color",
			Color(0.8, 0.85, 0.95)
		)

	_update_ui()


func _enemy_turn(fighter: Dictionary) -> void:
	var target: Dictionary = _get_first_alive_combatant("hero")

	if target.is_empty():
		battle_over = true
		waiting_for_enemy_turn = false
		pending_turns.clear()
		_update_ui()
		return

	var damage: int = maxi(1, int(fighter["atk"]) - int(target["def"]))
	var new_hp: int = maxi(0, int(target["hp"]) - damage)

	combat_manager.set_hp(str(target["id"]), new_hp)
	turn_label.text = "%s infligge %d danni a %s!" % [
		str(fighter["name"]),
		damage,
		str(target["name"])
	]

	combat_manager.reset_action_bar(str(fighter["id"]))
	waiting_for_enemy_turn = false
	active_enemy_id = ""

	if _get_alive_count("hero") == 0:
		battle_over = true
		pending_turns.clear()
		turn_label.text += "\nTutti gli alleati sono stati sconfitti!"
	else:
		turn_indicator_label.text = "COMBATTIMENTO IN CORSO"
		turn_indicator_label.add_theme_color_override(
			"font_color",
			Color(0.8, 0.85, 0.95)
		)

	_update_ui()


func _on_restart_pressed() -> void:
	_reset_battle()

	turn_indicator_label.text = "COMBATTIMENTO IN CORSO"
	turn_indicator_label.add_theme_color_override(
		"font_color",
		Color(0.8, 0.85, 0.95)
	)

	turn_label.text = "Le barre si stanno riempiendo..."
	_refresh_target_options()
	_update_ui()
