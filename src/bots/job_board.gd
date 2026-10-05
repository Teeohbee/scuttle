class_name JobBoard
extends Node
# Shares the work out between the bots, so five of them don't all run for powder.
# Fires come first - one bot for every two burning cells - then a bot per
# cannon, and anyone left over joins the fire. Bots keep the job they have where
# they can: a gunner halfway back with a keg isn't pulled off to fight a
# one-cell fire.

const REVIEW_INTERVAL := 0.25
const CELLS_PER_FIREFIGHTER := 2.0

var fire: FireHazard

var _pilots: Array = []
var _jobs := {} # pilot -> { kind: "fire" | "cannon", cannon }
var _review_in := 0.0

func enlist(pilot: Node) -> void:
	_pilots.append(pilot)

func job_for(pilot: Node) -> Dictionary:
	return _jobs.get(pilot, {})

func _physics_process(delta: float) -> void:
	_review_in -= delta
	if _review_in > 0.0:
		return
	_review_in = REVIEW_INTERVAL
	_review()

func _review() -> void:
	var burning := fire.burning_cells()
	var free: Array = _pilots.duplicate()
	var next := {}

	var firefighters := 0
	if not burning.is_empty():
		firefighters = mini(free.size(), ceili(burning.size() / CELLS_PER_FIREFIGHTER))
	# Whoever's already on the fire stays on it, then the nearest empty-handed.
	free.sort_custom(func(a, b): return _fire_fitness(a, burning) < _fire_fitness(b, burning))
	for i in firefighters:
		next[free[i]] = {"kind": "fire"}
	free = free.slice(firefighters)

	var cannons := get_tree().get_nodes_in_group("cannons").filter(_free_cannon)
	# Gunners keep their own gun.
	for pilot in free.duplicate():
		var job: Dictionary = _jobs.get(pilot, {})
		if job.get("kind") == "cannon" and cannons.has(job.cannon):
			next[pilot] = job
			cannons.erase(job.cannon)
			free.erase(pilot)
	for pilot in free:
		if cannons.is_empty():
			break
		var nearest = cannons[0]
		for cannon in cannons:
			if _dist(pilot, cannon) < _dist(pilot, nearest):
				nearest = cannon
		next[pilot] = {"kind": "cannon", "cannon": nearest}
		cannons.erase(nearest)
	if not burning.is_empty():
		for pilot in free:
			if not next.has(pilot):
				next[pilot] = {"kind": "fire"}
	_jobs = next

# Lower is a better pick for the fire.
func _fire_fitness(pilot: Node, burning: Array) -> float:
	var job: Dictionary = _jobs.get(pilot, {})
	if job.get("kind") == "fire":
		return -1.0
	var crew: Node2D = pilot.get_parent()
	var nearest := INF
	for cell in burning:
		nearest = minf(nearest, crew.global_position.distance_to(fire.world_of(cell)))
	var item = crew.held_item
	if item and (item.kind == Carryable.Kind.POWDER or item.kind == Carryable.Kind.SHOT):
		nearest += 1000.0
	return nearest

func _free_cannon(_cannon: Node) -> bool:
	return true

func _dist(pilot: Node, node: Node2D) -> float:
	return pilot.get_parent().global_position.distance_to(node.global_position)
