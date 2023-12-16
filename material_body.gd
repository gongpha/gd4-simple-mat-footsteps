extends Node3D
class_name MaterialBody

const MATBODY_PHYSICS_LAYER := 1 << 1 # layer 2

var meshlib : Dictionary # < Mesh, [each surface convex] >
var meshins : Array[MeshInstance3D]

func _ready() -> void :
	generate_matbody()
	
func _iterate_mesh(n : Node) -> void :
	if n is MeshInstance3D :
		var mesh : Mesh = n.mesh
		
		if !meshlib.has(mesh) :
			_add_mesh(mesh)
		meshins.append(n)
		
	for c in n.get_children() :
		_iterate_mesh(c)
	
func generate_matbody() -> void :
	_iterate_mesh(self)
	
	var static_body : StaticBody3D
	if !meshins.is_empty() :
		static_body = StaticBody3D.new()
		static_body.collision_layer = MATBODY_PHYSICS_LAYER
		static_body.name = &"_matbody_"
		
		for m in meshins :
			var cc : Array[ConcavePolygonShape3D] = meshlib[m.mesh]
			for i in m.get_surface_override_material_count() :
				var mat := m.material_override
				if !mat :
					mat = m.get_surface_override_material(i)
					if !mat :
						mat = m.mesh.surface_get_material(i)
						if !mat :
							continue
						continue
						
				var shape := CollisionShape3D.new()
				shape.transform = global_transform.affine_inverse() * m.global_transform
				shape.shape = cc[i]
				shape.set_meta(&'mb_mat', mat)
				static_body.add_child(shape)
				
		add_child(static_body)
	
	meshlib.clear()
	meshins.clear()
	
func _add_mesh(mesh : Mesh) -> void :
	var arrcc : Array[ConcavePolygonShape3D]
	
	var rmesh := mesh
	if rmesh is PrimitiveMesh :
		var amesh := ArrayMesh.new()
		amesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			mesh.get_mesh_arrays()
		)
		rmesh = amesh
	
	for i in rmesh.get_surface_count() :
		var pv3 : PackedVector3Array
		
		var mdts := MeshDataTool.new()
		mdts.create_from_surface(rmesh, i)
		
		var V := mdts.get_vertex
		var F := mdts.get_face_vertex
		
		var cursor := pv3.size()
		pv3.resize(pv3.size() + mdts.get_face_count() * 3)
		for j in mdts.get_face_count() :
			for k in 3 :
				pv3[cursor + (j * 3) + k] = V.call(
					F.call(j, k)
				)
				
		var concave := ConcavePolygonShape3D.new()
		concave.set_faces(pv3)
		
		arrcc.append(concave)
		
	meshlib[mesh] = arrcc
