extends StaticBody3D

const FIRE_RANGE := 42.0
const FIRE_INTERVAL := 1.05
const PROJECTILE_DAMAGE := 14

const _ProjectileScript := preload("res://scripts/tower_projectile.gd")

var _fire_cd: float = 0.0


func _ready() -> void:
	_fire_cd = randf_range(0.0, FIRE_INTERVAL * 0.6)


func _physics_process(delta: float) -> void:
	_fire_cd -= delta
	if _fire_cd > 0.0:
		return
	var tgt := _pick_nearest_enemy()
	if tgt == null:
		return
	_fire_cd = FIRE_INTERVAL
	_launch_at(tgt)


func _pick_nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d2 := FIRE_RANGE * FIRE_RANGE
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
	var aim := target.global_position + Vector3(0.0, 0.65, 0.0)

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
		prj.call(&"setup", muzzle, aim, PROJECTILE_DAMAGE)
