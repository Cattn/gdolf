extends Camera2D
const Find = preload("res://utilscripts/find.gd")

@export var x_follow_speed: float = 5.0
@export var x_offset: float = 0.0
@export var y_lerp_speed: float = 5.0
@export var y_deadzone: float = 40.0
@export var y_step: float = 80.0
@export var y_snap_threshold: float = 200.0
@export var y_step_cooldown_time: float = 0.15

@onready var ball: RigidBody2D = Find.find_ball(self)

var initial_y: float = 0.0
var target_y: float = 0.0
var step_cooldown_remaining: float = 0.0

func _ready() -> void:
	enabled = true
	initial_y = global_position.y
	target_y = initial_y
	if not ball:
		ball = Find.find_ball(self)

func _process(delta: float) -> void:
	ball = Find.find_ball(self)
	if not ball:
		return
	step_cooldown_remaining = max(step_cooldown_remaining - delta, 0.0)
	var target_x: float = ball.global_position.x + x_offset
	var new_x: float = lerp(global_position.x, target_x, clamp(x_follow_speed * delta, 0.0, 1.0))
	var y_diff_to_target: float = ball.global_position.y - target_y
	if absf(y_diff_to_target) >= y_snap_threshold:
		target_y = ball.global_position.y
	else:
		if y_diff_to_target < -y_deadzone and step_cooldown_remaining <= 0.0:
			target_y -= y_step
			step_cooldown_remaining = y_step_cooldown_time
	var new_y: float = lerp(global_position.y, target_y, clamp(y_lerp_speed * delta, 0.0, 1.0))
	global_position = Vector2(new_x, new_y)


