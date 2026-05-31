extends Area3D

const SPEED := 64.0
const LIFETIME_SEC := 8.0
const HIT_DISTANCE := 0.75

var _vel: Vector3 = Vector3.ZERO
var _target: Node3D = null
var _damage: int = 12
var _splash_damage: int = 0
var _splash_radius: float = 0.0
var _life: float = LIFETIME_SEC
var _damage_type: int = 0   # 0 = PHYSICAL, 1 = MAGIC  (matches enemy.gd DamageType)


func setup(from: Vector3, target: Node3D, damage: int, splash_damage: int = 0,
		splash_radius: float = 0.0, damage_type: int = 0) -> void:
	global_position = from
	_target       = target
	_damage       = damage
	_splash_damage = splash_damage
	_splash_radius = splash_radius
	_damage_type   = damage_type
	_update_velocity()
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.has_method(&"apply_sword_hit"):
		body.call(&"apply_sword_hit", _damage, self, _damage_type)
		_apply_splash(body)
	queue_free()


func _hit_target() -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	if _target.has_method(&"apply_sword_hit"):
		_target.call(&"apply_sword_hit", _damage, self, _damage_type)
		_apply_splash(_target)
	queue_free()


func _apply_splash(direct_body: Node3D) -> void:
	if _splash_damage <= 0 or _splash_radius <= 0.0:
		return
	var r2 := _splash_radius * _splash_radius
	for n in get_tree().get_nodes_in_group(&"enemy"):
		if not (n is Node3D) or not is_instance_valid(n) or n == direct_body:
			continue
		var enemy := n as Node3D
		if global_position.distance_squared_to(enemy.global_position) > r2:
			continue
		if enemy.has_method(&"apply_sword_hit"):
			enemy.call(&"apply_sword_hit", _splash_damage, self, _damage_type)


func _update_velocity() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var aim := _target.global_position + Vector3(0.0, 0.65, 0.0)
	var d := aim - global_position
	if d.length_squared() < 0.0001:
		d = Vector3.FORWARD
	_vel = d.normalized() * SPEED


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	_update_velocity()
	var aim := _target.global_position + Vector3(0.0, 0.65, 0.0)
	if global_position.distance_to(aim) <= HIT_DISTANCE:
		_hit_target()
		return
	global_position += _vel * delta
