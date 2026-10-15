extends Node3D

const CombatManagerScript = preload("res://scripts/combat_manager.gd")
const CHARACTER_DATA_PATH: String = "res://data/characters.json"
const MAX_ALLIES: int = 4
const MAX_ENEMIES: int = 5

const HP_BAR_WIDTH: float = 0.95
const HP_BAR_HEIGHT: float = 0.09
const HP_BAR_Y: float = 1.85
const TURN_INDICATOR_Y: float = 2.35

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
var fighter_hp_bars: Dictionary = {}
var fighter_hp_fills: Dictionary = {}
var turn_indicators: Dictionary = {}
var target_indicators: Dictionary = {}

var status_label: Label
var turn_label: Label
var hero_bar: ProgressBar
var enemy_bar: ProgressBar
var target_selector: OptionButton
var target_name_label: Label
var target_hp_label: Label
var target_hp_bar: ProgressBar
var ally_info_labels: Dictionary = {}
var ally_hp_labels: Dictionary = {}
var ally_hp_bars: Dictionary = {}
var action_buttons_container: VBoxContainer
var energy_label: Label
var ultimate_button: Button
var restart_button: Button


func _ready() -> void:
	_load_character_data()

	if party_data.is_empty() or enemies_data.is_empty():
		push_error("Servono almeno un alleato e un nemico per iniziare.")
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

	combat_manager.on_turn_start(fighter_id)

	if str(current_fighter["team"]) == "hero":
		active_hero_id = fighter_id
		waiting_for_hero_turn = true
		_rebuild_action_buttons()
		_update_ui()
		return

	active_enemy_id = fighter_id
	waiting_for_enemy_turn = true
	_update_ui()
	_perform_enemy_turn()


func _load_character_data() -> void:
	if not FileAccess.file_exists(CHARACTER_DATA_PATH):
		return

	var file: FileAccess = FileAccess.open(CHARACTER_DATA_PATH, FileAccess.READ)
	if file == null:
		return

	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var root: Dictionary = json.data
		party_data = root.get("party", [])
		enemies_data = root.get("enemies", [])


func _build_arena() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "ArenaGround"

	var ground_mesh: BoxMesh = BoxMesh.new()
	ground_mesh.size = Vector3(12.0, 0.2, 9.0)
	ground.mesh = ground_mesh
	ground.position = Vector3(0.0, -0.1, 0.0)

	var ground_material: StandardMaterial3D = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.18, 0.20, 0.24)
	ground.material_override = ground_material
	add_child(ground)

	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 8.5, 12.0)
	camera.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
	camera.current = true
	add_child(camera)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -25.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var environment: WorldEnvironment = WorldEnvironment.new()
	var env_data: Environment = Environment.new()
	env_data.background_mode = Environment.BG_SKY
	env_data.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_data.ambient_light_color = Color(0.55, 0.58, 0.65)
	env_data.ambient_light_energy = 0.8
	environment.environment = env_data
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
	add_child(canvas)

	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(380.0, 0.0)
	canvas.add_child(panel)

	var panel_contents: VBoxContainer = VBoxContainer.new()
	panel_contents.add_theme_constant_override("separation", 6)
	panel.add_child(panel_contents)

	var title: Label = Label.new()
	title.text = "BATTAGLIA"
	title.add_theme_font_size_override("font_size", 22)
	panel_contents.add_child(title)

	status_label = Label.new()
	panel_contents.add_child(status_label)

	var hero_title: Label = Label.new()
	hero_title.text = "Barra d'azione eroe di turno"
	panel_contents.add_child(hero_title)
	hero_bar = _create_action_bar()
	panel_contents.add_child(hero_bar)

	var enemy_title: Label = Label.new()
	enemy_title.text = "Barra d'azione nemico"
	panel_contents.add_child(enemy_title)
	enemy_bar = _create_action_bar()
	panel_contents.add_child(enemy_bar)

	var controls: PanelContainer = PanelContainer.new()
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_left = 16.0
	controls.offset_top = -370.0
	controls.offset_right = 410.0
	controls.offset_bottom = -16.0
	canvas.add_child(controls)

	var control_contents: VBoxContainer = VBoxContainer.new()
	control_contents.add_theme_constant_override("separation", 6)
	controls.add_child(control_contents)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 15)
	turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_contents.add_child(turn_label)

	target_selector = OptionButton.new()
	target_selector.item_selected.connect(_on_target_selected)
	control_contents.add_child(target_selector)

	target_name_label = Label.new()
	control_contents.add_child(target_name_label)

	target_hp_label = Label.new()
	control_contents.add_child(target_hp_label)

	target_hp_bar = _create_hp_progress_bar()
	control_contents.add_child(target_hp_bar)

	action_buttons_container = VBoxContainer.new()
	action_buttons_container.add_theme_constant_override("separation", 4)
	control_contents.add_child(action_buttons_container)

	energy_label = Label.new()
	control_contents.add_child(energy_label)

	ultimate_button = Button.new()
	ultimate_button.text = "⚡ ULTIMATE"
	ultimate_button.custom_minimum_size = Vector2(0.0, 36.0)
	ultimate_button.pressed.connect(_on_ultimate_pressed)
	control_contents.add_child(ultimate_button)

	restart_button = Button.new()
	restart_button.text = "Ricomincia battaglia"
	restart_button.pressed.connect(_on_restart_pressed)
	control_contents.add_child(restart_button)

	_build_ally_info_panel(canvas)


