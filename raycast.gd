extends Node2D

@onready var ray = $RayCast2D
@onready var ball = get_parent().get_node("RigidBody2D")  # Reference to ball

func _ready():
	if not ball:
		# Try to find RigidBody2D in the scene
		var scene_root = get_tree().current_scene
		for child in scene_root.get_children():
			if child is RigidBody2D:
				ball = child
				break

@export var line_length: float = 150.0



func _process(_delta):
	if not ray or not ball:
		return
	
	global_position = ball.global_position
	
	var mouse_pos = get_global_mouse_position()
	var direction_vector = mouse_pos - global_position
	
	if direction_vector.length() > 0:
		var dir = direction_vector.normalized()
		ray.target_position = dir * line_length  # Point towards mouse 
	else:
		ray.target_position = Vector2.DOWN * line_length
	
	queue_redraw()

func _draw():
	var mouse_pos = get_global_mouse_position()
	var direction_vector = mouse_pos - global_position
	var end_point: Vector2
	
	if direction_vector.length() > 0:
		var dir = direction_vector.normalized()
		end_point = dir * line_length  
	else:
		end_point = Vector2.DOWN * line_length

	draw_line(Vector2.ZERO, end_point, Color.WHITE, 3) 

	if ray and ray.is_colliding():
		var collision_point = ray.get_collision_point()
		draw_circle(to_local(collision_point), 5, Color.YELLOW)

func get_aim_direction() -> Vector2:
	var mouse_pos = get_global_mouse_position()
	var direction_vector = mouse_pos - global_position
	
	if direction_vector.length() > 0:
		return direction_vector.normalized()  
	else:
		return Vector2.DOWN
