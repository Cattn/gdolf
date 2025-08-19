extends RigidBody2D

@onready var aiming_system = get_parent().get_node("AimingSystem")  # Reference to separate aiming node
@export var hit_power: float = 500.0

func hit_ball():
	if aiming_system and aiming_system.has_method("get_aim_direction"):
		var hit_direction = aiming_system.get_aim_direction()
		var impulse = hit_direction * hit_power
		apply_central_impulse(impulse)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			hit_ball()
