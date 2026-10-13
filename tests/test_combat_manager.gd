extends SceneTree

const CombatManagerScript = preload("res://scripts/combat_manager.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: int = 0
	var manager = _create_manager()

	if manager.get_combatants().size() != 2:
		failures += _fail("Inizializzazione combattenti")

	if manager.get_skill_points() != 3:
		failures += _fail("Punti abilita iniziali")

	if manager.get_combatant("hero_001").is_empty():
		failures += _fail("Ricerca dell'eroe")

	manager.advance_time(0.5)

	if not manager.get_ready_combatants().is_empty():
		failures += _fail("Nessun combattente pronto dopo 0,5 secondi")

	manager.advance_time(0.5)

	var ready: Array[Dictionary] = manager.get_ready_combatants()

	if ready.size() != 1:
		failures += _fail("Prontezza del combattente piu veloce")
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
		failures += _fail("Danno dell'attacco base")

	if manager.get_energy("hero_001") != 20:
		failures += _fail("Recupero energia dell'attacco base")

	if manager.get_skill_points() != 4:
		failures += _fail("Recupero punti abilita dell'attacco base")

	var skill_result: Dictionary = manager.use_damage_ability(
		"hero_001",
		"enemy_001",
		"skill"
	)

	if not bool(skill_result.get("success", false)):
		failures += _fail("Uso dell'abilita speciale")

	if int(manager.get_combatant("enemy_001")["hp"]) != 21:
		failures += _fail("Danno dell'abilita speciale")

	if manager.get_skill_points() != 3:
		failures += _fail("Costo in punti abilita della skill")

	if manager.get_energy("hero_001") != 50:
		failures += _fail("Energia ottenuta dalla skill")

	var invalid_result: Dictionary = manager.use_damage_ability(
		"hero_001",
		"hero_001",
		"basic"
	)

	if bool(invalid_result.get("success", false)):
		failures += _fail("Rifiuto di un bersaglio alleato")

	if int(manager.get_combatant("hero_001")["hp"]) != 100:
		failures += _fail("Un attacco non valido non danneggia l'alleato")

	manager.set_hp("enemy_001", 0)

	if bool(manager.get_combatant("enemy_001")["alive"]):
		failures += _fail("Gestione della sconfitta")

	manager.set_hp("hero_001", 200)

	if int(manager.get_combatant("hero_001")["hp"]) != 100:
		failures += _fail("Limite massimo dei punti vita")

	failures += _test_ultimate()
	failures += _test_passive()

	if failures == 0:
		print("TEST COMBAT MANAGER: TUTTI I TEST SUPERATI")
		quit(0)
	else:
		push_error("TEST COMBAT MANAGER: %d TEST FALLITI" % failures)
		quit(1)


func _test_ultimate() -> int:
	var failures: int = 0
	var manager = _create_manager()

	manager.add_energy("hero_001", 99)

	if manager.can_use_ultimate("hero_001"):
		failures += _fail("Ultimate non disponibile con 99 energia")

	var failed_result: Dictionary = manager.use_damage_ability(
		"hero_001",
		"enemy_001",
		"ultimate"
	)

	if bool(failed_result.get("success", false)):
		failures += _fail("Rifiuto dell'Ultimate senza energia sufficiente")

	if manager.get_energy("hero_001") != 99:
		failures += _fail("Energia conservata dopo Ultimate rifiutata")

	if int(manager.get_combatant("enemy_001")["hp"]) != 60:
		failures += _fail("Nessun danno da Ultimate rifiutata")

	manager.add_energy("hero_001", 1)

	if not manager.can_use_ultimate("hero_001"):
		failures += _fail("Ultimate disponibile con 100 energia")

	var result: Dictionary = manager.use_damage_ability(
		"hero_001",
		"enemy_001",
		"ultimate"
	)

	if not bool(result.get("success", false)):
		failures += _fail("Uso dell'Ultimate con energia sufficiente")
	else:
		if int(result.get("damage", 0)) != 42:
			failures += _fail("Danno dell'Ultimate")

	if manager.get_energy("hero_001") != 0:
		failures += _fail("Consumo dell'energia dell'Ultimate")

	if int(manager.get_combatant("enemy_001")["hp"]) != 18:
		failures += _fail("Punti vita dopo l'Ultimate")

	return failures


func _test_passive() -> int:
	var failures: int = 0
	var manager = _create_manager()

	manager.set_hp("hero_001", 50)

	var result: Dictionary = manager.use_damage_ability(
		"hero_001",
		"enemy_001",
		"basic"
	)

	if not bool(result.get("success", false)):
		failures += _fail("Attacco con passiva attiva")
	elif int(result.get("damage", 0)) != 18:
		failures += _fail("Bonus danno della passiva al 50% HP")

	return failures


func _create_manager():
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
	return manager


func _fail(test_name: String) -> int:
	push_error("TEST FALLITO: " + test_name)
	return 1
