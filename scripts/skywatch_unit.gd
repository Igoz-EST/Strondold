## Skywatch Tower — attacks ONLY enemies in group "flying_enemy".
## Ignores all ground enemies.
extends StaticBody3D

const BASE_FIRE_RANGE    := 33.6   # 28.0 * 1.2 — 20% larger than standard tower
const BASE_FIRE_INTERVAL := 1.05   # same as standard tower
const BASE_DAMAGE        := 14     # same as standard tower

const _ProjectileScript := preload("res://scripts/tower_projectile.gd")

var _fire_cd:     float = 0.0
var upgrade_level := 1


func _ready() -> void:
	add_to_group(&"tower")
	add_to_group(&"skywatch_tower")
	_fire_cd = randf_range(0.0, BASE_FIRE_INTERVAL * 0.6)


func _physics_process(delta: float) -> void:
	_fire_cd -= delta
	if _fire_cd > 0.0: return
	var tgt := _pick_flying_enemy()
	if tgt == null: return
	_fire_cd = BASE_FIRE_INTERVAL
	_launch_at(tgt)


func _pick_flying_enemy() -> Node3D:
	var best: Node3D = null
	var best_d2 := BASE_FIRE_RANGE * BASE_FIRE_RANGE
	var p := global_position
	for n in get_tree().get_nodes_in_group(&"flying_enemy"):
		if not (n is Node3D) or not is_instance_valid(n): continue
		var d2 := p.distance_squared_to((n as Node3D).global_position)
		if d2 < best_d2: best_d2 = d2; best = n as Node3D
	return best


func _launch_at(target: Node3D) -> void:
	var world := get_tree().get_first_node_in_group(&"main_world")
	if world == null: return
	var muzzle := global_position + Vector3(0.0, 9.8, 0.0)

	var prj := Area3D.new()
	prj.collision_layer = 1024
	prj.collision_mask  = 256
	prj.monitoring    = true
	prj.monitorable   = false

	var col := CollisionShape3D.new()
	var sp  := SphereShape3D.new()
	sp.radius = 0.32
	col.shape = sp
	prj.add_child(col)

	var mesh := MeshInstance3D.new()
	var sm   := SphereMesh.new()
	sm.radius = 0.28; sm.height = 0.56
	mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color             = Color(0.38, 0.62, 1.0)
	mat.emission_enabled         = true
	mat.emission                 = Color(0.22, 0.45, 0.95)
	mat.emission_energy_multiplier = 1.2
	mat.roughness                = 0.28
	mesh.set_surface_override_material(0, mat)
	prj.add_child(mesh)

	prj.set_script(_ProjectileScript)
	world.add_child(prj)
	if prj.has_method(&"setup"):
		prj.call(&"setup", muzzle, target, BASE_DAMAGE, 0, 0.0, 0)