func _build_ally_info_panel(canvas: CanvasLayer) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -340.0
	panel.offset_top = 16.0
	panel.offset_right = -16.0
	panel.offset_bottom = 360.0
	canvas.add_child(panel)

	var contents: VBoxContainer = VBoxContainer.new()
	panel.add_child(contents)

	var title: Label = Label.new()
	title.text = "SQUADRA ALLEATA"
	title.add_theme_font_size_override("font_size", 18)
	contents.add_child(title)

	for character in party_data:
		var c_id: String = str(character["id"])

		var card: PanelContainer = PanelContainer.new()
		contents.add_child(card)

		var card_vbox: VBoxContainer = VBoxContainer.new()
		card.add_child(card_vbox)

		var info_label: Label = Label.new()
		info_label.text = str(character["name"]) + " | " + str(character.get("element", "Neutral")) + " | " + str(character.get("role", "DPS"))
		card_vbox.add_child(info_label)
		ally_info_labels[c_id] = info_label

		var hp_label: Label = Label.new()
		card_vbox.add_child(hp_label)
		ally_hp_labels[c_id] = hp_label

		var hp_bar: ProgressBar = _create_hp_progress_bar()
		card_vbox.add_child(hp_bar)
		ally_hp_bars[c_id] = hp_bar


func _create_action_bar() -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(300.0, 16.0)
	bar.max_value = 100.0
	return bar


func _create_hp_progress_bar() -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(260.0, 14.0)
	bar.max_value = 100.0
	bar.show_percentage = false
	return bar


func _reset_battle() -> void:
	battle_over = false
	waiting_for_hero_turn = false
	waiting_for_enemy_turn = false
	active_hero_id = ""
	active_enemy_id = ""
	pending_turns.clear()

	combat_manager.setup(party_data, enemies_data)
	_create_fighter_visuals()
	_refresh_target_options()
	_rebuild_action_buttons()
	_update_ui()


func _create_fighter_visuals() -> void:
	for node in fighter_meshes.values():
		if is_instance_valid(node):
			node.queue_free()

	fighter_meshes.clear()
	fighter_hp_bars.clear()
	fighter_hp_fills.clear()
	turn_indicators.clear()
	target_indicators.clear()

	var fighters: Array[Dictionary] = combat_manager.get_combatants()
	var hero_index: int = 0
	var enemy_index: int = 0

	for f in fighters:
		var pos: Vector3 = Vector3.ZERO
		if str(f["team"]) == "hero":
			pos = Vector3(-3.0, 0.78, float(hero_index) * 2.0 - 1.0)
			hero_index += 1
		else:
			pos = Vector3(3.0, 0.78, float(enemy_index) * 2.0 - 1.0)
			enemy_index += 1
		_create_fighter_model(f, pos)

	_update_fighter_visuals()


