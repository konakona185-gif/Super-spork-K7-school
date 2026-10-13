extends SceneTree

const CombatManagerScript = preload("res://scripts/combat_manager.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: int = 0

	var manager = CombatManagerScript.new()

	var party: Array = [
		{
			"id": "hero_001",
			"name": "Eroe test",
			"stats": {
				"hp": 100,
				"atk": 16,
				"def": 5,
				"speed": 100
			}
		}
	]

	var enemies: Array = [
		{
			"id": "enemy_001",
			"name": "Nemico test",
			"stats": {
				"hp": 60,
				"atk": 8,
				"def": 2,
				"speed": 50
			}
		}
	]

	manager.setup(party, enemies)

	if manager.get_combatants().size() != 2:
		failures += _fail("Inizializzazione combattenti")

	if manager.get_skill_points() != 3:
		failures += _fail("Punti abilità iniziali")

	if manager.get_combatant("hero_001").is_empty():
		failures += _fail("Ricerca dell'eroe")

	manager.advance_time(0.5)

	if not manager.get_ready_combatants().is_empty():
		failures += _fail("Nessun combattente deve essere pronto dopo 0,5 secondi")

	manager.advance_time(0.5)

	var ready: Array[Dictionary] = manager.get_ready_combatants()

	if ready.size() != 1:
		failures += _fail("Prontezza del combattente più veloce")
	elif str(ready[0]["id"]) != "hero_001":
		failures += _fail("Ordine di prontezza")

	var attack_result: Dictionary = manager.use_damage_ability(
		"hero_001",
		"enemy_001",
		"basic"
	)

	if not bool(attack_result.get("success", false)):
		failures += _fail("Attacco base")

	if int(manager.get_combatant("enemy_001")["hp"]) != 46:
		failures += _fail("Calcolo del danno dell'attacco base")

	if manager.get_energy("hero_001") != 20:
		failures += _fail("Recupero dell'energia")

	if manager.get_skill_points() != 4:
		failures += _fail("Recupero dei punti abilità")

	manager.set_hp("enemy_001", 0)

	if bool(manager.get_combatant("enemy_001")["alive"]):
		failures += _fail("Gestione della sconfitta")

	manager.set_hp("hero_001", 200)

	if int(manager.get_combatant("hero_001")["hp"]) != 100:
		failures += _fail("Limite massimo dei punti vita")

	if failures == 0:
		print("TEST COMBAT MANAGER: TUTTI I TEST SUPERATI")
		quit(0)
	else:
		push_error("TEST COMBAT MANAGER: %d TEST FALLITI" % failures)
		quit(1)


func _fail(test_name: String) -> int:
	push_error("TEST FALLITO: " + test_name)
	return 1
