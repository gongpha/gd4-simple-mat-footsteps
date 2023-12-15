extends CharacterBody3D
class_name Character

@export var max_speed : float = 7
@export var max_air_speed : float = 0.25
@export var accel : float = 100
@export var fric : float = 8
@export var sensitivity : float = 0.0025
@export var stairstep := 0.6
@export var gravity : float = 20
@export var jump_up : float = 7.6

var noclip : bool = false

@onready var around : Node3D = $around
@onready var head : Node3D = $around/head
@onready var camera : Camera3D = $around/head/cam
@onready var staircast : ShapeCast3D = $staircast
@onready var sound : AudioStreamPlayer3D = $sound
@onready var floorray : Marker3D = %floorray

var wishdir : Vector3
var wish_jump : bool = false
var auto_jump : bool = true
var smooth_y : float

var stepped : float = 0

func _ready() -> void :
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
func accelerate(in_speed : float, delta : float) -> void :
	velocity += wishdir * (
		clampf(in_speed - velocity.dot(wishdir), 0, accel * delta)
	)

func friction(delta : float) -> void :
	var speed : float = velocity.length()
	var svec : Vector3
	if speed > 0 :
		svec = velocity * maxf(speed - (
			fric * speed * delta
		), 0) / speed
	if speed < 0.1 :
		svec = Vector3.ZERO
	velocity = svec
	
func ray(
	start : Vector3, add : Vector3,
	col : int = 0b000111
) -> Dictionary :
	var w3d := get_world_3d()
	var dss := w3d.direct_space_state
	var d := dss.intersect_ray(PhysicsRayQueryParameters3D.create(
		start, start + add, col#, [byobj]
	))
	return d
	
func ray_matbody(
	start : Vector3, add : Vector3,
	dict : Dictionary = {}
) -> Material :
	var dictn := ray(start, add, MaterialBody.MATBODY_PHYSICS_LAYER)
	if dictn.is_empty() : return null
	
	dict.merge(dictn)
	
	var body : CollisionObject3D = dict["collider"]
	var shapeidx : int = dict["shape"]
	var shape := body.shape_owner_get_owner(shapeidx)
	if !shape.has_meta(&'mb_mat') : return null
	return shape.get_meta(&'mb_mat')
	
func teststep(jump : bool) -> void :
	var dict : Dictionary
	var mat := ray_matbody(
		floorray.global_position + Vector3(0, 0.01, 0),
		Vector3(0, -0.1, 0),
		dict
	)
	
	if mat and mat.has_meta(&'soundpack') :
		var sndpack = mat.get_meta(&'soundpack')
		if sndpack is MatSoundPack :
			if jump :
				sound.stream = sndpack.jump
			else :
				sound.stream = sndpack.footstep
			sound.play()

func move_ground(delta : float) -> void :
	friction(delta)
	accelerate(max_speed, delta)
	
	stepped += delta * Vector2(velocity.x, velocity.z).length()
	if stepped >= 1 :
		# test
		teststep(false)
		
		stepped = 0
	
	_stairs(delta)
	
	move_and_slide()
	
	# test ceiling
	staircast.target_position.y = 0.66 + stairstep
	staircast.force_shapecast_update()
	if staircast.get_collision_count() == 0 :
		staircast.target_position.y = -stairstep # (?)
		staircast.force_shapecast_update()
		if staircast.get_collision_count() > 0 and staircast.get_collision_normal(0).y >= 0.8 :
			var height := staircast.get_collision_point(0).y - (global_position.y - 0.75)
			if height < stairstep :
				position.y += height * 1.125 # additional bonus
				smooth_y = -height
				around.position.y += smooth_y
				# 0.688 is an initial value of around.y
	
func _stairs(delta : float) :
	var w := (velocity / max_speed) * Vector3(2.0, 0.0, 2.0) * delta
	var ws := w * max_speed
	
	# stair stuffs
	var shape : BoxShape3D = staircast.shape
	shape.size = Vector3(
		1.0 + ws.length(), shape.size.y, 1.0 + ws.length()
	)
	
	staircast.position = Vector3(
		ws.x, 0.175 + stairstep - 0.75, ws.z
	)

func move_air(delta : float) -> void :
	accelerate(max_air_speed, delta)
	_stairs(delta)
	move_and_slide()

func _physics_process(delta : float) -> void :
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED :
		return
		
	wishdir = (head if noclip else around).global_transform.basis * Vector3((
		Input.get_axis(&"move_left", &"move_right")
	), 0, (
		Input.get_axis(&"move_forward", &"move_back")
	)).normalized()
	
	if auto_jump :
		wish_jump = Input.is_action_pressed(&"jump")
	else :
		if !wish_jump and Input.is_action_just_pressed(&"jump") :
			wish_jump = true
		if Input.is_action_just_released(&"jump") :
			wish_jump = false
	
	if is_on_floor() :
		if wish_jump :
			teststep(true)
			velocity.y = jump_up
			move_air(delta)
			wish_jump = false
		else :
			velocity.y = 0
			move_ground(delta)
	else :
		velocity.y -= gravity * delta
		move_air(delta)
	
	if is_zero_approx(smooth_y) :
		smooth_y = 0.0
	else :
		#print(smooth_y)
		smooth_y /= 1.125
		around.position.y = smooth_y + 0.688
	#Engine.time_scale = 0.2
		
func _input(event : InputEvent) -> void :
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED :
		return
	
	if event is InputEventMouseMotion :
		var r : Vector2 = event.relative * -1
		head.rotate_x(r.y * sensitivity)
		around.rotate_y(r.x * sensitivity)
		
		var hrot = head.rotation
		hrot.x = clampf(hrot.x, -PI/2, PI/2)
		head.rotation = hrot
