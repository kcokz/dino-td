class_name Avoider
extends RefCounted
## The engine's avoidance (RVO) for one walker, driven through the navigation server as dino-td does it:
## a NavigationAgent3D node answers a zero velocity while it has nowhere to path to, and this field has no
## navigation mesh -- nobody here follows a path, they only keep out of each other's way.

var rid: RID


func _init(owner: Node3D, radius: float, answer: Callable) -> void:
	rid = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_map(rid, owner.get_world_3d().navigation_map)
	NavigationServer3D.agent_set_radius(rid, radius)
	NavigationServer3D.agent_set_neighbor_distance(rid, 14.0)
	NavigationServer3D.agent_set_max_neighbors(rid, 12)
	NavigationServer3D.agent_set_time_horizon_agents(rid, 0.6)
	NavigationServer3D.agent_set_time_horizon_obstacles(rid, 0.4)
	NavigationServer3D.agent_set_avoidance_callback(rid, answer)
	NavigationServer3D.agent_set_avoidance_enabled(rid, true)
	NavigationServer3D.agent_set_position(rid, owner.global_position)
	owner.tree_exiting.connect(release)


## Where it is and where it would like to go; the answer comes to the callback. Never faster than asked:
## at full speed the solver shoves a slow walker along at twice its pace (dino-td, v0.6).
func ask(at: Vector3, wanted: Vector3) -> void:
	if not rid.is_valid():
		return
	NavigationServer3D.agent_set_position(rid, at)
	NavigationServer3D.agent_set_max_speed(rid, maxf(0.01, wanted.length()))
	NavigationServer3D.agent_set_velocity(rid, wanted)


## Out of the others' way for good: it died.
func release() -> void:
	if rid.is_valid():
		NavigationServer3D.free_rid(rid)
		rid = RID()
