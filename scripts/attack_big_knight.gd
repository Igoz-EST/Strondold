extends "res://scripts/attack_knight.gd"

## Attack-tab Big Knight — same knight model as the barracks Lv2 warrior
## (azure_sentinel) but scaled up, with proportionally more HP and damage.
## Marches and fights (and assaults the enemy base in Mission 3) exactly like
## the normal attack Knight — only the size and stats differ.

const _BIG_SCALE   := 1.7
const _HP_MULT     := 3
const _DAMAGE_MULT := 2


func _ready() -> void:
	super._ready()
	add_to_group(&"attack_big_knight")
	max_hp = MAX_HP * _HP_MULT
	hp = max_hp
	melee_damage = MELEE_DAMAGE * _DAMAGE_MULT
	scale = Vector3.ONE * _BIG_SCALE
	if is_instance_valid(_hp_bar) and _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)
