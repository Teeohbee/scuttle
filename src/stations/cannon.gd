extends Station

signal fired(damage: float)

enum Phase { EMPTY, POWDERED, LOADED, RUN_OUT, COOLDOWN }

const RUN_OUT_HOLD_TIME := 0.8
const COOLDOWN_TIME := 1.5
const DAMAGE := 8.0

const PHASE_COLORS := {
	Phase.EMPTY:    Color(0.35, 0.35, 0.35),   # grey  - needs powder
	Phase.POWDERED: Color(0.85, 0.55, 0.15),   # amber - needs shot
	Phase.LOADED:   Color(0.90, 0.85, 0.20),   # yellow- needs ramming
	Phase.RUN_OUT:  Color(0.30, 0.85, 0.35),   # green - ready to fire
	Phase.COOLDOWN: Color(0.60, 0.20, 0.20),   # red   - too hot
}

var phase: Phase = Phase.EMPTY
var _run_out_elapsed := 0.0
var _cooldown_elapsed := 0.0

@onready var _light: ColorRect = $PhaseLight

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("cannons")
	_set_phase(Phase.EMPTY)

func _set_phase(next: Phase) -> void:
	phase = next
	_light.color = PHASE_COLORS[phase]

func _physics_process(delta: float) -> void:
	match phase:
		Phase.LOADED:
			_tick_run_out(delta)
		Phase.COOLDOWN:
			_cooldown_elapsed += delta
			if _cooldown_elapsed >= COOLDOWN_TIME:
				_cooldown_elapsed = 0.0
				_set_phase(Phase.EMPTY)

func _tick_run_out(delta: float) -> void:
	var holding_bare_hands := false
	for crew in get_tree().get_nodes_in_group("crew"):
		if crew_is_near(crew) and crew.held_item == null and PlayerRegistry.is_interact_pressed(crew.device_id):
			holding_bare_hands = true
			break
	if holding_bare_hands:
		_run_out_elapsed += delta
		if _run_out_elapsed >= RUN_OUT_HOLD_TIME:
			_run_out_elapsed = 0.0
			_set_phase(Phase.RUN_OUT)
	else:
		_run_out_elapsed = 0.0

func claims_interact(crew: Node2D) -> bool:
	if not crew_is_near(crew):
		return false
	match phase:
		Phase.EMPTY:
			return crew.held_item != null and crew.held_item.kind == Carryable.Kind.POWDER
		Phase.POWDERED:
			return crew.held_item != null and crew.held_item.kind == Carryable.Kind.SHOT
		Phase.RUN_OUT:
			return true
		_:
			return false

func perform_interact(crew: Node2D) -> void:
	match phase:
		Phase.EMPTY:
			crew.held_item.queue_free()
			crew.held_item = null
			_set_phase(Phase.POWDERED)
		Phase.POWDERED:
			crew.held_item.queue_free()
			crew.held_item = null
			_set_phase(Phase.LOADED)
		Phase.RUN_OUT:
			_set_phase(Phase.COOLDOWN)
			fired.emit(DAMAGE)
