extends Node2D
const Find = preload("res://utilscripts/find.gd")

@onready var ray = $RayCast2D
@onready var ball = Find.find_ball(self)  # Reference to ball

func _ready():
	if not ball:
		ball = Find.find_ball(self)

@export var line_length: float = 150.0



func _process(_delta):
	if not ray:
		return
	ball = Find.find_ball(self)
	if not ball:
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
		
		draw_power_bar()
	else:
		end_point = Vector2.DOWN * line_length

	draw_line(Vector2.ZERO, end_point, Color.WHITE, 3) 

	if ray and ray.is_colliding():
		var collision_point = ray.get_collision_point()
		draw_circle(to_local(collision_point), 5, Color.YELLOW)

func draw_power_bar():
	if not ball or not ball.has_method("get_current_power"):
		return
		
	var power_level = ball.get_current_power()
	if power_level <= 0:
		return
	
	# Power bar properties
	var max_bar_length = 60.0
	var cursor_offset = Vector2(30.0, 0.0)  # Fixed offset to the right of cursor
	var bar_thickness = 4.0
	
	# Get cursor position relative to ball
	var mouse_pos = get_global_mouse_position()
	var cursor_local = to_local(mouse_pos)
	
	# Position bar to the right of cursor
	var bar_start = cursor_local + cursor_offset
	var bar_length = power_level * max_bar_length
	var bar_end = bar_start + Vector2(0.0, bar_length)  # Vertical bar
	
	# Color changes from green to red based on power
	var power_color = Color.GREEN.lerp(Color.RED, power_level)
	
	# Draw the power bar
	draw_line(bar_start, bar_end, power_color, bar_thickness)
	
	# Draw a background line to show max power
	var max_end = bar_start + Vector2(0.0, max_bar_length)
	draw_line(bar_start, max_end, Color.GRAY, 2.0)

func get_aim_direction() -> Vector2:
	var mouse_pos = get_global_mouse_position()
	var direction_vector = mouse_pos - global_position
	
	if direction_vector.length() > 0:
		return direction_vector.normalized()  
	else:
		return Vector2.DOWN
