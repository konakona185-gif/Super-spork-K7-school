extends Node3D

var hero_hp: int = 100
var enemy_hp: int = 60
var hero_turn: bool = true

var status_label: Label
var attack_button: Button
var restart_button: Button

func _ready() -> void:
	_build_arena()
	_build_ui()
	_update_ui()

func _build_arena() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.1

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.20, 0.25)
	floor_mesh.material_override = material
	add_child(floor_mesh)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 7, 10)
	camera.look_at(Vector3(0, 0, 0))
	add_child(camera)

	_create_fighter(Vector3(-2, 0.8, 0), Color(0.2, 0.55, 1.0))
	_create_fighter(Vector3(2, 0.8, 0), Color(1.0, 0.25, 0.2))

func _create_fighter(pos: Vector3, tint: Color) -> void:
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

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := VBoxContainer.new()
	panel.position = Vector2(20, 20)
	panel.add_theme_constant_override("separation", 10)
	layer.add_child(panel)

	var title := Label.new()
	title.text = "ENDLESS ARENA"
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)

	status_label = Label.new()
	panel.add_child(status_label)

	attack_button = Button.new()
	attack_button.text = "Attacca"
	attack_button.pressed.connect(_on_attack_pressed)
	panel.add_child(attack_button)

	restart_button = Button.new()
	restart_button.text = "Ricomincia"
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.visible = false
	panel.add_child(restart_button)

func _update_ui() -> void:
	status_label.text = "Eroe: %d HP\nNemico: %d HP" % [hero_hp, enemy_hp]

	if hero_hp <= 0:
		status_label.text += "\nSconfitta!"
		attack_button.visible = false
		restart_button.visible = true
	elif enemy_hp <= 0:
		status_label.text += "\nVittoria!"
		attack_button.visible = false
		restart_button.visible = true
	else:
		attack_button.visible = hero_turn
		restart_button.visible = false

func _on_attack_pressed() -> void:
	if not hero_turn or hero_hp <= 0 or enemy_hp <= 0:
		return

	enemy_hp = max(0, enemy_hp - randi_range(12, 20))

	if enemy_hp > 0:
		hero_turn = false
		enemy_hp = max(0, enemy_hp)
		hero_hp = max(0, hero_hp - randi_range(5, 12))
		hero_turn = true

	_update_ui()

func _on_restart_pressed() -> void:
	hero_hp = 100
	enemy_hp = 60
	hero_turn = true
	_update_ui()
