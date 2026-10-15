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

	var used_ids: Dictionary = {}

	for character in party_data:
		var error_message: String = _get_combatant_data_error(character, used_ids)
		if not error_message.is_empty():
			push_error("Dati eroe non validi: " + error_message)
			combatants.clear()
			return

	for enemy in enemies_data:
		var error_message: String = _get_combatant_data_error(enemy, used_ids)
		if not error_message.is_empty():
			push_error("Dati nemico non validi: " + error_message)
			combatants.clear()
			return

	_load_ability_data()

	for character in party_data:
		_add_combatant(character, "hero")

	for enemy in enemies_data:
		_add_combatant(enemy, "enemy")


func _get_combatant_data_error(data: Variant, used_ids: Dictionary) -> String:
	if not data is Dictionary:
		return "Il combattente deve essere un oggetto."

	var combatant_data: Dictionary = data

	if not combatant_data.has("id") or str(combatant_data["id"]).strip_edges().is_empty():
		return "ID mancante o vuoto."

	if not combatant_data.has("name") or str(combatant_data["name"]).strip_edges().is_empty():
		return "Nome mancante o vuoto."

	if not combatant_data.has("stats") or not combatant_data["stats"] is Dictionary:
		return "Statistiche mancanti o non valide."

	var stats: Dictionary = combatant_data["stats"]

	if not stats.has("hp") or not stats.has("atk"):
		return "Le statistiche hp e atk sono obbligatorie."

	if not stats["hp"] is int or int(stats["hp"]) <= 0:
		return "HP deve essere un intero maggiore di zero."

	if not stats["atk"] is int or int(stats["atk"]) < 0:
		return "ATK deve essere un intero non negativo."

	if stats.has("def"):
		if not stats["def"] is int or int(stats["def"]) < 0:
			return "DEF deve essere un intero non negativo."

	if stats.has("speed"):
		if not (stats["speed"] is int or stats["speed"] is float):
			return "Speed deve essere un numero."

		if float(stats["speed"]) <= 0.0:
			return "Speed deve essere maggiore di zero."

	var combatant_id: String = str(combatant_data["id"])

	if used_ids.has(combatant_id):
		return "ID combattente duplicato: " + combatant_id

	used_ids[combatant_id] = true
	return ""


func _load_ability_data() -> void:
	abilities.clear()

	if not FileAccess.file_exists(ABILITY_DATA_PATH):
		push_error("File delle abilità non trovato: " + ABILITY_DATA_PATH)
		return

	var file: FileAccess = FileAccess.open(ABILITY_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Impossibile aprire il file delle abilità.")
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)

	if parse_result != OK:
		push_error("Errore nel JSON delle abilità: " + json.get_error_message())
		return

	var data: Variant = json.data
	if not data is Dictionary or not data.has("abilities") or not data["abilities"] is Array:
		push_error("Struttura abilità non valida.")
		return

	for ability_variant in data["abilities"]:
		if ability_variant is Dictionary:
			abilities.append(ability_variant)


func _add_combatant(data: Dictionary, team: String) -> void:
	var stats: Dictionary = data["stats"]
	var f_id: String = str(data["id"])

	combatants.append({
		"id": f_id,
		"name": str(data["name"]),
		"team": team,
		"role": str(data.get("role", "DPS")),
		"scaling": data.get("scaling", ["ATK"]),
		"speed": maxf(1.0, float(stats.get("speed", 1))),
		"action_bar": 0.0,
		"base_hp": int(stats["hp"]),
		"hp": int(stats["hp"]),
		"max_hp": int(stats["hp"]),
		"base_atk": int(stats["atk"]),
		"atk": int(stats["atk"]),
		"base_def": int(stats.get("def", 0)),
		"def": int(stats.get("def", 0)),
		"energy": 0,
		"alive": true,
		"cards": 4 if f_id == "hero_mimi" else 0,
		"turns_taken": 0,
		"pending_cards": 0,
		"consumed_cards_for_ult": 0,
		"atk_buff_amount": 0,
		"atk_buff_duration": 0,
		"dmg_reduction_amount": 0,
		"dmg_reduction_duration": 0,
		"max_hp_buff_amount": 0,
		"max_hp_buff_duration": 0
	})


