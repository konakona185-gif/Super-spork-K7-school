
extends RefCounted
class_name CombatManager

const ACTION_BAR_MAX: float = 100.0

var combatants: Array[Dictionary] = []

func setup(hero_data: Dictionary, enemy_data: Dictionary) -> void:
	combatants.clear()
	_add_combatant(hero_data, "hero")
	_add_combatant(enemy_data, "enemy")

func _add_combatant(data: Dictionary, team: String) -> void:
	var stats: Dictionary = data["stats"]

	combatants.append({
		"id": str(data["id"]),
		"name": str(data["name"]),
		"team": team,
		"speed": maxf(1.0, float(stats.get("speed", 1))),
		"action_bar": 0.0,
		"hp": int(stats["hp"]),
		"alive": true
	})


func get_next_turn() -> Dictionary:
	if combatants.is_empty():
		return {}

	var selected_index := -1
	var best_time: float = INF

	for i in range(combatants.size()):
		var fighter: Dictionary = combatants[i]

		if not fighter["alive"]:
			continue

		var remaining: float = ACTION_BAR_MAX - float(fighter["action_bar"])
		var time_to_turn: float = remaining / float(fighter["speed"])

		if time_to_turn < best_time:
			best_time = time_to_turn
			selected_index = i

	if selected_index == -1:
		return {}

	for fighter in combatants:
		if fighter["alive"]:
			fighter["action_bar"] = minf(
				ACTION_BAR_MAX,
				float(fighter["action_bar"]) + float(fighter["speed"]) * best_time
			)

	var selected: Dictionary = combatants[selected_index]
	selected["action_bar"] = 0.0
	return selected

func set_hp(combatant_id: String, new_hp: int) -> void:
	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			fighter["hp"] = maxi(0, new_hp)
			fighter["alive"] = new_hp > 0
			return

func get_combatants() -> Array[Dictionary]:
	return combatants
