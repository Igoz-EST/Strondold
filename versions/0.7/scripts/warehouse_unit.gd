extends StaticBody3D

## Локальная точка разгрузки (дверь, сторона +Z).
const UNLOAD_LOCAL := Vector3(0.0, 0.45, 1.95)


func _ready() -> void:
	add_to_group(&"warehouse")


func get_unload_anchor_global() -> Vector3:
	return global_transform * UNLOAD_LOCAL
