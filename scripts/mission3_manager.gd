extends "res://scripts/mission2_manager.gd"

## Mission 3 — base assault. Reuses Mission 2's terrain/base placement (inherited)
## and additionally spawns the enemy base at the enemy end of the path.
## Waves are disabled in Mission 3 (see wave_manager.gd); the enemy base streams
## units continuously instead.

const _EnemyBaseFactory := preload("res://scripts/enemy_base_scene.gd")


func _ready() -> void:
	if GameState.game_mode != GameState.GAME_MODE_MISSION_3:
		return
	_setup_groups()      # inherited: registers enemy_spawn / m2_enemy_path / terrain
	_rough_place()       # inherited: rough player-base placement
	call_deferred(&"_finish_m3")


func _finish_m3() -> void:
	_snap_to_terrain()   # inherited: snaps player base + spawns to terrain
	_spawn_enemy_base()


func _spawn_enemy_base() -> void:
	var spawn := get_tree().get_first_node_in_group(&"enemy_spawn") as Node3D
	if spawn == null:
		push_error("Mission3Manager: enemy_spawn not found — cannot place enemy base")
		return
	var sx := spawn.global_position.x
	var sz := spawn.global_position.z
	# Offset the base a few units behind the spawn (away from the player base) so
	# units spawn in front of it instead of inside its collider.
	var to_player := Vector2(_base_xz.x - sx, _base_xz.y - sz)
	if to_player.length() < 0.01:
		to_player = Vector2(0.0, -1.0)
	to_player = to_player.normalized()
	var bx := sx - to_player.x * 7.0
	var bz := sz - to_player.y * 7.0
	var ty := _terrain_y(Vector3(bx, 0.0, bz))

	var base := _EnemyBaseFactory.create_enemy_base()
	get_parent().add_child(base)
	base.global_position = Vector3(bx, ty + 0.6, bz)
	print("Mission3Manager: enemy base at %s" % base.global_position)
