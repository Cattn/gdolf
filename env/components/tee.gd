extends Area2D

const FindUtils = preload("res://utilscripts/find.gd")

signal ball_entered_tee(ball: RigidBody2D)

@onready var turn_manager: Node = null
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	turn_manager = FindUtils.find_turn_manager(self)
	
	if animation_player:
		animation_player.play("bob")

func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and body.get_script() != null:
		var ball_script = load("res://Ball/ball.gd")
		if body.get_script() == ball_script:
			print("Ball entered tee!")
			ball_entered_tee.emit(body)
			_handle_ball_at_tee(body)

func _on_body_exited(body: Node2D) -> void:
	if body is RigidBody2D and body.get_script() != null:
		var ball_script = load("res://Ball/ball.gd")
		if body.get_script() == ball_script:
			print("Ball left tee!")

func _handle_ball_at_tee(ball: RigidBody2D) -> void:
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	
	ball.global_position = global_position
	
	visible = false
	
	collision_layer = 0
	collision_mask = 0
	
	if turn_manager and turn_manager.has_method("notify_ball_at_tee"):
		turn_manager.notify_ball_at_tee(ball)
