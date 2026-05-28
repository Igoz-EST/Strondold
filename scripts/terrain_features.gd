extends Node3D

## Visual-only terrain decoration.
## The existing Ground mesh, collision, and building placement logic stay unchanged.

const TERRAIN_SEED := 64123
const MAP_HALF := 144.0
const DETAIL_HALF := 118.0

const GROUND_TEXTURE_SIZE := 512
const base_color := Color(0.32, 0.55, 0.38)
const dark_color := Color(0.24, 0.42, 0.30)
const light_color := Color(0.42, 0.65, 0.48)
const dirt_color := Color(0.38, 0.33, 0.22)

const TINT_PATCH_COUNT := 34
const DIRT_PATCH_COUNT := 8
const ROCK_COUNT := 22
const GRASS_COUNT := 48

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _object_points: Array[Vector2] = []
var _dirt_centers: Array[Vector2] = []


func _ready() -> void:
	_rng.seed = TERRAIN_SEED
	_setup_noise()
	call_deferred(&"_apply_visuals")


func _apply_visuals() -> void:
	_collect_structure_points()
	_apply_ground_material()
	_apply_build_radius_overlay()
	_add_flat_patches()
	_add_sparse_props()
	queue_free()


func _setup_noise() -> void:
	_noise.seed = TERRAIN_SEED
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.010
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 2
	_noise.fractal_gain = 0.25

	_detail_noise.seed = TERRAIN_SEED + 117
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.055
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail_noise.fractal_octaves = 1


func _collect_structure_points() -> void:
	_object_points.clear()
	_dirt_centers.clear()

	_add_object_point(Vector3.ZERO)
	_add_object_point(Vector3(14.0, 0.0, 0.0))
	_add_object_point(Vector3(10.0, 0.0, 9.5))
	_dirt_centers.append(Vector2.ZERO)
	_dirt_centers.append(Vector2(14.0, 0.0))

	var tree := get_tree()
	if tree == null:
		return
	for mine in tree.get_nodes_in_group(&"mine"):
		if mine is Node3D:
			_add_object_point((mine as Node3D).global_position)
			_dirt_centers.append(Vector2((mine as Node3D).global_position.x, (mine as Node3D).global_position.z))
	for breakable in tree.get_nodes_in_group(&"breakable"):
		if breakable is Node3D:
			_add_object_point((breakable as Node3D).global_position)


func _add_object_point(pos: Vector3) -> void:
	_object_points.append(Vector2(pos.x, pos.z))


func _apply_ground_material() -> void:
	var world := get_parent()
	if world == null:
		return

	var texture := _make_ground_texture()
	for node in world.get_children():
		if node is StaticBody3D and node.is_in_group(&"terrain"):
			_apply_terrain_material_to_meshes(node, texture)


func _apply_terrain_material_to_meshes(node: Node, texture: Texture2D) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.set_surface_override_material(0, _terrain_material(texture))
	for child in node.get_children():
		_apply_terrain_material_to_meshes(child, texture)


