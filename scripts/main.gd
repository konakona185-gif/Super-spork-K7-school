
extends Node3D

const CombatManagerScript = preload("res://scripts/combat_manager.gd")

var hero_data: Dictionary = {}
var enemy_data: Dictionary = {}

var hero_hp: int = 0
var enemy_hp: int = 0
var battle_over: bool = false
var waiting_for_hero_turn: bool = false

var rng := RandomNumberGenerator.new()
var combat_manager

var status_label: Label
var turn_label: Label
var turn_indicator_label: Label
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
	if battle_over or waiting_for_hero_turn:
		return

	var ready_fighter: Dictionary = combat_manager.advance_time(delta)

	_update_action_bars()

	if ready_fighter.is_empty():
		return

	if str(ready_fighter["team"]) == "hero":
		waiting_for_hero_turn = true
		turn_indicator_label.text = "▶ TURNO DEL GIOCATORE"
		turn_indicator_label.add_theme_color_override(
			"font_color",
			Color(0.3, 0.85, 1.0)
		)
		turn_label.text = "Il tuo personaggio è pronto. Scegli Attacca."
		_update_ui()
	else:
		turn_indicator_label.text = "▶ TURNO DEL NEMICO"
		turn_indicator_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.4, 0.3)
		)
		_enemy_turn(ready_fighter)


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

	if not content.has("hero") or not content.has("enemy"):
		push_error("Il JSON deve contenere hero ed enemy.")
		return false

	hero_data = content["hero"]
	enemy_data = content["enemy"]

	if not hero_data is Dictionary or not enemy_data is Dictionary:
		push_error("Dati dei combattenti non validi.")
		return false

	for fighter_data in [hero_data, enemy_data]:
		if not fighter_data.has("id") or not fighter_data.has("name"):
			push_error("Mancano nome o ID di un combattente.")
			return false

		if not fighter_data.has("stats"):
			push_error("Mancano le statistiche di un combattente.")
			return false

		if not fighter_data["stats"] is Dictionary:
			push_error("Il campo stats deve essere un oggetto.")
			return false

		var stats: Dictionary = fighter_data["stats"]

		for key in ["hp", "attack_min", "attack_max", "speed"]:
			if not stats.has(key):
				push_error("Statistica mancante: " + key)
				return false

		if int(stats["hp"]) <= 0:
			push_error("Gli HP devono essere maggiori di zero.")
			return false

		if int(stats["attack_min"]) < 0:
			push_error("L'attacco minimo non può essere negativo.")
			return false

		if int(stats["attack_min"]) > int(stats["attack_max"]):
			push_error("Intervallo di attacco non valido.")
			return false

		if float(stats["speed"]) <= 0.0:
			push_error("La Velocità deve essere maggiore di zero.")
			return false

	return true


func _reset_battle() -> void:
	hero_hp = int(hero_data["stats"]["hp"])
	enemy_hp = int(enemy_data["stats"]["hp"])
	battle_over = false
	waiting_for_hero_turn = false

	combat_manager = CombatManagerScript.new()
	combat_manager.setup(hero_data, enemy_data)

	if is_instance_valid(attack_button):
		attack_button.text = "Attacca"
		attack_button.disabled = true


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
	panel.custom_minimum_size = Vector2(380, 0)
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

	var separator := HSeparator.new()
	layout.add_child(separator)

	var hero_title := Label.new()
	hero_title.text = "AVVENTURIERO — BARRA D'AZIONE"
	layout.add_child(hero_title)

	hero_action_bar = ProgressBar.new()
	hero_action_bar.min_value = 0.0
	hero_action_bar.max_value = 100.0
	hero_action_bar.value = 0.0
	hero_action_bar.show_percentage = false
	hero_action_bar.custom_minimum_size = Vector2(320, 26)
	layout.add_child(hero_action_bar)

	hero_bar_label = Label.new()
	layout.add_child(hero_bar_label)

	var enemy_title := Label.new()
	enemy_title.text = "SLIME CREMISI — BARRA D'AZIONE"
	layout.add_child(enemy_title)

	enemy_action_bar = ProgressBar.new()
	enemy_action_bar.min_value = 0.0
	enemy_action_bar.max_value = 100.0
	enemy_action_bar.value = 0.0
	enemy_action_bar.show_percentage = false
	enemy_action_bar.custom_minimum_size = Vector2(320, 26)
	layout.add_child(enemy_action_bar)

	enemy_bar_label = Label.new()
	layout.add_child(enemy_bar_label)

	var turn_separator := HSeparator.new()
	layout.add_child(turn_separator)

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

	var hero_stats: Dictionary = hero_data["stats"]
	var enemy_stats: Dictionary = enemy_data["stats"]

	status_label.text = (
		"%s: %d / %d HP | Velocità: %d\n" +
		"%s: %d / %d HP | Velocità: %d"
	) % [
		str(hero_data["name"]),
		hero_hp,
		int(hero_stats["hp"]),
		int(hero_stats["speed"]),
		str(enemy_data["name"]),
		enemy_hp,
		int(enemy_stats["hp"]),
		int(enemy_stats["speed"])
	]

	if battle_over:
		if hero_hp <= 0:
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

		status_label.text += "\n\nCOMBATTIMENTO TERMINATO"

	attack_button.visible = not battle_over
	attack_button.disabled = not waiting_for_hero_turn
	restart_button.visible = battle_over

	_update_action_bars()


