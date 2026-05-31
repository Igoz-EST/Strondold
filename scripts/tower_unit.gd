extends StaticBody3D

const BASE_FIRE_RANGE := 28.0
const BASE_FIRE_INTERVAL := 1.05
const BASE_PROJECTILE_DAMAGE := 14
const SPLASH_RADIUS := 5.5

const _ProjectileScript := preload("res://scripts/tower_projectile.gd")

var _fire_cd: float = 0.0
var fire_range := BASE_FIRE_RANGE
var fire_interval := BASE_FIRE_INTERVAL
var projectile_damage := BASE_PROJECTILE_DAMAGE
var splash_damage := 0
var splash_radius := 0.0
var upgrade_level := 1


func _ready() -> void:
	add_to_group(&"tower")
	apply_upgrade_level(int(get_meta(&"tower_level", 1)))
	_fire_cd = randf_range(0.0, fire_interval * 0.6)


func apply_upgrade_level(level: int) -> void:
	upgrade_level = clampi(level, 1, 3)
	set_meta(&"tower_level", upgrade_level)
	fire_range = BASE_FIRE_RANGE
	fire_interval = BASE_FIRE_INTERVAL
	var multiplier := 1.0
	var splash_fraction := 0.0
	if upgrade_level == 2:
		multiplier = 1.25
		splash_fraction = 0.25
	elif upgrade_level == 3:
		multiplier = 1.75
		splash_fraction = 0.5
	projectile_damage = maxi(1, int(round(float(BASE_PROJECTILE_DAMAGE) * multiplier)))
	splash_damage = int(round(float(projectile_damage) * splash_fraction))
	splash_radius = SPLASH_RADIUS if splash_damage > 0 else 0.0
	var factory := load("res://scripts/tower_scene.gd")
	factory.add_level_visuals(self, upgrade_level)


func _physics_process(delta: float) -> void:
	_fire_cd -= delta
	if _fire_cd > 0.0:
		return
	var tgt := _pick_nearest_enemy()
	if tgt == null:
		return
	_fire_cd = fire_interval
	_launch_at(tgt)


func _pick_nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d2 := fire_range * fire_range
	var p := global_position
	for n in get_tree().get_nodes_in_group(&"enemy"):
		if not (n is Node3D) or not is_instance_valid(n):
			continue
		var nd := n as Node3D
		var d2 := p.distance_squared_to(nd.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = nd
	return best


func _launch_at(target: Node3D) -> void:
	var world := get_tree().get_first_node_in_group(&"main_world")
	if world == null:
		return
	var muzzle := global_position + Vector3(0.0, 5.65, 0.0)

	var prj := Area3D.new()
	prj.collision_layer = 1024
	prj.collision_mask = 256
	prj.monitoring = true
	prj.monitorable = false

	var col := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.32
	col.shape = sp
	prj.add_child(col)

	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.88, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.08)
	mat.emission_energy_multiplier = 1.1
	mat.roughness = 0.35
	mesh.set_surface_override_material(0, mat)
	prj.add_child(mesh)

	prj.set_script(_ProjectileScript)
	world.add_child(prj)
	if prj.has_method(&"setup"):
		prj.call(&"setup", muzzle, target, projectile_damage, splash_damage, splash_radius)
