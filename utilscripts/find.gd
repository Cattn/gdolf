extends Node
class_name Find

static func find_ball(context: Node) -> RigidBody2D:
	var nodes := context.get_tree().get_nodes_in_group("ball")
	if nodes.size() > 0 and nodes[0] is RigidBody2D:
		return nodes[0]
	var p := context
	while p:
		for child in p.get_children():
			if child is RigidBody2D:
				return child
		p = p.get_parent()
	var scene_root := _get_scene_root(context)
	if scene_root:
		var found := _bfs_find(scene_root, func(n): return n is RigidBody2D)
		if found is RigidBody2D:
			return found
	return null

static func find_aiming_system(context: Node) -> Node:
	var ps := find_player_system(context)
	if ps and ps.has_node("AimingSystem"):
		return ps.get_node("AimingSystem")
	var scene_root := _get_scene_root(context)
	if scene_root:
		var by_group := context.get_tree().get_nodes_in_group("aiming_system")
		if by_group.size() > 0:
			return by_group[0]
		if scene_root.has_node("AimingSystem"):
			return scene_root.get_node("AimingSystem")
		var script := load("res://raycast.gd")
		var found := _bfs_find(scene_root, func(n): return n.get_script() == script)
		if found:
			return found
	return null

static func find_turn_manager(context: Node) -> Node:
	var ps := find_player_system(context)
	if ps:
		if ps.has_node("Turn"):
			return ps.get_node("Turn")
		var found_ps := _bfs_find(ps, func(n): return n.has_method("can_start_shot"))
		if found_ps:
			return found_ps
	var scene_root := _get_scene_root(context)
	if not scene_root:
		return null
	if scene_root.has_node("Turn"):
		return scene_root.get_node("Turn")
	var by_group := context.get_tree().get_nodes_in_group("turn_manager")
	if by_group.size() > 0:
		return by_group[0]
	var found := _bfs_find(scene_root, func(n): return n.has_method("can_start_shot"))
	return found

static func find_camera(context: Node) -> Camera2D:
	var ps := find_player_system(context)
	if ps:
		var found_ps := _bfs_find(ps, func(n): return n is Camera2D)
		if found_ps is Camera2D:
			return found_ps
	var scene_root := _get_scene_root(context)
	if scene_root:
		var by_group := context.get_tree().get_nodes_in_group("player_camera")
		if by_group.size() > 0 and by_group[0] is Camera2D:
			return by_group[0]
		var found := _bfs_find(scene_root, func(n): return n is Camera2D)
		if found is Camera2D:
			return found
	return null

static func find_player_system(context: Node) -> Node:
	var node := context
	while node:
		if node.is_in_group("player_system"):
			return node
		if node.has_node("Turn") or node.has_node("AimingSystem"):
			return node
		node = node.get_parent()
	var scene_root := _get_scene_root(context)
	if not scene_root:
		return null
	var by_group := context.get_tree().get_nodes_in_group("player_system")
	if by_group.size() > 0:
		return by_group[0]
	if scene_root.has_node("PlayerSystem"):
		return scene_root.get_node("PlayerSystem")
	var found := _bfs_find(scene_root, func(n): return n.has_node("Turn") and n.has_node("AimingSystem"))
	return found

static func _get_scene_root(context: Node) -> Node:
	var tree := context.get_tree()
	if not tree:
		return null
	return tree.current_scene

static func _bfs_find(root: Node, predicate: Callable) -> Node:
	var q: Array = [root]
	var i := 0
	while i < q.size():
		var n: Node = q[i]
		if predicate.call(n):
			return n
		for c in n.get_children():
			if c is Node:
				q.append(c)
		i += 1
	return null
