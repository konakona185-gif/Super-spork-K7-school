extends RefCounted
class_name CombatManager

const ACTION_BAR_MAX: float = 100.0

var combatants: Array[Dictionary] = []


func setup(party_data: Array, enemies_data: Array) -> void:
	combatants.clear()

	for character in party_data:
		_add_combatant(character, "hero")

	for enemy in enemies_data:
		_add_combatant(enemy, "enemy")


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

	# Velocità decrescente; a parità mantiene l'ordine originale.
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


func get_combatant(combatant_id: String) -> Dictionary:
	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			return fighter

	return {}


func get_combatants() -> Array[Dictionary]:
	return combatants
