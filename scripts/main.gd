extends Node3D

const CombatManagerScript = preload("res://scripts/combat_manager.gd")
const CHARACTER_DATA_PATH: String = "res://data/characters.json"
const MAX_ALLIES: int = 4
const MAX_ENEMIES: int = 5

var combat_manager = CombatManagerScript.new()

var party_data: Array = []
var enemies_data: Array = []

var battle_over: bool = false
var waiting_for_hero_turn: bool = false
var waiting_for_enemy_turn: bool = false

var active_hero_id: String = ""
var active_enemy_id: String = ""
var selected_enemy_id: String = ""

var pending_turns: Array[Dictionary] = []
var fighter_meshes: Dictionary = {}

var status_label: Label
var turn_label: Label
var hero_bar: ProgressBar
var enemy_bar: ProgressBar
var target_selector: OptionButton
var attack_button: Button
var restart_button: Button


func _ready() -> void:
	_load_character_data()

	if party_data.is_empty() or enemies_data.is_empty():
		push_error("Servono almeno un alleato e un nemico per iniziare.")
		return

	if party_data.size() > MAX_ALLIES:
		push_error("La squadra può contenere al massimo 4 alleati.")
		return

	if enemies_data.size() > MAX_ENEMIES:
		push_error("La squadra nemica può contenere al massimo 5 nemici.")
		return

	if not _validate_character_data():
		return

	_build_arena()
	_build_ui()
	_reset_battle()


func _process(delta: float) -> void:
	if battle_over or waiting_for_hero_turn or waiting_for_enemy_turn:
		return

	if pending_turns.is_empty():
		var ready_combatants: Array[Dictionary] = combat_manager.advance_time(delta)

		for fighter in ready_combatants:
			pending_turns.append(fighter.duplicate())

	if pending_turns.is_empty():
		_update_action_bars()
		return

	var fighter: Dictionary = pending_turns.pop_front()
	var fighter_id: String = str(fighter["id"])

	var current_fighter: Dictionary = combat_manager.get_combatant(fighter_id)

	if current_fighter.is_empty() or not bool(current_fighter["alive"]):
		return

	if str(current_fighter["team"]) == "hero":
		active_hero_id = fighter_id
		waiting_for_hero_turn = true
		_update_ui()
		return

	active_enemy_id = fighter_id
	waiting_for_enemy_turn = true
	_perform_enemy_turn()


func _load_character_data() -> void:
	if not FileAccess.file_exists(CHARACTER_DATA_PATH):
		push_error("File dei personaggi non trovato: " + CHARACTER_DATA_PATH)
		return

	var file: FileAccess = FileAccess.open(CHARACTER_DATA_PATH, FileAccess.READ)

	if file == null:
		push_error("Impossibile aprire il file dei personaggi.")
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)

	if parse_result != OK:
		push_error("Errore nel JSON dei personaggi: " + json.get_error_message())
		return

	var data: Variant = json.data

	if not data is Dictionary:
		push_error("Il file JSON deve contenere un oggetto.")
		return

	var root_data: Dictionary = data

	if not root_data.has("party") or not root_data.has("enemies"):
		push_error("Il JSON deve contenere party ed enemies.")
		return

	if not root_data["party"] is Array or not root_data["enemies"] is Array:
		push_error("party ed enemies devono essere array.")
		return

	party_data = root_data["party"]
	enemies_data = root_data["enemies"]