func _create_fighter_model(fighter: Dictionary, pos: Vector3) -> void:
	var f_id: String = str(fighter["id"])
	var model: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.5
	model.mesh = capsule
	model.position = pos

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	if str(fighter["team"]) == "hero":
		mat.albedo_color = Color(0.15, 0.45, 1.0) if f_id == "hero_mimi" else Color(0.65, 0.25, 0.85)
	else:
		mat.albedo_color = Color(0.95, 0.2, 0.18)

	model.material_override = mat
	add_child(model)

	fighter_meshes[f_id] = model
	_create_fighter_hp_bar(fighter, model)
	_create_turn_indicator(fighter, model)
	_create_target_indicator(fighter, model)


func _create_fighter_hp_bar(fighter: Dictionary, model: MeshInstance3D) -> void:
	var f_id: String = str(fighter["id"])
	var bar_root: Node3D = Node3D.new()
	bar_root.position = Vector3(0.0, HP_BAR_Y, 0.0)
	model.add_child(bar_root)

	var background: MeshInstance3D = MeshInstance3D.new()
	var bg_mesh: BoxMesh = BoxMesh.new()
	bg_mesh.size = Vector3(HP_BAR_WIDTH, HP_BAR_HEIGHT, 0.035)
	background.mesh = bg_mesh
	var bg_mat: StandardMaterial3D = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08, 0.08, 0.08)
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	background.material_override = bg_mat
	bar_root.add_child(background)

	var fill: MeshInstance3D = MeshInstance3D.new()
	var fill_mesh: BoxMesh = BoxMesh.new()
	fill_mesh.size = Vector3(HP_BAR_WIDTH, HP_BAR_HEIGHT, 0.045)
	fill.mesh = fill_mesh
	var fill_mat: StandardMaterial3D = StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.12, 0.88, 0.22)
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill.material_override = fill_mat
	bar_root.add_child(fill)

	fighter_hp_bars[f_id] = bar_root
	fighter_hp_fills[f_id] = fill


func _create_turn_indicator(fighter: Dictionary, model: MeshInstance3D) -> void:
	var f_id: String = str(fighter["id"])
	var indicator: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	indicator.mesh = sphere
	indicator.position = Vector3(0.0, TURN_INDICATOR_Y, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	indicator.material_override = mat
	indicator.visible = false
	model.add_child(indicator)
	turn_indicators[f_id] = indicator


func _create_target_indicator(fighter: Dictionary, model: MeshInstance3D) -> void:
	if str(fighter["team"]) != "enemy":
		return

	var f_id: String = str(fighter["id"])
	var indicator: MeshInstance3D = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.43
	ring.outer_radius = 0.49
	indicator.mesh = ring
	indicator.rotation_degrees.x = 90.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.0)
	indicator.material_override = mat
	indicator.visible = false
	model.add_child(indicator)
	target_indicators[f_id] = indicator


func _on_target_selected(index: int) -> void:
	selected_enemy_id = str(target_selector.get_item_metadata(index))
	_update_ui()


func _refresh_target_options() -> void:
	target_selector.clear()
	for f in combat_manager.get_combatants():
		if str(f["team"]) == "enemy" and bool(f["alive"]):
			target_selector.add_item(str(f["name"]))
			target_selector.set_item_metadata(target_selector.item_count - 1, str(f["id"]))

	if target_selector.item_count > 0:
		target_selector.select(0)
		selected_enemy_id = str(target_selector.get_item_metadata(0))
	else:
		selected_enemy_id = ""


