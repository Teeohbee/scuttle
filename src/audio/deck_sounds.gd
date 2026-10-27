class_name DeckSounds
extends Node
# The deck's sound effects. Like View3D it only ever reads 2D state: it listens to the signals the deck
# already has, and watches a few things change from one frame to the next (what each crab is carrying,
# each cannon's phase, how much is burning, whether the pump is being worked).

const PUMP_STROKE := 0.55   # seconds between pump sounds while it's worked
const CRACKLE_QUIET_DB := -14.0   # one burning cell
const CRACKLE_FULL_CELLS := 8     # this many and the crackle is at full volume

@export var fire: FireHazard
@export var enemy: EnemyShip

var _carrying := {}   # crab -> the Carryable.Kind it held last frame, or -1 for nothing
var _phases := {}     # cannon -> its phase last frame
var _burning := 0
var _next_pump_stroke := 0.0
var _crackle := AudioStreamPlayer.new()

func _ready() -> void:
	_crackle.stream = Sound.stream_for("crackle")
	add_child(_crackle)
	enemy.fired.connect(Sound.play.bind("distant_cannon"))
	enemy.broadside_landed.connect(Sound.play.bind("crash"))
	fire.fuse_lit.connect(Sound.play.bind("bell"))
	fire.fuse_out.connect(Sound.play.bind("phew"))
	for cannon in get_tree().get_nodes_in_group("cannons"):
		cannon.fired.connect(func(_damage: float) -> void: Sound.play("cannon"))
		_phases[cannon] = cannon.phase
	# GameState outlives the deck, so these are methods, not lambdas: Godot drops a method's connection
	# when its node is freed.
	GameState.won.connect(_on_won)
	GameState.lost.connect(_on_lost)

func _physics_process(_delta: float) -> void:
	_listen_to_crabs()
	_listen_to_cannons()
	_listen_to_fire()
	_listen_to_pumps()

func _listen_to_crabs() -> void:
	for crab in get_tree().get_nodes_in_group("crew"):
		var now: int = crab.held_item.kind if crab.held_item else -1
		var before: int = _carrying.get(crab, -1)
		_carrying[crab] = now
		if now == before:
			continue
		if before == -1:
			Sound.play("pick_up")
		elif now == -1:
			Sound.play("drop")
		elif before == Carryable.Kind.BUCKET_EMPTY and now == Carryable.Kind.BUCKET_WATER:
			Sound.play("fill")

func _listen_to_cannons() -> void:
	for cannon in get_tree().get_nodes_in_group("cannons"):
		var before = _phases[cannon]
		_phases[cannon] = cannon.phase
		if cannon.phase == before:
			continue
		match cannon.phase:
			cannon.Phase.POWDERED: Sound.play("powder")
			cannon.Phase.LOADED: Sound.play("shot")
			cannon.Phase.RUN_OUT: Sound.play("run_out")

# One sound per frame however many cells changed, so a bucket's splash doesn't hiss five times over.
func _listen_to_fire() -> void:
	var burning := fire.burning_cells().size()
	if burning > _burning:
		Sound.play("whoosh")
	elif burning < _burning:
		Sound.play("hiss")
	_burning = burning
	if burning == 0:
		_crackle.stop()
		return
	var share := minf(float(burning) / CRACKLE_FULL_CELLS, 1.0)
	_crackle.volume_db = lerpf(CRACKLE_QUIET_DB, 0.0, sqrt(share))
	if not _crackle.playing:
		_crackle.play()

func _listen_to_pumps() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for pump in get_tree().get_nodes_in_group("stations"):
		if pump is Pump and pump.manned and now >= _next_pump_stroke:
			Sound.play("pump")
			_next_pump_stroke = now + PUMP_STROKE

func _on_won() -> void:
	Sound.play("victory")

func _on_lost(_reason: String) -> void:
	Sound.play("defeat")
