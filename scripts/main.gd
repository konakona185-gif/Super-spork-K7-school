
extends Node3D

const CombatManagerScript = preload("res://scripts/combat_manager.gd")

var hero_data: Dictionary = {}
var enemy_data: Dictionary = {}

var hero_hp: int = 0
var enemy_hp: int = 0
var battle_over: bool = false

var rng := RandomNumberGenerator.new()
var combat_manager

var status_label: Label
var turn_label: Label
var attack_button: Button
var restart_button: Button

var hero_mesh: MeshInstance3D
var enemy_mesh: MeshInstance3D


func _ready() -> void:
	rng.randomize()

	if not _load_character_data():
		_show_data_error()
		return

	_reset_battle()
	_build_arena()
	_build_ui()
	_update_ui()


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
	var parse_result := json.parse(file.get_as_text())

	if parse_result != OK:
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
		if not fighter_data.has("name") or not fighter_data.has("id"):
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
			push_error("Gli HP iniziali devono essere maggiori di zero.")
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

	combat_manager = CombatManagerScript.new()
	combat_manager.setup(hero_data, enemy_data)

	if is_instance_valid(attack_button):
		attack_button.text = "Avanza turno"


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
	panel.custom_minimum_size = Vector2(360, 0)
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

	turn_label = Label.new()
	turn_label.text = "Pronto al combattimento."
	layout.add_child(turn_label)

	attack_button = Button.new()
	attack_button.text = "Avanza turno"
	attack_button.pressed.connect(_on_attack_pressed)
	layout.add_child(attack_button)

	restart_button = Button.new()
	restart_button.text = "Ricomincia"
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.visible = false
	layout.add_child(restart_button)


func _update_ui() -> void:
	if combat_manager == null:
		return

	var hero_stats: Dictionary = hero_data["stats"]
	var enemy_stats: Dictionary = enemy_data["stats"]

	var hero_bar := 0.0
	var enemy_bar := 0.0

	for fighter in combat_manager.get_combatants():
		if str(fighter["team"]) == "hero":
			hero_bar = float(fighter["action_bar"])
		elif str(fighter["team"]) == "enemy":
			enemy_bar = float(fighter["action_bar"])

	status_label.text = (
		"%s: %d / %d HP\nVelocità: %d\nBarra d'azione: %d%%\n\n" +
		"%s: %d / %d HP\nVelocità: %d\nBarra d'azione: %d%%"
	) % [
		str(hero_data["name"]),
		hero_hp,
		int(hero_stats["hp"]),
		int(hero_stats["speed"]),
		int(round(hero_bar)),
		str(enemy_data["name"]),
		enemy_hp,
		int(enemy_stats["hp"]),
		int(enemy_stats["speed"]),
		int(round(enemy_bar))
	]

	if hero_hp <= 0:
		status_label.text += "\n\nSCONFITTA!"
	elif enemy_hp <= 0:
		status_label.text += "\n\nVITTORIA!"

	attack_button.visible = not battle_over
	restart_button.visible = battle_over


func _on_attack_pressed() -> void:
	if battle_over:
		return

	var turn: Dictionary = combat_manager.get_next_turn()

	if turn.is_empty():
		turn_label.text = "Nessun combattente può agire."
		return

	var is_hero_turn := str(turn["team"]) == "hero"
	var attacker_data: Dictionary
	var defender_data: Dictionary
	var defender_id: String
	var attacker_name: String

	if is_hero_turn:
		attacker_data = hero_data
		defender_data = enemy_data
		defender_id = str(enemy_data["id"])
		attacker_name = str(hero_data["name"])
	else:
		attacker_data = enemy_data
		defender_data = hero_data
		defender_id = str(hero_data["id"])
		attacker_name = str(enemy_data["name"])

	var attacker_stats: Dictionary = attacker_data["stats"]
	var damage := rng.randi_range(
		int(attacker_stats["attack_min"]),
		int(attacker_stats["attack_max"])
	)

	if is_hero_turn:
		enemy_hp = maxi(0, enemy_hp - damage)
		combat_manager.set_hp(defender_id, enemy_hp)
	else:
		hero_hp = maxi(0, hero_hp - damage)
		combat_manager.set_hp(defender_id, hero_hp)

	turn_label.text = "%s agisce e infligge %d danni!" % [
		attacker_name,
		damage
	]

	if hero_hp <= 0:
		battle_over = true
		turn_label.text += "\nIl tuo eroe è stato sconfitto!"
	elif enemy_hp <= 0:
		battle_over = true
		turn_label.text += "\nIl nemico è stato sconfitto!"

	_update_ui()


func _on_restart_pressed() -> void:
	_reset_battle()
	turn_label.text = "Nuovo combattimento!"
	_update_ui()