func _rebuild_action_buttons() -> void:
	for child in action_buttons_container.get_children():
		child.queue_free()

	if not waiting_for_hero_turn or active_hero_id.is_empty():
		return

	var hero_abilities: Array[Dictionary] = combat_manager.get_abilities_for_character(active_hero_id)

	for ab in hero_abilities:
		var ab_type: String = str(ab.get("type", ""))
		if ab_type == "passive" or ab_type == "ultimate":
			continue

		var btn: Button = Button.new()
		btn.text = str(ab.get("name", "Abilità"))
		btn.custom_minimum_size = Vector2(0.0, 32.0)
		var ab_id: String = str(ab.get("id", ""))
		btn.pressed.connect(func(): _execute_hero_action(ab_id))
		action_buttons_container.add_child(btn)


func _execute_hero_action(ability_id: String) -> void:
	if battle_over or not waiting_for_hero_turn or active_hero_id.is_empty():
		return

	var hero: Dictionary = combat_manager.get_combatant(active_hero_id)
	var result: Dictionary = combat_manager.use_ability_by_id(active_hero_id, selected_enemy_id, ability_id)

	if not bool(result.get("success", false)):
		turn_label.text = str(result.get("message", "Azione non valida."))
		_update_ui()
		return

	var eff: String = str(result.get("effect_type", "damage"))

	if eff == "damage":
		turn_label.text = str(hero["name"]) + " usa " + str(result["ability_name"]) + " su " + str(result["target_name"]) + " per " + str(result["damage"]) + " danni!"
	elif eff == "cards_shuffle":
		turn_label.text = str(hero["name"]) + " usa Rimescola! Carte consumate: " + str(result["consumed"]) + "."
	elif eff == "buff_atk":
		var extra: String = " (applicato anche a sé per Clausola di Tutela!)" if result.get("applied_to_self", false) else ""
		turn_label.text = str(hero["name"]) + " usa Iniezione di Capitale: +" + str(result["amount"]) + " ATK a " + str(result["target_name"]) + extra
	elif eff == "buff_dmg_reduction":
		var extra: String = " (applicato anche a sé!)" if result.get("applied_to_self", false) else ""
		turn_label.text = str(hero["name"]) + " usa Polizza Assicurativa: riduce di " + str(result["amount"]) + " i danni a " + str(result["target_name"]) + extra
	elif eff == "buff_max_hp_and_heal":
		var extra: String = " (applicato anche a sé!)" if result.get("applied_to_self", false) else ""
		turn_label.text = str(hero["name"]) + " usa Fondo di Soccorso: +" + str(result["amount"]) + " HP max e cura a " + str(result["target_name"]) + extra

	waiting_for_hero_turn = false
	active_hero_id = ""
	_rebuild_action_buttons()

	_check_battle_end()
	_update_fighter_visuals()
	_refresh_target_options()
	_update_ui()


func _on_ultimate_pressed() -> void:
	if battle_over:
		return

	var ready_hero_id: String = _get_ready_ultimate_hero_id()
	if ready_hero_id.is_empty():
		return

	var hero: Dictionary = combat_manager.get_combatant(ready_hero_id)
	var ult_id: String = "mimi_ultimate" if ready_hero_id == "hero_mimi" else "parunan_ultimate"
	var result: Dictionary = combat_manager.use_ability_by_id(ready_hero_id, selected_enemy_id, ult_id)

	if not bool(result.get("success", false)):
		turn_label.text = str(result.get("message", "Impossibile usare l'Ultimate."))
		_update_ui()
		return

	var eff: String = str(result.get("effect_type", ""))
	if eff == "cards_ultimate":
		turn_label.text = str(hero["name"]) + " attiva Scala Reale! +" + str(result["bonus_atk"]) + " ATK per 2 turni!"
	elif eff == "parunan_ultimate":
		turn_label.text = str(hero["name"]) + " attiva Pacchetto All-Inclusive su " + str(result["target_name"]) + ": applicati tutti i 3 investimenti!"
	elif eff == "parunan_ultimate_solo":
		turn_label.text = str(hero["name"]) + " attiva Pacchetto All-Inclusive in solitaria: curata al 100%!"

	_check_battle_end()
	_update_fighter_visuals()
	_refresh_target_options()
	_update_ui()


