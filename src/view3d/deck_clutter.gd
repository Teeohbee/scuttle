class_name DeckClutter
extends MeshInstance3D
# The odds and ends of a working deck that aren't any room's cargo. None of it stands on a tile you
# can walk on: what's solid sits on the rail or on wall tiles, so the 2D rule holds that what you
# can't walk through is what you can see. All of it is one mesh.

const HAMMOCK_RADIUS := 0.13
const HAMMOCK_LENGTH := 0.55
const HAMMOCK_GAP := 0.05
const RAIL_TOP := View3D.BULWARK_HEIGHT + 0.07

var _hammocks: Array[Vector3] = []

func _init(view: View3D) -> void:
	var st := MeshKit.begin()
	_stow_hammocks(st, view)
	mesh = MeshKit.commit(st)

# The middle of every rolled hammock.
func hammocks() -> Array[Vector3]:
	return _hammocks

# Where the rats run: along the tops of the hammocks.
static func hammock_top() -> float:
	return RAIL_TOP + HAMMOCK_RADIUS * 2.0

# Hammocks rolled and lashed along the rail top, the way a fighting ship stowed them, on every
# straight run of rail between the gun ports.
func _stow_hammocks(st: SurfaceTool, view: View3D) -> void:
	var along_x := Basis(Vector3.BACK, -PI / 2)   # the rolls lie fore and aft
	var pitch := HAMMOCK_LENGTH + HAMMOCK_GAP
	for run in view.rail_runs():
		var count := floori((run.y - run.x + HAMMOCK_GAP) / pitch)
		var from := (run.x + run.y - count * pitch + HAMMOCK_GAP) / 2.0
		for k in count:
			var centre := Vector3(from + k * pitch + HAMMOCK_LENGTH / 2.0, RAIL_TOP + HAMMOCK_RADIUS, run.z)
			var shade := DeckDresser.CANVAS.darkened(0.15 + 0.07 * ((k * 7 + int(run.x)) % 3))
			MeshKit.cylinder(st, centre - Vector3(HAMMOCK_LENGTH / 2.0, 0, 0), HAMMOCK_RADIUS, HAMMOCK_LENGTH, 8, shade, along_x)
			for u in [-0.3, 0.3]:
				MeshKit.torus(st, centre + Vector3(u * HAMMOCK_LENGTH, 0, 0), HAMMOCK_RADIUS + 0.005, 0.015, DeckDresser.ROPE, along_x, 8)
			_hammocks.append(centre)
