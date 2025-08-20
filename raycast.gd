extends Node2D
const Find = preload("res://utilscripts/find.gd")

@onready var ray = $RayCast2D
@onready var ball = Find.find_ball(self)
@onready var turn_manager: Node = Find.find_turn_manager(self)
@onready var tex_yes: Texture2D = load("res://Ball/YesBall.png")
@onready var tex_no: Texture2D = load("res://Ball/NoBall.png")

func _ready():
	if not ball:
		ball = Find.find_ball(self)
	if not turn_manager:
		turn_manager = Find.find_turn_manager(self)

@export var line_length: float = 150.0



func _process(_delta):
	if not ray:
		return
	ball = Find.find_ball(self)
	if not turn_manager:
		turn_manager = Find.find_turn_manager(self)
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

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var can_shoot := _can_shoot()
		var icon := tex_yes if can_shoot else tex_no
		if icon:
			var cursor_local = to_local(mouse_pos)
			var icon_pos = cursor_local + Vector2(20.0, -20.0)
			var icon_size = Vector2(icon.get_width(), icon.get_height()) / 3.0
			draw_texture_rect(icon, Rect2(icon_pos, icon_size), false)

func draw_power_bar():
	if not ball or not ball.has_method("get_current_power"):
		return
		
	var power_level = ball.get_current_power()
	if power_level <= 0:
		return
	
	# hit power bar
	var max_bar_length = 60.0
	var cursor_offset = Vector2(30.0, 0.0) 
	var bar_thickness = 4.0
	
	var mouse_pos = get_global_mouse_position()
	var cursor_local = to_local(mouse_pos)
	
	var bar_start = cursor_local + cursor_offset
	var bar_length = power_level * max_bar_length
	var bar_end = bar_start + Vector2(0.0, bar_length) 
	
	var power_color = Color.GREEN.lerp(Color.RED, power_level)
	
	draw_line(bar_start, bar_end, power_color, bar_thickness)
	
	var max_end = bar_start + Vector2(0.0, max_bar_length)
	draw_line(bar_start, max_end, Color.GRAY, 2.0)

func get_aim_direction() -> Vector2:
	var mouse_pos = get_global_mouse_position()
	var direction_vector = mouse_pos - global_position
	
	if direction_vector.length() > 0:
		return direction_vector.normalized()  
	else:
		return Vector2.DOWN

func _can_shoot() -> bool:
	if not ball:
		return false
	if turn_manager and turn_manager.has_method("can_start_shot"):
		return turn_manager.can_start_shot()
	var lin_ok: bool = ball.linear_velocity.length() <= 0.1
	var ang_ok: bool = abs(ball.angular_velocity) <= 0.1
	return lin_ok and ang_ok