func _get_ready_ultimate_hero_id() -> String:
	if not active_hero_id.is_empty() and combat_manager.can_use_ultimate(active_hero_id):
		return active_hero_id

	for f in combat_manager.get_combatants():
		if str(f["team"]) == "hero" and bool(f["alive"]):
			if combat_manager.can_use_ultimate(str(f["id"])):
				return str(f["id"])

	return ""


func _perform_enemy_turn() -> void:
	if battle_over:
		waiting_for_enemy_turn = false
		_update_turn_indicator()
		return

	_update_turn_indicator()
	await get_tree().create_timer(0.45).timeout

	if battle_over:
		waiting_for_enemy_turn = false
		_update_turn_indicator()
		return

	var enemy: Dictionary = combat_manager.get_combatant(active_enemy_id)
	if enemy.is_empty() or not bool(enemy["alive"]):
		waiting_for_enemy_turn = false
		active_enemy_id = ""
		_update_turn_indicator()
		return

	var living_heroes: Array[Dictionary] = combat_manager.get_living_allies()
	if living_heroes.is_empty():
		waiting_for_enemy_turn = false
		_check_battle_end()
		_update_turn_indicator()
		return

	var target: Dictionary = {}
	if randf() < 0.7:
		var lowest_hp: int = 9999999
		for hero in living_heroes:
			var current_hp: int = int(hero["hp"])
			if current_hp < lowest_hp:
				lowest_hp = current_hp
				target = hero
	else:
		target = living_heroes.pick_random()

	var damage: int = maxi(1, int(enemy["atk"]) - int(target["def"]))
	var reduction: int = int(target.get("dmg_reduction_amount", 0))
	damage = maxi(1, damage - reduction)

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
	var living_allies: int = combat_manager.get_living_allies().size()
	var living_enemies: int = 0

	for f in combat_manager.get_combatants():
		if str(f["team"]) == "enemy" and bool(f["alive"]):
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

	for fighter in combat_manager.get_combatants():
		var team_label: String = "Alleato" if str(fighter["team"]) == "hero" else "Nemico"
		var hp_text: String = str(fighter["hp"]) + "/" + str(fighter["max_hp"])
		var extra_info: String = ""

		if str(fighter["id"]) == "hero_mimi":
			extra_info = " | Carte: " + str(combat_manager.get_cards("hero_mimi")) + "/7 (ATK: " + str(combat_manager.get_effective_atk("hero_mimi")) + ")"
		elif str(fighter["id"]) == "hero_parunan":
			extra_info = " | ATK: " + str(combat_manager.get_effective_atk("hero_parunan")) + " | DEF: " + str(combat_manager.get_effective_def("hero_parunan"))

		var fighter_line: String = team_label + " | " + str(fighter["name"]) + " | HP: " + hp_text + extra_info
		if not bool(fighter["alive"]):
			fighter_line += " | SCONFITTO"

		lines.append(fighter_line)

	status_label.text = "\n".join(lines)

	if turn_label != null and not battle_over:
		if waiting_for_hero_turn:
			turn_label.text = "Turno di " + active_hero_id + ": scegli un'azione."
		elif waiting_for_enemy_turn:
			turn_label.text = "Turno nemico..."
		else:
			turn_label.text = "Avanzamento del tempo..."

	var display_hero_id: String = active_hero_id
	if display_hero_id.is_empty():
		for f in combat_manager.get_living_allies():
			display_hero_id = str(f["id"])
			break

	if energy_label != null:
		if display_hero_id.is_empty():
			energy_label.text = "Energia: -- / 100"
		else:
			var cur_e: int = combat_manager.get_energy(display_hero_id)
			var h_name: String = str(combat_manager.get_combatant(display_hero_id).get("name", "Eroe"))
			energy_label.text = "Energia (" + h_name + "): " + str(cur_e) + " / " + str(combat_manager.MAX_ENERGY)

	if ultimate_button != null:
		var ready_h: String = _get_ready_ultimate_hero_id()
		ultimate_button.disabled = battle_over or ready_h.is_empty()

	_update_action_bars()
	_update_turn_indicator()
	_update_target_indicator()
	_update_target_info()
	_update_ally_info()


