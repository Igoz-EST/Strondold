## House — даёт +5 к лимиту населения (бонус начисляется в GameState.try_place_tower).
extends StaticBody3D


func _ready() -> void:
	add_to_group(&"house")
