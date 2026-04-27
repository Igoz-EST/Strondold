extends Area3D

const SPEED := 64.0
const LIFETIME_SEC := 8.0

var _vel: Vector3 = Vector3.ZERO
var _damage: int = 12
var _life: float = LIFETIME_SEC


func setup(from: Vector3, aim_point: Vector3, damage: int) -> void:
	global_position = from
	_damage = damage
	var d := aim_point - from
	if d.length_squared() < 0.0001:
		d = Vector3.FORWARD
	_vel = d.normalized() * SPEED
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.has_method(&"apply_sword_hit"):
		body.call(&"apply_sword_hit", _damage)
	queue_free()


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	global_position += _vel * delta
