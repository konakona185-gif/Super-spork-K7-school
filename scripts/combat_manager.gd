
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


func advance_time(delta: float) -> Dictionary:
	if delta <= 0.0 or combatants.is_empty():
		return {}

	for fighter in combatants:
		if not bool(fighter["alive"]):
			continue

		var current_bar: float = float(fighter["action_bar"])
		var speed: float = float(fighter["speed"])

		fighter["action_bar"] = minf(
			ACTION_BAR_MAX,
			current_bar + speed * delta
		)

	return get_next_ready_combatant()


func get_next_ready_combatant() -> Dictionary:
	var ready_fighter: Dictionary = {}

	for fighter in combatants:
		if not bool(fighter["alive"]):
			continue

		if float(fighter["action_bar"]) < ACTION_BAR_MAX:
			continue

		if ready_fighter.is_empty():
			ready_fighter = fighter
		elif float(fighter["action_bar"]) > float(ready_fighter["action_bar"]):
			ready_fighter = fighter

	return ready_fighter


func reset_action_bar(combatant_id: String) -> void:
	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			fighter["action_bar"] = 0.0
			return


func set_hp(combatant_id: String, new_hp: int) -> void:
	for fighter in combatants:
		if str(fighter["id"]) == combatant_id:
			fighter["hp"] = maxi(0, new_hp)
			fighter["alive"] = new_hp > 0
			return


func get_combatants() -> Array[Dictionary]:
	return combatants
