extends Camera2D

@export var x_follow_speed: float = 5.0
@export var x_offset: float = 0.0

@onready var ball: RigidBody2D = get_parent().get_node("RigidBody2D")

var initial_y: float = 0.0

func _ready() -> void:
	enabled = true
	initial_y = global_position.y
	if not ball:
		var scene_root = get_tree().current_scene
		for child in scene_root.get_children():
			if child is RigidBody2D:
				ball = child
				break

func _process(delta: float) -> void:
	if not ball:
		return
	var target_x: float = ball.global_position.x + x_offset
	var new_x: float = lerp(global_position.x, target_x, clamp(x_follow_speed * delta, 0.0, 1.0))
	global_position = Vector2(new_x, initial_y)