func _validate_character_data() -> bool:
	var used_ids: Dictionary = {}
	var valid_roles: Array[String] = ["DPS", "Support", "Tank"]

	for character in party_data + enemies_data:
		if not character is Dictionary:
			push_error("Ogni combattente deve essere un oggetto JSON.")
			return false

		var fighter_data: Dictionary = character

		for required_field in ["id", "name", "stats"]:
			if not fighter_data.has(required_field):
				push_error("Manca il campo obbligatorio: " + required_field)
				return false

		var fighter_id: String = str(fighter_data["id"])

		if fighter_id.is_empty() or used_ids.has(fighter_id):
			push_error("Gli ID dei combattenti devono essere univoci e non vuoti.")
			return false

		used_ids[fighter_id] = true

		if not fighter_data["stats"] is Dictionary:
			push_error("Le statistiche devono essere un oggetto JSON.")
			return false

		var stats: Dictionary = fighter_data["stats"]

		for stat in ["hp", "atk", "def", "speed"]:
			if not stats.has(stat):
				push_error("Manca la statistica " + stat + " per " + fighter_id)
				return false

			if not (stats[stat] is int or stats[stat] is float):
				push_error("La statistica " + stat + " deve essere numerica.")
				return false

			if float(stats[stat]) < 0.0:
				push_error("Le statistiche non possono essere negative.")
				return false

		if int(stats["hp"]) <= 0 or float(stats["speed"]) <= 0.0:
			push_error("HP e velocità devono essere maggiori di zero.")
			return false

		if fighter_data.has("role"):
			if not valid_roles.has(str(fighter_data["role"])):
				push_error("Ruolo non valido per " + fighter_id)
				return false

		if fighter_data.has("scaling") and not fighter_data["scaling"] is Array:
			push_error("Il campo scaling deve essere un array.")
			return false

	return true


