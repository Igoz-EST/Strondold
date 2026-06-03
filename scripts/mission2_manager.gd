## Mission 2 initializer — runs only in GAME_MODE_MISSION_2.
## Registers designer-placed nodes into groups so the rest of
## the gameplay code (wave_manager, enemy) can find them.
## Does NOT modify any Mission 1 or Endless Mode nodes.
extends Node3D


func _ready() -> void:
	if GameState.game_mode != GameState.GAME_MODE_MISSION_2:
		return
	_init_mission2()


func _init_mission2() -> void:
	# h_terrain.tscn is instanced as "Terrain" (sibling of this node)
	var terrain: Node3D = get_parent().get_node_or_null("Terrain") as Node3D
	if terrain == null:
		push_error("Mission2Manager: 'Terrain' node not found. Is h_terrain.tscn in main2.tscn?")
		return

	var base_spawn:  Node3D = terrain.get_node_or_null("BaseSpawn")  as Node3D
	var enemy_spawn: Node3D = terrain.get_node_or_null("EnemySpawn") as Node3D
	var enemy_path:  Path3D = _find_path(terrain)

	if base_spawn  == null: push_error("Mission2Manager: BaseSpawn not found in Terrain")
	if enemy_spawn == null: push_error("Mission2Manager: EnemySpawn not found in Terrain")
	if enemy_path  == null: push_error("Mission2Manager: Path3D not found in Terrain")

	# ── Swap enemy_spawn group to the designer's node ─────────────────────────
	for n in get_tree().get_nodes_in_group(&"enemy_spawn"):
		n.remove_from_group(&"enemy_spawn")
	if enemy_spawn != null:
		enemy_spawn.add_to_group(&"enemy_spawn")

	# ── Register enemy path so wave_manager can assign it to enemies ──────────
	if enemy_path != null:
		enemy_path.add_to_group(&"m2_enemy_path")

	# ── Move the fortress Base to the designer-placed BaseSpawn ───────────────
	if base_spawn != null:
		var root := get_parent()
		var base: Node3D = root.get_node_or_null("Base") as Node3D
		if base != null:
			base.global_position = base_spawn.global_position
		# Also move the player's start position to the base area
		var exterior: Node3D = root.get_node_or_null("ExteriorSpawn") as Node3D
		if exterior != null:
			exterior.global_position = base_spawn.global_position + Vector3(0.0, 0.55, -10.0)

	print("Mission2Manager: OK — spawn=", enemy_spawn != null,
		"  path=", enemy_path != null, "  base=", base_spawn != null)


func _find_path(parent: Node) -> Path3D:
	var n := parent.get_node_or_null("Path3D") as Path3D
	if n != null:
		return n
	for c in parent.get_children():
		if c is Path3D:
			return c as Path3D
	return null
