extends StaticBody2D

var _win_area: Area2D = null
var _triggered: bool = false

func _ready() -> void:
	var node := get_node_or_null("WinDetection")
	if node is Area2D:
		_win_area = node
		_win_area.monitoring = true
		_win_area.monitorable = true
		_win_area.collision_mask = -1
		_win_area.body_entered.connect(_on_body_entered)
		return
	var det: CollisionShape2D = node
	if det:
		det.set_deferred("disabled", true)
		_win_area = Area2D.new()
		add_child(_win_area)
		_win_area.position = det.position
		_win_area.monitoring = true
		_win_area.monitorable = true
		_win_area.collision_mask = -1
		var cs := CollisionShape2D.new()
		_win_area.add_child(cs)
		cs.shape = det.shape
		_win_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if body is RigidBody2D:
		_triggered = true
		get_tree().change_scene_to_file("res://utilscripts/win_screen.tscn")

func _physics_process(_delta: float) -> void:
	if _triggered:
		return
	if _win_area:
		var bodies := _win_area.get_overlapping_bodies()
		for b in bodies:
			if b is RigidBody2D:
				_triggered = true
				get_tree().change_scene_to_file("res://utilscripts/win_screen.tscn")
				return
