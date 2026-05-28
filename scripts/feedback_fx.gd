extends Node

const TEXT_LIFETIME := 0.9
const BURST_LIFETIME := 0.42


func spawn_hit_burst(world: Node, pos: Vector3, color: Color, amount: int = 9, strength: float = 1.0) -> void:
	if world == null:
		return
	var root := Node3D.new()
	root.name = &"HitBurstFx"
	root.global_position = pos
	world.add_child(root)

	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.18 * strength
	flash_mesh.height = 0.36 * strength
	flash.mesh = flash_mesh
	flash.set_surface_override_material(0, _make_fx_material(color.lightened(0.35), 0.85, 0.9))
	root.add_child(flash)
	var flash_tw := root.create_tween()
	flash_tw.tween_property(flash, "scale", Vector3.ONE * 2.6, 0.12)
	flash_tw.parallel().tween_property(flash, "transparency", 1.0, 0.12)

	for i in amount:
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s := randf_range(0.08, 0.18) * strength
		box.size = Vector3(s, s, s)
		shard.mesh = box
		shard.set_surface_override_material(0, _make_fx_material(color, 1.0, 0.25))
		root.add_child(shard)

		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.35, 1.25), randf_range(-1.0, 1.0)).normalized()
		var target := dir * randf_range(0.5, 1.2) * strength
		var tw := root.create_tween()
		tw.tween_property(shard, "position", target, BURST_LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(shard, "scale", Vector3.ZERO, BURST_LIFETIME)

	get_tree().create_timer(BURST_LIFETIME + 0.08).timeout.connect(root.queue_free, CONNECT_ONE_SHOT)


func spawn_floating_text(world: Node, pos: Vector3, text: String, color: Color) -> void:
	if world == null or text.is_empty():
		return
	var label := Label3D.new()
	label.name = &"FloatingTextFx"
	label.text = text
	label.font_size = 34
	label.outline_size = 8
	label.modulate = color
	label.outline_modulate = Color(0.02, 0.02, 0.04, 0.95)
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.global_position = pos + Vector3(randf_range(-0.18, 0.18), 0.0, randf_range(-0.18, 0.18))
	world.add_child(label)

	var tw := label.create_tween()
	tw.tween_property(label, "global_position", label.global_position + Vector3(0.0, 1.15, 0.0), TEXT_LIFETIME)
	tw.parallel().tween_property(label, "modulate:a", 0.0, TEXT_LIFETIME)
	tw.tween_callback(label.queue_free)


func show_wood_hit(world: Node, pos: Vector3) -> void:
	spawn_hit_burst(world, pos, Color(0.58, 0.34, 0.13), 10, 1.05)


func show_stone_hit(world: Node, pos: Vector3) -> void:
	spawn_hit_burst(world, pos, Color(0.62, 0.6, 0.56), 9, 0.95)


func show_ore_gain(world: Node, pos: Vector3, amount: int) -> void:
	if amount > 0:
		spawn_floating_text(world, pos, "+%d ore" % amount, Color(0.38, 0.92, 1.0))


func show_wood_gain(world: Node, pos: Vector3, amount: int) -> void:
	if amount > 0:
		spawn_floating_text(world, pos, "+%d wood" % amount, Color(0.72, 0.42, 0.16))


func show_coin_gain(world: Node, pos: Vector3, amount: int) -> void:
	if amount > 0:
		spawn_floating_text(world, pos, "+%d coins" % amount, Color(1.0, 0.82, 0.18))


func _make_fx_material(color: Color, alpha: float, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.roughness = 0.75
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = emission > 0.0
	mat.emission = color
	mat.emission_energy_multiplier = emission
	return mat