func on_turn_start(combatant_id: String) -> void:
	var fighter: Dictionary = get_combatant(combatant_id)
	if fighter.is_empty() or not bool(fighter["alive"]):
		return

	if fighter.get("atk_buff_duration", 0) > 0:
		fighter["atk_buff_duration"] -= 1
		if fighter["atk_buff_duration"] == 0:
			fighter["atk_buff_amount"] = 0

	if fighter.get("dmg_reduction_duration", 0) > 0:
		fighter["dmg_reduction_duration"] -= 1
		if fighter["dmg_reduction_duration"] == 0:
			fighter["dmg_reduction_amount"] = 0

	if fighter.get("max_hp_buff_duration", 0) > 0:
		fighter["max_hp_buff_duration"] -= 1
		if fighter["max_hp_buff_duration"] == 0:
			fighter["max_hp"] = int(fighter["base_hp"])
			fighter["max_hp_buff_amount"] = 0
			fighter["hp"] = mini(int(fighter["hp"]), int(fighter["max_hp"]))

	if str(fighter["id"]) == "hero_mimi":
		var pending: int = int(fighter.get("pending_cards", 0))
		if pending > 0:
			fighter["cards"] = mini(7, int(fighter.get("cards", 0)) + pending)
			fighter["pending_cards"] = 0

		fighter["turns_taken"] = int(fighter.get("turns_taken", 0)) + 1
		if int(fighter["turns_taken"]) % 2 == 0:
			fighter["cards"] = mini(7, int(fighter.get("cards", 0)) + 1)


func get_effective_atk(combatant_id: String) -> int:
	var fighter: Dictionary = get_combatant(combatant_id)
	if fighter.is_empty():
		return 0
	return int(fighter["atk"]) + int(fighter.get("atk_buff_amount", 0))


func get_effective_def(combatant_id: String) -> int:
	var fighter: Dictionary = get_combatant(combatant_id)
	if fighter.is_empty():
		return 0
	return int(fighter["def"])


func get_cards(combatant_id: String) -> int:
	var fighter: Dictionary = get_combatant(combatant_id)
	return int(fighter.get("cards", 0)) if not fighter.is_empty() else 0


func advance_time(delta: float) -> Array[Dictionary]:
	if delta > 0.0:
		for fighter in combatants:
			if not bool(fighter["alive"]):
				continue

			var current_bar: float = float(fighter["action_bar"])
			var speed: float = float(fighter["speed"])

			fighter["action_bar"] = minf(ACTION_BAR_MAX, current_bar + speed * delta)

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
			fighter["hp"] = clampi(new_hp, 0, int(fighter["max_hp"]))
			fighter["alive"] = fighter["hp"] > 0
			return


func heal_hp(combatant_id: String, amount: int) -> void:
	for fighter in combatants:
		if str(fighter["id"]) == combatant_id and bool(fighter["alive"]):
			fighter["hp"] = mini(int(fighter["max_hp"]), int(fighter["hp"]) + amount)
			return


func get_combatant(combatant_id: String) -> Dictionary:
	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			return fighter

	return {}


func get_combatants() -> Array[Dictionary]:
	return combatants


func get_living_allies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for f in combatants:
		if str(f["team"]) == "hero" and bool(f["alive"]):
			result.append(f)
	return result


func get_abilities_for_character(character_id: String) -> Array[Dictionary]:
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

	skill_points = mini(MAX_SKILL_POINTS, skill_points + amount)


func get_energy(combatant_id: String) -> int:
	var fighter: Dictionary = get_combatant(combatant_id)
	return int(fighter.get("energy", 0)) if not fighter.is_empty() else 0


func add_energy(combatant_id: String, amount: int) -> void:
	if amount <= 0:
		return

	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			fighter["energy"] = mini(MAX_ENERGY, int(fighter.get("energy", 0)) + amount)
			return


func can_use_ultimate(combatant_id: String) -> bool:
	var fighter: Dictionary = get_combatant(combatant_id)
	if fighter.is_empty():
		return false

	return bool(fighter["alive"]) and int(fighter.get("energy", 0)) >= MAX_ENERGY


func spend_ultimate_energy(combatant_id: String) -> bool:
	if not can_use_ultimate(combatant_id):
		return false

	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			fighter["energy"] = 0
			return true

	return false


func _check_parunan_passive_def(parunan: Dictionary) -> bool:
	var parunan_def: int = int(parunan["base_def"])
	for ally in get_living_allies():
		if str(ally["id"]) != str(parunan["id"]):
			if int(ally["base_def"]) >= parunan_def:
				return false
	return true


