# Godot 4 Simple Material-Based Footsteps

This Godot project contains the class `MaterialBody`, a helper class that bakes a special `StaticBody` for detecting a specific material on surfaces.

# Usage
Attach the script `material_body.gd` to any Node3D you want to have a detectable surface e.g. level node/scene.

# Detecting
You can use any physics nodes for detecting collision objects, whether Area3D, RayCast3D, or ShapeCast3D with the `collision_mask` bit corresponding to the constant variable `MATBODY_PHYSICS_LAYER` value in `matbody.gd`. The metadata `mb_mat` inside detected `CollisionShape3D` will tell the material.

In this project, I used Layer 2 (`1 << 1`)

## Ray casting example
```gdscript
func _physics_process(delta : float) -> void :
	# Get collided object
	var body : CollisionObject3D = raycast3d.get_collider()
	# Get the shape index
	var shapeidx : int = raycast3d.get_collider_shape()
	# Get CollisionShape3D object
	var shape : CollisionShape3D = body.shape_owner_get_owner(shapeidx)
	# Check if the CollisionShape3D node has information from MaterialBody
	if shape.has_meta('mb_mat') :
		# Detected a material
		var mat : Material = shape.get_meta('mb_mat')
		# ...do something...
```

---

[![vid](http://img.youtube.com/vi/yzxTWFJ7uwM/0.jpg)](http://www.youtube.com/watch?v=yzxTWFJ7uwM)
