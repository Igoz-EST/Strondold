extends "res://scripts/giant_warrior.gd"

## Purchased Giant Warrior (100 coins, Attack tab) — identical to the
## companion Giant Warrior in every way except death does not clear
## GameState.has_giant_warrior: that flag tracks the persistent companion
## only, while purchased reinforcements are expendable and repurchasable.

func apply_sword_hit(damage: int = 10, _attacker: Node = null) -> void:
	hp -= damage
	if is_instance_valid(_hp_bar) and _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)
	if hp <= 0:
		SoundManager.play_npc_death()
		set_physics_process(false)
		if _duel_enemy != null and is_instance_valid(_duel_enemy) and _duel_enemy.has_method(&"notify_ally_destroyed"):
			_duel_enemy.call(&"notify_ally_destroyed", self)
		if not _gw_play(_GW_ANIM_DEATH, false):
			_gw_death_fall()
		get_tree().create_timer(0.7).timeout.connect(queue_free)
	else:
		SoundManager.play_one_shot(SoundManager.KEY_SHIELD_HIT)
		_gw_play(_GW_ANIM_HIT, false)
