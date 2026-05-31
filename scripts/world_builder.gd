@tool
## Terrain base: ground overlay + hills + road.
## GLB assets are placed manually by the designer into the container nodes below.
extends Node3D

# ─── Road waypoints: south (z+) → base (0,0,0) ────────────────────────────────
const RD_X : Array[float] = [ 10, -14,  16, -10,  13,  -8,   7,   4,   0]
const RD_Z : Array[float] = [132, 108,  88,  68,  52,  38,  24,  10,   0]
const ROAD_HW := 3.0
const ROAD_Y  := 0.06

# ─── Foreground hills (paired east/west flanking road) ─────────────────────────
const FG_X : Array[float] = [ 24,-20,  28,-18,  26,-20,  24,-18,  22,-18,  20,-16,  18,-12]
const FG_Z : Array[float] = [118,116,  96, 96,  76, 76,  58, 56,  42, 40,  28, 26,  13, 12]
const FG_H : Array[float] = [5.0,4.5, 4.5,5.0, 4.0,4.5, 3.5,4.0, 3.5,3.0, 3.0,3.5, 2.5,2.5]
const FG_R : Array[float] = [ 11, 10,  10, 11,   9, 10,   8,  9,   8,  7,   7,  8,   6,  5]

# ─── Midground hills ────────────────────────────────────────────────────────────
const MG_X : Array[float] = [ 55,-55,  65,-62,  70,-68,  75,-72,  45,-45]
const MG_Z : Array[float] = [105,108,  72, 75,  45, 48,  22, 24, 130,128]
const MG_H : Array[float] = [ 13, 14,  12, 14,  11, 12,  10, 11,  12, 11]
const MG_R : Array[float] = [ 20, 21,  19, 20,  17, 18,  16, 17,  18, 18]

# ─── Colors ─────────────────────────────────────────────────────────────────────
const C_GROUND_A := Color(0.32, 0.55, 0.38)
const C_GROUND_B := Color(0.28, 0.50, 0.33)
const C_HILL_BOT := Color(0.24, 0.50, 0.19)
const C_HILL_MID := Color(0.30, 0.55, 0.23)
const C_HILL_TOP := Color(0.36, 0.58, 0.27)
const C_ROAD     := Color(0.65, 0.54, 0.35)
const C_ROAD_EDG := Color(0.54, 0.45, 0.28)


func _ready() -> void:
	_clear_generated()
	_build_hills()
	_build_road()
	_ensure_containers()


# ── Removes previously generated nodes so @tool reruns cleanly ─────────────────
func _clear_generated() -> void:
	for child in get_children():
		if child.get_meta("generated", false):
			child.queue_free()


# ══════════════════════════════════════════════════════════════════════════════
# GROUND OVERLAY
# ══════════════════════════════════════════════════════════════════════════════
func _build_ground_overlay() -> void:
	var st  := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var half := 150.0;  var n := 32
	var step := (half * 2.0) / float(n)
	for gz in n:
		for gx in n:
			var x0 := -half + float(gx)*step;  var z0 := -half + float(gz)*step
			var x1 := x0+step;                  var z1 := z0+step
			var v  := rng.randf_range(-0.025, 0.025)
			var c  := C_GROUND_A.lerp(C_GROUND_B, rng.randf())
			c.r = clampf(c.r+v, 0.0, 1.0)
			c.g = clampf(c.g+v*0.6, 0.0, 1.0)
			st.set_normal(Vector3.UP);  st.set_color(c)
			st.add_vertex(Vector3(x0,0.01,z0)); st.add_vertex(Vector3(x1,0.01,z0)); st.add_vertex(Vector3(x0,0.01,z1))
			st.add_vertex(Vector3(x1,0.01,z0)); st.add_vertex(Vector3(x1,0.01,z1)); st.add_vertex(Vector3(x0,0.01,z1))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true;  mat.roughness = 0.94
	var mi := MeshInstance3D.new()
	mi.name = "GroundOverlay";  mi.mesh = st.commit()
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("generated", true)
	add_child(mi)
	if Engine.is_editor_hint():
		mi.owner = get_tree().edited_scene_root


# ══════════════════════════════════════════════════════════════════════════════
# ROAD
# ══════════════════════════════════════════════════════════════════════════════
func _build_road() -> void:
	var root := Node3D.new()
	root.name = "RoadMesh"
	root.set_meta("generated", true)
	add_child(root)
	if Engine.is_editor_hint():
		root.owner = get_tree().edited_scene_root

	for i in RD_X.size() - 1:
		var p0  := Vector3(RD_X[i],   ROAD_Y, RD_Z[i])
		var p1  := Vector3(RD_X[i+1], ROAD_Y, RD_Z[i+1])
		var dir := (p1 - p0).normalized()
		var rgt := dir.cross(Vector3.UP)

		# Edge strip
		_road_strip(root, p0, p1, rgt, ROAD_HW + 1.2, ROAD_Y - 0.01, C_ROAD_EDG)
		# Road surface
		_road_strip(root, p0, p1, rgt, ROAD_HW, ROAD_Y, C_ROAD)