func _build_arena() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "ArenaGround"

	var ground_mesh: BoxMesh = BoxMesh.new()
	ground_mesh.size = Vector3(12.0, 0.2, 9.0)
	ground.mesh = ground_mesh
	ground.position = Vector3(0.0, -0.1, 0.0)

	var ground_material: StandardMaterial3D = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.18, 0.20, 0.24)
	ground_material.roughness = 1.0
	ground.material_override = ground_material

	add_child(ground)

	var camera: Camera3D = Camera3D.new()
	camera.name = "BattleCamera"
	camera.position = Vector3(0.0, 8.5, 12.0)
	camera.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
	camera.current = true
	add_child(camera)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "ArenaLight"
	light.rotation_degrees = Vector3(-50.0, -25.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var environment: WorldEnvironment = WorldEnvironment.new()
	var environment_data: Environment = Environment.new()
	environment_data.background_mode = Environment.BG_SKY
	environment_data.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_data.ambient_light_color = Color(0.55, 0.58, 0.65)
	environment_data.ambient_light_energy = 0.8
	environment.environment = environment_data
	add_child(environment)

	var hero_marker: MeshInstance3D = MeshInstance3D.new()
	hero_marker.name = "HeroSideMarker"

	var hero_marker_mesh: BoxMesh = BoxMesh.new()
	hero_marker_mesh.size = Vector3(0.08, 0.02, 5.0)
	hero_marker.mesh = hero_marker_mesh
	hero_marker.position = Vector3(-1.4, 0.02, 0.0)

	var hero_marker_material: StandardMaterial3D = StandardMaterial3D.new()
	hero_marker_material.albedo_color = Color(0.15, 0.35, 0.9)
	hero_marker.material_override = hero_marker_material
	add_child(hero_marker)

	var enemy_marker: MeshInstance3D = MeshInstance3D.new()
	enemy_marker.name = "EnemySideMarker"

	var enemy_marker_mesh: BoxMesh = BoxMesh.new()
	enemy_marker_mesh.size = Vector3(0.08, 0.02, 5.0)
	enemy_marker.mesh = enemy_marker_mesh
	enemy_marker.position = Vector3(1.4, 0.02, 0.0)

	var enemy_marker_material: StandardMaterial3D = StandardMaterial3D.new()
	enemy_marker_material.albedo_color = Color(0.8, 0.18, 0.18)
	enemy_marker.material_override = enemy_marker_material
	add_child(enemy_marker)


func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "BattleUI"
	add_child(canvas)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "StatusPanel"
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	canvas.add_child(panel)

	var panel_contents: VBoxContainer = VBoxContainer.new()
	panel_contents.add_theme_constant_override("separation", 6)
	panel.add_child(panel_contents)

	var title: Label = Label.new()
	title.text = "BATTAGLIA"
	title.add_theme_font_size_override("font_size", 22)
	panel_contents.add_child(title)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Preparazione combattimento..."
	panel_contents.add_child(status_label)

	var hero_title: Label = Label.new()
	hero_title.text = "Barra d'azione alleato"
	panel_contents.add_child(hero_title)

	hero_bar = ProgressBar.new()
	hero_bar.custom_minimum_size = Vector2(300.0, 18.0)
	hero_bar.max_value = 100.0
	hero_bar.show_percentage = true
	panel_contents.add_child(hero_bar)

	var enemy_title: Label = Label.new()
	enemy_title.text = "Barra d'azione nemico"
	panel_contents.add_child(enemy_title)

	enemy_bar = ProgressBar.new()
	enemy_bar.custom_minimum_size = Vector2(300.0, 18.0)
	enemy_bar.max_value = 100.0
	enemy_bar.show_percentage = true
	panel_contents.add_child(enemy_bar)

	var controls: PanelContainer = PanelContainer.new()
	controls.name = "ControlsPanel"
	controls.anchor_left = 0.0
	controls.anchor_top = 1.0
	controls.anchor_right = 0.0
	controls.anchor_bottom = 1.0
	controls.offset_left = 16.0
	controls.offset_top = -170.0
	controls.offset_right = 376.0
	controls.offset_bottom = -16.0
	canvas.add_child(controls)

	var control_contents: VBoxContainer = VBoxContainer.new()
	control_contents.add_theme_constant_override("separation", 8)
	controls.add_child(control_contents)

	turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.text = "Inizio combattimento"
	turn_label.add_theme_font_size_override("font_size", 18)
	control_contents.add_child(turn_label)

	var target_label: Label = Label.new()
	target_label.text = "Seleziona il bersaglio"
	control_contents.add_child(target_label)

	target_selector = OptionButton.new()
	target_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_selector.item_selected.connect(_on_target_selected)
	control_contents.add_child(target_selector)

	attack_button = Button.new()
	attack_button.text = "Attacca"
	attack_button.custom_minimum_size = Vector2(0.0, 40.0)
	attack_button.pressed.connect(_on_attack_pressed)
	control_contents.add_child(attack_button)

	restart_button = Button.new()
	restart_button.text = "Ricomincia battaglia"
	restart_button.pressed.connect(_on_restart_pressed)
	control_contents.add_child(restart_button)


func _reset_battle() -> void:
	battle_over = false
	waiting_for_hero_turn = false
	waiting_for_enemy_turn = false
	active_hero_id = ""
	active_enemy_id = ""
	selected_enemy_id = ""
	pending_turns.clear()

	combat_manager.setup(party_data, enemies_data)

	_create_fighter_visuals()
	_refresh_target_options()
	_update_ui()


func _create_fighter_visuals() -> void:
	for fighter_node in fighter_meshes.values():
		if is_instance_valid(fighter_node):
			fighter_node.queue_free()

	fighter_meshes.clear()

	var allies: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []

	for fighter_variant in combat_manager.get_combatants():
		var fighter: Dictionary = fighter_variant

		if str(fighter["team"]) == "hero":
			allies.append(fighter)
		else:
			enemies.append(fighter)

	for i in range(allies.size()):
		var ally: Dictionary = allies[i]
		var position: Vector3 = _get_formation_position("hero", i, allies.size())
		_create_fighter_model(ally, position)

	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		var position: Vector3 = _get_formation_position("enemy", i, enemies.size())
		_create_fighter_model(enemy, position)

	_update_fighter_visuals()


func _get_formation_position(team: String, index: int, total: int) -> Vector3:
	var x_position: float = -3.0 if team == "hero" else 3.0
	var z_position: float = 0.0

	if total == 1:
		z_position = 0.0
	elif total == 2:
		z_position = -0.9 if index == 0 else 0.9
	elif total == 3:
		z_position = float(index - 1) * 1.25
	elif total == 4:
		z_position = (float(index) - 1.5) * 1.05
	else:
		z_position = (float(index) - 2.0) * 0.9

	return Vector3(x_position, 0.0, z_position)


func _create_fighter_model(fighter: Dictionary, fighter_position: Vector3) -> void:
	var fighter_id: String = str(fighter["id"])

	var model: MeshInstance3D = MeshInstance3D.new()
	model.name = "Fighter_" + fighter_id

	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.5
	model.mesh = capsule
	model.position = fighter_position + Vector3(0.0, 0.78, 0.0)

	var material: StandardMaterial3D = StandardMaterial3D.new()

	if str(fighter["team"]) == "hero":
		material.albedo_color = Color(0.15, 0.45, 1.0)
	else:
		material.albedo_color = Color(0.95, 0.2, 0.18)

	material.roughness = 0.7
	model.material_override = material

	add_child(model)
	fighter_meshes[fighter_id] = model


func _update_fighter_visuals() -> void:
	for fighter_id_variant in fighter_meshes.keys():
		var fighter_id: String = str(fighter_id_variant)
		var fighter: Dictionary = combat_manager.get_combatant(fighter_id)
		var model: MeshInstance3D = fighter_meshes[fighter_id]

		if fighter.is_empty() or not is_instance_valid(model):
			continue

		var material: StandardMaterial3D = model.material_override as StandardMaterial3D

		if not bool(fighter["alive"]):
			material.albedo_color = Color(0.16, 0.16, 0.18)
			model.scale = Vector3(0.75, 0.35, 0.75)
			model.position.y = 0.22
		else:
			if str(fighter["team"]) == "hero":
				material.albedo_color = Color(0.15, 0.45, 1.0)
			else:
				material.albedo_color = Color(0.95, 0.2, 0.18)

			model.scale = Vector3.ONE
			model.position.y = 0.78


func _refresh_target_options() -> void:
	if target_selector == null:
		return

	target_selector.clear()

	var first_target_id: String = ""

	for fighter_variant in combat_manager.get_combatants():
		var fighter: Dictionary = fighter_variant

		if str(fighter["team"]) != "enemy":
			continue

		if not bool(fighter["alive"]):
			continue

		var fighter_id: String = str(fighter["id"])
		var display_text: String = str(fighter["name"]) + " (" + fighter_id + ")"

		target_selector.add_item(display_text)
		target_selector.set_item_metadata(target_selector.item_count - 1, fighter_id)

		if first_target_id.is_empty():
			first_target_id = fighter_id

	selected_enemy_id = first_target_id

	if target_selector.item_count > 0:
		target_selector.select(0)


func _on_target_selected(index: int) -> void:
	if index < 0 or index >= target_selector.item_count:
		return

	selected_enemy_id = str(target_selector.get_item_metadata(index))
	_update_ui()


func _on_attack_pressed() -> void:
	if battle_over or not waiting_for_hero_turn:
		return

	if active_hero_id.is_empty() or selected_enemy_id.is_empty():
		return

	var hero: Dictionary = combat_manager.get_combatant(active_hero_id)
	var enemy: Dictionary = combat_manager.get_combatant(selected_enemy_id)

	if hero.is_empty() or enemy.is_empty():
		return

	if not bool(hero["alive"]) or not bool(enemy["alive"]):
		return

	var damage: int = maxi(1, int(hero["atk"]) - int(enemy["def"]))
	var new_hp: int = int(enemy["hp"]) - damage

	combat_manager.set_hp(selected_enemy_id, new_hp)
	combat_manager.reset_action_bar(active_hero_id)

	turn_label.text = str(hero["name"]) + " attacca " + str(enemy["name"]) + " per " + str(damage) + " danni."

	waiting_for_hero_turn = false
	active_hero_id = ""

	_check_battle_end()
	_update_fighter_visuals()
	_refresh_target_options()
	_update_ui()


func _perform_enemy_turn() -> void:
	if battle_over:
		waiting_for_enemy_turn = false
		return

	var enemy: Dictionary = combat_manager.get_combatant(active_enemy_id)

	if enemy.is_empty() or not bool(enemy["alive"]):
		waiting_for_enemy_turn = false
		return

	var target: Dictionary = {}

	for fighter_variant in combat_manager.get_combatants():
		var fighter: Dictionary = fighter_variant

		if str(fighter["team"]) == "hero" and bool(fighter["alive"]):
			target = fighter
			break

	if target.is_empty():
		waiting_for_enemy_turn = false
		_check_battle_end()
		return

	var damage: int = maxi(1, int(enemy["atk"]) - int(target["def"]))
	var target_id: String = str(target["id"])

	combat_manager.set_hp(target_id, int(target["hp"]) - damage)
	combat_manager.reset_action_bar(active_enemy_id)

	turn_label.text = str(enemy["name"]) + " attacca " + str(target["name"]) + " per " + str(damage) + " danni."

	waiting_for_enemy_turn = false
	active_enemy_id = ""

	_check_battle_end()
	_update_fighter_visuals()
	_refresh_target_options()
	_update_ui()


func _check_battle_end() -> void:
	var living_allies: int = 0
	var living_enemies: int = 0

	for fighter_variant in combat_manager.get_combatants():
		var fighter: Dictionary = fighter_variant

		if not bool(fighter["alive"]):
			continue

		if str(fighter["team"]) == "hero":
			living_allies += 1
		else:
			living_enemies += 1

	if living_allies == 0:
		battle_over = true
		waiting_for_hero_turn = false
		waiting_for_enemy_turn = false
		pending_turns.clear()
		turn_label.text = "Sconfitta! Tutti gli alleati sono stati sconfitti."
	elif living_enemies == 0:
		battle_over = true
		waiting_for_hero_turn = false
		waiting_for_enemy_turn = false
		pending_turns.clear()
		turn_label.text = "Vittoria! Tutti i nemici sono stati sconfitti."


func _update_ui() -> void:
	if status_label == null:
		return

	var lines: PackedStringArray = []

	for fighter_variant in combat_manager.get_combatants():
		var fighter: Dictionary = fighter_variant
		var team_label: String = "Alleato" if str(fighter["team"]) == "hero" else "Nemico"
		var hp_text: String = str(fighter["hp"]) + "/" + str(fighter["max_hp"])
		var fighter_line: String = team_label + " | " + str(fighter["name"]) + " | HP: " + hp_text

		if not bool(fighter["alive"]):
			fighter_line += " | SCONFITTO"

		lines.append(fighter_line)

	status_label.text = "\n".join(lines)

	if turn_label != null and not battle_over:
		if waiting_for_hero_turn:
			turn_label.text = "Il tuo turno: scegli un bersaglio e attacca."
		elif waiting_for_enemy_turn:
			turn_label.text = "Turno nemico..."
		else:
			turn_label.text = "Le barre d'azione stanno avanzando..."

	if attack_button != null:
		attack_button.disabled = battle_over or not waiting_for_hero_turn or selected_enemy_id.is_empty()

	_update_action_bars()


func _update_action_bars() -> void:
	if hero_bar == null or enemy_bar == null:
		return

	var hero: Dictionary = {}
	var enemy: Dictionary = {}

	if not active_hero_id.is_empty():
		hero = combat_manager.get_combatant(active_hero_id)

	if not active_enemy_id.is_empty():
		enemy = combat_manager.get_combatant(active_enemy_id)

	if hero.is_empty():
		for fighter_variant in combat_manager.get_combatants():
			var fighter: Dictionary = fighter_variant

			if str(fighter["team"]) == "hero" and bool(fighter["alive"]):
				hero = fighter
				break

	if enemy.is_empty():
		for fighter_variant in combat_manager.get_combatants():
			var fighter: Dictionary = fighter_variant

			if str(fighter["team"]) == "enemy" and bool(fighter["alive"]):
				enemy = fighter
				break

	hero_bar.value = float(hero.get("action_bar", 0.0))
	enemy_bar.value = float(enemy.get("action_bar", 0.0))


func _on_restart_pressed() -> void:
	_reset_battle()