func _terrain_material(texture: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.albedo_texture = texture
	mat.emission_enabled = false
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	return mat


func _apply_build_radius_overlay() -> void:
	var world := get_parent()
	if world == null:
		return
	var circle := world.get_node_or_null("ExteriorSpawn/PlayerSpawnZoneVisual") as MeshInstance3D
	if circle == null:
		return

	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled;

uniform vec4 indicator_color : source_color = vec4(0.42, 0.65, 0.48, 0.28);
uniform float edge_softness = 0.24;
uniform float pulse_strength = 0.08;

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float d = length(p);
	float edge = 1.0 - smoothstep(1.0 - edge_softness, 1.0, d);
	float center_hole = smoothstep(0.03, 0.18, d);
	float pulse = 1.0 + sin(TIME * 2.2) * pulse_strength;
	ALBEDO = indicator_color.rgb;
	ALPHA = indicator_color.a * edge * center_hole * pulse;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	circle.set_surface_override_material(0, mat)


func _make_ground_texture() -> ImageTexture:
	var image := Image.create(GROUND_TEXTURE_SIZE, GROUND_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(GROUND_TEXTURE_SIZE):
		for x in range(GROUND_TEXTURE_SIZE):
			var wx := float(x) / float(GROUND_TEXTURE_SIZE) * MAP_HALF * 2.0
			var wz := float(y) / float(GROUND_TEXTURE_SIZE) * MAP_HALF * 2.0
			var world_pos := Vector2(wx - MAP_HALF, wz - MAP_HALF)
			var large_n := _smooth_noise((_noise.get_noise_2d(wx, wz) + 1.0) * 0.5)
			var detail_n := (_detail_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
			var zone_color := _grass_zone_color(large_n)
			var detail_dark := (1.0 - smoothstep(0.34, 0.52, detail_n)) * 0.045
			var detail_light := smoothstep(0.58, 0.82, detail_n) * 0.055
			var color := zone_color.lerp(dark_color, detail_dark)
			color = color.lerp(light_color, detail_light)
			var dirt_amount := _dirt_amount(world_pos)
			color = color.lerp(dirt_color, dirt_amount)
			color = color.lerp(dark_color, _fake_ao_amount(world_pos))
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _smooth_noise(value: float) -> float:
	return smoothstep(0.18, 0.86, value)


func _grass_zone_color(large_n: float) -> Color:
	var dark_weight := (1.0 - smoothstep(0.22, 0.52, large_n)) * 0.44
	var light_weight := smoothstep(0.56, 0.88, large_n) * 0.36
	var color := base_color.lerp(dark_color, dark_weight)
	return color.lerp(light_color, light_weight)


func _dirt_amount(pos: Vector2) -> float:
	var path_band := clampf(1.0 - absf(pos.x) / 16.0, 0.0, 1.0) * clampf(1.0 - absf(pos.y) / 82.0, 0.0, 1.0)
	var base_wear := clampf(1.0 - pos.length() / 36.0, 0.0, 1.0)
	var random_raw := (_noise.get_noise_2d(pos.x + 57.0, pos.y - 21.0) + 1.0) * 0.5
	var random_dirt := smoothstep(0.64, 0.90, random_raw)
	var around_objects := 0.0
	for center in _dirt_centers:
		var d := pos.distance_to(center)
		var soft := 1.0 - smoothstep(6.0, 24.0, d)
		around_objects = maxf(around_objects, soft)
	var dirt := maxf(maxf(maxf(path_band * 0.10, base_wear * 0.16), random_dirt * 0.045), around_objects * 0.12)
	return smoothstep(0.0, 1.0, dirt)


func _fake_ao_amount(pos: Vector2) -> float:
	var amount := 0.0
	for center in _object_points:
		var d := pos.distance_to(center)
		var soft := 1.0 - smoothstep(1.5, 8.5, d)
		amount = maxf(amount, soft)
	var low_zone := clampf(0.40 - ((_detail_noise.get_noise_2d(pos.x - 19.0, pos.y + 43.0) + 1.0) * 0.5), 0.0, 0.20)
	return maxf(amount * 0.11, low_zone * 0.10)


func _add_flat_patches() -> void:
	var world := get_parent()
	if world == null:
		return

	var root := Node3D.new()
	root.name = &"TerrainFlatVisualPatches"
	world.add_child(root)

	for i in range(TINT_PATCH_COUNT):
		var pos := _random_safe_visual_point()
		var color := dark_color.lerp(light_color, _rng.randf_range(0.10, 0.62))
		color = color.lerp(dirt_color, _rng.randf_range(0.03, 0.08))
		color.a = _rng.randf_range(0.07, 0.14)
		_add_patch(root, pos, _rng.randf_range(11.0, 24.0), color, float(i) * 0.0004)

	var dirt_points := [
		Vector2(0.0, -12.0),
		Vector2(0.0, 13.0),
		Vector2(12.0, 0.0),
		Vector2(-13.0, 0.0),
		Vector2(18.0, 7.0),
		Vector2(24.0, 0.0),
		Vector2(32.0, -4.0),
		Vector2(40.0, 4.0),
	]
	for i in range(mini(DIRT_PATCH_COUNT, dirt_points.size())):
		var dirt := dirt_color
		dirt.a = 0.16
		_add_patch(root, dirt_points[i], _rng.randf_range(8.0, 15.0), dirt, 0.02 + float(i) * 0.0004)


func _add_patch(parent: Node3D, pos: Vector2, radius: float, color: Color, y_offset: float) -> void:
	var patch := MeshInstance3D.new()
	patch.name = &"FlatTerrainPatch"
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.mesh = _flat_blob_mesh(radius, _rng.randi_range(20, 28))
	patch.position = Vector3(pos.x, 0.018 + y_offset, pos.y)
	patch.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	patch.set_surface_override_material(0, _transparent_unshaded_material(color))
	parent.add_child(patch)


func _flat_blob_mesh(radius: float, points: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	verts.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	for i in range(points):
		var angle := TAU * float(i) / float(points)
		var r := radius * _rng.randf_range(0.72, 1.12)
		verts.append(Vector3(cos(angle) * r, 0.0, sin(angle) * r))
		normals.append(Vector3.UP)

	for i in range(points):
		indices.append(0)
		indices.append(i + 1)
		indices.append(1 if i == points - 1 else i + 2)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _transparent_unshaded_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.roughness = 1.0
	return mat


func _add_sparse_props() -> void:
	var world := get_parent()
	if world == null:
		return

	var root := Node3D.new()
	root.name = &"TerrainNonCollidingProps"
	world.add_child(root)

	var rock_mesh := _rock_mesh()
	var grass_mesh := _grass_mesh()

	for i in range(ROCK_COUNT):
		var p := _random_safe_visual_point()
		var rock := MeshInstance3D.new()
		rock.name = &"DecorRock"
		rock.mesh = rock_mesh
		rock.position = Vector3(p.x, 0.08, p.y)
		rock.rotation_degrees = Vector3(_rng.randf_range(-5.0, 5.0), _rng.randf_range(0.0, 360.0), _rng.randf_range(-5.0, 5.0))
		var s := _rng.randf_range(0.5, 1.2)
		rock.scale = Vector3(s, _rng.randf_range(0.35, 0.7), s * _rng.randf_range(0.75, 1.15))
		rock.set_surface_override_material(0, _rock_material())
		root.add_child(rock)

	for i in range(GRASS_COUNT):
		var p := _random_safe_visual_point()
		var grass := MeshInstance3D.new()
		grass.name = &"DecorGrass"
		grass.mesh = grass_mesh
		grass.position = Vector3(p.x, 0.025, p.y)
		grass.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
		var s := _rng.randf_range(0.65, 1.1)
		grass.scale = Vector3(s, _rng.randf_range(0.8, 1.2), s)
		grass.set_surface_override_material(0, _grass_material())
		root.add_child(grass)


func _random_safe_visual_point() -> Vector2:
	for attempt in range(32):
		var p := Vector2(_rng.randf_range(-DETAIL_HALF, DETAIL_HALF), _rng.randf_range(-DETAIL_HALF, DETAIL_HALF))
		if _is_safe_visual_point(p):
			return p
	return Vector2(_rng.randf_range(-DETAIL_HALF, DETAIL_HALF), _rng.randf_range(-DETAIL_HALF, DETAIL_HALF))


func _is_safe_visual_point(p: Vector2) -> bool:
	if p.length() < 32.0:
		return false
	if p.distance_to(Vector2(14.0, 0.0)) < 18.0:
		return false
	if p.distance_to(Vector2(10.0, 9.5)) < 14.0:
		return false
	if absf(p.x) < 18.0 or absf(p.y) < 18.0:
		return false
	if p.length() > 126.0:
		return false
	return true


func _rock_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.7
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh


func _rock_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.33, 0.33, 0.30).lerp(Color(0.48, 0.45, 0.38), _rng.randf())
	mat.roughness = 0.95
	return mat


func _grass_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var angles := [0.0, TAU / 3.0, TAU * 2.0 / 3.0]

	for angle in angles:
		var right := Vector3(cos(angle), 0.0, sin(angle)) * 0.11
		var forward := Vector3(-sin(angle), 0.0, cos(angle)) * 0.08
		var base := verts.size()
		verts.append(-right)
		verts.append(right)
		verts.append(forward + Vector3(0.0, 0.28, 0.0))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _grass_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = dark_color.lerp(base_color, _rng.randf_range(0.15, 0.75))
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