func _apply_atk_buff(target_id: String, amount: int, duration: int) -> void:
	for f in combatants:
		if str(f["id"]) == target_id:
			f["atk_buff_amount"] = amount
			f["atk_buff_duration"] = duration
			return


func _apply_dmg_reduction_buff(target_id: String, amount: int, duration: int) -> void:
	for f in combatants:
		if str(f["id"]) == target_id:
			f["dmg_reduction_amount"] = amount
			f["dmg_reduction_duration"] = duration
			return


func _apply_max_hp_buff_and_heal(target_id: String, hp_bonus: int, heal_ratio: float, duration: int) -> void:
	for f in combatants:
		if str(f["id"]) == target_id:
			f["max_hp"] = int(f["base_hp"]) + hp_bonus
			f["max_hp_buff_amount"] = hp_bonus
			f["max_hp_buff_duration"] = duration
			var heal_amount: int = maxi(1, roundi(float(f["max_hp"]) * heal_ratio))
			heal_hp(target_id, heal_amount)
			return


func use_ability_by_id(attacker_id: String, target_id: String, ability_id: String) -> Dictionary:
	var attacker: Dictionary = get_combatant(attacker_id)
	if attacker.is_empty() or not bool(attacker["alive"]):
		return {"success": false, "message": "Combattente non valido."}

	var selected_ability: Dictionary = {}
	for ab in abilities:
		if str(ab.get("id", "")) == ability_id:
			selected_ability = ab
			break

	if selected_ability.is_empty():
		return {"success": false, "message": "Abilità non trovata."}

	var effect: String = str(selected_ability.get("effect", "damage"))
	var ability_type: String = str(selected_ability.get("type", "basic"))

	if effect == "cards_shuffle":
		var current_cards: int = int(attacker.get("cards", 0))
		attacker["cards"] = 0
		attacker["pending_cards"] = int(floor(float(current_cards) / 2.0)) + 1
		attacker["consumed_cards_for_ult"] = current_cards

		add_energy(attacker_id, int(selected_ability.get("energy_gain", 0)))
		reset_action_bar(attacker_id)

		return {
			"success": true,
			"ability_name": str(selected_ability["name"]),
			"effect_type": "cards_shuffle",
			"consumed": current_cards,
			"pending": attacker["pending_cards"]
		}

	if effect == "cards_ultimate":
		if not can_use_ultimate(attacker_id):
			return {"success": false, "message": "Energia insufficiente per l'Ultimate."}

		spend_ultimate_energy(attacker_id)
		var bonus: int = int(attacker.get("consumed_cards_for_ult", 0))
		_apply_atk_buff(attacker_id, bonus, 2)

		return {
			"success": true,
			"ability_name": str(selected_ability["name"]),
			"effect_type": "cards_ultimate",
			"bonus_atk": bonus
		}

	if effect == "buff_atk":
		var living_allies: Array[Dictionary] = get_living_allies()
		var is_solo: bool = living_allies.size() == 1
		var applies_to_self: bool = _check_parunan_passive_def(attacker)

		var best_ally: Dictionary = living_allies[0]
		for ally in living_allies:
			if get_effective_atk(str(ally["id"])) > get_effective_atk(str(best_ally["id"])):
				best_ally = ally

		var atk_bonus: int = 6 if is_solo else 3
		var duration: int = 2 if is_solo else 1

		_apply_atk_buff(str(best_ally["id"]), atk_bonus, duration)
		if applies_to_self and not is_solo and str(best_ally["id"]) != attacker_id:
			_apply_atk_buff(attacker_id, atk_bonus, duration)

		add_energy(attacker_id, int(selected_ability.get("energy_gain", 0)))
		reset_action_bar(attacker_id)

		return {
			"success": true,
			"ability_name": str(selected_ability["name"]),
			"effect_type": "buff_atk",
			"target_name": str(best_ally["name"]),
			"amount": atk_bonus,
			"duration": duration,
			"applied_to_self": applies_to_self and not is_solo
		}

	if effect == "buff_dmg_reduction":
		var living_allies: Array[Dictionary] = get_living_allies()
		var is_solo: bool = living_allies.size() == 1
		var applies_to_self: bool = _check_parunan_passive_def(attacker)

		var best_ally: Dictionary = living_allies[0]
		for ally in living_allies:
			if get_effective_def(str(ally["id"])) < get_effective_def(str(best_ally["id"])):
				best_ally = ally

		var reduction: int = 2 if is_solo else 1
		var duration: int = 2 if is_solo else 1

		_apply_dmg_reduction_buff(str(best_ally["id"]), reduction, duration)
		if applies_to_self and not is_solo and str(best_ally["id"]) != attacker_id:
			_apply_dmg_reduction_buff(attacker_id, reduction, duration)

		add_energy(attacker_id, int(selected_ability.get("energy_gain", 0)))
		reset_action_bar(attacker_id)

		return {
			"success": true,
			"ability_name": str(selected_ability["name"]),
			"effect_type": "buff_dmg_reduction",
			"target_name": str(best_ally["name"]),
			"amount": reduction,
			"duration": duration,
			"applied_to_self": applies_to_self and not is_solo
		}

	if effect == "buff_max_hp_and_heal":
		var living_allies: Array[Dictionary] = get_living_allies()
		var is_solo: bool = living_allies.size() == 1
		var applies_to_self: bool = _check_parunan_passive_def(attacker)

		var best_ally: Dictionary = living_allies[0]
		for ally in living_allies:
			if int(ally["hp"]) < int(best_ally["hp"]):
				best_ally = ally

		var hp_bonus: int = 6 if is_solo else 3
		var heal_ratio: float = 0.6 if is_solo else 0.3
		var duration: int = 2 if is_solo else 1

		_apply_max_hp_buff_and_heal(str(best_ally["id"]), hp_bonus, heal_ratio, duration)
		if applies_to_self and not is_solo and str(best_ally["id"]) != attacker_id:
			_apply_max_hp_buff_and_heal(attacker_id, hp_bonus, heal_ratio, duration)

		add_energy(attacker_id, int(selected_ability.get("energy_gain", 0)))
		reset_action_bar(attacker_id)

		return {
			"success": true,
			"ability_name": str(selected_ability["name"]),
			"effect_type": "buff_max_hp_and_heal",
			"target_name": str(best_ally["name"]),
			"amount": hp_bonus,
			"duration": duration,
			"applied_to_self": applies_to_self and not is_solo
		}

	if effect == "parunan_ultimate":
		if not can_use_ultimate(attacker_id):
			return {"success": false, "message": "Energia insufficiente per l'Ultimate."}

		spend_ultimate_energy(attacker_id)
		var living_allies: Array[Dictionary] = get_living_allies()

		if living_allies.size() == 1:
			heal_hp(attacker_id, int(attacker["max_hp"]))
			return {
				"success": true,
				"ability_name": str(selected_ability["name"]),
				"effect_type": "parunan_ultimate_solo",
				"target_name": str(attacker["name"])
			}

		var other_target_id: String = ""
		for ally in living_allies:
			if str(ally["id"]) != attacker_id:
				other_target_id = str(ally["id"])
				break

		_apply_atk_buff(other_target_id, 3, 1)
		_apply_dmg_reduction_buff(other_target_id, 1, 1)
		_apply_max_hp_buff_and_heal(other_target_id, 3, 0.3, 1)

		var other_combatant = get_combatant(other_target_id)
		return {
			"success": true,
			"ability_name": str(selected_ability["name"]),
			"effect_type": "parunan_ultimate",
			"target_name": str(other_combatant.get("name", "Alleato"))
		}

	var target: Dictionary = get_combatant(target_id)
	if target.is_empty() or not bool(target["alive"]):
		return {"success": false, "message": "Bersaglio non valido."}

	if str(attacker["team"]) == str(target["team"]):
		return {"success": false, "message": "Non puoi colpire un alleato."}

	var power: float = float(selected_ability.get("power", 1.0))
	var effective_atk: int = get_effective_atk(attacker_id)
	var raw_damage: float = maxf(1.0, float(effective_atk) - float(target["def"]))
	var damage: int = maxi(1, roundi(raw_damage * power))

	var reduction: int = int(target.get("dmg_reduction_amount", 0))
	damage = maxi(1, damage - reduction)

	set_hp(target_id, int(target["hp"]) - damage)

	var energy_gain: int = int(selected_ability.get("energy_gain", 0))
	add_energy(attacker_id, energy_gain)

	if ability_type == "basic":
		restore_skill_points(1)

	if ability_type != "ultimate":
		reset_action_bar(attacker_id)

	return {
		"success": true,
		"ability_name": str(selected_ability["name"]),
		"damage": damage,
		"target_name": str(target["name"]),
		"effect_type": "damage"
	}