func _road_strip(parent: Node3D, p0: Vector3, p1: Vector3,
		rgt: Vector3, hw: float, y: float, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o   := Vector3(0.0, y - p0.y, 0.0)
	var v0  := p0+o - rgt*hw;  var v1 := p0+o + rgt*hw
	var v2  := p1+o - rgt*hw;  var v3 := p1+o + rgt*hw
	st.set_normal(Vector3.UP); st.set_color(col)
	st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
	st.add_vertex(v1); st.add_vertex(v3); st.add_vertex(v2)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true; mat.roughness = 0.96
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit(); mi.set_surface_override_material(0, mat)
	mi.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if Engine.is_editor_hint():
		mi.owner = get_tree().edited_scene_root


# ══════════════════════════════════════════════════════════════════════════════
# HILLS
# ══════════════════════════════════════════════════════════════════════════════
func _build_hills() -> void:
	var fg := Node3D.new(); fg.name = "ForegroundHills"; fg.set_meta("generated", true)
	var mg := Node3D.new(); mg.name = "MidgroundHills";  mg.set_meta("generated", true)
	add_child(fg); add_child(mg)
	if Engine.is_editor_hint():
		fg.owner = get_tree().edited_scene_root
		mg.owner = get_tree().edited_scene_root
	for i in FG_X.size():
		var t := float(i) / float(FG_X.size())
		_add_dome(fg, FG_X[i], FG_Z[i], FG_H[i], FG_R[i], C_HILL_BOT.lerp(C_HILL_MID, t))
	for i in MG_X.size():
		_add_dome(mg, MG_X[i], MG_Z[i], MG_H[i], MG_R[i], C_HILL_MID)


func _add_dome(parent: Node3D, x: float, z: float,
		h: float, r: float, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 10;  var rings := 5
	for ring in rings:
		var t0 := float(ring)   / float(rings) * (PI*0.5)
		var t1 := float(ring+1) / float(rings) * (PI*0.5)
		var y0 := sin(t0)*h;  var y1 := sin(t1)*h
		var r0 := cos(t0)*r;  var r1 := cos(t1)*r
		var c0 := col.lerp(C_HILL_TOP, t0/(PI*0.5))
		var c1 := col.lerp(C_HILL_TOP, t1/(PI*0.5))
		for s in seg:
			var a0  := float(s)/float(seg)*TAU;  var a1 := float(s+1)/float(seg)*TAU
			var v00 := Vector3(cos(a0)*r0,y0,sin(a0)*r0); var v10 := Vector3(cos(a1)*r0,y0,sin(a1)*r0)
			var v01 := Vector3(cos(a0)*r1,y1,sin(a0)*r1); var v11 := Vector3(cos(a1)*r1,y1,sin(a1)*r1)
			st.set_color(c0); st.set_normal(_fn(v00,v10,v01))
			st.add_vertex(v00); st.add_vertex(v10); st.add_vertex(v01)
			st.set_color(c1); st.set_normal(_fn(v10,v11,v01))
			st.add_vertex(v10); st.add_vertex(v11); st.add_vertex(v01)
	var tt := float(rings-1)/float(rings)*(PI*0.5)
	var tr := cos(tt)*r;  var ty := sin(tt)*h;  var tp := Vector3(0.0,h,0.0)
	for s in seg:
		var a0 := float(s)/float(seg)*TAU;  var a1 := float(s+1)/float(seg)*TAU
		var v0 := Vector3(cos(a0)*tr,ty,sin(a0)*tr); var v1 := Vector3(cos(a1)*tr,ty,sin(a1)*tr)
		st.set_color(C_HILL_TOP); st.set_normal(_fn(v0,v1,tp))
		st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(tp)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true; mat.roughness = 0.88
	var mi := MeshInstance3D.new()
	mi.name = "Hill"; mi.mesh = st.commit(); mi.position = Vector3(x,0.0,z)
	mi.set_surface_override_material(0, mat)
	parent.add_child(mi)
	if Engine.is_editor_hint():
		mi.owner = get_tree().edited_scene_root


# ══════════════════════════════════════════════════════════════════════════════
# CONTAINER NODES — drag your GLB assets here in the editor
# ══════════════════════════════════════════════════════════════════════════════
func _ensure_containers() -> void:
	var names := ["Mountains", "Trees", "Rocks", "Grass", "Road_Path_B", "Decorations"]
	for n in names:
		if not has_node(n):
			var node := Node3D.new()
			node.name = n
			add_child(node)
			if Engine.is_editor_hint():
				node.owner = get_tree().edited_scene_root


func _fn(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n := (b-a).cross(c-a)
	return n.normalized() if n.length_squared() > 1e-10 else Vector3.UP
