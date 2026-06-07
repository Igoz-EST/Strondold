## Market — passively generates coins on a per-level interval.
extends StaticBody3D

const _INTERVAL_BY_LEVEL: Array[float] = [0.0, 7.5, 5.0, 2.5]

var upgrade_level := 1

var _timer: Timer


func _ready() -> void:
	add_to_group(&"market_building")
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	apply_upgrade_level(int(get_meta(&"market_level", 1)))


func apply_upgrade_level(level: int) -> void:
	upgrade_level = clampi(level, 1, 3)
	set_meta(&"market_level", upgrade_level)
	_timer.wait_time = _INTERVAL_BY_LEVEL[upgrade_level]
	_timer.start()
	var factory := load("res://scripts/market_scene.gd")
	factory.add_level_visuals(self, upgrade_level)


func _on_timeout() -> void:
	GameState.add_coin()
