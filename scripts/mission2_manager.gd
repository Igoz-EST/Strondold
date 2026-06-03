## Mission 2 Manager — runs only in GAME_MODE_MISSION_2.
## Removes all Mission 1 terrain nodes before the first frame renders,
## registers designer nodes into groups, and repositions the Base onto
## the HTerrain surface via a deferred raycast.
extends Node3D

const _SURFACE_LIFT := 0.15   # Base sits this many units above terrain hit point

# All node names in main.tscn that belong to Mission 1 terrain only.
# These are removed before the first render so nothing from M1 is visible.
const _M1_TERRAIN_NAMES: Array[StringName] = [
	&"WorldBuilder", &"Ground", &"TerrainExtra",
	&"Hill1",  &"Hill2",  &"Hill3",  &"Hill4",  &"Hill5",  &"Hill6",
	&"Hill7",  &"Hill8",  &"Hill9",  &"Hill10", &"Hill11",
]

var _base_pos := Vector3(250.95, 0.0, 369.29)  # fallback until raycast runs


func _ready() -> void:
	if GameState.game_mode != GameState.GAME_MODE_MISSION_2:
		return
	_remove_m1_terrain()
	_setup_groups()
	# Rough placement at Y=0 now; snapped to real terrain height next frame
	_rough_place_nodes()
	call_deferred(&"_snap_base_to_terrain")


# ── Step 1: remove all Mission 1 visual/collision content ─────────────────────

func _remove_m1_terrain() -> void:
	var root := get_parent()

	# Named nodes
	for n_name in _M1_TERRAIN_NAMES:
		var n := root.get_node_or_null(n_name)
		if n == null:
			continue
		# Hide instantly so it never appears in frame 0
		if n is Node3D:
			(n as Node3D).visible = false
		if n is StaticBody3D:
			(n as StaticBody3D).collision_layer = 0
			(n as StaticBody3D).collision_mask  = 0
		n.queue_free()

	# Direct children whose names start with M1-specific prefixes:
	# Tree1-25, Rock1-25, "Lowpoly Tree Sample*", "Root scene*"
	for child in root.get_children():
		var cn := String(child.name)
		if cn.begins_with("Tree") or cn.begins_with("Rock") \
		   or cn.begins_with("Lowpoly") or cn.begins_with("Root scene"):
			if child is Node3D:
				(child as Node3D).visible = false
			if child is StaticBody3D:
				(child as StaticBody3D).collision_layer = 0
				(child as StaticBody3D).collision_mask  = 0
			child.queue_free()


# ── Step 2: register designer nodes into groups ───────────────────────────────

func _setup_groups() -> void:
	var terrain: Node3D = get_parent().get_node_or_null("Terrain") as Node3D
	if terrain == null:
		push_error("Mission2Manager: 'Terrain' node not found in scene")
		return

	var enemy_spawn: Node3D = terrain.get_node_or_null("EnemySpawn") as Node3D
	var enemy_path:  Path3D = _find_path(terrain)
	var base_spawn:  Node3D = terrain.get_node_or_null("BaseSpawn")  as Node3D

	if enemy_spawn == null: push_error("Mission2Manager: EnemySpawn not found")
	if enemy_path  == null: push_error("Mission2Manager: Path3D not found")
	if base_spawn  == null: push_error("Mission2Manager: BaseSpawn not found")

	# Replace main.tscn's EnemySpawn with the terrain's EnemySpawn
	for n in get_tree().get_nodes_in_group(&"enemy_spawn"):
		n.remove_from_group(&"enemy_spawn")
	if enemy_spawn != null:
		enemy_spawn.add_to_group(&"enemy_spawn")

	if enemy_path != null:
		enemy_path.add_to_group(&"m2_enemy_path")

	if base_spawn != null:
		_base_pos = base_spawn.global_position


# ── Step 3: rough placement (Y=0) before raycast ──────────────────────────────

func _rough_place_nodes() -> void:
	var root  := get_parent()
	var rough := Vector3(_base_pos.x, 0.0, _base_pos.z)
	for n_name in [&"Base", &"InteriorFloor", &"BaseCommandZone"]:
		var n: Node3D = root.get_node_or_null(n_name) as Node3D
		if n != null:
			n.global_position = rough

	# Move player start near base
	var ext: Node3D = root.get_node_or_null("ExteriorSpawn") as Node3D
	if ext != null:
		ext.global_position = rough + Vector3(0.0, 0.55, -10.0)


# ── Step 4 (deferred): raycast down onto HTerrain to get real surface Y ───────

func _snap_base_to_terrain() -> void:
	var root   := get_parent()
	var base_y := _terrain_y(Vector3(_base_pos.x, 0.0, _base_pos.z))

	var final_pos := Vector3(_base_pos.x, base_y + _SURFACE_LIFT, _base_pos.z)
	for n_name in [&"Base", &"InteriorFloor", &"BaseCommandZone"]:
		var n: Node3D = root.get_node_or_null(n_name) as Node3D
		if n != null:
			n.global_position = final_pos

	# Spawn markers slightly above surface
	var marker_offsets := {
		&"ExteriorSpawn": Vector3(  0.0, 0.0, -10.0),
		&"WorkerSpawn":   Vector3(  6.0, 0.0,  -6.0),
		&"OreDeposit":    Vector3( 18.0, 0.0, -10.0),
		&"InteriorSpawn": Vector3(  0.0, 0.0,   2.0),
	}
	for n_name in marker_offsets:
		var off: Vector3 = marker_offsets[n_name]
		var xz   := Vector3(_base_pos.x + off.x, 0.0, _base_pos.z + off.z)
		var surf := _terrain_y(xz)
		var m: Node3D = root.get_node_or_null(n_name) as Node3D
		if m != null:
			m.global_position = Vector3(xz.x, surf + 0.55, xz.z)

	print("Mission2Manager: base Y = %.2f (terrain=%.2f)" % [final_pos.y, base_y])


## Downward raycast on collision_mask=1 (HTerrain) to find surface height.
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
