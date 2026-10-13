
extends Node3D

const HERO_MAX_HP: int = 100
const ENEMY_MAX_HP: int = 60

var hero_hp: int = HERO_MAX_HP
var enemy_hp: int = ENEMY_MAX_HP
var battle_over: bool = false
var rng := RandomNumberGenerator.new()

var status_label: Label
var attack_button: Button
var restart_button: Button
var hero_mesh: MeshInstance3D
var enemy_mesh: MeshInstance3D

func _ready() -> void:
	rng.randomize()
	_build_arena()
	_build_ui()
	_update_ui()

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
	panel.custom_minimum_size = Vector2(320, 0)
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

	attack_button = Button.new()
	attack_button.text = "Attacca"
	attack_button.pressed.connect(_on_attack_pressed)
	layout.add_child(attack_button)

	restart_button = Button.new()
	restart_button.text = "Ricomincia"
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.visible = false
	layout.add_child(restart_button)

func _update_ui() -> void:
	status_label.text = "EROE: %d / %d HP\nNEMICO: %d / %d HP" % [
		hero_hp, HERO_MAX_HP, enemy_hp, ENEMY_MAX_HP
	]

	if hero_hp <= 0:
		status_label.text += "\n\nSCONFITTA!"
	elif enemy_hp <= 0:
		status_label.text += "\n\nVITTORIA!"
	elif battle_over:
		status_label.text += "\n\nBattaglia terminata."

	attack_button.visible = not battle_over
	restart_button.visible = battle_over

func _on_attack_pressed() -> void:
	if battle_over:
		return

	var hero_damage := rng.randi_range(12, 20)
	enemy_hp = max(0, enemy_hp - hero_damage)

	if enemy_hp <= 0:
		battle_over = true
		_update_ui()
		return

	var enemy_damage := rng.randi_range(5, 12)
	hero_hp = max(0, hero_hp - enemy_damage)

	if hero_hp <= 0:
		battle_over = true

	_update_ui()

func _on_restart_pressed() -> void:
	hero_hp = HERO_MAX_HP
	enemy_hp = ENEMY_MAX_HP
	battle_over = false
	_update_ui()
