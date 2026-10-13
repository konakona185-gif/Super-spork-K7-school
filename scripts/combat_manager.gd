extends RefCounted
class_name CombatManager

const ACTION_BAR_MAX: float = 100.0
const ABILITY_DATA_PATH: String = "res://data/abilities.json"
const MAX_SKILL_POINTS: int = 5
const STARTING_SKILL_POINTS: int = 3
const MAX_ENERGY: int = 100

var combatants: Array[Dictionary] = []
var abilities: Array[Dictionary] = []
var skill_points: int = STARTING_SKILL_POINTS


func setup(party_data: Array, enemies_data: Array) -> void:
	combatants.clear()
	skill_points = STARTING_SKILL_POINTS
	_load_ability_data()

	for character in party_data:
		_add_combatant(character, "hero")

	for enemy in enemies_data:
		_add_combatant(enemy, "enemy")


func _load_ability_data() -> void:
	abilities.clear()

	if not FileAccess.file_exists(ABILITY_DATA_PATH):
		push_error("File delle abilità non trovato: " + ABILITY_DATA_PATH)
		return

	var file: FileAccess = FileAccess.open(
		ABILITY_DATA_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error("Impossibile aprire il file delle abilità.")
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)

	if parse_result != OK:
		push_error(
			"Errore nel JSON delle abilità: "
			+ json.get_error_message()
		)
		return

	var data: Variant = json.data

	if not data is Dictionary:
		push_error("Il file delle abilità deve contenere un oggetto.")
		return

	var root_data: Dictionary = data

	if not root_data.has("abilities"):
		push_error("Il JSON delle abilità deve contenere abilities.")
		return

	if not root_data["abilities"] is Array:
		push_error("Il campo abilities deve essere un array.")
		return

	var used_ids: Dictionary = {}
	var valid_types: Array[String] = [
		"basic",
		"skill",
		"passive",
		"ultimate"
	]

	for ability_variant in root_data["abilities"]:
		if not ability_variant is Dictionary:
			push_error("Ogni abilità deve essere un oggetto JSON.")
			abilities.clear()
			return

		var ability: Dictionary = ability_variant

		for required_field in [
			"id",
			"character_id",
			"name",
			"type",
			"effect"
		]:
			if not ability.has(required_field):
				push_error(
					"Manca il campo obbligatorio in un'abilità: "
					+ required_field
				)
				abilities.clear()
				return

		var ability_id: String = str(ability["id"])

		if ability_id.is_empty() or used_ids.has(ability_id):
			push_error(
				"Gli ID delle abilità devono essere univoci e non vuoti."
			)
			abilities.clear()
			return

		used_ids[ability_id] = true

		if str(ability["character_id"]).is_empty():
			push_error("Un'abilità ha un character_id vuoto.")
			abilities.clear()
			return

		if not valid_types.has(str(ability["type"])):
			push_error(
				"Tipo di abilità non valido: "
				+ str(ability["type"])
			)
			abilities.clear()
			return

		if ability.has("power"):
			if not (
				ability["power"] is int
				or ability["power"] is float
			):
				push_error(
					"Il campo power deve essere numerico: "
					+ ability_id
				)
				abilities.clear()
				return

			if float(ability["power"]) < 0.0:
				push_error(
					"Il campo power non può essere negativo: "
					+ ability_id
				)
				abilities.clear()
				return

		abilities.append(ability)

	print(
		"Caricate ",
		abilities.size(),
		" abilità dal file JSON."
	)


func get_abilities_for_character(
	character_id: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for ability in abilities:
		if str(ability["character_id"]) == character_id:
			result.append(ability)

	return result


func get_skill_points() -> int:
	return skill_points


func can_spend_skill_points(amount: int) -> bool:
	return amount >= 0 and skill_points >= amount


func spend_skill_points(amount: int) -> bool:
	if not can_spend_skill_points(amount):
		return false

	skill_points -= amount
	return true


func restore_skill_points(amount: int) -> void:
	if amount <= 0:
		return

	skill_points = mini(
		MAX_SKILL_POINTS,
		skill_points + amount
	)


func get_energy(combatant_id: String) -> int:
	var fighter: Dictionary = get_combatant(combatant_id)

	if fighter.is_empty():
		return 0

	return int(fighter.get("energy", 0))


func add_energy(combatant_id: String, amount: int) -> void:
	if amount <= 0:
		return

	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			fighter["energy"] = mini(
				MAX_ENERGY,
				int(fighter.get("energy", 0)) + amount
			)
			return


func can_use_ultimate(combatant_id: String) -> bool:
	var fighter: Dictionary = get_combatant(combatant_id)

	if fighter.is_empty():
		return false

	return (
		bool(fighter["alive"])
		and int(fighter.get("energy", 0)) >= MAX_ENERGY
	)


func spend_ultimate_energy(combatant_id: String) -> bool:
	if not can_use_ultimate(combatant_id):
		return false

	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			fighter["energy"] = 0
			return true

	return false


func _add_combatant(data: Dictionary, team: String) -> void:
	var stats: Dictionary = data["stats"]

	combatants.append({
		"id": str(data["id"]),
		"name": str(data["name"]),
		"team": team,
		"role": str(data.get("role", "DPS")),
		"scaling": data.get("scaling", ["ATK"]),
		"speed": maxf(1.0, float(stats.get("speed", 1))),
		"action_bar": 0.0,
		"hp": int(stats["hp"]),
		"max_hp": int(stats["hp"]),
		"atk": int(stats["atk"]),
		"def": int(stats.get("def", 0)),
		"energy": 0,
		"alive": true
	})


func advance_time(delta: float) -> Array[Dictionary]:
	if delta > 0.0:
		for fighter in combatants:
			if not bool(fighter["alive"]):
				continue

			var current_bar: float = float(fighter["action_bar"])
			var speed: float = float(fighter["speed"])

			fighter["action_bar"] = minf(
				ACTION_BAR_MAX,
				current_bar + speed * delta
			)

	return get_ready_combatants()


func get_ready_combatants() -> Array[Dictionary]:
	var ready: Array[Dictionary] = []

	for fighter in combatants:
		if not bool(fighter["alive"]):
			continue

		if float(fighter["action_bar"]) >= ACTION_BAR_MAX:
			ready.append(fighter)

	for i in range(1, ready.size()):
		var current: Dictionary = ready[i]
		var j: int = i - 1

		while j >= 0:
			var previous: Dictionary = ready[j]

			if float(previous["speed"]) >= float(current["speed"]):
				break

			ready[j + 1] = previous
			j -= 1

		ready[j + 1] = current

	return ready


func reset_action_bar(combatant_id: String) -> void:
	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			fighter["action_bar"] = 0.0
			return


func set_hp(combatant_id: String, new_hp: int) -> void:
	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			fighter["hp"] = clampi(
				new_hp,
				0,
				int(fighter["max_hp"])
			)
			fighter["alive"] = fighter["hp"] > 0
			return


func get_combatant(combatant_id: String) -> Dictionary:
	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			return fighter

	return {}


func get_combatants() -> Array[Dictionary]:
	return combatants