func _update_action_bars() -> void:
	if hero_bar == null or enemy_bar == null:
		return

	var hero: Dictionary = {}
	if not active_hero_id.is_empty():
		hero = combat_manager.get_combatant(active_hero_id)
	else:
		var living: Array[Dictionary] = combat_manager.get_living_allies()
		if not living.is_empty():
			hero = living[0]

	var enemy: Dictionary = {}
	for f in combat_manager.get_combatants():
		if str(f["team"]) == "enemy" and bool(f["alive"]):
			enemy = f
			break

	hero_bar.value = float(hero.get("action_bar", 0.0))
	enemy_bar.value = float(enemy.get("action_bar", 0.0))


func _update_turn_indicator() -> void:
	for f_id in turn_indicators.keys():
		var show: bool = false
		if waiting_for_hero_turn and f_id == active_hero_id:
			show = true
		elif waiting_for_enemy_turn and f_id == active_enemy_id:
			show = true
		turn_indicators[f_id].visible = show


func _update_target_indicator() -> void:
	for f_id in target_indicators.keys():
		target_indicators[f_id].visible = (f_id == selected_enemy_id)


func _update_target_info() -> void:
	if target_name_label == null:
		return

	var target: Dictionary = combat_manager.get_combatant(selected_enemy_id)
	if target.is_empty():
		target_name_label.text = "Nessun bersaglio"
		target_hp_label.text = "HP: -- / --"
		target_hp_bar.value = 0.0
		return

	target_name_label.text = str(target["name"])
	if bool(target["alive"]):
		target_hp_label.text = "HP: " + str(target["hp"]) + " / " + str(target["max_hp"])
	else:
		target_hp_label.text = "SCONFITTO"

	target_hp_bar.max_value = maxf(1.0, float(target["max_hp"]))
	target_hp_bar.value = float(target["hp"])


func _update_ally_info() -> void:
	for c_id in ally_hp_bars.keys():
		var fighter: Dictionary = combat_manager.get_combatant(c_id)
		if fighter.is_empty():
			continue

		var c_hp: int = int(fighter["hp"])
		var m_hp: int = int(fighter["max_hp"])
		var hp_label: Label = ally_hp_labels[c_id]
		var hp_bar: ProgressBar = ally_hp_bars[c_id]

		if bool(fighter["alive"]):
			hp_label.text = "HP: " + str(c_hp) + " / " + str(m_hp)
		else:
			hp_label.text = "SCONFITTO"

		hp_bar.max_value = maxf(1.0, float(m_hp))
		hp_bar.value = float(c_hp)


func _update_fighter_visuals() -> void:
	for f_id in fighter_meshes.keys():
		var fighter: Dictionary = combat_manager.get_combatant(f_id)
		var model: MeshInstance3D = fighter_meshes[f_id]
		if not is_instance_valid(model):
			continue

		if not bool(fighter["alive"]):
			model.scale = Vector3(0.75, 0.35, 0.75)
			model.position.y = 0.22
		else:
			model.scale = Vector3.ONE
			model.position.y = 0.78

		_update_fighter_hp_bar(f_id, fighter)

	_update_turn_indicator()
	_update_target_indicator()
	_update_target_info()
	_update_ally_info()


func _update_fighter_hp_bar(fighter_id: String, fighter: Dictionary) -> void:
	if not fighter_hp_fills.has(fighter_id):
		return

	var fill: MeshInstance3D = fighter_hp_fills[fighter_id]
	if not is_instance_valid(fill):
		return

	var max_hp: float = maxf(1.0, float(fighter["max_hp"]))
	var current_hp: float = clampf(float(fighter["hp"]), 0.0, max_hp)
	var ratio: float = current_hp / max_hp

	fill.scale.x = ratio
	fill.position.x = -(HP_BAR_WIDTH * (1.0 - ratio)) / 2.0
	fill.visible = bool(fighter["alive"])


func _on_restart_pressed() -> void:
	_reset_battle()
