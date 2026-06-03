## Mission 2 Manager — runs only in GAME_MODE_MISSION_2.
## Registers designer nodes into groups and repositions gameplay nodes
## to match the designer-placed terrain markers.
extends Node3D

const _SURFACE_LIFT := 0.15

var _base_xz := Vector2(250.95, 369.29)


func _ready() -> void:
	if GameState.game_mode != GameState.GAME_MODE_MISSION_2:
		return
	_setup_groups()
	_rough_place()
	call_deferred(&"_snap_to_terrain")


func _setup_groups() -> void:
	var terrain: Node3D = get_parent().get_node_or_null("Terrain") as Node3D
	if terrain == null:
		push_error("Mission2Manager: 'Terrain' node not found")
		return

	var base_spawn:  Node3D = terrain.get_node_or_null("BaseSpawn")  as Node3D
	var enemy_spawn: Node3D = terrain.get_node_or_null("EnemySpawn") as Node3D
	var enemy_path:  Path3D = _find_path(terrain)

	if base_spawn  == null: push_error("Mission2Manager: BaseSpawn not found")
	if enemy_spawn == null: push_error("Mission2Manager: EnemySpawn not found")
	if enemy_path  == null: push_error("Mission2Manager: Path3D not found")

	for n in get_tree().get_nodes_in_group(&"enemy_spawn"):
		n.remove_from_group(&"enemy_spawn")
	if enemy_spawn != null:
		enemy_spawn.add_to_group(&"enemy_spawn")
	if enemy_path != null:
		enemy_path.add_to_group(&"m2_enemy_path")
	if base_spawn != null:
		_base_xz = Vector2(base_spawn.global_position.x, base_spawn.global_position.z)


func _rough_place() -> void:
	var root  := get_parent()
	var rough := Vector3(_base_xz.x, 0.0, _base_xz.y)
	for n_name in ["Base", "InteriorFloor", "BaseCommandZone"]:
		var n: Node3D = root.get_node_or_null(n_name) as Node3D
		if n != null:
			n.global_position = rough
	var ext: Node3D = root.get_node_or_null("ExteriorSpawn") as Node3D
	if ext != null:
		ext.global_position = rough + Vector3(0.0, 0.55, -10.0)


func _snap_to_terrain() -> void:
	var root   := get_parent()
	var base_y := _terrain_y(Vector3(_base_xz.x, 0.0, _base_xz.y))
	var final  := Vector3(_base_xz.x, base_y + _SURFACE_LIFT, _base_xz.y)

	for n_name in ["Base", "InteriorFloor", "BaseCommandZone"]:
		var n: Node3D = root.get_node_or_null(n_name) as Node3D
		if n != null:
			n.global_position = final

	var offsets := {
		"ExteriorSpawn": Vector3(  0.0, 0.0, -10.0),
		"WorkerSpawn":   Vector3(  6.0, 0.0,  -6.0),
		"OreDeposit":    Vector3( 18.0, 0.0, -10.0),
		"InteriorSpawn": Vector3(  0.0, 0.0,   2.0),
	}
	for n_name in offsets:
		var off: Vector3 = offsets[n_name]
		var xz := Vector3(_base_xz.x + off.x, 0.0, _base_xz.y + off.z)
		var gy := _terrain_y(xz)
		var m: Node3D = root.get_node_or_null(n_name) as Node3D
		if m != null:
			m.global_position = Vector3(xz.x, gy + 0.55, xz.z)

	print("Mission2Manager: base Y=%.2f (terrain=%.2f)" % [final.y, base_y])


func _terrain_y(at_xz: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var query  := PhysicsRayQueryParameters3D.create(
		Vector3(at_xz.x, 500.0, at_xz.z),
		Vector3(at_xz.x, -50.0, at_xz.z),
		1
	)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	return hit.position.y if hit else 0.0


func _find_path(parent: Node) -> Path3D:
	var n := parent.get_node_or_null("Path3D") as Path3D
	if n != null:
		return n
	for c in parent.get_children():
		if c is Path3D:
			return c as Path3D
	return null
