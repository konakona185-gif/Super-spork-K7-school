
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

	for fighter in combatants:
		if bool(fighter["alive"]) and float(fighter["action_bar"]) >= ACTION_BAR_MAX:
			return fighter

	return {}


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
