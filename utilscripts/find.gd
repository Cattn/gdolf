extends Node
class_name Find

static func find_ball(context: Node) -> RigidBody2D:
	var nodes := context.get_tree().get_nodes_in_group("ball")
	if nodes.size() > 0 and nodes[0] is RigidBody2D:
		return nodes[0]
	if context.get_parent() and context.get_parent().has_node("RigidBody2D"):
		var n = context.get_parent().get_node("RigidBody2D")
		if n is RigidBody2D:
			return n
	var scene_root = context.get_tree().current_scene
	if scene_root:
		for child in scene_root.get_children():
			if child is RigidBody2D:
				return child
	return null

static func find_aiming_system(context: Node) -> Node:
	if context.get_parent() and context.get_parent().has_node("AimingSystem"):
		return context.get_parent().get_node("AimingSystem")
	var scene_root = context.get_tree().current_scene
	if scene_root and scene_root.has_node("AimingSystem"):
		return scene_root.get_node("AimingSystem")
	return null

static func find_turn_manager(context: Node) -> Node:
	var scene_root = context.get_tree().current_scene
	if not scene_root:
		return null
	for child in scene_root.get_children():
		if child.name == "Turn" or child.has_method("can_start_shot"):
			return child
	return null