func _update_action_bars() -> void:
	if combat_manager == null:
		return

	for fighter in combat_manager.get_combatants():
		var progress: float = float(fighter["action_bar"])
		var team: String = str(fighter["team"])

		if team == "hero":
			hero_action_bar.value = progress
			hero_bar_label.text = "Avanzamento: %d%%" % int(round(progress))

			if waiting_for_hero_turn:
				hero_action_bar.modulate = Color(1.0, 0.85, 0.35)
			else:
				hero_action_bar.modulate = Color.WHITE

		elif team == "enemy":
			enemy_action_bar.value = progress
			enemy_bar_label.text = "Avanzamento: %d%%" % int(round(progress))

			if not waiting_for_hero_turn and progress >= 100.0:
				enemy_action_bar.modulate = Color(1.0, 0.75, 0.65)
			else:
				enemy_action_bar.modulate = Color.WHITE


func _on_attack_pressed() -> void:
	if battle_over or not waiting_for_hero_turn:
		return

	var hero_stats: Dictionary = hero_data["stats"]

	var damage: int = rng.randi_range(
		int(hero_stats["attack_min"]),
		int(hero_stats["attack_max"])
	)

	enemy_hp = maxi(0, enemy_hp - damage)
	combat_manager.set_hp(str(enemy_data["id"]), enemy_hp)

	turn_label.text = "%s infligge %d danni!" % [
		str(hero_data["name"]),
		damage
	]

	waiting_for_hero_turn = false
	_reset_action_bar("hero")

	if enemy_hp <= 0:
		battle_over = true
		turn_label.text += "\nIl nemico è stato sconfitto!"
	else:
		turn_indicator_label.text = "COMBATTIMENTO IN CORSO"
		turn_indicator_label.add_theme_color_override(
			"font_color",
			Color(0.8, 0.85, 0.95)
		)

	_update_ui()


func _enemy_turn(_fighter: Dictionary) -> void:
	var enemy_stats: Dictionary = enemy_data["stats"]

	var damage: int = rng.randi_range(
		int(enemy_stats["attack_min"]),
		int(enemy_stats["attack_max"])
	)

	hero_hp = maxi(0, hero_hp - damage)
	combat_manager.set_hp(str(hero_data["id"]), hero_hp)

	turn_label.text = "%s infligge %d danni!" % [
		str(enemy_data["name"]),
		damage
	]

	_reset_action_bar("enemy")

	if hero_hp <= 0:
		battle_over = true
		turn_label.text += "\nIl tuo eroe è stato sconfitto!"
	else:
		turn_indicator_label.text = "COMBATTIMENTO IN CORSO"
		turn_indicator_label.add_theme_color_override(
			"font_color",
			Color(0.8, 0.85, 0.95)
		)

	_update_ui()


func _reset_action_bar(team: String) -> void:
	if team == "hero":
		combat_manager.reset_action_bar(str(hero_data["id"]))
	elif team == "enemy":
		combat_manager.reset_action_bar(str(enemy_data["id"]))


func _on_restart_pressed() -> void:
	_reset_battle()

	turn_indicator_label.text = "COMBATTIMENTO IN CORSO"
	turn_indicator_label.add_theme_color_override(
		"font_color",
		Color(0.8, 0.85, 0.95)
	)

	turn_label.text = "Le barre si stanno riempiendo..."
	_update_ui()
