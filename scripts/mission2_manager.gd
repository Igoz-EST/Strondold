## Mission 2 Manager — runs only in GAME_MODE_MISSION_2.
## Registers designer nodes into groups and repositions gameplay nodes
## so the fortress sits on the HTerrain exactly as it does on the flat
## ground in Mission 1.
##
## Mission 1 reference layout (terrain Y = 0):
##   Base origin       Y = 3.0   (podium bottom lands at Y=0)
##   InteriorFloor     Y = 1.5
##   BaseCommandZone   Y = 0.0   (sphere trigger at ground level)
##   InteriorSpawn    (0, 2.1, 0) — inside the keep
##   ExteriorSpawn   (14, 0.5, 0) — in front of the gate (gate faces world +X)
##
## For Mission 2 every offset is applied on top of the actual terrain Y
## at the relevant XZ position.
extends Node3D

# Vertical offsets that mirror Mission 1's base layout.
const _BASE_ABOVE_TERRAIN    := 3.0   # base origin above terrain
const _FLOOR_ABOVE_TERRAIN   := 1.5   # interior floor above terrain
const _SPAWN_ABOVE_TERRAIN   := 0.5   # ExteriorSpawn / marker height above terrain

var _base_xz := Vector2(250.95, 369.29)   # fallback; overwritten from BaseSpawn


func _ready() -> void:
	if GameState.game_mode != GameState.GAME_MODE_MISSION_2:
		return
	_setup_groups()
	_rough_place()          # synchronous — fixes InteriorSpawn before deferred player teleport
	call_deferred(&"_snap_to_terrain")


# ── 1. Groups ─────────────────────────────────────────────────────────────────

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
	# HTerrain must be in "terrain" group so _commander_ground_hit accepts it
	if terrain != null:
		terrain.add_to_group(&"terrain")


# ── 2. Rough placement (synchronous) ─────────────────────────────────────────
# Uses approximate Y values matching Mission 1 offsets (terrain Y ≈ 0 here).
# _snap_to_terrain will correct to exact surface height.

func _rough_place() -> void:
	var root := get_parent()
	var bx := _base_xz.x
	var bz := _base_xz.y

	_set_pos(root, "Base",             Vector3(bx, _BASE_ABOVE_TERRAIN,  bz))
	_set_pos(root, "InteriorFloor",    Vector3(bx, _FLOOR_ABOVE_TERRAIN, bz))
	_set_pos(root, "BaseCommandZone",  Vector3(bx, 0.0,                  bz))
	# InteriorSpawn: placed synchronously so _start_game_in_commander (deferred)
	# teleports the player into the keep rather than the scene-default (0,2.1,0).
	_set_pos(root, "InteriorSpawn",    Vector3(bx, 2.1, bz))
	# ExteriorSpawn: gate faces world +X (same rotation as M1)
	_set_pos(root, "ExteriorSpawn",    Vector3(bx + 14.0, _SPAWN_ABOVE_TERRAIN, bz))


# ── 3. Terrain snap (deferred — PhysicsDirectSpaceState ready) ───────────────

func _snap_to_terrain() -> void:
	var root := get_parent()
	var bx   := _base_xz.x
	var bz   := _base_xz.y

	var ty_base := _terrain_y(Vector3(bx, 0.0, bz))

	# Base: origin sits _BASE_ABOVE_TERRAIN units above the terrain surface.
	# This exactly replicates M1's Y=3 when terrain Y=0.
	_set_pos(root, "Base",            Vector3(bx, ty_base + _BASE_ABOVE_TERRAIN,  bz))
	_set_pos(root, "InteriorFloor",   Vector3(bx, ty_base + _FLOOR_ABOVE_TERRAIN, bz))
	# CommandZone at terrain level so the trigger sphere sits around the base entrance
	_set_pos(root, "BaseCommandZone", Vector3(bx, ty_base,                         bz))
	# InteriorSpawn inside the keep (M1: 2.1 above terrain)
	_set_pos(root, "InteriorSpawn",   Vector3(bx, ty_base + 2.1,                  bz))

	# ExteriorSpawn: in front of the gate — gate faces world +X (after 90° Y rotation)
	var ext_xz := Vector3(bx + 14.0, 0.0, bz)
	_set_pos(root, "ExteriorSpawn",
		Vector3(ext_xz.x, _terrain_y(ext_xz) + _SPAWN_ABOVE_TERRAIN, ext_xz.z))

	# Service spawns
	var svc := {
		"WorkerSpawn": Vector3(bx + 6.0,  0.0, bz - 6.0),
		"OreDeposit":  Vector3(bx + 18.0, 0.0, bz - 10.0),
	}
	for n_name in svc:
		var xz: Vector3 = svc[n_name]
		_set_pos(root, n_name, Vector3(xz.x, _terrain_y(xz) + _SPAWN_ABOVE_TERRAIN, xz.z))

	print("Mission2Manager snap: base_origin_y=%.2f  terrain_y=%.2f" \
		% [ty_base + _BASE_ABOVE_TERRAIN, ty_base])


# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_pos(root: Node, n_name: String, pos: Vector3) -> void:
	var n: Node3D = root.get_node_or_null(n_name) as Node3D
	if n != null:
		n.global_position = pos


## Downward raycast on collision_mask = 1 (HTerrain layer).
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
